#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: update_users.rb [options]"

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
  mime_type = `file --mime -b "#{options[:file]}"`.chomp
  if !mime_type.include?("text/plain") && !mime_type.include?("application/csv")
    raise RuntimeError, 'File must be a csv'
  end
  CSV.foreach(options[:file], headers: true, header_converters: :symbol) do |row|
    user = User.find_by_identifier(row[:identifier])
    ids = UserOccurrence.left_joins(:occurrence)
            .where(occurrences: { id: nil })
            .where(user_id: user.id)
            .pluck(:id)
    if ids.length > 0
      UserOccurrence.where(id: ids).order(id: :desc).delete_all
      user.flush_caches
      puts row[:identifier].red
    end
  end
end

if options[:orphaned] && options[:directory]
  directory = options[:directory]
  raise "Directory not found" unless File.directory?(directory)

  csv_file = File.join(directory, "orphaned.csv")
  puts "Querying for orphaned records...".green
  CSV.open(csv_file, 'w') do |csv|
    csv << ["Identifier", "Name", "Number Orphaned", "Claimants/Attributors"]
    UserOccurrence.orphaned_user_claims.each do |k,v|
      user = User.find(k)
      attributors = v[:claimants].map{|u| User.find(u).fullname}.join("; ")
      csv << [user.identifier, user.fullname, v[:count], attributors]
    end
  end
end
