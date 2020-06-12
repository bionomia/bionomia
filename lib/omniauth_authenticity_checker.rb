require 'rack-protection'

class OmniauthAuthenticityChecker < Rack::Protection::AuthenticityToken
  def initialize(options = {})
    @options = default_options.merge(options)
  end

  def call(env)
    unless accepts? env
      instrument env
      react env
    end
  end

  def deny(env)
    warn env, "attack prevented by #{self.class}"
    raise Net::HTTPForbidden, options[:message]
  end
end