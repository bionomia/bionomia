# encoding: utf-8

module Sinatra
  module Bionomia
    module Route
      module Initialize

        def self.registered(app)

          app.before { set_session }

          self.module_parent
              .constants.reject!{|c| c == :Initialize}
              .sort
              .each{|c| app.register (self.module_parent.to_s + "::#{c}").constantize }
        end

      end
    end
  end
end
