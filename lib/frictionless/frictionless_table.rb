# encoding: utf-8

module Bionomia
  class FrictionlessTable

    class << self

      def descendants
        ObjectSpace.each_object(singleton_class).reduce([]) do |des, k|
          des.unshift k unless k.singleton_class? || k == self
          des
        end
      end

    end

    def initialize(occurrence_files: nil, csv_handle: nil)
      @occurrence_files = occurrence_files
      @csv_handle = csv_handle
    end

    # Child class should have a resource method
    def resource
      {
        schema: {
          fields: []
        }
      }
    end

    # Child class should have a file method
    def file
    end

    # Child class should have a write_table_rows
    def write_table_rows
    end

    # Get the header from the resource
    def header
      resource[:schema][:fields].map{ |u| u[:name] }
    end

  end
end
