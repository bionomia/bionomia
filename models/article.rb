class Article < ActiveRecord::Base
  attr_accessor :skip_callbacks

  has_many :article_occurrences
  has_many :occurrences, through: :article_occurrences, source: :occurrence

  validates :doi, presence: true
  validates :gbif_dois, presence: true
  validates :gbif_downloadkeys, presence: true

  serialize :gbif_dois, Array
  serialize :gbif_downloadkeys, Array

  after_create :update_citation, :add_search, unless: :skip_callbacks
  after_update :update_citation, :update_search, unless: :skip_callbacks
  after_destroy :remove_search, unless: :skip_callbacks

  include ActionView::Helpers::SanitizeHelper

  def user_specimen_count(user_id)
    article_occurrences.joins(:user_occurrences)
                       .where(user_occurrences: { user_id: user_id, visible: true } )
                       .count
  end


  def claimed_specimen_count
    article_occurrences.select(:occurrence_id)
                       .joins("INNER JOIN user_occurrences FORCE INDEX (user_occurrence_idx) ON article_occurrences.occurrence_id = user_occurrences.occurrence_id")
                       .where(user_occurrences: { visible: true })
                       .distinct
                       .count
  end

  def claimants
    User.joins("INNER JOIN ( SELECT DISTINCT
              user_occurrences.user_id, user_occurrences.visible
            FROM
              user_occurrences FORCE INDEX (user_occurrence_idx)
            INNER JOIN
              article_occurrences ON article_occurrences.occurrence_id = user_occurrences.occurrence_id
            WHERE
              article_occurrences.article_id = #{id}
            ) a ON a.user_id = users.id")
        .where("a.visible = true")
  end

  def agents
    determiners = OccurrenceDeterminer
                    .select(:agent_id)
                    .joins("INNER JOIN article_occurrences ON article_occurrences.occurrence_id = occurrence_determiners.occurrence_id")
                    .where(article_occurrences: { article_id: id })
    recorders = OccurrenceRecorder
                    .select(:agent_id)
                    .joins("INNER JOIN article_occurrences ON article_occurrences.occurrence_id = occurrence_recorders.occurrence_id")
                    .where(article_occurrences: { article_id: id })
    combined = recorders
                    .union_all(determiners)
                    .unscope(:order)
                    .select(:agent_id)
                    .distinct
    Agent.where(id: combined).order(:family)
  end

  def agents_occurrence_counts
    determiners = OccurrenceDeterminer
                    .joins("INNER JOIN article_occurrences ON article_occurrences.occurrence_id = occurrence_determiners.occurrence_id")
                    .where(article_occurrences: { article_id: id })
    recorders = OccurrenceRecorder
                    .joins("INNER JOIN article_occurrences ON article_occurrences.occurrence_id = occurrence_recorders.occurrence_id")
                    .where(article_occurrences: { article_id: id })
    recorders.union_all(determiners)
             .select(:agent_id, "count(*) AS count_all")
             .group(:agent_id)
             .order(count_all: :desc)
  end

  def agents_occurrence_counts_unclaimed
    determiners = OccurrenceDeterminer
                    .joins("INNER JOIN article_occurrences ON occurrence_determiners.occurrence_id = article_occurrences.occurrence_id")
                    .joins("LEFT OUTER JOIN user_occurrences ON occurrence_determiners.occurrence_id = user_occurrences.occurrence_id AND user_occurrences.action IN ('identified', 'identified,recorded', 'recorded,identified')")
                    .where(article_occurrences: { article_id: id })
                    .where(user_occurrences: { occurrence_id: nil })
                    .distinct
    recorders = OccurrenceRecorder
                    .joins("INNER JOIN article_occurrences ON occurrence_recorders.occurrence_id = article_occurrences.occurrence_id")
                    .joins("LEFT OUTER JOIN user_occurrences ON occurrence_recorders.occurrence_id = user_occurrences.occurrence_id AND user_occurrences.action IN ('recorded', 'identified,recorded', 'recorded,identified')")
                    .where(article_occurrences: { article_id: id })
                    .where(user_occurrences: { occurrence_id: nil })
                    .distinct
    recorders.union(determiners)
             .select(:agent_id, "count(*) AS count_all")
             .group(:agent_id)
             .order(count_all: :desc)
  end

  private

  def update_citation
    begin
      response = RestClient::Request.execute(
        method: :get,
        headers: { Accept: "text/x-bibliography" },
        url: "https://doi.org/" + URI.encode_www_form_component(doi)
      )
      self.update_columns(citation: strip_tags(response))
    rescue
    end
  end

  def add_search
    es = Bionomia::ElasticArticle.new
    if !es.get(self)
      es.add(self)
    end
  end

  def update_search
    es = Bionomia::ElasticArticle.new
    es.update(self)
  end

  def remove_search
    es = Bionomia::ElasticArticle.new
    begin
      es.delete(self)
    rescue
    end
  end

end
