class Organization < ActiveRecord::Base
  attr_accessor :skip_callbacks

  serialize :institution_codes, JSON

  has_many :user_organizations, dependent: :delete_all
  has_many :users, through: :user_organizations, source: :user

  after_create :add_search, unless: :skip_callbacks
  after_update :update_search, unless: :skip_callbacks
  after_destroy :remove_search, unless: :skip_callbacks

  METRICS_YEAR_RANGE = (2005..DateTime.now.year)

  def self.active_user_organizations
    self.includes(:user_organizations)
        .where(user_organizations: { end_year: nil })
        .distinct
  end

  def self.find_by_identifier(id)
    self.find_by_wikidata(id) ||
    self.find_by_ror(id) ||
    self.find_by_ringgold(id) ||
    self.find_by_grid(id)
  end

  def identifier
    wikidata || ror || grid || ringgold
  end

  def active_users
    users.includes(:user_organizations)
         .where(user_organizations: { end_year: nil })
         .where(wikidata: nil)
         .distinct
  end

  def inactive_users
    known_end = users.joins(:user_organizations)
                     .where.not(user_organizations: { end_year: nil })
    unknown_end = users.joins(:user_organizations)
                       .where.not(wikidata: nil)
    known_end.union(unknown_end).distinct
  end

  def public_users
    users.includes(:user_organizations)
         .where(user_organizations: { end_year: nil })
         .where(is_public: true)
         .distinct
  end

  def others_specimens(type = "recorded")
    date_field = type == "recorded" ? "eventDate_processed" : "dateIdentified_processed"

    data = Occurrence.joins(users: :organizations)
                .where(user_occurrences:  { visible: true })
                .where("user_occurrences.action LIKE ?", "%#{type}%")
                .where(user_organizations: { organization_id: id })
                .where("( user_organizations.end_year IS NULL AND YEAR(occurrences.#{date_field}) >= user_organizations.start_year) OR ( user_organizations.end_year IS NOT NULL AND user_organizations.start_year IS NOT NULL AND YEAR(occurrences.#{date_field}) >= user_organizations.start_year AND YEAR(occurrences.#{date_field}) <= user_organizations.end_year )")
                .where.not(occurrences: { institutionCode: nil })
                .where("occurrences.institutionCode NOT IN (?)", institution_codes)
                .distinct
                .unscope(:order)
                .pluck(:gbifID, :institutionCode).compact

    Hash.new(0).tap{ |h| data.each { |f| h[f[1]] += 1 } }
               .sort_by {|_key, value| value}
               .reverse
               .to_h
  end

  def others_specimens_by_year(type = "recorded", year = DateTime.now.year)
    date_field = type == "recorded" ? "eventDate_processed" : "dateIdentified_processed"

    data = Occurrence.joins(users: :organizations)
                .where(user_occurrences: { visible: true })
                .where("user_occurrences.action LIKE ?", "%#{type}%")
                .where(user_organizations: { organization_id: id })
                .where("( user_organizations.end_year IS NULL AND user_organizations.start_year <= ? ) OR ( user_organizations.start_year IS NOT NULL AND user_organizations.end_year IS NOT NULL )", year)
                .where("YEAR(occurrences.#{date_field}) = ?", year)
                .where.not(occurrences: { institutionCode: nil })
                .where("occurrences.institutionCode NOT IN (?)", institution_codes)
                .distinct
                .unscope(:order)
                .pluck(:gbifID, :institutionCode).compact
                .compact

    Hash.new(0).tap{ |h| data.each { |f| h[f[1]] += 1 } }
               .sort_by {|_key, value| value}
               .reverse
               .to_h
  end

  def articles
    current = Article
                .select(:id, :doi, :citation, :abstract, :created, "users.id AS user_id")
                .joins(occurrences: { users: :organizations })
                .where(user_occurrences: { visible: true })
                .where(user_organizations: { organization_id: id })
                .where(user_organizations: { end_year: nil })
                .where("YEAR(occurrences.eventDate_processed) >= user_organizations.start_year OR YEAR(occurrences.dateIdentified_processed) >= user_organizations.start_year")

    past = Article
                .select(:id, :doi, :citation, :abstract, :created, "users.id AS user_id")
                .joins(occurrences: { users: :organizations })
                .where(user_occurrences: { visible: true })
                .where(user_organizations: { organization_id: id })
                .where.not(user_organizations: { end_year: nil })
                .where.not(user_organizations: { start_year: nil })
                .where("(YEAR(occurrences.eventDate_processed) >= user_organizations.start_year AND YEAR(occurrences.eventDate_processed) <= user_organizations.end_year) OR (YEAR(occurrences.dateIdentified_processed) >= user_organizations.start_year AND YEAR(occurrences.dateIdentified_processed) <= user_organizations.end_year)")

    current.union_all(past).select(:id, :doi, :citation, :abstract, :created, "group_concat( DISTINCT user_id) AS user_ids")
           .group(:id, :doi, :citation, :abstract, :created)
           .distinct
           .order(created: :desc)
  end

  def update_wikidata
    wikidata_lib = Bionomia::WikidataSearch.new
    code = wikidata || identifier.to_s
    wiki = wikidata_lib.institution_wikidata(code)
    if wikidata
      codes = wikidata_lib.wiki_organization_codes(wikidata)
      wiki = wiki.merge(codes)
    end
    update(wiki)
  end

  def update_institution_codes
    wikidata_lib = Bionomia::WikidataSearch.new
    codes = wikidata_lib.wiki_institution_codes(identifier)
    update(codes) if !codes[:institution_codes].empty?
  end

  def update_organization_codes
    wikidata_lib = Bionomia::WikidataSearch.new
    codes = wikidata_lib.wiki_organization_codes(wikidata)
    update(codes)
  end

  private

  def add_search
    es = Bionomia::ElasticOrganization.new
    if !es.get(self)
      es.add(self)
    end
  end

  def update_search
    es = Bionomia::ElasticOrganization.new
    es.update(self)
  end

  def remove_search
    es = Bionomia::ElasticOrganization.new
    begin
      es.delete(self)
    rescue
    end
  end

end
