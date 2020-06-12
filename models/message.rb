class Message < ActiveRecord::Base
  belongs_to :sender, class_name: "User", foreign_key: :user_id
  belongs_to :recipient, class_name: "User", foreign_key: :recipient_id

  validates :user_id, presence: true
  validates :recipient_id, presence: true

  before_update :set_update_time

  private

  def set_update_time
    self.updated_at = Time.now
  end

end
