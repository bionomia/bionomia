require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class Zenodo < OmniAuth::Strategies::OAuth2

      option :name, "zenodo"

      option :sandbox, false

      option :authorize_options, [:response_type,
                                  :redirect_uri,
                                  :client_id,
                                  :scope,
                                  :state]

      args [:client_id, :client_secret]

      def initialize(app, *args, &block)
        super
        @options.client_options.site          = site
        @options.client_options.authorize_url = authorize_url
        @options.client_options.token_url     = token_url
      end

      def authorize_params
        super.tap do |params|
          %w[response_type redirect_uri client_id scope state].each do |v|
            if request.params[v]
              params[v.to_sym] = request.params[v]
            end
          end

          params[:redirect_uri] ||= redirect_uri
          params[:response_type] = 'code' if params[:response_type].nil?
          params[:scope] ||= scope
          params[:state] ||= state
          session['omniauth.state'] = params[:state] if params['state']
        end
      end

      #Override the build_access_token method because the redirect_uri is not supposed to have query parameters
      def build_access_token
        verifier = request.params["code"]
        client.auth_code
              .get_token(verifier, {:redirect_uri => callback_url.split("?").first}.merge(token_params.to_hash(:symbolize_keys => true)), deep_symbolize(options.auth_token_params))
      end

      def root_url
        if options[:sandbox]
          'https://sandbox.zenodo.org'
        else
          'https://zenodo.org'
        end
      end

      def site
        root_url + '/api'
      end

      def authorize_url
        root_url + '/oauth/authorize'
      end

      def token_url
        root_url + '/oauth/token'
      end

      def redirect_uri
        '/auth/zenodo/callback'
      end

      def scope
        'deposit:write deposit:actions'
      end

      def state
        SecureRandom.uuid
      end

      uid { raw_info[:user][:id] }

      info do
        {
          :access_token_hash => raw_info
        }
      end

      def raw_info
        @raw_info ||= access_token.to_hash.deep_symbolize_keys
      end
    end
  end
end
