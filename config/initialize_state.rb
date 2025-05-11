# encoding: utf-8

module Sinatra
  module Bionomia
    module Config
      module InitializeState

        def self.registered(app)
          offline_settings = KeyValue.mget(["off_datetime", "off_duration", "online_when"]) rescue {}
          if offline_settings
            Settings.add_source!({
              off_datetime: offline_settings[:off_datetime],
              off_duration: offline_settings[:off_duration],
              online_when: offline_settings[:online_when]
            })
            Settings.reload!
          end
        end

      end
    end
  end
end