class TaxonImage < ActiveRecord::Base
   belongs_to :taxon, foreign_key: :family, primary_key: :family

   validates :family, presence: true
   validates :file_name, presence: true

   def self.phylopic_search
     Taxon.find_each do |taxon|
       next if taxon.has_image?
       begin
         response = RestClient::Request.execute(
           method: :get,
           url: "http://phylopic.org/api/a/name/search?text=#{taxon.family}"
         )
         result = JSON.parse(response, symbolize_names: true)
         if result[:result].size > 0
           uid = result[:result][0][:canonicalName][:uid]
           response = RestClient::Request.execute(
             method: :get,
             url: "http://phylopic.org/api/a/name/#{uid}/images?subtaxa=true&options=pngFiles+credit+licenseURL"
           )
           result = JSON.parse(response, symbolize_names: true)
           if result[:result][:same].size > 0
             save_image(taxon, result[:result][:same])
           elsif result[:result][:subtaxa].size > 0
             save_image(taxon, result[:result][:subtaxa])
           elsif result[:result][:supertaxa].size > 0
             save_image(taxon, result[:result][:supertaxa])
           end
         end
       rescue
         puts "Failed #{taxon.family}".red
         next
       end
     end
   end

   def self.save_image(taxon, metadata)
     url = "http://phylopic.org" + metadata[0][:pngFiles][0][:url]
     file_name = File.basename(url)
     read_image = URI.open(url).read
     File.open(File.join(BIONOMIA.root, BIONOMIA.public_folder, 'images', 'taxa', file_name), 'wb') do |file|
       file.write read_image
     end
     create(
       family: taxon.family,
       file_name: file_name,
       credit: metadata[0][:credit],
       licenseURL: metadata[0][:licenseURL]
     )
     puts "#{taxon.family}".green
   end

   def update_credit
     image_uuid = file_name.split(".")[0]
     url = "http://phylopic.org/api/a/image/#{image_uuid}?options=credit+licenseURL"
     begin
       response = RestClient::Request.execute(
         method: :get,
         url: url
       )
       result = JSON.parse(response, symbolize_names: true)
       if result[:result]
         update(
           credit: result[:result][:credit],
           licenseURL: result[:result][:licenseURL]
         )
       end
     rescue
     end
   end

end
