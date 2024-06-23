class AgentJob < ActiveRecord::Base
   serialize :parsed, JSON
end