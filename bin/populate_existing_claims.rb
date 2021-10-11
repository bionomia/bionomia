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
  redis = Redis.new(url: ENV['REDIS_URL'])
  redis.flushdb
  Sidekiq::Stats.new.reset
  UserOccurrence.where(created_by: User::GBIF_AGENT_ID).delete_all
end

if options[:directory]
  directory = options[:directory]
  raise "Directory not found" unless File.directory?(directory)
  accepted_formats = [".csv"]
  files = Dir.entries(directory).select {|f| accepted_formats.include?(File.extname(f))}
  files.each do |file|
    file_path = File.join(options[:directory], file)
    CSV.foreach(file_path, headers: true).with_index do |row, i|
      Sidekiq::Client.push('class' => Bionomia::ExistingClaimsWorker, 'args' => [row.to_hash])
    end
    puts file.green
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
