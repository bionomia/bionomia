# encoding: utf-8

module Bionomia
   class ZenodoDatasetWorker
      include Sidekiq::Job
      sidekiq_options queue: :zenodo_dataset, retry: 1
 
      def perform(row)
         @dataset = Dataset.find(row["id"]) rescue nil
         return if @dataset.nil?

         @directory = File.join(BIONOMIA.settings.root, BIONOMIA.settings.public_folder, "data", @dataset.uuid)
         return if !Dir.exist?(@directory) || Dir.empty?(@directory)

         case row["action"]
         when "new"
            submit_new
         when "update"
            submit_update
         end
      end

      def dataset
         @dataset
      end
 
      def submit_new
         dataset.skip_callbacks = true
      
         z = Bionomia::ZenodoDataset.new(resource: dataset)
      
         begin
            doi_id = z.new_deposit
            id = doi_id[:recid]

            Dir.glob(File.join(@directory, "*.{json,zip}")).each do |file|
               z.add_file(file_path: file)
            end
            pub = z.publish(id: id)
      
            dataset.zenodo_doi = pub[:doi]
            dataset.zenodo_concept_doi = pub[:conceptdoi]
            dataset.save
      
            puts "#{dataset.uuid}  (id=#{dataset.id}) ... created".green
         rescue
            z.delete_draft(id: id) if id
            puts "#{dataset.uuid} (id=#{dataset.id}) ... token failed".red
         end
      end
 
      def submit_update
         dataset.skip_callbacks = true
      
         z = Bionomia::ZenodoDataset.new(resource: dataset)

         begin
            old_id = dataset.zenodo_doi.split(".").last
            doi_id = z.new_version(id: old_id)
      
            # DELETE existing files
            id = doi_id[:recid]
            files = z.list_files(id: id).map{|f| f[:id]}
            files.each do |file_id|
               z.delete_file(id: id, file_id: file_id)
            end
      
            Dir.glob(File.join(@directory, "*.{json,zip}")).each do |file|
               z.add_file(file_path: file)
            end
            pub = z.publish(id: id)
      
            if !pub[:doi].nil?
               dataset.zenodo_doi = pub[:doi]
               dataset.save
               puts "#{dataset.uuid}  (id=#{dataset.id}) ... new version created".green
            else
               z.delete_draft(id: id)
               puts "#{dataset.uuid} (id=#{dataset.id}) ... new version unnecessary".red
            end
         rescue
            z.delete_draft(id: id) if id
            puts "#{dataset.uuid} (id=#{dataset.id}) ... token failed".red
         end

      end

   end
 end