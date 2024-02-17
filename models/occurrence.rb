class Occurrence < ActiveRecord::Base

  self.primary_key = :gbifID

  has_many :occurrence_agents, primary_key: :id, foreign_key: :occurrence_id
  has_many :determiners, -> { where(occurrence_agents: { agent_role: false }) }, through: :occurrence_agents, source: :agents
  has_many :recorders, -> { where(occurrence_agents: { agent_role: true }) }, through: :occurrence_agents, source: :agents

  has_many :user_occurrences
  has_many :users, -> { where(user_occurrences: { visible: true }) }, through: :user_occurrences, source: :user

  has_many :claims, class_name: "UserOccurrence"
  has_many :claimants, through: :claims, primary_key: :created_by, class_name: "User"

  has_many :article_occurrences
  has_many :articles, through: :article_occurrences, source: :article

  has_one :taxon_occurrence
  has_one :taxon, through: :taxon_occurrence, source: :taxon

  has_one :occurrence_count

  belongs_to :dataset, primary_key: :datasetKey, foreign_key: :datasetKey
  counter_culture :dataset

  alias_attribute :id, :gbifID

  validates :id, presence: true

  IGNORED_COLUMNS_OUTPUT = [
    "gbifID",
    "dateIdentified_processed",
    "eventDate_processed",
    "hasImage"
  ]

  def self.accepted_fields
    Occurrence.column_names - Occurrence::IGNORED_COLUMNS_OUTPUT
  end

  def has_image?
    hasImage
  end

  def uri
    "https://gbif.org/occurrence/#{id}"
  end

  def license_uri
    if license == "CC_BY_4_0"
      "https://creativecommons.org/licenses/by/4.0/legalcode"
    elsif license == "CC_BY_NC_4_0"
      "https://creativecommons.org/licenses/by-nc/4.0/legalcode"
    elsif license == "CC0_1_0"
      "https://creativecommons.org/publicdomain/zero/1.0/legalcode"
    end
  end

  def coordinates
    lat = decimalLatitude.to_f
    long = decimalLongitude.to_f
    if lat == 0 ||
      long == 0 ||
       lat > 90 ||
      lat < -90 ||
     long > 180 ||
     long < -180
      return nil
    end
    [long, lat]
  end

  def interpretedCountry(lang = :en)
    I18nData.countries(lang)[countryCode]
  end

  def agents
    {
      determiners: determiners.map{|d| {
        id: d[:id],
        given: d[:given],
        family: d[:family]
        }
      },
      recorders: recorders.map{|d| {
        id: d[:id],
        given: d[:given],
        family: d[:family]
        }
      }
    }
  end

  def images
    begin
      response = RestClient::Request.execute(
        method: :get,
        url: "https://api.gbif.org/v1/occurrence/#{id}"
      )
      result = JSON.parse(response, :symbolize_names => true)
      api = "https://api.gbif.org/v1/image/unsafe/"
      result[:media].map{|a| {
            original: api + CGI.escape(a[:identifier]),
            small: "#{api}fit-in/250x/#{CGI.escape(a[:identifier])}",
            large: "#{api}fit-in/750x/#{CGI.escape(a[:identifier])}",
            license: "#{a[:license]}",
            rightsHolder: "#{a[:rightsHolder]}"
            } if a[:type] == "StillImage"
          }
          .compact
    rescue
      []
    end
  end

  def user_identifications
    user_occurrences.where(visible: true)
                    .where(qry_identified)
                    .includes(:user)
                    .includes(:claimant)
  end

  def user_recordings
    user_occurrences.where(visible: true)
                    .where(qry_recorded)
                    .includes(:user)
                    .includes(:claimant)
  end

  def user_ignoreds
    user_occurrences.where(visible: false)
                    .includes(:user)
                    .includes(:claimant)
  end

  def qry_identified
    "user_occurrences.action IN ('identified', 'identified,recorded', 'recorded,identified')"
  end

  def qry_recorded
    "user_occurrences.action IN ('recorded', 'identified,recorded', 'recorded,identified')"
  end

end
