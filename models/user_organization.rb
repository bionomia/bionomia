class UserOrganization < ActiveRecord::Base
  belongs_to :user
  belongs_to :organization

  validates :user_id, presence: true
  validates :organization_id, presence: true
end