class KeyValue < ActiveRecord::Base

  serialize :v, coder: JSON

  def self.get(key)
    find_by_k(key).v rescue nil
  end

  def self.set(key, value)
    upsert({ k: key, v: value })
  end

  def self.destroy(key)
    find_by_k(key).destroy rescue nil
  end

  def self.mget(keys)
    where(k: keys).map{|a| { "#{a.k}": a.v }}.reduce(&:merge) || {}
  end

end