#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: stats.rb [options]"

  opts.on("-c", "--cache", "Rebuild daily cached stats.") do
    options[:cache] = true
  end

  opts.on("-u", "--users", "Rebuild user stats.") do
    options[:users] = true
  end

  opts.on("-m", "--monthly", "Rebuild monthly stats.") do
    options[:monthly] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:cache]
  BIONOMIA.cache_clear("fragments/")
  BIONOMIA.cache_clear("blocks/country-counts")
  BIONOMIA.cache_clear("blocks/scribe-stats")
  stats = Class.new
  stats.extend Sinatra::Bionomia::Helper::StatsHelper
  BIONOMIA.cache_put_tag("blocks/scribe-stats", stats.stats_scribes)
end

if options[:users]
  User.joins(:user_occurrences).distinct.find_each do |u|
    u.flush_caches
    puts "#{u.viewname}".green
  end
end

if options[:monthly]
  stats = Class.new
  stats.extend Sinatra::Bionomia::Helper::StatsHelper
  puts "Rebuilding claims stats...".yellow
  BIONOMIA.cache_put_tag("blocks/stats-claims", stats.stats_claims)

  puts "Rebuilding attributions stats...".yellow
  BIONOMIA.cache_put_tag("blocks/stats-attributions", stats.stats_attributions)

  puts "Rebuilding rejected stats...".yellow
  BIONOMIA.cache_put_tag("blocks/stats-rejected", stats.stats_rejected)

  puts "Rebuilding profiles stats...".yellow
  BIONOMIA.cache_put_tag("blocks/stats-profiles", stats.stats_profiles)
end
