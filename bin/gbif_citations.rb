#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: gbif_citations.rb [options]. Check and import citations of downloaded specimens"

  opts.on("-f", "--first-page", "Download new articles and their data packages and parse for gbifIDs") do
    options[:first] = true
  end

  opts.on("-a", "--all", "Download all articles and their data packages and parse for gbifIDs") do
    options[:all] = true
  end

  opts.on("-p", "--process", "Loop through unprocessed articles, download all their data packages and import") do
    options[:process] = true
  end

  opts.on("-i", "--article_id [article_id]", Integer, "Submit unprocessed article id, download all its data packages and import") do |article_id|
    options[:article_id] = article_id
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

if options[:first]
  params[:first_page_only] = true
else
  params[:first_page_only] = false
end

tracker = Bionomia::GbifTracker.new(params)

if options[:first] || options[:all]
  tracker.create_package_records
end

if options[:process]
  tracker.process_articles
elsif options[:article_id]
  tracker.process_article(options[:article_id])
end

if options[:delete]
  tracker.flush_irrelevant_entries
end

if options[:email]
  sm = Bionomia::SendMail.new
  sm.send_messages
  sm.mark_articles_sent
end
