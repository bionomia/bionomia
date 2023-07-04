# encoding: utf-8
require 'filemagic'

module Bionomia
  class Zenodo

    def initialize(user:, opts: {})
      @bucket_url = nil
      @user = user
      @settings = Settings.merge!(opts)
    end

    def creator
      if @user.orcid
        { name: @user.viewname, orcid: @user.orcid }
      else
        { name: @user.viewname }
      end
    end

    def global_metadata
      hash = {
        upload_type: "dataset",
        title: "Natural history specimens collected and/or identified and deposited.",
        creators:  [ creator ],
        description: "Natural history specimen data collected and/or identified by #{@user.viewname}, <a href=\"#{@user.uri}\">#{@user.uri}</a>. Claims or attributions were made on Bionomia, <a href=\"http://bionomia.net\">https://bionomia.net</a> using specimen data from the Global Biodiversity Information Facility, <a href=\"https://gbif.org\">https://gbif.org</a>.",
        access_right: "open",
        license: "cc-zero",
        keywords: ["specimen", "natural history", "taxonomy"],
        communities: [{ identifier: 'bionomia' }]
      }
      if @user.wikidata
        hash.merge!({ notes: @user.uri })
      end
      hash
    end

    def client
      @client ||= OAuth2::Client.new(@settings.zenodo.key, @settings.zenodo.secret,
                      site: @settings.zenodo.site,
                      authorize_url: @settings.zenodo.authorize_url,
                      token_url:  @settings.zenodo.token_url,
                      token_method: :post) do |stack|
                        stack.request :multipart
                        stack.request :url_encoded
                        stack.adapter Faraday.default_adapter
                  end
    end

    def new_deposit_url
      "/api/deposit/depositions"
    end

    def deposit_url(id)
      "/api/deposit/depositions/#{id}"
    end

    def deposits_url
      "/api/deposit/depositions"
    end

    def list_files_url(id)
      "/api/deposit/depositions/#{id}/files"
    end

    def delete_file_url(id, file_id)
      "/api/deposit/depositions/#{id}/files/#{file_id}"
    end

    def new_version_url(id)
      "/api/deposit/depositions/#{id}/actions/newversion"
    end

    def discard_version_url(id)
      "/api/deposit/depositions/#{id}/actions/discard"
    end

    def delete_url(id)
      "/api/deposit/depositions/#{id}"
    end

    def publish_url(id)
      "/api/deposit/depositions/#{id}/actions/publish"
    end

    def token_hash
      @token_hash ||= ( @user.orcid ? @user.zenodo_access_token : { access_token: @settings.zenodo.access_token } )
    end

    def access_token
      @access_token ||= OAuth2::AccessToken.from_hash(client, token_hash)
    end

    # Have to store this again otherwise can no longer use the old one
    def refresh_token
      params = { client_id: @settings.zenodo.key, client_secret: @settings.zenodo.secret }
      @access_token = access_token.refresh(params)
      @access_token.to_hash.deep_symbolize_keys
    end

    def list_deposits
      response = access_token.get(deposits_url)
      JSON.parse(response.body).map(&:deep_symbolize_keys)
    end

    # Returns { upload_type: ... , prereserve_doi: { doi: "10.5281/zenodo.2652235", recid: 2652235 }
    def get_deposit(id:)
      raw_response = access_token.get(deposit_url(id))
      response = JSON.parse(raw_response.body).deep_symbolize_keys
      @bucket_url = response[:links][:bucket]
      response[:metadata]
    end

    def update_deposit(id:, metadata:)
      headers = { "Content-Type": "application/json" }
      body = { metadata: metadata }
      raw_response = access_token.put(deposit_url(id), { body: body.to_json, headers: headers })
      JSON.parse(raw_response.body).deep_symbolize_keys
    end

    # Input, name: "Shorthouse, David", orcid: "0000-0001-7618-5230"
    # Returns { doi: "10.5281/zenodo.2652234", recid: 2652234}
    def new_deposit
      headers = { "Content-Type": "application/json" }
      body = { metadata: global_metadata }
      raw_response = access_token.post(new_deposit_url, { body: body.to_json, headers: headers })
      response = JSON.parse(raw_response.body).deep_symbolize_keys
      @bucket_url = response[:links][:bucket]
      response[:metadata][:prereserve_doi]
    end

    def list_files(id:)
      raw_response = access_token.get(list_files_url(id))
      JSON.parse(raw_response.body).map(&:deep_symbolize_keys)
    end

    # Uses Net::HTTP here and not the OAuth2 Faraday adapter because these cannot stream a body
    def add_file(file_path:, file_name: nil)
      filename = file_name ||= File.basename(file_path)
      uri = URI(@bucket_url + "/#{filename}")
      io = File.open(file_path, "rb")
      total_size = io.dup.size
      header = {
        "Content-Type" => "application/octet-stream",
        "Content-Length" => "#{total_size}",
        "Authorization" => "Bearer #{access_token.token}"
      }
      request = Net::HTTP::Put.new(uri.request_uri, header)
      request.body_stream = io
      http = Net::HTTP.new(uri.hostname, uri.port)
      http.use_ssl = true
      response = http.request(request)
      io.close
      if response.code.to_i != 200
        raise RuntimeError, "File upload failed."
      end
      JSON.parse(response.body).deep_symbolize_keys
    end

    def delete_file(id:, file_id:)
      access_token.delete(delete_file_url(id, file_id))
    end

    def new_version(id:)
      raw_response = access_token.post(new_version_url(id))
      response = JSON.parse(raw_response.body).deep_symbolize_keys
      new_id = response[:links][:latest_draft].split("/").last.to_i
      metadata = get_deposit(id: new_id)
      metadata.merge!(global_metadata)
      metadata[:publication_date] = Time.now.strftime('%F')
      update_deposit(id: new_id, metadata: metadata)
      metadata[:prereserve_doi]
    end

    def discard_version(id:)
      begin
        raw_response = access_token.post(discard_version_url(id))
        JSON.parse(raw_response.body).deep_symbolize_keys
      rescue
        {}
      end
    end

    def delete_draft(id:)
      begin
        raw_response = access_token.delete(delete_url(id))
        JSON.parse(raw_response.body).deep_symbolize_keys
      rescue
        {}
      end
    end

    # concept DOI is returned as [:conceptdoi] whereas version DOI is [:doi]
    def publish(id:)
      begin
        response = access_token.post(publish_url(id))
        JSON.parse(response.body).deep_symbolize_keys
      rescue
        { doi: nil }
      end
    end

  end
end
