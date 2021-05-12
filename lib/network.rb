# encoding: utf-8

module Bionomia
  class Network

    def initialize(args = {})
      args = defaults.merge(args)
      @user = args[:user]
      @params = args[:params]
      @request = args[:request]
    end

    def defaults
      { user: nil }
    end

    def base_url
      "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}"
    end

    def params
      @params
    end

    def request
      @request
    end

    def jsonld_context
      {
        "@vocab": "http://schema.org/",
        "co-collector": "http://www.wikidata.org/entity/Q81546212"
      }
    end

    def jsonld_stream
      output = StringIO.open("", "w+")
      w = Oj::StreamWriter.new(output, indent: 1)
      w.push_object()
      w.push_value(jsonld_context.as_json, "@context")
      add_user(@user).each do |k,v|
        w.push_value(v, k.to_s)
      end
      w.push_object("@reverse")
      w.push_array("co-collector")
      @user.recorded_with.find_each do |user|
        w.push_value(add_user(user).as_json)
      end
      w.pop
      w.pop_all
      output.string()
    end

    def add_user(user)
      {
        "@type": "Person",
        "@id": "#{base_url}/#{user.identifier}",
        givenName: user.given,
        familyName: user.family,
        alternateName: user.other_names.split("|"),
        sameAs: user.uri
      }
    end

  end

end
