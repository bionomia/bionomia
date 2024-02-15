#!/usr/bin/env ruby
# encoding: utf-8
require File.dirname(File.dirname(__FILE__)) + '/application.rb'

ARGV << '-h' if ARGV.empty?

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: zenodo_dataset.rb [options]"

  opts.on("-r", "--refresh", "Queue up all Frictionless files for datasets to Zenodo") do
    options[:refresh] = true
  end

  opts.on("-u", "--uuid [UUID]", String, "Queue a dataset to publish to Zenodo by uuid") do |uuid|
    options[:uuid] = uuid
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

def submit_new(d)
  vars = { id: d.id, action: "new" }.stringify_keys
  ::Bionomia::ZenodoDatasetWorker.perform_async(vars)
end

def submit_update(d)
  vars = { id: d.id, action: "update" }.stringify_keys
  ::Bionomia::ZenodoDatasetWorker.perform_async(vars)
end

if options[:uuid]
   d = Dataset.find_by_uuid(options[:uuid])
   return if d.nil? || !d.has_claim?
   if d.zenodo_doi.nil?
      submit_new(d)
   else
      submit_update(d)
   end
elsif options[:refresh]
   week_ago = DateTime.now - 7.days
   Dataset.where("frictionless_created_at <= '#{week_ago}'").find_each do |d|
      return if d.nil? || !d.has_claim?
      if d.zenodo_doi.nil?
         submit_new(d)
      else
         submit_update(d)
      end
   end
end
