# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module DatasetHelper

        def dataset_from_param
          @dataset = Dataset.find_by_datasetKey(params[:id]) rescue nil
          if @dataset.nil?
            halt 404
          end
        end

        def search_dataset
          searched_term = params[:q] || params[:dataset]
          @results = []
          return if !searched_term.present?

          page = (params[:page] || 1).to_i
          from = (page -1) * 30
          body = build_dataset_query(searched_term)

          response = ::Bionomia::ElasticDataset.new.search(from: from, size: 30, body: body)
          results = response["hits"].deep_symbolize_keys

          @pagy = Pagy.new(count: results[:total][:value], limit: 30, page: page)
          @results = results[:hits]
        end

        def search_dataset_by_uuid(uuid)
          body = {
            query: {
              term: {
                datasetkey: {
                  value: uuid
                }
              }
            }
          }
          response = ::Bionomia::ElasticDataset.new.search(size: 1, body: body)
          results = response["hits"].deep_symbolize_keys
          results[:hits][0][:_source] rescue nil
        end

        def datasets
          if params[:order] && Dataset.column_names.include?(params[:order]) && ["asc", "desc"].include?(params[:sort])
            data = Dataset.order("#{params[:order]} #{params[:sort]}")
          elsif params[:has_identifiers] && params[:has_identifiers] == "true"
            data = Dataset.where.not(source_attribution_count: 0).order(:title)
          else
            data = Dataset.order(:title)
          end
          @pagy, @results = pagy(data)
        end

        def dataset_users
          if @dataset.is_large?
            @pagy = OpenStruct.new(count: nil, pages: 1)
            @results = []
          else
            @pagy, @results = pagy(@dataset.users.order(:family))
          end
        end

        def dataset_agents
          @pagy, @results = pagy_array(@dataset.agents.to_a, limit: 75)
        end

        def dataset_agents_counts
          data = @dataset.agents_occurrence_counts.to_a.sort_by{|a| -a[:count_all]}
          @pagy, @results = pagy_array(data, count: data.size, limit: 75)
        end

        def dataset_agents_unclaimed_counts
          data = @dataset.agents_occurrence_unclaimed_counts.to_a.sort_by{|a| -a[:count_all]}
          @pagy, @results = pagy_array(data, count: data.size, limit: 75)
        end

        def dataset_stats
          dataset_from_param
          {
            title: "#{@dataset.title}",
            description: "#{@dataset.description}",
            datasetKey: "#{@dataset.datasetKey}",
            doi: "#{@dataset.doi}",
            license: "#{@dataset.license}",
            people: @dataset.users_count
          }
        end

        def dataset_scribes
          @pagy, @results = pagy(@dataset.scribes.order(:family))
        end

        def dataset_json_ld
          descriptor = {
            "@context": "http://schema.org",
            "@type": "Dataset",
            "@id": "https://doi.org/#{@dataset.doi}",
            identifier: [
              {
                "@type": "PropertyValue",
                propertyID: "doi",
                value: "https://doi.org/#{@dataset.doi}"
              },
              {
                "@type": "PropertyValue",
                propertyID: "UUID",
                value: "#{@dataset.datasetKey}"
              }
            ],
            url: "https://bionomia.net/dataset/#{@dataset.datasetKey}/datapackage.json",
            name: "ATTRIBUTIONS MADE FOR: #{h(@dataset.title)}"
          }
          if @dataset.description
            descriptor.merge!(
              {
                description: "#{h(Sanitize.fragment(@dataset.description))}"
              }
            )
          else
            descriptor.merge!(
              {
                description: "(The description of this dataset is missing or too short)"
              }
            )
          end
          if @dataset.license && @dataset.license_icon
            descriptor.merge!(
              {
                license: "#{@dataset.license}"
              }
            )
          end
          if @dataset.image_url
            descriptor.merge!(
              {
                image: "#{@dataset.image_url}"
              }
            )
          end
          if @compressed_file_size
            descriptor.merge!(
              {
                distribution: {
                  contentUrl: "https://bionomia.net/dataset/#{@dataset.datasetKey}/datapackage.json",
                  contentSize: "#{@compressed_file_size} MB",
                  encodingFormat: "https://frictionlessdata.io/specs/"
                }
              }
            )
          end
          if @dataset.zenodo_concept_doi
            descriptor[:identifier] << {
              "@type": "PropertyValue",
                propertyID: "doi",
                value: "https://doi.org/#{@dataset.zenodo_concept_doi}"
            }
          end
          descriptor
        end

        def dataset_frictionless
          @frictionless_data = nil
          file = File.join(BIONOMIA.root, "public", "data", "#{@dataset.uuid}", "datapackage.json")
          if File.file?(file)
            data_hash = JSON.parse(File.read(file), symbolize_names: true)
            @frictionless_data = data_hash[:resources].map{|d| d.slice(:name, :path, :bytes) }
          end
        end

      end
    end
  end
end
