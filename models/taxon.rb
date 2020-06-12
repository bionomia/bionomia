class Taxon < ActiveRecord::Base
  has_many :taxon_occurrences, dependent: :delete_all
  has_many :occurrences, through: :taxon_occurrences, source: :occurrence

  validates :family, presence: true
end
