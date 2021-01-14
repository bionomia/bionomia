#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: populate_agents.rb [options]"

  opts.on("-d", "--directory [directory]", String, "Directory containing csv file(s)") do |directory|
    options[:directory] = directory
  end

  opts.on("-t", "--truncate", "Remove existing claims from GBIF Agent") do |a|
    options[:truncate] = true
  end

  opts.on("-s", "--start-date [DATE]", String, "Start date in the form YYYY-MM-DD") do |date|
    options[:start_date] = date
  end

  opts.on("-e", "--export [directory]", String, "Export a csv of attributions made at the completion of all jobs") do |directory|
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
    csv << ["identifier", "occurrence_id", "action", "created_by"]
    claims = UserOccurrence.includes(:user)
                           .where(created_by: User::GBIF_AGENT_ID)

    if options[:start_date]
      date = DateTime.strptime(options[:start_date], '%Y-%m-%d')
      claims = claims.where("created >= '#{date}'")
    end

    claims.find_each do |o|
      csv << [o.user.identifier, o.occurrence_id, o.action, o.created_by]
    end
  end
end
