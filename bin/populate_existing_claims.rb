#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: populate_existing_claims.rb [options]"

  opts.on("-d", "--directory [directory]", String, "Directory containing csv file(s)") do |directory|
    options[:directory] = directory
  end

  opts.on("-t", "--truncate", "Remove existing claims from GBIF Agent") do |a|
    options[:truncate] = true
  end

  opts.on("-e", "--export [directory]", String, "Export csv file of attributions made at the source using recordedByID or identifiedByID") do |directory|
    options[:export] = directory
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:truncate]
  sql = %{ DELETE FROM user_occurrences WHERE created_by = 2 ORDER BY id DESC LIMIT 100000 }
  total = UserOccurrence.where(created_by: User::GBIF_AGENT_ID).count
  batch_total = total/100000
  (1..batch_total).each do |i|
    ActiveRecord::Base.connection.execute(sql)
    puts (batch_total - i).to_s.yellow
  end
  ActiveRecord::Base.connection.execute(sql)
  puts "Total records left: #{UserOccurrence.where(created_by: User::GBIF_AGENT_ID).count}".green
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE source_users")
  ActiveRecord::Base.connection.execute("TRUNCATE TABLE source_attributions")
  Sidekiq::Stats.new.reset
end

if options[:directory]
  directory = options[:directory]
  raise "Directory not found" unless File.directory?(directory)
  accepted_formats = [".csv"]
  files = Dir.entries(directory).select {|f| accepted_formats.include?(File.extname(f))}
  files.each do |file|
    file_path = File.join(options[:directory], file)
    CSV.foreach(file_path, headers: true).with_index do |row, i|
      row["agentIDs"].split("|").sort.map(&:strip).uniq.each do |id|
        next if id.blank?

        source_user = SourceUser.find_or_create_by({ identifier: id })
        
        uo = row["gbifIDs_recordedByID"]
              .tr('[]', '')
              .split(',')
              .map{|r| [ source_user.id, r.to_i, "recorded" ]}.compact
        if !uo.empty?
          SourceAttribution.import [:user_id, :occurrence_id, :action], uo, batch_size: 1_000, validate: false, on_duplicate_key_ignore: true
        end
        
        uo = row["gbifIDs_identifiedByID"]
              .tr('[]', '')
              .split(',')
              .map{|r| [ source_user.id, r.to_i, "identified" ]}.compact
        if !uo.empty?
          SourceAttribution.import [:user_id, :occurrence_id, :action], uo, batch_size: 1_000, validate: false, on_duplicate_key_ignore: true
        end
      end
    end
    puts file.green
  end
  SourceUser.find_each do |u|
    vars = {
      user_id: u.id
    }.stringify_keys
    ::Bionomia::ExistingClaimsWorker.perform_async(vars)
  end
end

if options[:export]
  CSV.open(options[:export], "wb") do |csv|
    csv << ["identifier", "action", "occurrence_ids"]
    user_ids = UserOccurrence.where(created_by: User::GBIF_AGENT_ID)
                             .pluck(:user_id)
                             .uniq
    user_ids.each do |u|
      user = User.find(u) rescue nil
      next if user.nil?
      recorded_ids = UserOccurrence.where(user_id: u)
                                   .where(created_by: User::GBIF_AGENT_ID)
                                   .where(action: "recorded")
                                   .pluck(:occurrence_id)
      csv << [user.identifier, "recorded", recorded_ids.to_s] if !recorded_ids.empty?

      identified_ids = UserOccurrence.where(user_id: u)
                                     .where(created_by: User::GBIF_AGENT_ID)
                                     .where(action: "identified")
                                     .pluck(:occurrence_id)
      csv << [user.identifier, "identified", identified_ids.to_s] if !identified_ids.empty?

      both_ids = UserOccurrence.where(user_id: u)
                               .where(created_by: User::GBIF_AGENT_ID)
                               .where(action: ["recorded,identified", "identified,recorded"])
                               .pluck(:occurrence_id)
      csv << [user.identifier, "recorded,identified", both_ids.to_s] if !both_ids.empty?
    end
  end
end
