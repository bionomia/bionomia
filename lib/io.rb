# encoding: utf-8

module Bionomia
  class IO

    include Pagy::Backend

    def initialize(args = {})
      args = defaults.merge(args)
      @user = args[:user]
      @params = args[:params]
      @request = args[:request]
    end

    def defaults
      { user: nil, params: {}, request: {} }
    end

    def ignored_cols(keep_gbifID = true)
      if keep_gbifID
        ["dateIdentified_processed", "eventDate_processed", "hasImage"]
      else
        Occurrence::IGNORED_COLUMNS_OUTPUT
      end
    end

    def params
      @params
    end

    def request
      @request
    end

    def csv_stream_agent_occurrences(occurrences)
      Enumerator.new do |y|
        header = Occurrence.attribute_names - ignored_cols
        y << CSV::Row.new(header, header, true).to_s
        if !occurrences.empty?
          occurrences.find_each do |o|
            attributes = o.attributes
            ignored_cols.each do |col|
              attributes.delete(col)
            end
            data = attributes.values
            y << CSV::Row.new(header, data).to_s
          end
        end
      end
    end

    def csv_stream_articles_profile(user, articles)
      Enumerator.new do |y|
        header = ["doi", "reference", "num_specimens", "URL"]
        y << CSV::Row.new(header, header, true).to_s
        if !articles.empty?
          articles.each do |a|
            data = [
              a.doi,
              (a.citation || "NO TITLE"),
              a.user_specimen_count(user.id),
              "#{Settings.base_url}/profile/citation/#{a.doi}"
            ]
            y << CSV::Row.new(header, data).to_s
          end
        end
      end
    end

    def csv_stream_article_specimen_profile(user, occurrences, article)
      Enumerator.new do |y|
        header = Occurrence.attribute_names - ignored_cols
        header.unshift "used_in_doi"
        y << CSV::Row.new(header, header, true).to_s
        if !occurrences.empty?
          occurrences.find_each do |o|
            attributes = o.occurrence.attributes
            ignored_cols.each do |col|
              attributes.delete(col)
            end
            data = attributes.values
            data.unshift article.doi
            y << CSV::Row.new(header, data).to_s
          end
        end
      end
    end

    def csv_stream_occurrences(occurrences)
      Enumerator.new do |y|
        header = ["action"].concat(Occurrence.attribute_names - ignored_cols)
        y << CSV::Row.new(header, header, true).to_s
        if !occurrences.empty?
          occurrences.find_each do |o|
            attributes = o.occurrence.attributes
            ignored_cols.each do |col|
              attributes.delete(col)
            end
            data = [o.action].concat(attributes.values)
            y << CSV::Row.new(header, data).to_s
          end
        end
      end
    end

    def csv_stream_candidates(occurrences)
      Enumerator.new do |y|
        header = ["action"].concat(Occurrence.attribute_names - ignored_cols)
                           .concat(["not me"])
        y << CSV::Row.new(header, header, true).to_s
        if !occurrences.empty?
          occurrences.each do |o|
            attributes = o.occurrence.attributes
            ignored_cols.each do |col|
              attributes.delete(col)
            end
            data = [""].concat(attributes.values)
                       .concat([""])
            y << CSV::Row.new(header, data).to_s
          end
        end
      end
    end

    def jsonld_context
      dwc_contexts = Hash[Occurrence.attribute_names
                                    .reject {|column| ignored_cols(false).include?(column)}
                                    .map{|o| ["#{o}", "http://rs.tdwg.org/dwc/terms/#{o}"] if !ignored_cols(false).include?(o)}]
      {
        "@vocab": "http://schema.org/",
        sameAs: {
          "@id": "sameAs",
          "@type": "@id"
        },
        identified: "http://rs.tdwg.org/dwc/iri/identifiedBy",
        recorded: "http://rs.tdwg.org/dwc/iri/recordedBy",
        PreservedSpecimen: "http://rs.tdwg.org/dwc/terms/PreservedSpecimen",
        as: "https://www.w3.org/ns/activitystreams#"
      }.merge(dwc_contexts)
       .merge({ datasetKey: "http://rs.gbif.org/terms/1.0/datasetKey" })
    end

    def jsonld_stream(scope = "paged")
      output = StringIO.open("", "w+")
      w = Oj::StreamWriter.new(output, indent: 1)
      w.push_object()
      w.push_value(jsonld_context.as_json, "@context")
      w.push_key("@type")
      w.push_value("Person")
      w.push_key("@id")
      w.push_value("#{Settings.base_url}/#{@user.identifier}")
      w.push_key("givenName")
      w.push_value(@user.given)
      w.push_key("familyName")
      w.push_value(@user.family)
      w.push_key("name")
      w.push_value(@user.fullname)
      w.push_value(@user.other_names.split("|"), "alternateName")
      w.push_key("sameAs")
      w.push_value(@user.uri)

      if scope == "paged"
        identifications = jsonld_occurrences_paged("identifications")
        recordings = jsonld_occurrences_paged("recordings")

        if identifications[:metadata][:prev].nil? && recordings[:metadata][:prev].nil?
          prev_url = nil
        else
          if identifications[:metadata][:prev].nil?
            prev_url = "#{Settings.base_url}/#{recordings[:metadata][:prev_url]}"
          else
            prev_url = "#{Settings.base_url}/#{identifications[:metadata][:prev_url]}"
          end
        end
        w.push_value(prev_url, "as:prev")

        current_stub = identifications[:metadata][:page_url] || recordings[:metadata][:page_url]
        if current_stub.nil?
          current_url = nil
        else
          current_url = "#{Settings.base_url}/#{current_stub}"
        end
        w.push_value(current_url, "as:current")

        if identifications[:metadata][:next].nil? && recordings[:metadata][:next].nil?
          next_url = nil
        else
          if identifications[:metadata][:next].nil?
            next_url = "#{Settings.base_url}/#{recordings[:metadata][:next_url]}"
          else
            next_url = "#{Settings.base_url}/#{identifications[:metadata][:next_url]}"
          end
        end
        w.push_value(next_url, "as:next")

        w.push_object("@reverse")
        w.push_array("identified")
        identifications[:results].each do |o|
          w.push_value(o.as_json)
        end
        w.pop
        w.push_array("recorded")
        recordings[:results].each do |o|
          w.push_value(o.as_json)
        end
        w.pop
      else
        w.push_object("@reverse")
        w.push_array("identified")
        jsonld_occurrences_enum("identifications").each do |o|
          w.push_value(o.as_json)
        end
        w.pop
        w.push_array("recorded")
        jsonld_occurrences_enum("recordings").each do |o|
          w.push_value(o.as_json)
        end
        w.pop
      end

      w.pop_all
      output.string()
    end

    def jsonld_occurrences_paged(type = "identifcations")
      begin
        pagy, results = pagy_countless(@user.send(type).includes(:claimant), items: 100)
        metadata = pagy_metadata(pagy)
      rescue
        results = []
        metadata = {
          first_url: nil,
          prev_url: nil,
          page_url: nil,
          next_url: nil,
          prev: nil,
          next: nil
        }
      end

      items = results.map do |o|
        { "@type": "PreservedSpecimen",
          "@id": "#{Settings.base_url}/occurrence/#{o.occurrence.id}",
          sameAs: "#{o.occurrence.uri}"
        }.merge(o.occurrence.attributes.reject {|column| ignored_cols(false).include?(column)})
      end
      { metadata: metadata, results: items }
    end

    def jsonld_occurrences_enum(type = "identifications")
      Enumerator.new do |y|
        @user.send(type).includes(:claimant).find_each do |o|
          y << { "@type": "PreservedSpecimen",
                 "@id": "#{Settings.base_url}/occurrence/#{o.occurrence.id}",
                 sameAs: "#{o.occurrence.uri}"
               }.merge(o.occurrence.attributes.reject {|column| ignored_cols(false).include?(column)})
        end
      end
    end

  end

end
