class UserOrganization < ActiveRecord::Base
  belongs_to :user
  belongs_to :organization

  validates :user_id, presence: true
  validates :organization_id, presence: true

  def start_date
    return if !start_year
    Date.new(start_year, start_month || 1, start_day || 1)
  end

  def end_date
    return if !end_year
    Date.new(end_year, end_month || 1, end_day || 1)
  end

end
