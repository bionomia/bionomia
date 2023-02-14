class TaxonImage < ActiveRecord::Base
  belongs_to :taxon, foreign_key: :family, primary_key: :family

  validates :family, presence: true
  validates :file_name, presence: true

end
