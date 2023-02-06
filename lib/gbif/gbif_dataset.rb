# encoding: utf-8

module Bionomia
  class GbifDataset

    def initialize
    end

    def update_all
      Dataset.find_each do |d|
        self.process_dataset(d.uuid)
        puts d.datasetKey.green
      end
    end

    def process_dataset(datasetkey)
      begin
        response = RestClient::Request.execute(
          method: :get,
          url: "http://api.gbif.org/v1/dataset/#{datasetkey}"
        )
        response = JSON.parse(response, :symbolize_names => true) rescue []
        dataset = Dataset.create_or_find_by({
          datasetKey: response[:key]
        })
        dataset.description = response[:description] || nil
        dataset.title = response[:title]
        dataset.doi = response[:doi] || nil
        dataset.license = response[:license] || nil
        dataset.image_url = response[:logoUrl] || nil
        dataset.dataset_type = response[:type] || nil
        dataset.save
      rescue
      end
    end

  end
end
