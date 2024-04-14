# encoding: utf-8

module Bionomia
  module Validator

    def self.resolved_user_dates(user)
      date_born = user.date_born
      if(user.date_born && user.date_born_precision == "century")
        date_born = "#{user.date_born.year - 100}-01-01".to_date rescue nil
      end
      if (user.date_born && user.date_born_precision == "year")
        date_born = "#{user.date_born.year}-12-31".to_date rescue nil
      end
      if (user.date_born && user.date_born_precision == "month")
        date_born = "#{user.date_born.year}-#{user.date_born.month}-28".to_date rescue nil
      end

      date_died = user.date_died
      if(user.date_died && user.date_died_precision == "century")
        date_died = "#{user.date_died.year - 100}-01-01".to_date rescue nil
      end
      if (user.date_died && user.date_died_precision == "year")
        date_died = "#{user.date_died.year}-12-31".to_date rescue nil
      end
      if (user.date_died && user.date_died_precision == "month")
        date_died = "#{user.date_died.year}-#{user.date_died.month}-28".to_date rescue nil
      end

      [date_born, date_died]
    end

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
