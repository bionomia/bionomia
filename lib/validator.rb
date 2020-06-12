# encoding: utf-8

module Bionomia
  module AgentUtility

    def self.valid_year(year)
      return if year.presence.nil?

      parsed = Date.strptime(year, "%Y").year rescue nil

      if parsed.nil? || parsed <= 1756 || parsed >= Time.now.year
        parsed = Chronic.parse(year).year rescue nil
      end

      if !parsed.nil? && parsed >= 1756 && parsed <= Time.now.year
        parsed
      end
    end

    def self.valid_date(date)
      return if date.presence.nil?

      parsed = Date.strptime(date, "%Y-%m-%d") rescue nil

      if parsed.year.nil? || parsed.year <= 1756 || parsed.year >= Time.now.year
        parsed = Chronic.parse(date) rescue nil
      end

      if !parsed.year.nil? && parsed.year >= 1756 && parsed.year <= Time.now.year
        parsed
      end
    end

    def self.valid_json?(json)
      begin
        JSON.parse(json)
        return true
      rescue JSON::ParserError => e
        return false
      end
    end

  end
end
