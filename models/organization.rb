class Organization < ActiveRecord::Base
  attr_accessor :skip_callbacks

  serialize :institution_codes, coder: JSON

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
    self.find_by_grid(id) ||
    self.find_by_isni(id)
  end

  def self.merge(ids)
    ids = ids.map(&:to_i)
    orgs = self.joins(:user_organizations)
               .where(id: ids)
               .group(:isni, :ringgold, :grid, :ror, :wikidata, :address, :institution_codes, :name, :id)
               .select(:isni, :ringgold, :grid, :ror, :wikidata, :address, :institution_codes, :name, :id, "COUNT(user_organizations.user_id) AS user_count")
               .order("user_count DESC")

    isni = orgs.map(&:isni).uniq.compact
    ringgold = orgs.map(&:ringgold).uniq.compact
    grid = orgs.map(&:grid).uniq.compact
    ror = orgs.map(&:ror).uniq.compact
    wikidata = orgs.map(&:wikidata).uniq.compact
    address = orgs.map(&:address).uniq.compact
    institution_codes = orgs.map(&:institution_codes).uniq.compact

    if isni.size > 1 || ringgold.size > 1 || grid.size > 1 || ror.size > 1 || wikidata.size > 1
      raise StandardError.new "Organizations cannot be merged until identifiers are resolved."
    end

    destination = orgs.first
    org = Organization.find(destination.id)
    org.isni = isni.first
    org.ringgold = ringgold.first
    org.grid = grid.first
    org.ror = ror.first
    org.wikidata = wikidata.first
    org.address = address.first
    org.institution_codes = institution_codes.flatten.uniq
    org.save
    org.update_wikidata

    organizations = orgs.dup

    Organization.where(id: ids - [destination.id]).find_each do |o|
      o.user_organizations.update_all(organization_id: destination.id)
      o.destroy
    end

    organizations
  end

  def identifier
    wikidata || ror || grid || ringgold || isni
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
    date_field = type == "recorded" ? "eventDate_processed_year" : "dateIdentified_processed_year"
    start_year = user_organizations.minimum(:start_year) || 1600

    Occurrence.joins(:user_occurrences)
      .joins("INNER JOIN user_organizations ON user_organizations.user_id = user_occurrences.user_id")
      .where(user_organizations: { organization_id: id })
      .where("( user_organizations.end_year IS NULL AND occurrences.#{date_field} >= user_organizations.start_year) OR ( user_organizations.end_year IS NOT NULL AND user_organizations.start_year IS NOT NULL AND occurrences.#{date_field} >= user_organizations.start_year AND occurrences.#{date_field} <= user_organizations.end_year )")
      .where("user_occurrences.action LIKE ?", "%#{type}%")
      .where.not(occurrences: { institutionCode: nil })
      .where("occurrences.institutionCode NOT IN (?)", institution_codes)
      .where("occurrences.#{date_field} >= #{start_year}")
      .unscope(:order)
      .pluck(:institutionCode).tally
  end

  def others_specimens_by_year(type = "recorded", year = DateTime.now.year)
    date_field = type == "recorded" ? "eventDate_processed_year" : "dateIdentified_processed_year"

    Occurrence.joins(:user_occurrences)
      .joins("INNER JOIN user_organizations ON user_organizations.user_id = user_occurrences.user_id")
      .where(user_organizations: { organization_id: id })
      .where("( user_organizations.end_year IS NULL AND user_organizations.start_year <= ? ) OR ( user_organizations.start_year <= ? AND user_organizations.end_year >= ? )", year, year, year)
      .where("occurrences.#{date_field} = ?", year)
      .where("user_occurrences.action LIKE ?", "%#{type}%")
      .where.not(occurrences: { institutionCode: nil })
      .where("occurrences.institutionCode NOT IN (?)", institution_codes)
      .unscope(:order)
      .pluck(:institutionCode).tally
  end

  def articles
    current = Article
                .joins(occurrences: { users: :user_organizations })
                .where(user_occurrences: { visible: true })
                .where(user_organizations: { organization_id: id })
                .where(user_organizations: { end_year: nil })
                .where("occurrences.eventDate_processed_year > 1900")
                .where("user_organizations.start_year > 1900")
                .where("occurrences.eventDate_processed_year >= user_organizations.start_year OR occurrences.dateIdentified_processed_year >= user_organizations.start_year")

    past = Article
                .joins(occurrences: { users: :user_organizations })
                .where(user_occurrences: { visible: true })
                .where(user_organizations: { organization_id: id })
                .where.not(user_organizations: { end_year: nil })
                .where.not(user_organizations: { start_year: nil })
                .where("(occurrences.eventDate_processed_year >= user_organizations.start_year AND occurrences.eventDate_processed_year <= user_organizations.end_year) OR (occurrences.dateIdentified_processed_year >= user_organizations.start_year AND occurrences.dateIdentified_processed_year <= user_organizations.end_year)")

    current.or(past)
           .select(:id, :doi, :citation, :abstract, :created, "GROUP_CONCAT(DISTINCT users.id) AS user_ids")
           .group(:id, :doi, :citation, :abstract, :created)
           .order(created: :desc)
  end

  def update_wikidata
    wikidata_lib = Bionomia::WikidataSearch.new
    code = wikidata || identifier.to_s
    wiki = wikidata_lib.institution_wikidata(code)
    if wikidata
      codes = wikidata_lib.wiki_organization_codes(wikidata)
      codes[:ringgold] = ringgold || codes[:ringgold]
      wiki = wiki.merge(codes)
    end
    update(wiki)
  end

  def update_institution_codes
    wikidata_lib = Bionomia::WikidataSearch.new
    codes = wikidata_lib.wiki_institution_codes(identifier)
    codes[:institution_codes].push(*institution_codes).uniq!
    update(codes) if !codes[:institution_codes].empty?
  end

  def update_organization_codes
    wikidata_lib = Bionomia::WikidataSearch.new
    codes = wikidata_lib.wiki_organization_codes(wikidata)
    update(codes)
  end

  def flush_metrics
    return if !::Module::const_get("BIONOMIA")
    BIONOMIA.cache_clear("blocks/organization-#{id}-recorded")
    BIONOMIA.cache_clear("blocks/organization-#{id}-identified")

    BIONOMIA.cache_put_tag("blocks/organization-#{id}-recorded", others_specimens("recorded"))
    BIONOMIA.cache_put_tag("blocks/organization-#{id}-identified", others_specimens("identified"))
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
