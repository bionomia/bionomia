#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'
require 'zlib'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: csv-dump.rb [options]"

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
    pbar = ProgressBar.create(title: "Claims Dump", total: UserOccurrence.count, autofinish: false, format: '%t %b>> %i| %e')
    CSV.open(csv_file, 'w') do |csv|
      csv << ["Subject", "Predicate", "Object"]
      UserOccurrence.includes(:user).where(visible: true).where.not(action: nil).where(users: { is_public: true }).find_each do |o|
        o.action.split(",").each do |item|
          if item.strip == "recorded"
            action = "http://rs.tdwg.org/dwc/iri/recordedBy"
          elsif item.strip == "identified"
            action = "http://rs.tdwg.org/dwc/iri/identifiedBy"
          end
          id_url = o.user.orcid ? "https://orcid.org/#{o.user.orcid}" : "https://www.wikidata.org/wiki/#{o.user.wikidata}"
          csv << ["https://gbif.org/occurrence/#{o.occurrence_id}", action, id_url]
        end
        pbar.increment
      end
    end
    pbar.finish

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
      csv << ["Family", "Given", "wikidata", "ORCID", "URL"]
      users.find_each do |u|
        csv << [u.family, u.given, u.wikidata, u.orcid, Settings.base_url + "/" + u.identifier]
      end
    end
  end

  if options[:quickstatements]
    csv_file = File.join(directory, "quickstatements.csv")
    puts "Making new public profiles...".green
    local = User.where(is_public: true).where.not(wikidata: nil).pluck(:wikidata)
    wiki = Bionomia::WikidataSearch.new
    new_qnumbers = local - wiki.wiki_bionomia_id
    CSV.open(csv_file, 'w') do |csv|
      csv << ["qid", "P6944"]
      new_qnumbers.each do |w|
        csv << [w, "\"#{w}\""]
      end
    end
  end

end
