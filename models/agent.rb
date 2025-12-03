class Agent < ActiveRecord::Base

  has_many :occurrence_agents, dependent: :delete_all
  has_many :determinations, -> { where(occurrence_agents: { agent_role: false }) }, through: :occurrence_agents, source: :occurrence
  has_many :recordings, -> { where(occurrence_agents: { agent_role: true }) }, through: :occurrence_agents, source: :occurrence
  has_many :occurrences, -> { distinct }, through: :occurrence_agents, source: :occurrence

  # agent_role values: recorded = TRUE; identified = FALSE

  def fullname
    [appellation, given_part, family_part, suffix].compact.reject(&:empty?).join(' ').strip
  end

  alias_method :viewname, :fullname

  def fullname_reverse
    [family_part, given_part].compact.reject(&:empty?).join(", ").strip
  end

  def family_part
    [particle, family].compact.reject(&:empty?).join(' ').strip
  end
  
  def given_part
    [given, dropping_particle].compact.reject(&:empty?).join(' ').strip
  end

  def agents_same_family
    Agent.where(family: family)
  end

  def agents_same_family_first_initial
    agents_same_family.where("LOWER(LEFT(given,1)) = '#{given[0].downcase}'") rescue []
  end

  def processed?
    processed
  end

  def determinations_institutions
    determinations.pluck(:institutionCode)
                  .uniq
                  .compact
                  .reject{ |c| c.empty? }
  end

  def recordings_institutions
    recordings.pluck(:institutionCode)
              .uniq
              .compact
              .reject{ |c| c.empty? }
  end

  def recordings_country_codes
    recordings.pluck(:countryCode)
              .uniq
              .compact
              .reject{ |c| c.empty? }
  end

  def determinations_year_range
    years = determinations.pluck(:dateIdentified)
                          .map{ |d| Bionomia::Validator.valid_year(d) }
                          .compact
                          .minmax rescue [nil,nil]
    years[0] = years[1] if years[0].nil?
    years[1] = years[0] if years[1].nil?
    Range.new(years[0], years[1])
  end

  def recordings_year_range
    years = recordings.pluck(:eventDate, :year)
                      .map{ |d| Bionomia::Validator.valid_year(d.compact.reject(&:empty?).first) }
                      .compact
                      .minmax rescue [nil,nil]
    years[0] = years[1] if years[0].nil?
    years[1] = years[0] if years[1].nil?
    Range.new(years[0], years[1])
  end

  def recordings_coordinates
    recordings.map(&:coordinates).uniq.compact
  end

  def recordings_with
    colleagues = Set.new
    occurrence_agents.where(agent_role: true).pluck(:occurrence_id).each_slice(500) do |group|
      agents = Agent.joins(:occurrence_agents)
                    .where(occurrence_agents: { occurrence_id: group }).uniq
      colleagues.merge(agents)
    end
    colleagues.delete(self)
  end

  def identified_taxa
    determinations.pluck(:scientificName).compact.uniq
  end

end
