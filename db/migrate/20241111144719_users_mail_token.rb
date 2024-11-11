class UsersMailToken < ActiveRecord::Migration[8.0]
  def up
    unless column_exists? :users, :mail_token
      add_column :users, :mail_token, :string, after: :mail_last_sent, limit: 25
    end
    User.where.not(orcid: nil).where(wants_mail: true).find_each do |u|
      u.skip_callbacks = true
      u.mail_token = SecureRandom.hex(10)
      u.save
    end
  end

  def down
    if column_exists? :users, :mail_token
      remove_column :users, :mail_token, :string, limit: 25
    end
  end
end
