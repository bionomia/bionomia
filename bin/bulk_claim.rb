#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: bulk_claim.rb [options]. Assumes collector and determiner are spelled exactly the same."

  opts.on("-a", "--agent [agent_id]", Integer, "Local agent identifier") do |agent_id|
    options[:agent_id] = agent_id
  end

  opts.on("-c", "--conditions [conditions]", String, "executes a WHERE as JSON on occurrence records, eg '{ \"institutionCode\" : \"CAN\" }' or a LIKE statement '{ \"scientificName LIKE ?\":\"Bolbelasmus %\"}'") do |conditions|
    options[:conditions] = conditions
  end

  opts.on("-i", "--ignore", "Ignore all selections") do
    options[:ignore] = true
  end

  opts.on("-o", "--orcid [orcid]", String, "ORCID identifier for user") do |orcid|
    options[:orcid] = orcid
  end

  opts.on("-k", "--wikidata [wikidata]", String, "Wikidata identifier for user") do |wikidata|
    options[:wikidata] = wikidata
  end

  opts.on("-f", "--file [FILE]", String, "Import attributions using a csv file whose first column is an ORCID or wikidata identifier") do |file|
    options[:file] = file
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:file]
  mime_type = `file --mime -b "#{options[:file]}"`.chomp
  raise RuntimeError, 'File must be a csv' if !mime_type.include?("text/plain") && !mime_type.include?("application/csv")

  UserOccurrence.where(created_by: User::GBIF_AGENT_ID).delete_all

  CSV.foreach(options[:file], headers: true) do |row|
    if row["identifier"].is_wiki_id?
      d = DestroyedUser.where(identifier: row["identifier"])
      if d.exists?
        redirect = d.where.not(redirect_to: nil).first
        next if redirect.nil?
        u = User.find_by_wikidata(redirect.redirect_to)
      else
        u = User.find_or_create_by({ wikidata: row["identifier"] })
        if u.wikidata && !u.valid_wikicontent?
          u.delete_search
          u.delete
          next
        end
      end
    elsif row["identifier"].is_orcid?
      u = User.find_or_create_by({ orcid: row["identifier"] })
    end
    next if User::BOT_IDS.include?(u.id)
    row["occurrence_ids"].tr('[]', '').split(',').in_groups_of(1_000, false) do |group|
      import = group.map{|r| [ r.to_i, u.id, row["action"], User::GBIF_AGENT_ID ] }
      UserOccurrence.import [:occurrence_id, :user_id, :action, :created_by], import, batch_size: 1000, validate: false, on_duplicate_key_ignore: true
    end
    if u.wikidata && !u.is_public?
      u.is_public = true
      u.save
    end
    u.flush_caches
    puts u.identifier.to_s.green
  end
elsif options[:agent_id] && ![options[:orcid], options[:wikidata]].compact.empty?
  agent = Agent.find(options[:agent_id])

  if options[:orcid]
    user = User.find_by_orcid(options[:orcid])
  elsif options[:wikidata]
    user = User.find_by_wikidata(options[:wikidata])
  end

  if agent.nil? || user.nil?
    puts "ERROR: either agent or user not found".red
    exit
  else
    result = user.bulk_claim(agent: agent, conditions: options[:conditions], ignore: options[:ignore])
    user.flush_caches
    puts result.green
  end
else
  puts "ERROR: Either -f or both -a and one of -o or -k are required".red
end
