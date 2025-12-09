#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: users.rb [options]"

  opts.on("-c", "--cache", "Flush caches for users that have received updates to claims/attributions in last day") do
    options[:cache] = true
  end

  opts.on("-p", "--poll-orcid", "Poll ORCID for new accounts") do
    options[:poll_orcid] = true
  end

  opts.on("-w", "--poll-wikidata", "Poll wikidata for new accounts") do
    options[:poll_wikidata] = true
  end

  opts.on("-o", "--orcid [ORCID]", String, "Add/update user with an ORCID") do |orcid|
    options[:orcid] = orcid
  end

  opts.on("-k", "--wikidata [WIKIDATA]", String, "Add/update user with a Wikidata identifier") do |wikidata|
    options[:wikidata] = wikidata
  end

  opts.on("-f", "--file [FILE]", String, "Import users using a csv with a single column of either wikidata or ORCID numbers") do |file|
    options[:file] = file
  end

  opts.on("-l", "--logged-in", "Update ORCID data for user accounts that have logged in.") do
    options[:logged] = true
  end

  opts.on("-i", "--public", "Update all public accounts") do
    options[:public] = true
  end

  opts.on("-u", "--update-orcid", "Update all ORCID accounts.") do
    options[:update_orcid] = true
  end

  opts.on("-v", "--update-wikidata", "Update all wikidata accounts.") do
    options[:update_wikidata] = true
  end

  opts.on("-x", "--modified-wikidata", "Update all wikidata accounts that were modified within last 24hrs") do
    options[:modified_wikidata] = true
  end

  opts.on("-a", "--all", "Update all user accounts.") do
    options[:all] = true
  end

  opts.on("-m", "--claimed", "Update all user accounts that have claimed a specimen.") do
    options[:claimed] = true
  end

  opts.on("-d", "--duplicates", "Merge duplicate wikidata accounts.") do
    options[:duplicates] = true
  end

  opts.on("-z", "--missing-wikidata", "Find wikidata entries that were deleted at the source.") do
    options[:deleted] = true
  end

  opts.on("-r", "--flagged-deletion", "Find wikidata entries that have been flagged for deletion") do
    options[:flagged_deletion] = true
  end

  opts.on("-b", "--make-public", "Make private wikidata profiles public that have received attributions") do
    options[:make_public] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def update(u)
  u.update_profile
  u.flush_caches
  puts "#{u.viewname}".green
end

if options[:poll_orcid]
  search = Bionomia::OrcidSearch.new
  search.add_new_users
end

if options[:poll_wikidata]
  search = Bionomia::WikidataSearch.new
  search.add_new_users
end

if options[:cache]
  yesterday = DateTime.now - 1.days
  ids = UserOccurrence.where("created >= '#{yesterday}'")
                      .where.not(created_by: User::BOT_IDS)
                      .pluck(:user_id, :created_by)
                      .flatten.uniq
  User.where(id: ids).find_each do |u|
    vars = { id: u.id }.stringify_keys
    ::Bionomia::UserWorker.perform_async(vars)
  end
end

if options[:file]
  mime_type = `file --mime -b "#{options[:file]}"`.chomp
  raise RuntimeError, 'File must be a csv' if !mime_type.include?("text/plain")
  CSV.foreach(options[:file]) do |row|
    next if !row[0].is_orcid? && !row[0].is_wiki_id?
    next if !DestroyedUser.find_by_identifier(row[0]).blank?
    if row[0].is_wiki_id?
      u = User.find_or_create_by({ wikidata: row[0] })
    elsif row[0].is_orcid?
      u = User.find_or_create_by({ orcid: row[0] })
    end
    if u.wikidata && !u.valid_wikicontent?
      u.delete_search
      u.delete
      puts "#{u.wikidata} deleted. Missing either label, birth or death date or has an ORCID".red
    else
      puts "#{u.viewname} #{u.identifier}".green
    end
  end
end

if options[:deleted]
  puts "Locating deleted wikidata entries that have attributions...".green
  local = User.joins(:user_occurrences)
              .where(user_occurrences: { visible: true })
              .where.not(wikidata: nil)
              .pluck(:wikidata).uniq
  wiki = Bionomia::WikidataSearch.new
  qnumbers = local - wiki.wiki_bionomia_id
  qnumbers.each do |wikicode|
    wiki_user = Wikidata::Item.find(wikicode)
    if wiki_user
      puts wiki_user.title.green
    else
      puts wikicode.red
    end
  end
end

if options[:flagged_deletion]
  wiki = Bionomia::WikidataSearch.new
  flagged = wiki.users_flagged_deletion
  if flagged.empty?
    puts "No wikidata entities flagged for deletion.".green
  else
    puts "Oh, oh. Something may have been flagged for deletion".red
    subject = "ALERT! A wikidata page is flagged for deletion."
    body = "A wikidata page(s) may have been flagged for deletion on https://www.wikidata.org/wiki/Wikidata:Requests_for_deletions\n\n"
    body += flagged.join("\n")
    vars = { email: Settings.gmail.email, subject: subject, body: body }.stringify_keys
    ::Bionomia::MailWorker.perform_async(vars)
  end
end

if options[:wikidata]
  u = User.find_or_create_by({ wikidata: options[:wikidata] })
  if !u.valid_wikicontent?
    u.delete_search
    u.delete
    puts "#{u.wikidata} deleted. Missing either family name, birth or death date or has an ORCID".red
  else
    update(u)
  end
elsif options[:orcid]
  u = User.find_or_create_by({ orcid: options[:orcid] })
  update(u)
  puts "#{u.viewname} created/updated".green
elsif options[:logged]
  User.where.not(visited: nil).find_each do |u|
    update(u)
  end
elsif options[:public]
  User.where(is_public: true).find_each do |u|
    update(u)
  end
elsif options[:all]
  User.find_each do |u|
    update(u)
  end
elsif options[:claimed]
  User.where(id: UserOccurrence.select(:user_id).group(:user_id)).find_each do |u|
    update(u)
  end
elsif options[:update_wikidata]
  User.where.not(wikidata: nil).find_each do |u|
    update(u)
  end
elsif options[:update_orcid]
  User.where.not(orcid: nil).find_each do |u|
    update(u)
  end
elsif options[:modified_wikidata]
  wikidata_lib = Bionomia::WikidataSearch.new
  wikidata_lib.modified_users.each do |qid|
    u = User.find_by_wikidata(qid) rescue nil
    if !u.nil?
      update(u)
    end
  end
elsif options[:duplicates]
  wiki = Bionomia::WikidataSearch.new
  wiki.merge_users
end

if options[:make_public]
  last_week = DateTime.now - 7.days
  User.joins(:user_occurrences)
      .where("user_occurrences.created >= '#{last_week}'")
      .where.not(user_occurrences: { visible: nil })
      .where.not(wikidata: nil)
      .where(is_public: false)
      .distinct
      .find_each do |u|
    u.is_public = true
    u.save
    u.flush_caches
  end
end
