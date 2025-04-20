#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: bulk_claim.rb [options]."

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
  raise RuntimeError, 'File must be a csv' if !mime_type.include?("text/csv")

  puts "Flushing existing claims made by GBIF agent...".yellow
  sql = %{ DELETE FROM user_occurrences WHERE created_by = 2 ORDER BY id DESC LIMIT 100000 }
  total = UserOccurrence.where(created_by: User::GBIF_AGENT_ID).count
  batch_total = total/100000
  (1..batch_total).each do |i|
    ActiveRecord::Base.connection.execute(sql)
    puts (batch_total - i).to_s
  end
  ActiveRecord::Base.connection.execute(sql)
  puts "Total records left: #{UserOccurrence.where(created_by: User::GBIF_AGENT_ID).count}".green

  all_users = {}

  CSV.foreach(options[:file], headers: true) do |row|
    if !all_users.keys.include?(row["identifier"])
      d = DestroyedUser.active_user_identifier(row["identifier"])
      if !d.nil?
        u = User.find_by_identifier(d)
      else
        if row["identifier"].is_wiki_id?
          u = User.find_or_create_by({ wikidata: row["identifier"] })
          if u.wikidata && !u.valid_wikicontent?
            u.delete_search
            u.delete
            next
          end
        elsif row["identifier"].is_orcid?
          u = User.find_or_create_by({ orcid: row["identifier"] })
        end
      end
      all_users[row["identifier"]] = u.id
      puts row["identifier"].to_s.green
    end

    next if User::BOT_IDS.include?(all_users[row["identifier"]])
    next if !all_users.keys.include?(row["identifier"])

    row["occurrence_ids"].tr('[]', '').split(',').each_slice(2_500) do |group|
      import = group.map{|r| [ r.to_i, all_users[row["identifier"]], row["action"], User::GBIF_AGENT_ID ] }
      UserOccurrence.import [:occurrence_id, :user_id, :action, :created_by], import, validate: false, on_duplicate_key_ignore: true
    end
  end

  all_users.values.each do |id|
    u = User.find(id)
    u.skip_callbacks = true
    if u.wikidata && !u.is_public?
      u.is_public = true
      u.save
    end
    vars = { id: u.id }.stringify_keys
    ::Bionomia::UserWorker.perform_async(vars) 
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
