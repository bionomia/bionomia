# encoding: utf-8

module Sinatra
  module Bionomia
    module Controller
      module Initialize

        def self.registered(app)
          self.module_parent
              .constants.reject!{|c| c == :Initialize}
              .sort
              .each{|c| app.register (self.module_parent.to_s + "::#{c}").constantize }
        end

      end
    end
  end
end
