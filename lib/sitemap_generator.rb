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
      add_taxa
    end

    def add_flat_pages
      puts "Adding flat pages..."
      sitemap.add '/about'
      sitemap.add '/agents'
      sitemap.add '/articles'
      sitemap.add '/collection-data-managers'
      sitemap.add '/countries'
      sitemap.add '/datasets'
      sitemap.add '/developers'
      sitemap.add '/developers/structured-data'
      sitemap.add '/developers/code'
      sitemap.add '/developers/parse'
      sitemap.add '/donate'
      sitemap.add '/get-started'
      sitemap.add '/help'
      sitemap.add '/history'
      sitemap.add '/how-it-works'
      sitemap.add '/integrations'
      sitemap.add '/on-this-day'
      sitemap.add '/on-this-day/died'
      sitemap.add '/on-this-day/collected'
      sitemap.add '/organizations'
      sitemap.add '/parse'
      sitemap.add '/privacy'
      sitemap.add '/reconcile'
      sitemap.add '/roster'
      sitemap.add '/roster/gallery'
      sitemap.add '/roster/signatures'
      sitemap.add '/scribes'
      sitemap.add '/terms-of-service'
      sitemap.add '/taxa'
      sitemap.add '/workshops'
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
        sitemap.add "/#{user.identifier}/strings"
        sitemap.add "/#{user.identifier}/support"
        if user.orcid
          sitemap.add "/#{user.identifier}/helped"
        end
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
      I18nData.countries(:en).keys.each do |code|
        sitemap.add "/country/#{code}"
      end
    end

    def add_datasets
      puts "Adding datasets..."
      Dataset.find_each do |d|
        sitemap.add "/dataset/#{d.datasetKey}"
        next if d.is_large?
        sitemap.add "/dataset/#{d.datasetKey}/visualizations"
        sitemap.add "/dataset/#{d.datasetKey}/visualizations?action=identified"
        sitemap.add "/dataset/#{d.datasetKey}/scribes"
        sitemap.add "/dataset/#{d.datasetKey}/agents"
      end
    end

    def add_articles
      puts "Adding articles..."
      Article.find_each do |a|
        sitemap.add "/article/#{a.doi}"
      end
    end

    def add_taxa
      puts "Adding taxa..."
      Taxon.find_each do |t|
        sitemap.add "/taxon/#{t.family}"
        sitemap.add "/taxon/#{t.family}?action=identified"
        sitemap.add "/taxon/#{t.family}/visualizations"
        sitemap.add "/taxon/#{t.family}/visualizations?action=identified"
        sitemap.add "/taxon/#{t.family}/agents"
        sitemap.add "/taxon/#{t.family}/agents/counts"
        sitemap.add "/taxon/#{t.family}/agents/unclaimed"
      end
    end

    private

    def defaults
      { domain: "example.com", directory: "/tmp", sitemap: nil }
    end

  end
end
