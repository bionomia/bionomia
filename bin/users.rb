#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: update_users.rb [options]"

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

  opts.on("-s", "--stats", "Rebuild user stats.") do
    options[:stats] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def update(u)
  puts "#{u.fullname_reverse}".yellow
  u.update_profile
  u.flush_caches
  puts "#{u.fullname_reverse}".green
end

if options[:poll_orcid]
  search = Bionomia::OrcidSearch.new
  search.populate_new_users
end

if options[:poll_wikidata]
  search = Bionomia::WikidataSearch.new
  search.populate_new_users
end

if options[:cache]
  yesterday = DateTime.now - 1.days
  User.joins(:user_occurrences)
      .where("user_occurrences.created >= '#{yesterday}'")
      .distinct
      .find_each do |u|
    u.flush_caches
  end
end

if options[:file]
  mime_type = `file --mime -b "#{options[:file]}"`.chomp
  raise RuntimeError, 'File must be a csv' if !mime_type.include?("text/plain")
  CSV.foreach(options[:file]) do |row|
    next if !row[0].is_orcid? && !row[0].is_wiki_id?
    if row[0].is_wiki_id?
      u = User.find_or_create_by({ wikidata: row[0] })
    elsif row[0].is_orcid?
      u = User.find_or_create_by({ orcid: row[0] })
    end
    if u.wikidata && !u.valid_wikicontent?
      u.delete_search
      u.delete
      puts "#{u.wikidata} deleted. Missing either family name, birth or death date or has an ORCID".red
    else
      update(u)
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
  url = "https://www.wikidata.org/wiki/Wikidata:Requests_for_deletions"
  doc = Nokogiri::HTML(URI.open(url))
  ids = doc.to_s.scan(/Q\d+/).uniq
  flagged = ids & User.pluck(:wikidata).compact
  if flagged.empty?
    puts "No wikidata entities flagged for deletion.".green
  else
    puts "Oh, oh. Something may have been flagged for deletion".red
    sm = Bionomia::SendMail.new({ subject: "ALERT! A wikidata page is flagged for deletion." })
    body = "A wikidata page(s) may have been flagged for deletion at #{url}!\n\n"
    body += flagged.map{|w| "https://www.wikidata.org/wiki/#{w}"}.join("\n")
    sm.send_message(email: Settings.gmail.email, body: body)
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
  u.flush_caches
  puts "#{u.fullname_reverse} created/updated".green
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
  wikidata_lib.recently_modified.each do |qid|
    u = User.find_by_wikidata(qid) rescue nil
    if !u.nil?
      update(u)
    end
  end
elsif options[:duplicates]
  wiki = Bionomia::WikidataSearch.new
  wiki.merge_users
elsif options[:stats]
  User.joins(:user_occurrences).distinct.find_each do |u|
    u.flush_caches
    puts "#{u.fullname_reverse}".green
  end
end
