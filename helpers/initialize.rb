# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module Initialize

        def self.registered(app)
          app.helpers Sinatra::ContentFor
          self.module_parent
              .constants.reject!{|h| h == :Initialize}
              .sort
              .each{|h| app.helpers (self.module_parent.to_s + "::#{h}").constantize }
        end

      end
    end
  end
end
