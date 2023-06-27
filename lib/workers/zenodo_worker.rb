# encoding: utf-8

module Bionomia
   class ZenodoWorker
      include SuckerPunch::Job
      workers 1
 
      def perform(data)
         ActiveRecord::Base.connection_pool.with_connection do
            @user = User.find(data[:id])
            case data[:action]
            when "new"
               submit_new
            when "update"
               submit_update
            when "refresh"
               refresh
            end
         end
      end

      def user
         @user
      end

      def refresh
         z = Bionomia::Zenodo.new(user: user)
         if user.orcid
            begin
               user.skip_callbacks = true
               user.zenodo_access_token = z.refresh_token
               user.save
               puts "#{user.viewname} (id=#{user.id})".green
            rescue
               puts "#{user.viewname} (id=#{user.id}) token failed".red
            end
         end
      end

      # Warning: must unlink after creation
      def make_csv
         io = Bionomia::IO.new({ user: user })
         temp = Tempfile.new
         temp.binmode
         io.csv_stream_occurrences(user.visible_occurrences.includes(:claimant))
           .each { |line| temp << line }
         temp.close
         temp
      end
 
      # Warning: must unlink after creation
      def make_json
         io = Bionomia::IO.new({ user: user })
         temp = Tempfile.new
         temp.binmode
         io.jsonld_stream("all", temp)
         temp.close
         temp
      end
 
      def submit_new
         user.skip_callbacks = true
      
         # Create the files
         csv = make_csv
         json = make_json
      
         # Temporary hack because API can't handle files > 50MB
         # See the add_file method in Bionomia::Zenodo
         if csv.size > 50_000_000 || json.size > 50_000_000
            csv.unlink
            json.unlink
            return
         end
      
         z = Bionomia::Zenodo.new(user: user)
      
         begin
            # Refresh the token
            if user.orcid
               user.zenodo_access_token = z.refresh_token
               user.save
            end
      
            doi_id = z.new_deposit
            id = doi_id[:recid]
      
            # POST the files & publish
            z.add_file(id: id, file_path: csv.path, file_name: user.identifier + ".csv")
            z.add_file(id: id, file_path: json.path, file_name: user.identifier + ".json")
            pub = z.publish(id: id)
      
            user.zenodo_doi = pub[:doi]
            user.zenodo_concept_doi = pub[:conceptdoi]
            user.save
      
            puts "#{user.viewname}".green
         rescue
            puts "#{user.viewname} (id=#{user.id}) token failed".red
         end
      
         # Unlink the files
         csv.unlink    
         json.unlink
      end
 
      def submit_update
         user.skip_callbacks = true
      
         # Create the files
         csv = make_csv
         json = make_json
      
         # Temporary hack because API can't handle files > 50MB
         # See the add_file method in Bionomia::Zenodo
         if csv.size > 50_000_000 || json.size > 50_000_000
            csv.unlink
            json.unlink
            return
         end
      
         z = Bionomia::Zenodo.new(user: user)
      
         begin
            # Refresh the token
            if user.orcid
               user.zenodo_access_token = z.refresh_token
               user.save
            end
      
            old_id = user.zenodo_doi.split(".").last
            doi_id = z.new_version(id: old_id)
      
            # DELETE existing files
            id = doi_id[:recid]
            files = z.list_files(id: id).map{|f| f[:id]}
            files.each do |file_id|
               z.delete_file(id: id, file_id: file_id)
            end
      
            # POST the files & publish
            z.add_file(id: id, file_path: csv.path, file_name: user.identifier + ".csv")
            z.add_file(id: id, file_path: json.path, file_name: user.identifier + ".json")
            pub = z.publish(id: id)
      
            if !pub[:doi].nil?
               user.zenodo_doi = pub[:doi]
               user.save
               puts "#{user.viewname}".green
            else
               z.discard_version(id: id)
               puts "#{user.viewname}".red
            end
         rescue
            puts "#{user.viewname} (id=#{user.id}) token failed".red
         end
      
         # Unlink the files
         csv.unlink    
         json.unlink
      end

   end
 end