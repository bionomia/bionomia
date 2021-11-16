#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: tweet.rb [options]"

  opts.on("-b", "--born", "Tweet a user born today") do
    options[:born] = true
  end

  opts.on("-t", "--holotype", "Tweet a holotype collected today") do
    options[:holotype] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:born]
  @date = DateTime.now
  users = User.joins(:user_occurrences)
              .where.not(wikidata: nil)
              .where(is_public: true)
              .where.not(image_url: nil)
              .where(date_born_precision: "day")
              .where("MONTH(date_born) = ? and DAY(date_born) = ?", @date.month, @date.day)
              .order(Arel.sql("RAND()"))
              .limit(1)
  if !users.nil?
    t = Bionomia::Twitter.new
    t.birthday_tweet(users[0])
  end
end

if options[:holotype]
  @date = DateTime.now
  holotypes = Occurrence.joins(:users)
                        .where(hasImage: true)
                        .where(typeStatus: ["HOLOTYPE", "holotype"])
                        .where("MONTH(eventDate_processed) = ? and DAY(eventdate_processed) = ?", @date.month, @date.day)
                        .where.not(users: { orcid: nil })
                        .where(user_occurrences: { action: ["recorded", "recorded,identified", "identified,recorded"]})
                        .order(Arel.sql("RAND()"))
                        .limit(1)
  if !holotypes.nil?
    t = Bionomia::Twitter.new
    images = holotypes[0].images.first(2).map{|i| File.new(URI.parse(i[:large]).open) } rescue []
    t.holotype_tweet(holotypes[0], images)
  end
end
