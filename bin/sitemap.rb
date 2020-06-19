#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'
require 'zlib'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: sitemap.rb [options]"

  opts.on("-o", "--domain [domain]", String, "Domain name for sitemap") do |domain|
    options[:domain] = domain
  end

  opts.on("-d", "--directory [directory]", String, "Directory to dump sitemap file") do |directory|
    options[:directory] = directory
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:directory] && options[:domain]
  directory = options[:directory]
  raise "Directory not found" unless File.directory?(directory)

  SitemapGenerator::Sitemap.create do
    opts = { sitemap: sitemap, domain: options[:domain], directory: directory }
    Bionomia::SitemapGenerator.new(opts).run
  end
end
