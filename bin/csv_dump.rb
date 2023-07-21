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

  opts.on("-a", "--all", "Dump all claims") do
    options[:all] = true
  end

  opts.on("-p", "--profiles", "Dump list of profiles") do
    options[:profiles] = true
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
    csv_file = File.join(directory, "bionomia-public-claims.csv")
    puts "Making public claimed occurrences...".green
    query = UserOccurrence.joins(:user)
                          .select(:occurrence_id, :action, :wikidata, :orcid)
                          .where(user_occurrences: { visible: true })
                          .where(users: {is_public: true })
                          .to_sql
    mysql2 = ActiveRecord::Base.connection.instance_variable_get(:@connection)
    rows = mysql2.query(query, stream: true, cache_rows: false)
    CSV.open(csv_file, 'w') do |csv|
      csv << ["Subject", "Predicate", "Object"]
      rows.each do |row|
        if row[2]
          user = "http://www.wikidata.org/entity/#{row[2]}"
        elsif row[3]
          user = "https://orcid.org/#{row[3]}"
        end
        row[1].split(",").each do |item|
          if item.strip == "recorded"
            action = "http://rs.tdwg.org/dwc/iri/recordedBy"
          elsif item.strip == "identified"
            action = "http://rs.tdwg.org/dwc/iri/identifiedBy"
          end
          csv << ["https://gbif.org/occurrence/#{row[0]}", action, user]
        end
      end
    end

    puts "Compressing...".green
    zipped = File.join(directory, "#{File.basename(csv_file, ".csv")}.csv.gz")
    Zlib::GzipWriter.open(zipped) do |gz|
      gz.mtime = File.mtime(csv_file)
      gz.orig_name = csv_file
      File.open(csv_file) do |file|
        while chunk = file.read(16*1024) do
          gz.write(chunk)
        end
      end
    end
    File.delete(csv_file)
  end

  if options[:profiles]
    csv_file = File.join(directory, "bionomia-public-profiles.csv")
    puts "Making public profiles...".green
    users = User.where(is_public: true)
    CSV.open(csv_file, 'w') do |csv|
      csv << ["Family", "Given", "Particle", "OtherNames", "Country", "Keywords", "wikidata", "ORCID", "URL"]
      users.find_each do |u|
        csv << [
          u.family,
          u.given,
          u.particle,
          u.other_names,
          u.country,
          u.keywords,
          u.wikidata,
          u.orcid,
          Settings.base_url + "/" + u.identifier
        ]
      end
    end
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
