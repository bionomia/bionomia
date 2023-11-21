class SourceAttribution < ActiveRecord::Base
   belongs_to :source_user, foreign_key: :id, primary_key: :user_id
end