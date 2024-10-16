class KeyValue < ActiveRecord::Base

  serialize :v, JSON

  def self.get(key)
    find_by_k(key).v rescue nil
  end

  def self.set(key, value)
    upsert({ k: key, v: value })
  end

end