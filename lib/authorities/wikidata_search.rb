# encoding: utf-8

module Bionomia
  class WikidataSearch

    PEOPLE_PROPERTIES = {
      "IPNI": "P586",
      "Harvard Index of Botanists": "P6264",
      "Entomologists of the World": "P5370",
      "ZooBank Author ID": "P2006",
      "BHL Creator ID": "P4081",
      "Stuttgart Database of Scientific Illustrators ID": "P2349",
      "Zürich Herbaria collector ID": "P10168"
    }

    def initialize
      headers = { 'User-Agent' => 'Bionomia/1.0' }
      @sparql = SPARQL::Client.new("https://query.wikidata.org/sparql", headers: headers, read_timeout: 120)
      Wikidata.configure do |config|
        config.options = {
          request: {
            timeout: 20,
            open_timeout: 20
          }
        }
        config.adapter = :typhoeus
      end
    end

    def name_parser
      options = {
        prefer_comma_as_separator: true,
        title: DwcAgent::TITLE
      }
      Namae::Parser.new(options)
    end

    def wikidata_multiple_bionomia_ids_query
      %Q(
        SELECT ?item ?itemLabel (COUNT(?value) AS ?valueCount)
        WHERE {
          ?item wdt:P6944 ?value1 .
          ?item wdt:P6944 ?value2 .
          FILTER(?value1 != ?value2)
          SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
        }
        GROUP BY ?item ?itemLabel
        HAVING (COUNT(?item) > 1)
      )
    end

    def wikidata_people_query(property)
      %Q(
          SELECT DISTINCT
            ?item ?id ?itemLabel
          WHERE {
            ?item wdt:#{property} ?id .
            SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
          }
        )
    end

    def wikidata_people_query_recent_minus_bionomia
      yesterday = Time.now - 86400
      list = PEOPLE_PROPERTIES.values.map{|a| "wdt:#{a}"}.join("|")
      %Q(
          SELECT DISTINCT
            ?item ?itemLabel
          WHERE {
            ?item #{list} ?id .
            ?item wdt:P570 ?date_of_death .
            ?item schema:dateModified ?change .
            MINUS { ?item wdt:P6944 ?bionomia . }
            SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en". }
            FILTER(?change > "#{yesterday.iso8601}"^^xsd:dateTime)
          }
        )
    end

    # With help from @rdmpage
    def wikidata_institution_code_query(identifier)
      %Q(
        SELECT DISTINCT
          *
        WHERE {
          VALUES ?identifier {"#{identifier}"} {
            # institution that includes collection has GRID, ringgold, ROR, or ISNI
            ?institution wdt:P3500|wdt:P2427|wdt:P6782|wdt:P213 ?identifier .
            # various part of relationships
            ?collection wdt:P195|wdt:P137|wdt:P749|wdt:P361 ?institution .
          } UNION {
            # collection itself has GRID, ringgold, ROR, or ISNI identifier
            ?collection wdt:P3500|wdt:P2427|wdt:P6782|wdt:P213 ?identifier .
          } UNION {
            # Use the QID if it was passed in
            BIND( wd:#{identifier} as ?institution)
            ?collection wdt:P195|wdt:P137|wdt:P749|wdt:P361 ?institution .
          }
          # Code(s) for collection
          {
            # Index Herb. or Biodiv Repo ID
            ?collection wdt:P5858|wdt:P4090 ?code .
          } UNION {
            # Derive from Wikispecies URL
            ?wikispecies schema:about ?collection .
            BIND( REPLACE( STR(?wikispecies),"https://species.wikimedia.org/wiki/","" ) AS ?code).
            FILTER contains (STR(?wikispecies),'species.wikimedia.org')
          }
        }
      )
    end

    def wikidata_institution_wiki_query(identifier)
      %Q(
        SELECT ?item ?itemLabel ?lat ?long ?image_url ?website
        WHERE {
          VALUES ?identifier {"#{identifier}"} {
            ?item wdt:P3500|wdt:P2427|wdt:P6782 ?identifier .
          }
          OPTIONAL {
            ?item p:P625 ?statement .
            ?statement psv:P625 ?coordinate_node .
            ?coordinate_node wikibase:geoLatitude ?lat .
            ?coordinate_node wikibase:geoLongitude ?long .
          }
          OPTIONAL {
            ?item wdt:P18|wdt:P154 ?image_url .
          }
          OPTIONAL {
            #TODO FILTER BY current when a date
            ?item wdt:P856 ?website .
          }
          SERVICE wikibase:label {
            bd:serviceParam wikibase:language "en" .
          }
        }
      )
    end

    def wikidata_by_orcid_query(orcid)
      %Q(
        SELECT (REPLACE(STR(?item),".*Q","Q") AS ?qid)
        WHERE {
          VALUES ?orcid {"#{orcid}"} {
            ?item wdt:P496 ?orcid .
          }
        }
      )
    end

    def wikidata_by_property_query(prop, id)
      properties = {
        viaf: "P214",
        ipni: "P586",
        bhl: "P4081",
        zoobank: "P2006",
        isni: "P213",
        congress: "P244"
      }
      property = properties[prop.downcase.to_sym]
      return if property.nil?

      %Q(
        SELECT ?item ?itemLabel
        WHERE {
          VALUES ?identifier {"#{id}"} {
            ?item wdt:#{property} ?identifier .
          }
          SERVICE wikibase:label {
            bd:serviceParam wikibase:language "en" .
          }
        }
      )
    end

    def merged_wikidata_people_query
      week_ago = Time.now - 604800
      watched_properties = PEOPLE_PROPERTIES.merge("Bionomia ID": "P6944")
      list = watched_properties.values.map{|a| "wdt:#{a}"}.join("|")
      %Q(
        SELECT DISTINCT (REPLACE(STR(?item),".*Q","Q") AS ?qid) (REPLACE(STR(?redirect),".*Q","Q") AS ?redirect_toqid)
        WHERE {
          ?redirect wdt:P31 wd:Q5 .
          ?redirect wdt:P570 ?date_of_death .
          ?redirect #{list} ?id .
          ?item owl:sameAs ?redirect .
          ?item schema:dateModified ?change .
          SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en" }
          FILTER(?change > "#{week_ago.iso8601}"^^xsd:dateTime)
        }
      )
    end

    def wikidata_modified_query
      yesterday = Time.now - 86400
      %Q(
        SELECT DISTINCT (REPLACE(STR(?item),".*Q","Q") AS ?qid)
        WHERE {
          ?item wdt:P31 wd:Q5 .
          ?item wdt:P6944 ?bionomia_id .
          ?item schema:dateModified ?change .
          SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en" }
          FILTER(?change > "#{yesterday.iso8601}"^^xsd:dateTime)
        }
      )
    end

    def wikidata_candidate_deletion_query
      %Q(
        SELECT DISTINCT ?item ?itemLabel
        WHERE {
          SERVICE wikibase:mwapi {
            bd:serviceParam wikibase:endpoint "www.wikidata.org".
            bd:serviceParam wikibase:api "Generator".
            bd:serviceParam mwapi:generator "links".
            bd:serviceParam mwapi:titles "Wikidata:Requests for deletions".
            bd:serviceParam mwapi:gpllimit "max".
            bd:serviceParam mwapi:gplnamespace "0".
            ?item wikibase:apiOutputItem mwapi:title.
          }
          ?item wdt:P6944 ?id .
          SERVICE wikibase:label { bd:serviceParam wikibase:language "en". }
        }
      )
    end

    def users_flagged_deletion
      flagged = []
      @sparql.query(wikidata_candidate_deletion_query)
             .each_solution do |solution|
               flagged << solution.to_h[:item].to_s
      end
      flagged.uniq
    end

    def new_users
      existing = existing_wikicodes + destroyed_users
      new_wikicodes = {}
      @sparql.query(wikidata_people_query_recent_minus_bionomia)
             .each_solution do |solution|
        wikicode = solution.to_h[:item].to_s.match(/Q[0-9]{1,}/).to_s
        next if existing.include? wikicode
        new_wikicodes[wikicode] = solution.to_h[:itemLabel].to_s
      end
      new_wikicodes
    end

    def modified_users
      requires_refresh = []
      @sparql.query(wikidata_modified_query)
             .each_solution do |solution|
        requires_refresh << solution.to_h[:qid].to_s.match(/Q[0-9]{1,}/).to_s
      end
      requires_refresh.uniq
    end

    def merged_users
      merged_wikicodes = {}
      @sparql.query(merged_wikidata_people_query)
             .each_solution do |solution|
        qid = solution.to_h[:qid].to_s.match(/Q[0-9]{1,}/).to_s
        merged_wikicodes[qid] =  solution.to_h[:redirect_toqid]
                                         .to_s
                                         .match(/Q[0-9]{1,}/)
                                         .to_s
      end
      merged_wikicodes
    end

    def add_new_users
      new_users.each do |wikicode, name|
        parsed = name_parser.parse(name.dup)[0] rescue nil
        if parsed.nil?
          parsed = DwcAgent.parse(name.dup)[0] rescue nil
        end
        next if parsed.nil? || parsed.family.nil? || parsed.given.nil?
        user_data = wiki_user_data(wikicode)
        date_died = user_data[:date_died]
        date_born = user_data[:date_born]
        date_died_precision = user_data[:date_died_precision]
        date_born_precision = user_data[:date_born_precision]
        next if !(
              ( !date_died.nil? && !date_died_precision.nil? ) ||
              ( !date_born.nil? && !date_born_precision.nil? && Date.today.year - date_born.year >= 120 )
            )

        # We have the user with that ORCID so switch to wikidata
        if user_data[:orcid] && User.where(orcid: user_data[:orcid]).exists?
          user = User.find_by_orcid(user_data[:orcid])
          user.orcid = nil
          user.wikidata = wikicode
          user.save
          user.reload
          user.update_profile
          user.flush_caches
          DestroyedUser.create(identifier: user_data[:orcid], redirect_to: wikicode)
        else
          u = User.find_or_create_by({ wikidata: wikicode })
          if !u.valid_wikicontent?
            u.delete_search
            u.delete
            puts "#{u.wikidata} deleted. Missing either label, birth or death date".red
          else
            puts "#{u.viewname}".green
          end
        end
      end
    end

    def merge_users
      merged_wikicodes = merged_users.dup
      qids_to_merge = merged_wikicodes.keys & existing_wikicodes
      qids_to_merge.each do |qid|
        dest_id = merged_wikicodes[qid]
        User.merge_users(src_id: qid, dest_id: dest_id)
        puts "#{qid} => #{dest_id}".red
      end
    end

    def wiki_institution_codes(identifier)
      institution_codes = []
      @sparql.query(wikidata_institution_code_query(identifier))
             .each_solution do |solution|
        institution_codes << solution.code.to_s
      end
      { institution_codes: institution_codes.compact.uniq }
    end

    def wiki_organization_codes(qid)
      data = Wikidata::Item.find(qid)
      isni = data.properties("P213").first.value.gsub(/[[:space:]]+/, "") rescue nil
      grid = data.properties("P2427").first.value rescue nil
      ringgold = data.properties("P3500").first.value rescue nil
      ror = data.properties("P6782").first.value rescue nil
      { isni: isni, grid: grid, ringgold: ringgold, ror: ror }
    end

    def institution_wikidata(identifier)
      name, wikicode, latitude, longitude, image_url, logo_url, website = nil

      if identifier.match(/Q[0-9]{1,}/)
        data = Wikidata::Item.find(identifier)
        name = data.title
        wikicode = identifier
        latitude = data.properties("P625").first.latitude.to_f rescue nil
        longitude = data.properties("P625").first.longitude.to_f rescue nil
        image = data.properties("P18").first.url rescue nil
        logo = data.properties("P154").first.url rescue nil
        image_url = image || logo
        website = data.properties("P856").last.value rescue nil
      else
        response = @sparql.query(wikidata_institution_wiki_query(identifier))
                          .first
        if response
          name = response[:itemLabel].to_s if !response[:itemLabel].nil?
          wikicode = response[:item].to_s.match(/Q[0-9]{1,}/).to_s
          latitude = response[:lat].to_f if !response[:lat].nil?
          longitude = response[:long].to_f if !response[:long].nil?
          image_url = response[:image_url].to_s if !response[:image_url].nil?
          website = response[:website].to_s if !response[:website].nil?
        end
      end
      {
        name: name,
        wikidata: wikicode,
        latitude: latitude,
        longitude: longitude,
        image_url: image_url,
        website: website
      }
    end

    def parse_wikitime(time, precision)
      year = nil
      month = nil
      day = nil
      d = Hash[[:year, :month, :day, :hour, :min, :sec].zip(
        time.scan(/(-?\d+)-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/)
            .first
            .map(&:to_i)
      )]
      if precision > 8
        year = d[:year]
      end
      if precision > 9
        month = d[:month]
      end
      if precision > 10
        day = d[:day]
      end
      { year: year, month: month, day: day }
    end

    def rank_score(rank)
      case rank
      when "preferred"
        2
      when "normal"
        1
      when "deprecated"
        -1
      else
        0
      end
    end

    def wiki_date_precision(wiki_user, property)
      data = wiki_user.properties(property)
                      .map{|a| { 
                        precision: a.precision_key,
                        date: a.value.time,
                        rank: rank_score(a.property.rank)
                        }
                      }
                      .sort_by{|v| -v[:rank] }
                      .first rescue { precision: nil }
      return [nil, nil] if data.nil? || data.empty?

      case data[:precision]
      when :day
        [Date.parse(data[:date]), "day"]
      when :month
        [Date.parse(data[:date][1..7] + "-01"), "month"]
      when :year
        [Date.parse(data[:date][1..4] + "-01-01"), "year"]
      when :century
        [Date.parse(data[:date][1..4] + "-01-01"), "century"]
      else
        [nil, nil]
      end
    end

    def ranked_name(items)
      items.map{|a| { 
        title: a.title,
        rank: (rank_score(a.property.rank) rescue 0)
        }
      }
      .sort_by{|v| -v[:rank] }
      .map{|a| a[:title] }
      .compact
      .join(" ") rescue nil
    end

    def extract_sitelinks(wiki_user)
      wiki_user.sitelinks
               .slice(*I18n.backend.translations.keys.map{|k| "#{k}wiki"}) rescue nil
    end

    def wiki_user_data(wikicode)
      wiki_user = Wikidata::Item.find(wikicode)

      if !wiki_user ||
          wiki_user.properties("P31").size == 0 ||
         !wiki_user.properties("P31")[0].respond_to?("title") ||
          wiki_user.properties("P31")[0].title != "human"
        return
      end

      label = wiki_user.title
      family = ranked_name(wiki_user.properties("P734"))
      given = ranked_name(wiki_user.properties("P735"))
      particle = nil

      parsed = name_parser.parse(label.dup)[0] rescue nil
      if parsed.nil?
        parsed = DwcAgent.parse(label.dup)[0] rescue nil
      end

      particle = parsed.particle rescue nil

      if family.blank?
        family = parsed.family rescue nil
      end

      if given.blank?
        given = parsed.given rescue nil
      end

      if family.blank? && !given.blank?
        family = given.dup
        given = ""
      end

      country = wiki_user.properties("P27")
                         .compact
                         .map(&:title)
                         .join("|") rescue nil
      country_code = wiki_user.properties("P27")
                              .compact
                              .map{|a| I18nData.country_code(a.title) || IsoCountryCodes.search_by_name(a.title).first.alpha2 || "" }
                              .compact
                              .join("|")
                              .presence rescue nil
      keywords = wiki_user.properties("P106")
                          .map{|k| k.title if !/^Q\d+/.match?(k.title)}
                          .compact
                          .join("|") rescue nil
      description = wiki_user.descriptions["en"].value rescue nil
      orcid = wiki_user.properties("P496")
                       .first
                       .value rescue nil

      image_url = nil
      signature_url = nil
      youtube_id = wiki_user.properties("P1651").first.value rescue nil
      image = wiki_user.image.value rescue nil
      if image
        image_url = "https://commons.wikimedia.org/wiki/Special:FilePath/" << Addressable::URI.encode(image)
      end
      signature = wiki_user.properties("P109").first.value rescue nil
      if signature
        signature_url = "https://commons.wikimedia.org/wiki/Special:FilePath/" << Addressable::URI.encode(signature)
      end

      other_names = ""
      aliases = []
      aliases.concat(wiki_user.properties("P1559").compact.map{|a| a.value.text})
      aliases.concat(wiki_user.aliases.values.compact.map{|a| a.map{|b| b.value if b.language == "en"}.compact}.flatten) rescue nil
      if aliases.length > 0
        other_names = aliases.uniq.join("|")
      end

      date_born, date_born_precision = wiki_date_precision(wiki_user, "P569")
      date_died, date_died_precision = wiki_date_precision(wiki_user, "P570")

      organizations = []
      ["P108", "P1416"].each do |property|
        wiki_user.properties(property).each do |org|
          next if org.nil? || (org.title rescue nil).nil?
          organization = wiki_user_organization(wiki_user, org, property)
          organizations << organization
        end
      end

      {
        wikidata: wiki_user.id,
        family: family,
        given: given,
        particle: particle,
        label: label,
        other_names: other_names,
        country: country,
        country_code: country_code,
        keywords: keywords,
        description: description,
        orcid: orcid,
        image_url: image_url,
        signature_url: signature_url,
        youtube_id: youtube_id,
        date_born: date_born,
        date_born_precision: date_born_precision,
        date_died: date_died,
        date_died_precision: date_died_precision,
        wiki_sitelinks: extract_sitelinks(wiki_user),
        organizations: organizations
      }
    end

    def wiki_user_organization(wiki_user, org, property)
      start_time = { year: nil, month: nil, day: nil }
      end_time = { year: nil, month: nil, day: nil }

      qualifiers = wiki_user.hash[:claims][property.to_sym]
                            .select{|a| a[:mainsnak][:datavalue][:value][:id] == org.id}
                            .first
                            .qualifiers rescue nil
      if !qualifiers.nil?
        start_precision = qualifiers[:P580].first
                                           .datavalue
                                           .value
                                           .precision rescue nil
        if !start_precision.nil?
          start_time = parse_wikitime(qualifiers[:P580].first.datavalue.value.time, start_precision)
        end

        end_precision = qualifiers[:P582].first
                                         .datavalue
                                         .value
                                         .precision rescue nil
        if !end_precision.nil?
          end_time = parse_wikitime(qualifiers[:P582].first.datavalue.value.time, end_precision)
        end
      end
      {
        name: org.title,
        wikidata: org.id,
        ringgold: nil,
        grid: nil,
        ror: nil,
        address: nil,
        start_day: start_time[:day],
        start_month: start_time[:month],
        start_year: start_time[:year],
        end_day: end_time[:day],
        end_month: end_time[:month],
        end_year: end_time[:year]
      }
    end

    def wiki_user_by_orcid(orcid)
      data = {}
      wikicode = @sparql.query(wikidata_by_orcid_query(orcid)).first[:qid].value rescue nil
      if wikicode
        wiki_user = Wikidata::Item.find(wikicode)
        data[:qid] = wikicode
        data[:bionomia_id] = wiki_user.properties("P6944").first.value rescue nil
        data[:youtube_id] = wiki_user.properties("P1651").first.value rescue nil
        data[:wiki_sitelinks] = extract_sitelinks(wiki_user)
      end
      data
    end

    def wiki_bionomia_id
      ids = []
      @sparql.query(wikidata_people_query("P6944")).each_solution do |solution|
        ids << solution.to_h[:id].to_s
      end
      ids.uniq
    end

    def wiki_bionomia_multiple_ids
      ids = []
      @sparql.query(wikidata_multiple_bionomia_ids_query).each_solution do |solution|
        ids << solution.to_h[:id].to_s
      end
      ids.uniq
    end

    def wiki_by_property(property, identifier)
      data = {}
      @sparql.query(wikidata_by_property_query(property, identifier)).each_solution do |solution|
        data[:wikidata] = solution.to_h[:item].to_s.match(/Q[0-9]{1,}/).to_s
      end
      data
    end

    def existing_wikicodes
      User.pluck(:wikidata).compact
    end

    def destroyed_users
      DestroyedUser.pluck(:identifier).compact
    end

  end
end
