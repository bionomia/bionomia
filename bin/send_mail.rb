#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: send_mail.rb [options]"

  opts.on("-f", "--file [file]", String, "CSV file containing information") do |file|
    options[:file] = file
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def salutation(fullname:)
  "Dear #{fullname},\n\n"\
  "As you are the administrative point of contact for one or more datasets published to the Global Biodiversity Information Facility (GBIF), "\
  "I am writing to draw your attention to a crowd-sourced, open data curation environment I maintain that allows anyone to create linkages between peristent, unique identifiers for collectors and the natural history specimens they collected and/or determined. "\
  "The project is called Bionomia, https://bionomia.net and was launched in 2018."\
  "\n\nTo date 2,040+ people have either claimed their own specimen records as presented on GBIF or have attributed them to others; 20 million such linkages have been created. Some of these are contained in your dataset, "
end

def body(title:, uuid:)
  "\"#{title}\", https://gbif.org/dataset/#{uuid}, which is why I am writing today. These linkages can be downloaded at https://bionomia.net/dataset/#{uuid} as relational, Frictionless Data packages – a bundle of zipped csv files – and is regenerated every two weeks alongside wholesale refreshes of data from GBIF. "\
  "Unique identifiers are in the form of ORCID IDs for people who are alive today or Wikidata Q numbers for the deceased. These unique identifiers help maximize other linking activities, inspire the production of new visualizations, and introduce new efficiencies. "\
  "For example, other files in your Frictionless Data package include mismatches between collecting event and birth/death dates, who made the linkages (for provenance), and record-level citations in recent scientific literature as tracked in secondary downloads from GBIF."\
  "\n\nBionomia volunteers (called \"Scribes\") are enthusiastic and work hard to disambiguate the people in your data. I encourage you to incorporate these persistent, unique identifiers for people in your dataset(s). "\
  "Two new terms were added to Darwin Core for this purpose: recordedByID and identifiedByID."
end

def closing
  "\n\nI hope you are able to take full advantage of Bionomia and find it useful to both explore and manage the data about the people in your specimen data."\
  "\n\nSincerely,"\
  "\nDavid P. Shorthouse"\
  "\nhttps://orcid.org/0000-0001-7618-5230"
end

if options[:file]
  file = options[:file]
  raise "File not found" unless File.file?(file)

  CSV.foreach(file, headers: true) do |row|
    sm = Bionomia::SendMail.new(subject: "Bionomia – A platform to link collectors & determiners to specimen records")
    body = salutation(fullname: row[0]) + body(title: row[2], uuid: row[3]) + closing
    sm.send_message(email: row[1], body: body)
    puts row[0].green
    sleep(5)
  end

end
