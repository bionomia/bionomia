class Article < ActiveRecord::Base
  attr_accessor :skip_callbacks

  has_many :article_occurrences
  has_many :occurrences, through: :article_occurrences

  has_many :occurrence_agents, through: :article_occurrences
  has_many :agents, -> { distinct }, through: :occurrence_agents

  validates :doi, presence: true
  validates :gbif_dois, presence: true
  validates :gbif_downloadkeys, presence: true

  serialize :gbif_dois, coder: JSON
  serialize :gbif_downloadkeys, coder: JSON

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
    subq = article_occurrences.joins(:user_occurrences)
                              .select(:user_id, :visible)
                              .distinct        
    User.optimizer_hints("INDEX(user_occurrences user_occurrence_idx)")
        .joins("INNER JOIN (#{subq.to_sql}) a ON a.user_id = users.id")
        .where("a.visible": true)
  end

  def agents_with_family
    agents.where.not(family: "")
  end

  def agents_occurrence_counts
    occurrence_agents.select(:agent_id, "COUNT(*) AS count_all")
                     .joins(:agent)
                     .where.not(agent: { family: "" })
                     .group(:agent_id)
  end

  def agents_occurrence_counts_unclaimed
    occurrence_agents.select(:agent_id, "COUNT(*) AS count_all")
                     .joins(:agent)
                     .left_outer_joins(:user_occurrences)
                     .where.not(agent: { family: "" })
                     .where(user_occurrences: { id: nil })
                     .group(:agent_id)
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
        headers: { Accept: "text/x-bibliography; style=american-journal-of-botany", "Accept-Charset": "UTF-8" },
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
    if !es.get(self)
      es.add(self)
    else
      es.update(self)
    end
  end

  def remove_search
    es = Bionomia::ElasticArticle.new
    begin
      es.delete(self)
    rescue
    end
  end

end
