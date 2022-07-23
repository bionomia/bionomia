#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: zenodo.rb [options]"

  opts.on("-n", "--new", "Push brand new claims data to Zenodo") do
    options[:new] = true
  end

  opts.on("-a", "--all", "Push new versions to Zenodo") do
    options[:all] = true
  end

  opts.on("-w", "--within-week", "Push new versions to Zenodo but only for people who have logged in within last week.") do
    options[:within_week] = true
  end

  opts.on("-o", "--orcid [ORCID]", String, "Push new version for a particular user with an ORCID") do |orcid|
    options[:orcid] = orcid
  end

  opts.on("-r", "--refresh", "Refresh all Zenodo tokens") do
    options[:refresh] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:new]
  User.where.not(orcid: nil)
      .where.not(zenodo_access_token: nil)
      .where(zenodo_doi: nil).find_each do |u|
    z = Bionomia::Zenodo.new(user: u)
    begin
      u.zenodo_access_token = z.refresh_token
      u.save

      doi_id = z.new_deposit
      id = doi_id[:recid]
      io = Bionomia::IO.new({ user: u })
      csv = io.csv_stream_occurrences(u.visible_occurrences)
      z.add_file_enum(id: id, enum: csv, file_name: u.orcid + ".csv")
      json = io.jsonld_stream("all")
      z.add_file_string(id: id, string: json, file_name: u.orcid + ".json")
      pub = z.publish(id: id)
      u.zenodo_doi = pub[:doi]
      u.zenodo_concept_doi = pub[:conceptdoi]
      u.save
      puts "#{u.fullname_reverse}".green
    rescue
      puts "#{u.fullname_reverse} (id=#{u.id}) token failed".red
    end
  end

elsif options[:orcid]
  u = User.where(orcid: options[:orcid])
          .where.not(zenodo_doi: nil)
          .where.not(zenodo_access_token: nil)
          .first
  if !u.nil?
    z = Bionomia::Zenodo.new(user: u)
    begin
      u.zenodo_access_token = z.refresh_token
      u.save

      old_id = u.zenodo_doi.split(".").last
      doi_id = z.new_version(id: old_id)

      id = doi_id[:recid]
      files = z.list_files(id: id).map{|f| f[:id]}
      files.each do |file_id|
        z.delete_file(id: id, file_id: file_id)
      end

      io = Bionomia::IO.new({ user: u })
      csv = io.csv_stream_occurrences(u.visible_occurrences)
      z.add_file_enum(id: id, enum: csv, file_name: u.orcid + ".csv")
      json = io.jsonld_stream("all")
      z.add_file_string(id: id, string: json, file_name: u.orcid + ".json")

      pub = z.publish(id: id)
      if !pub[:doi].nil?
        u.zenodo_doi = pub[:doi]
        u.save
        puts "#{u.fullname_reverse}".green
      else
        z.discard_version(id: id)
        puts "#{u.fullname_reverse}".red
      end
    rescue
      puts "#{u.fullname_reverse} (id=#{u.id}) token failed".red
    end
  end

elsif options[:all] || options[:within_week]
  qry = User.where.not(zenodo_doi: nil)
            .where.not(zenodo_access_token: nil)
  if options[:within_week]
    week_ago = DateTime.now - 7.days
    qry = qry.where("visited >= '#{week_ago}'")
  end
  qry.find_each do |u|
    z = Bionomia::Zenodo.new(user: u)
    begin
      u.zenodo_access_token = z.refresh_token
      u.save

      old_id = u.zenodo_doi.split(".").last
      doi_id = z.new_version(id: old_id)

      id = doi_id[:recid]
      files = z.list_files(id: id).map{|f| f[:id]}
      files.each do |file_id|
        z.delete_file(id: id, file_id: file_id)
      end

      io = Bionomia::IO.new({ user: u })
      csv = io.csv_stream_occurrences(u.visible_occurrences)
      z.add_file_enum(id: id, enum: csv, file_name: u.orcid + ".csv")
      json = io.jsonld_stream("all")
      z.add_file_string(id: id, string: json, file_name: u.orcid + ".json")

      pub = z.publish(id: id)
      if !pub[:doi].nil?
        u.zenodo_doi = pub[:doi]
        u.save
        puts "#{u.fullname_reverse}".green
      else
        z.discard_version(id: id)
        puts "#{u.fullname_reverse}".red
      end
    rescue
      puts "#{u.fullname_reverse} (id=#{u.id}) token failed".red
    end
  end
end

if options[:refresh]
  User.where.not(zenodo_access_token: nil).find_each do |u|
    z = Bionomia::Zenodo.new(user: u)
    begin
      u.zenodo_access_token = z.refresh_token
      u.save
      puts "#{u.fullname_reverse} (id=#{u.id})".green
    rescue
      puts "#{u.fullname_reverse} (id=#{u.id}) token failed".red
    end
  end
end
