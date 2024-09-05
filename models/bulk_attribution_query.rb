class BulkAttributionQuery < ActiveRecord::Base
  belongs_to :user, class_name: "User", foreign_key: :user_id
  belongs_to :created_by, class_name: "User", foreign_key: :created_by

  validates :user_id, presence: true
  validates :created_by, presence: true

end