class SourceUser < ActiveRecord::Base
   has_many :source_attributions, foreign_key: :user_id

   def recordings
      source_attributions.where(action: "recorded")
   end

   def identifications
      source_attributions.where(action: "identified")
   end

end