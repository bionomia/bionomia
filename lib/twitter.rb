# encoding: utf-8

module Bionomia
  class Twitter
    attr_reader :client
    attr_reader :base_url

    def initialize(opts = {})
      settings = Settings.merge!(opts)
      @client = ::Twitter::REST::Client.new do |config|
        config.consumer_key        = settings.twitter.consumer_key
        config.consumer_secret     = settings.twitter.consumer_secret
        config.access_token        = settings.twitter.access_token
        config.access_token_secret = settings.twitter.access_token_secret
      end
      @base_url = settings.base_url
    end

    def welcome_user(user)
      return if user.nil? || user.class.name != "User"
      id_statement = nil
      recorded_statement = nil
      twitter = nil
      statement = nil
      if !user.twitter.nil?
        twitter = "@#{user.twitter}"
      end
      if !user.top_family_recorded.nil?
        recorded_statement = "collected #{user.top_family_recorded}"
      end
      if !user.top_family_identified.nil?
        id_statement = "identified #{user.top_family_identified}"
      end
      if !user.top_family_identified.nil? || !user.top_family_recorded.nil?
        statement = [recorded_statement, id_statement].compact.join(" and ")
      end
      url = "#{@base_url}/#{user.identifier}"
      message = "#{user.fullname} #{twitter} #{statement} #{url}".split.join(" ")
      @client.update(message)
    end

    def birthday_tweet(user)
      return if user.nil? || user.class.name != "User"
      collected = user.top_family_recorded
      return if collected.nil? || collected == ""
      url = "#{@base_url}/#{user.identifier}"
      keywords = user.keywords.split("|").map(&:strip).first(3).to_sentence rescue nil
      statement = "(#{user.date_born} – #{user.date_died}) #{keywords} collected #{collected} and was #BornOnThisDay"
      message = "#{user.fullname} #{statement} #{url}".split.join(" ")
      @client.update(message)
    end

    def holotype_tweet(o, images = [])
      return if o.nil? || o.class.name != "Occurrence"
      collectors = o.users
                    .where(user_occurrences: { action: ["recorded", "recorded,identified", "identified,recorded"]})
                    .map{|u| [u.fullname, "https://bionomia.net/#{u.identifier}", (!u.twitter.blank? ? "@#{u.twitter}" : nil)].compact.join(" ")}
                    .first(2)
                    .to_sentence
      country = !o.interpretedCountry.nil? ? "in #{o.interpretedCountry}" : nil
      family = !o.family.blank? ? "#{o.family.upcase}:" : nil
      statement = "#{collectors} collected the holotype #{family} #{o.scientificName} #{country}"
      message = "#{statement} https://gbif.org/occurrence/#{o.gbifID} #TypeSpecimenToday"
      if images.empty?
        @client.update(message)
      else
        begin
          @client.update_with_media(message, images)
        rescue
          @client.update(message)
        end
      end
    end

  end
end
