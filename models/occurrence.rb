class Occurrence < ActiveRecord::Base

  self.primary_key = :gbifID

  has_many :occurrence_agents
  has_many :recorders, -> { where(occurrence_agents: { agent_role: true }) }, through: :occurrence_agents, source: :agent
  has_many :determiners, -> { where(occurrence_agents: { agent_role: false }) }, through: :occurrence_agents, source: :agent

  has_many :user_occurrences
  has_many :users, -> { where(user_occurrences: { visible: true }) }, through: :user_occurrences, source: :user

  has_many :collectors, -> { where(user_occurrences: { action: ["recorded", "recorded,identified", "identified,recorded"]}) }, through: :user_occurrences, source: :user
  has_many :identifiers, -> { where(user_occurrences: { action: ["identified", "recorded,identified", "identified,recorded"]}) }, through: :user_occurrences, source: :user

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
    "hasImage",
    "eventDate_processed_year",
    "eventDate_processed_month",
    "eventDate_processed_day",
    "dateIdentified_processed_year",
    "dateIdentified_processed_month",
    "dateIdentified_processed_day"
  ]

  def self.accepted_fields
    Occurrence.column_names - Occurrence::IGNORED_COLUMNS_OUTPUT
  end

  def self.images(id:)
    begin
      response = RestClient::Request.execute(
        method: :get,
        url: "https://api.gbif.org/v1/occurrence/#{id}"
      )
      result = JSON.parse(response, :symbolize_names => true)
      api = "https://api.gbif.org/v1/image/cache/fit-in/"
      result[:media].map do |a|
        if a[:type] == "StillImage" && a[:identifier]
          md5 = Digest::MD5.hexdigest(a[:identifier])
          {
            original: "https://api.gbif.org/v1/image/unsafe/" + CGI.escape(a[:identifier]),
            small: "#{api}250x/occurrence/#{id}/media/#{md5}",
            large: "#{api}750x/occurrence/#{id}/media/#{md5}",
            license: "#{a[:license]}",
            rightsHolder: "#{a[:rightsHolder]}"
          }
        end
      end.compact
    rescue
      []
    end
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

  def occurrence_recorders
    occurrence_agents.where(agent_role: true)
  end

  def occurrence_determiners
    occurrence_agents.where(agent_role: false)
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
