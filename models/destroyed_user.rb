class DestroyedUser < ActiveRecord::Base
  validates :identifier, presence: true
end