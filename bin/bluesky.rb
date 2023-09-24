#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: bluesky.rb [options]"

  opts.on("-t", "--holotype", "Post a holotype collected today") do
   options[:holotype] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:holotype]
  date = DateTime.now
  o = Occurrence.joins(:users)
                 .where(hasImage: true)
                 .where(typeStatus: ["HOLOTYPE", "holotype"])
                 .where("MONTH(eventDate_processed) = ? and DAY(eventdate_processed) = ?", date.month, date.day)
                 .where.not(users: { orcid: nil })
                 .where(user_occurrences: { action: ["recorded", "recorded,identified", "identified,recorded"]})
                 .order(Arel.sql("RAND()"))
                 .limit(1)
                 .first rescue nil

  return if o.nil?
  collectors = o.users
                .where(user_occurrences: { action: ["recorded", "recorded,identified", "identified,recorded"]})
                .map{|u| [u.fullname, "https://bionomia.net/#{u.identifier}"].compact.join(" ")}
                .first(2)
                .to_sentence
  country = !o.interpretedCountry.nil? ? "in #{o.interpretedCountry}" : ""
  family = !o.family.blank? ? "#{o.family.upcase}:" : ""
  statement = "#{collectors} collected the holotype #{family} #{o.scientificName} #{country}"
  message = "#{statement} #{o.uri} #TypeSpecimenToday"

  puts "Post attempt: #{o.uri}"
  bs = Bionomia::Bluesky.new
  bs.add_text(text: message)
  o.images.first(2).each do |image|
    rights = image[:rightsHolder] rescue ""
    license = image[:license] rescue ""
    alt_text = "Image of the holotype #{family} #{o.scientificName}. #{rights} #{license}".strip
    bs.add_image(image_url: image[:large], alt_text: alt_text)
  end
  if bs.has_image?
    bs.post
    puts "Success!".green
  else
    puts "Image failed".red
  end
end
