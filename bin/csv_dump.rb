#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'
require 'zlib'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: csv_dump.rb [options]"

  opts.on("-d", "--directory [directory]", String, "Directory to dump csv file(s)") do |directory|
    options[:directory] = directory
  end

  opts.on("-a", "--all", "Dump all claims and public profiles and upload to Zenodo") do
    options[:all] = true
  end

  opts.on("-q", "--quickstatements", "Dump list of new wikidata profiles to be used in quickstatements") do
    options[:quickstatements] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:directory]
  directory = options[:directory]
  raise "Directory not found" unless File.directory?(directory)

  if options[:all]
    ::Bionomia::ZenodoDownloadWorker.perform_async
  end

  if options[:quickstatements]
    csv_file = File.join(directory, "quickstatements.csv")
    puts "Dumping new quickstatements...".green
    local = User.where(is_public: true).where.not(wikidata: nil).pluck(:wikidata)
    wiki = Bionomia::WikidataSearch.new
    new_qnumbers = local - wiki.wiki_bionomia_id
    CSV.open(csv_file, 'w') do |csv|
      csv << ["qid", "P6944"]
      new_qnumbers.each do |w|
        csv << [w, "\"#{w}\""]
      end
    end
    local = User.where(is_public: true).where.not(orcid: nil).pluck(:orcid)
    wiki = Bionomia::WikidataSearch.new
    new_orcid_numbers = local - wiki.wiki_bionomia_id
    CSV.open(csv_file, 'a') do |csv|
      new_orcid_numbers.each do |o|
        item = wiki.wiki_user_by_orcid(o)
        if !item.empty? && !item[:bionomia_id]
          csv << [item[:qid], "\"#{o}\""]
        end
      end
    end
  end

end
