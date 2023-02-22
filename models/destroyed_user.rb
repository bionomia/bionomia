class DestroyedUser < ActiveRecord::Base
  validates :identifier, presence: true

  def self.active_user_identifier(id)
    u = self.find_by_identifier(id)
    if !u.nil? && !u.redirect_to.blank?
      r = self.find_by_identifier(u.redirect_to)
      while !r.nil?
        u = self.find_by_identifier(r.identifier)
        r = self.find_by_identifier(u.redirect_to) rescue nil
      end
      u.redirect_to
    end
  end

  def self.is_banned?(id)
    u = self.find_by_identifier(id)
    !u.nil? && u.redirect_to.blank?
  end

end
