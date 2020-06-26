# encoding: utf-8

module Bionomia
  class SitemapGenerator

    attr_accessor :sitemap

    def initialize(args = {})
      args = defaults.merge(args)
      @domain = args[:domain]
      @directory = args[:directory]
      @sitemap = args[:sitemap]
      ::SitemapGenerator::Sitemap.default_host = @domain
      ::SitemapGenerator::Sitemap.create_index = :auto
      ::SitemapGenerator::Sitemap.public_path = args[:directory]
    end

    def run
      add_flat_pages
      add_users
      add_organizations
      add_countries
      add_datasets
      add_articles
    end

    def add_flat_pages
      puts "Adding flat pages..."
      sitemap.add '/about'
      sitemap.add '/agents'
      sitemap.add '/articles'
      sitemap.add '/countries'
      sitemap.add '/datasets'
      sitemap.add '/donate'
      sitemap.add '/get-started'
      sitemap.add '/collection-data-managers'
      sitemap.add '/developers'
      sitemap.add '/developers/structured-data'
      sitemap.add '/developers/code'
      sitemap.add '/history'
      sitemap.add '/help'
      sitemap.add '/how-it-works'
      sitemap.add '/integrations'
      sitemap.add '/organizations'
      sitemap.add '/on-this-day'
      sitemap.add '/on-this-day/died'
      sitemap.add '/on-this-day/collected'
      sitemap.add '/privacy'
      sitemap.add '/roster'
      sitemap.add '/scribes'
      sitemap.add '/terms-of-service'
    end

    def add_users
      puts "Adding users..."
      User.where(is_public: true).find_each do |user|
        sitemap.add "/#{user.identifier}"
        sitemap.add "/#{user.identifier}/specialties"
        sitemap.add "/#{user.identifier}/co-collectors"
        sitemap.add "/#{user.identifier}/identified-for"
        sitemap.add "/#{user.identifier}/identifications-by"
        sitemap.add "/#{user.identifier}/deposited-at"
        sitemap.add "/#{user.identifier}/citations"
        sitemap.add "/#{user.identifier}/specimens"
        sitemap.add "/#{user.identifier}/comments"
        sitemap.add "/#{user.identifier}/support"
      end
    end

    def add_organizations
      puts "Adding organizations..."
      Organization.find_each do |o|
        sitemap.add "/organization/#{o.identifier}"
        sitemap.add "/organization/#{o.identifier}/past"
        sitemap.add "/organization/#{o.identifier}/metrics"
        sitemap.add "/organization/#{o.identifier}/citations"
      end
    end

    def add_countries
      puts "Adding countries..."
      countries = IsoCountryCodes.for_select
      countries.each do |country|
        sitemap.add "/country/#{country[1]}"
      end
    end

    def add_datasets
      puts "Adding datasets..."
      Dataset.find_each do |d|
        sitemap.add "/dataset/#{d.datasetKey}"
      end
    end

    def add_articles
      puts "Adding articles..."
      Article.find_each do |a|
        sitemap.add "/article/#{a.doi}"
      end
    end

    private

    def defaults
      { domain: "example.com", directory: "/tmp", sitemap: nil }
    end

  end
end
