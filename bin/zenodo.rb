#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: zenodo.rb [options]"

  opts.on("-n", "--new", "Push brand new claims data to Zenodo for ORCID-based profiles") do
    options[:new] = true
  end

  opts.on("-w", "--within-week", "Push to Zenodo for accounts that have a recent claim/attribution.") do
    options[:within_week] = true
  end

  opts.on("-i", "--identifier [IDENTIFIER]", String, "Push new version for an account by ORCID or Wikidata Q number") do |identifier|
    options[:identifier] = identifier
  end

  opts.on("-r", "--refresh", "Refresh all Zenodo tokens for ORCID-based profiles") do
    options[:refresh] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def submit_new(u)
  vars = { id: u.id, action: "new" }
  ::Bionomia::ZenodoWorker.perform_async(vars)
end

def submit_update(u)
  vars = { id: u.id, action: "update" }
  ::Bionomia::ZenodoWorker.perform_async(vars)
end

def submit_refresh(u)
  vars = { id: u.id, action: "refresh" }
  ::Bionomia::ZenodoWorker.perform_async(vars)
end

if options[:new]
  if options[:identifier]
    u = User.find_by_identifier(options[:identifier])
    return if u.nil? || !u.zenodo_doi.nil?
    submit_new(u)
  elsif !options[:identifier]
    User.where.not(zenodo_access_token: nil)
        .where(zenodo_doi: nil).find_each do |u|
          submit_new(u)
    end
  end

elsif !options[:new] && options[:identifier]
  u = User.find_by_identifier(options[:identifier])
  return if u.nil? || u.zenodo_doi.nil? || (u.orcid && u.zenodo_access_token.nil?)
  submit_update(u)

elsif options[:within_week]
  week_ago = DateTime.now - 7.days
  user_ids = UserOccurrence.select(:user_id, "MAX(created) AS created")
                           .where("created >= '#{week_ago}'")
                           .group(:user_id)
  User.where(id: user_ids.map(&:user_id))
    .find_each do |u|
      if u.zenodo_doi && u.orcid
        submit_update(u) 
      elsif u.zenodo_doi && u.wikidata
        latest = u.visible_user_occurrences.order(created: :desc).limit(1).first rescue nil
        next if latest.nil? || User::BOT_IDS.include?(latest.created_by)
        submit_update(u)
      end
  end
end

if options[:refresh]
  User.where.not(zenodo_access_token: nil).find_each do |u|
    submit_refresh(u)
  end
end
