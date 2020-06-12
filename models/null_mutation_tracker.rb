# encoding: utf-8
# https://stackoverflow.com/questions/55886060/rails-6-and-neo4j-rb

module ActiveModel
  class NullMutationTracker

    def forget_change(attr_name)
    end

    def original_value(attr_name)
    end

    def force_change(attr_name)
    end

  end
end