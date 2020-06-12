# encoding: utf-8

module Bionomia
  class OrcidSearch

    def initialize(opts = {})
      @settings = Settings.merge!(opts)
    end

    def populate_new_users(doi = nil)
      existing = existing_orcids + destroyed_users
      found_orcids = !doi.nil? ? search_orcids_by_doi(doi) : search_orcids_by_keyword
      (found_orcids.to_a - existing).each do |orcid|
        create_user(orcid)
      end
    end

    def search_orcids_by_doi(doi)
      lucene_chars = {
        '+' => '\+',
        '-' => '\-',
        '&' => '\&',
        '|' => '\|',
        '!' => '\!',
        '(' => '\(',
        ')' => '\)',
        '{' => '\{',
        '}' => '\}',
        '[' => '\[',
        ']' => '\]',
        '^' => '\^',
        '"' => '\"',
        '~' => '\~',
        '*' => '\*',
        '?' => '\?',
        ':' => '\:'
      }
      clean_doi = URI::encode(doi.gsub(/[#{lucene_chars.keys.join('\\')}]/, lucene_chars))

      Enumerator.new do |yielder|
        start = 0
        loop do
          orcid_search_url = "#{@settings.orcid.api_url}search?q=doi-self:#{clean_doi}&start=#{start}&rows=50"
          response = RestClient::Request.execute(
            method: :get,
            url: orcid_search_url,
            headers: { accept: 'application/orcid+json' }
          )
          results = JSON.parse(response, :symbolize_names => true)[:result] rescue []
          if results.size > 0
            results.map { |item| yielder << item[:"orcid-identifier"][:path] }
            start += 50
          else
            raise StopIteration
          end
        end
      end.lazy
    end

    def search_orcids_by_keyword
      if !@settings.orcid.keywords || !@settings.orcid.keywords.is_a?(Array)
        raise ArgumentError, 'ORCID keywords to search on not in config.yml'
      end

      keyword_parameter = URI::encode(@settings.orcid.keywords.map{ |k| "keyword:#{k}" }.join(" OR "))
      Enumerator.new do |yielder|
        start = 0

        loop do
          orcid_search_url = "#{@settings.orcid.api_url}search?q=#{keyword_parameter}&start=#{start}&rows=200"
          response = RestClient::Request.execute(
            method: :get,
            url: orcid_search_url,
            headers: { accept: 'application/orcid+json' }
          )
          results = JSON.parse(response, :symbolize_names => true)[:result] rescue []
          if results && results.size > 0
            results.map { |item| yielder << item[:"orcid-identifier"][:path] }
          else
            raise StopIteration
          end
          start += 200
        end
      end.lazy
    end

    def existing_orcids
      User.pluck(:orcid).compact
    end

    def destroyed_users
      DestroyedUser.pluck(:identifier).compact
    end

    def create_user(orcid)
      u = User.create(orcid: orcid)
      puts "#{u.fullname_reverse}".green
    end

    def account_data(orcid)
      response = RestClient::Request.execute(
        method: :get,
        url: "#{@settings.orcid.api_url}#{orcid}",
        headers: { accept: 'application/orcid+json' }
      )
      data = JSON.parse(response, :symbolize_names => true)

      family = data[:person][:name][:"family-name"][:value].strip rescue nil
      given = data[:person][:name][:"given-names"][:value].strip rescue nil

      credit_name = [data[:person][:name][:"credit-name"][:value].strip] rescue []
      aliases = data[:person][:"other-names"][:"other-name"].map{|n| n[:content].strip} rescue []
      other_names = (credit_name + aliases).uniq.compact.join("|") rescue ""

      keywords = data[:person][:keywords][:keyword].map{|k| k[:content]}.compact.join("|") rescue nil
      email = nil
      data[:person][:emails][:email].each do |mail|
        next if !mail[:primary]
        email = mail[:email]
      end
      country_code = data[:person][:addresses][:address][0][:country][:value] rescue nil
      country = IsoCountryCodes.find(country_code).name rescue nil

      organizations = []
      data[:"activities-summary"][:educations][:"affiliation-group"].each do |group|
        group[:summaries].each do |summary|
          if summary.has_key?(:"education-summary")
            org = orcid_place(summary[:"education-summary"])
            if !org.nil?
              organizations << org
            end
          end
        end
      end
      data[:"activities-summary"][:employments][:"affiliation-group"].each do |group|
        group[:summaries].each do |summary|
          if summary.has_key?(:"employment-summary")
            org = orcid_place(summary[:"employment-summary"])
            if !org.nil?
              organizations << org
            end
          end
        end
      end

      {
        family: family,
        given: given,
        other_names: other_names,
        email: email,
        country: country,
        country_code: country_code,
        keywords: keywords,
        organizations: organizations.compact
      }
    end

    def orcid_place(place)
      ringgold = nil
      grid = nil
      if place[:organization][:"disambiguated-organization"]
        if place[:organization][:"disambiguated-organization"][:"disambiguation-source"] == "RINGGOLD"
          ringgold = place[:organization][:"disambiguated-organization"][:"disambiguated-organization-identifier"] rescue nil
        end
        if place[:organization][:"disambiguated-organization"][:"disambiguation-source"] == "GRID"
          grid = place[:organization][:"disambiguated-organization"][:"disambiguated-organization-identifier"] rescue nil
        end
      end
      return {} if ringgold.nil? && grid.nil?
      name = place[:organization][:name].strip
      address = place[:organization][:address].values.compact.join(", ").strip rescue nil
      start_year = place[:"start-date"][:year][:value].to_i rescue nil
      start_month = place[:"start-date"][:month][:value].to_i rescue nil
      start_day = place[:"start-date"][:day][:value].to_i rescue nil
      end_year = place[:"end-date"][:year][:value].to_i rescue nil
      end_month = place[:"end-date"][:month][:value].to_i rescue nil
      end_day = place[:"end-date"][:day][:value].to_i rescue nil
      {
        name: name,
        address: address,
        ringgold: ringgold,
        grid: grid,
        wikidata: nil,
        start_year: start_year,
        start_month: start_month,
        start_day: start_day,
        end_year: end_year,
        end_month: end_month,
        end_day: end_day
      }
    end

  end
end
