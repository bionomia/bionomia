class Article < ActiveRecord::Base
  attr_accessor :skip_callbacks

  has_many :article_occurrences
  has_many :occurrences, through: :article_occurrences, source: :occurrence

  validates :doi, presence: true
  validates :gbif_dois, presence: true
  validates :gbif_downloadkeys, presence: true

  serialize :gbif_dois, JSON
  serialize :gbif_downloadkeys, JSON

  after_create :update_citation, :add_search, unless: :skip_callbacks
  after_update :update_citation, :update_search, :flush_cache, unless: :skip_callbacks
  after_destroy :remove_search, unless: :skip_callbacks

  include ActionView::Helpers::SanitizeHelper

  def user_specimen_count(user_id)
    article_occurrences.joins(:user_occurrences)
                       .where(user_occurrences: { user_id: user_id, visible: true })
                       .count
  end


  def claimed_specimen_count
    article_occurrences.select(:occurrence_id)
                       .joins(:user_occurrences)
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
                    .joins(:article_occurrence)
                    .group(:agent_id)
                    .where(article_occurrences: { article_id: id })
    recorders = OccurrenceRecorder
                    .select(:agent_id)
                    .joins(:article_occurrence)
                    .group(:agent_id)
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
                    .joins(:article_occurrence)
                    .where(article_occurrences: { article_id: id })
    recorders = OccurrenceRecorder
                    .joins(:article_occurrence)
                    .where(article_occurrences: { article_id: id })
    recorders.union_all(determiners)
             .select(:agent_id, "count(*) AS count_all")
             .group(:agent_id)
             .order(count_all: :desc)
  end

  def agents_occurrence_counts_unclaimed
    determiners = OccurrenceDeterminer
                    .joins(:article_occurrence)
                    .joins("LEFT OUTER JOIN user_occurrences ON occurrence_determiners.occurrence_id = user_occurrences.occurrence_id AND user_occurrences.action IN ('identified', 'identified,recorded', 'recorded,identified')")
                    .where(article_occurrences: { article_id: id })
                    .where(user_occurrences: { occurrence_id: nil })
                    .distinct
    recorders = OccurrenceRecorder
                    .joins(:article_occurrence)
                    .joins("LEFT OUTER JOIN user_occurrences ON occurrence_recorders.occurrence_id = user_occurrences.occurrence_id AND user_occurrences.action IN ('recorded', 'identified,recorded', 'recorded,identified')")
                    .where(article_occurrences: { article_id: id })
                    .where(user_occurrences: { occurrence_id: nil })
                    .distinct
    recorders.union_all(determiners)
             .select(:agent_id, "count(*) AS count_all")
             .group(:agent_id)
             .order(count_all: :desc)
  end

  def flush_cache
    return if !::Module::const_get("BIONOMIA")
    stats = Class.new
    stats.extend Sinatra::Bionomia::Helper::ArticleHelper
    BIONOMIA.cache_put_tag("blocks/article-#{id}-stats", stats.article_stats(self))
  end

  private

  def update_citation
    begin
      response = RestClient::Request.execute(
        method: :get,
        headers: { Accept: "text/x-bibliography; style=american-journal-of-botany" },
        url: "https://doi.org/" + URI.encode_www_form_component(doi)
      )
      if !response.body.nil?
        citation = strip_tags(response).sub("https://doi.org/" + doi,"").strip
        self.update_columns(citation: citation)
      end
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
