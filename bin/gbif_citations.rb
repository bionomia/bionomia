#!/usr/bin/env ruby
# encoding: utf-8
require 'optparse/date'
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: gbif_citations.rb [options]. Check and import citations of downloaded specimens"

  opts.on("-f", "--from [from]", Date, "Download new articles and their data packages using from date to today when added") do |from|
    options[:from] = from
  end

  opts.on("-c", "--flush-caches", "Loop through processed articles and flush their caches") do
    options[:caches] = true
  end

  opts.on("-e", "--email", "Send out email notifications to users") do
    options[:email] = true
  end

  opts.on("-d", "--delete", "Delete irrelevant article_occurrences entries because gbifID no longer exists") do
    options[:delete] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

params = { max_size: 100_000_000 }

if options[:from ]
  params[:from] = options[:from]
end

tracker = Bionomia::GbifTracker.new(params)

if options[:first]
  tracker.create_package_records
end

if options[:email]
  sm = Bionomia::SendMail.new
  sm.send_messages
  sm.mark_articles_sent
end

if options[:caches]
  Article.where(processed: true).find_each do |a|
    a.flush_cache
    puts "#{a.id}".green
  end
end
