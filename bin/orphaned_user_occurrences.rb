#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: orphaned_user_occurrences.rb [options]"

  opts.on("-d", "--directory [directory]", String, "Directory to dump csv file(s)") do |directory|
    options[:directory] = directory
  end

  opts.on("-o", "--orphaned", "Dump orphaned records") do
    options[:orphaned] = true
  end

  opts.on("-f", "--file [file]", String, "csv file generated from -o to upload and use to delete orphaned claims") do |file|
    options[:file] = file
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:file]
  mime_type = `file --mime-type -b "#{options[:file]}"`.chomp
  if !["text/plain", "application/csv", "text/csv"].include?(mime_type)
    raise RuntimeError, 'File must be a csv'
  end
  CSV.foreach(options[:file], headers: true, header_converters: :symbol) do |row|
    user = User.find_by_identifier(row[:identifier])
    ids = UserOccurrence.left_joins(:occurrence)
            .where(visible: true)
            .where(occurrences: { id: nil })
            .where(user_id: user.id)
            .pluck(:id)
    if ids.length > 0
      UserOccurrence.where(id: ids).order(id: :desc).delete_all
      begin
        user.flush_caches
        puts row[:identifier].green
      rescue
        puts "#{row[:identifier]} did not flush_caches".red
      end
    end
  end
end

if options[:orphaned] && options[:directory]
  directory = options[:directory]
  raise "Directory not found" unless File.directory?(directory)

  csv_file = File.join(directory, "orphaned.csv")
  puts "Querying for orphaned records...".yellow
  OrphanedUserOccurrence.rebuild
  puts "Writing to file...".yellow
  CSV.open(csv_file, 'w') do |csv|
    csv << ["Identifier", "Name", "Number Orphaned", "Claimants/Attributors"]
    OrphanedUserOccurrence.select(:user_id, "COUNT(*) AS num", "JSON_ARRAYAGG(created_by) AS user_ids")
                          .group(:user_id)
                          .each do |item|
      user = User.find(item[:user_id])
      attributors = item[:user_ids].tr('[]', '')
                      .split(',')
                      .uniq
                      .map{|u| User.find(u).viewname}
                      .uniq
                      .join("; ")
      csv << [user.identifier, user.viewname, item[:num], attributors]
    end
  end
  puts "Done".green
end
