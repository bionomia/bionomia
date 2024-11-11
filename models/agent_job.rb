class AgentJob < ActiveRecord::Base
   serialize :parsed, coder: JSON
end