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

  opts.on("-w", "--within-week", "Push new versions to Zenodo but only accounts updated within last week.") do
    options[:within_week] = true
  end

  opts.on("-i", "--identifier [IDENTIFIER]", String, "Push new version for an account by ORCID or Wikidata Q number") do |identifier|
    options[:identifier] = identifier
  end

  opts.on("-r", "--refresh", "Refresh all Zenodo tokens") do
    options[:refresh] = true
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def submit_new(u)
  z = Bionomia::Zenodo.new(user: u)
  begin
    u.skip_callbacks = true

    if u.orcid
      u.zenodo_access_token = z.refresh_token
      u.save
    end

    doi_id = z.new_deposit
    id = doi_id[:recid]
    io = Bionomia::IO.new({ user: u })
    csv = io.csv_stream_occurrences(u.visible_occurrences)
    z.add_file_enum(id: id, enum: csv, file_name: u.identifier + ".csv")
    temp = Tempfile.new
    temp.binmode
    io.jsonld_stream("all", temp)
    z.add_file(id: id, file_path: temp.path, file_name: u.identifier + ".json")
    temp.close
    temp.unlink
    pub = z.publish(id: id)
    u.zenodo_doi = pub[:doi]
    u.zenodo_concept_doi = pub[:conceptdoi]
    u.save
    puts "#{u.viewname}".green
  rescue
    puts "#{u.viewname} (id=#{u.id}) token failed".red
  end
end

if options[:new] && options[:identifier]
  u = User.find_by_identifier(options[:identifier])
  return if u.nil? || !u.zenodo_doi.nil?
  submit_new(u)

elsif options[:new]
  User.where.not(zenodo_access_token: nil)
      .where(zenodo_doi: nil).find_each do |u|
        submit_new(u)
  end

elsif options[:identifier]
  u = User.find_by_identifier(options[:identifier])
  return if u.nil? || u.zenodo_doi.nil? || (u.orcid && u.zenodo_access_token.nil?)

  z = Bionomia::Zenodo.new(user: u)
  begin
    u.skip_callbacks = true

    if u.orcid
      u.zenodo_access_token = z.refresh_token
      u.save
    end

    old_id = u.zenodo_doi.split(".").last
    doi_id = z.new_version(id: old_id)

    id = doi_id[:recid]
    files = z.list_files(id: id).map{|f| f[:id]}
    files.each do |file_id|
      z.delete_file(id: id, file_id: file_id)
    end

    io = Bionomia::IO.new({ user: u })
    csv = io.csv_stream_occurrences(u.visible_occurrences)
    z.add_file_enum(id: id, enum: csv, file_name: u.identifier + ".csv")
    temp = Tempfile.new
    temp.binmode
    io.jsonld_stream("all", temp)
    z.add_file(id: id, file_path: temp.path, file_name: u.identifier + ".json")
    temp.close
    temp.unlink

    pub = z.publish(id: id)
    if !pub[:doi].nil?
      u.zenodo_doi = pub[:doi]
      u.save
      puts "#{u.viewname}".green
    else
      z.discard_version(id: id)
      puts "#{u.viewname}".red
    end
  rescue
    puts "#{u.viewname} (id=#{u.id}) token failed".red
  end

elsif options[:all] || options[:within_week]
  qry = User.where.not(zenodo_doi: nil)
            .where.not(zenodo_access_token: nil)
  if options[:within_week]
    week_ago = DateTime.now - 7.days
    qry = qry.where("updated >= '#{week_ago}'")
  end
  qry.find_each do |u|
    z = Bionomia::Zenodo.new(user: u)
    begin
      u.skip_callbacks = true

      if u.orcid
        u.zenodo_access_token = z.refresh_token
        u.save
      end

      old_id = u.zenodo_doi.split(".").last
      doi_id = z.new_version(id: old_id)

      id = doi_id[:recid]
      files = z.list_files(id: id).map{|f| f[:id]}
      files.each do |file_id|
        z.delete_file(id: id, file_id: file_id)
      end

      io = Bionomia::IO.new({ user: u })
      csv = io.csv_stream_occurrences(u.visible_occurrences)
      z.add_file_enum(id: id, enum: csv, file_name: u.identifier + ".csv")
      temp = Tempfile.new
      temp.binmode
      io.jsonld_stream("all", temp)
      z.add_file(id: id, file_path: temp.path, file_name: u.identifier + ".json")
      temp.close
      temp.unlink

      pub = z.publish(id: id)
      if !pub[:doi].nil?
        u.zenodo_doi = pub[:doi]
        u.save
        puts "#{u.viewname}".green
      else
        z.discard_version(id: id)
        puts "#{u.viewname}".red
      end
    rescue
      puts "#{u.viewname} (id=#{u.id}) token failed".red
    end
  end
end

if options[:refresh]
  User.where.not(zenodo_access_token: nil).find_each do |u|
    z = Bionomia::Zenodo.new(user: u)
    begin
      u.skip_callbacks = true
      u.zenodo_access_token = z.refresh_token
      u.save
      puts "#{u.viewname} (id=#{u.id})".green
    rescue
      puts "#{u.viewname} (id=#{u.id}) token failed".red
    end
  end
end
