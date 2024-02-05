# encoding: utf-8

module Sinatra
   module Bionomia
     module Helper
       module ImageHelper
 
         def cloud_img
           "https://img.bionomia.net/"
         end

         def profile_image(user, size=nil)
           query = "&height=200"
           if size == "thumbnail"
             query = "&width=24&height=24"
           elsif size == "thumbnail_grey"
             query = "&width=24&height=24&grey=1"
           elsif size == "medium"
             query = "&width=48&height=48"
           elsif size == "social"
             query = "&width=240&height=240"
           end
           if user.image_url
             if user.wikidata
               src = "?src=" + CGI.escapeURIComponent(user.image_url)
               img =  cloud_img + src + query
             else
               src = "?src=" + CGI.escapeURIComponent(Settings.base_url + "/images/users/" + user.image_url)
               img = cloud_img + src + query
             end
           else
             src = "?src=" + CGI.escapeURIComponent(Settings.base_url + "/images/photo.png")
             img = cloud_img + src + query
           end
           img
         end
 
         def organization_image(organization, size=nil)
           img = nil
           query = "&height=200"
           if size == "thumbnail"
             query = "&width=24&height=24"
           elsif size == "medium"
             query = "&width=48&height=48"
           elsif size == "social"
             query = "&width=240&height=240"
           elsif size == "large"
             query = "&width=350&height=200"
           end
           if organization.image_url
             src = "?src=" + CGI.escapeURIComponent(organization.image_url)
             img = cloud_img + src + query
           end
           img
         end
 
         def dataset_image(dataset, size=nil)
           img = nil
           if size == "large"
             query = "&width=350&height=200"
           elsif size == "crop"
             query = "&width=48&height=48"
           end
           if dataset.image_url
             src = "?src=" + CGI.escapeURIComponent(dataset.image_url)
             img = cloud_img + src + query
           end
           img
         end
 
         def signature_image(user)
           src = "?src=" + CGI.escapeURIComponent(Settings.base_url + "/images/signature.png")
           query = "&height=80"
           if user.signature_url
             src = "?src=" + CGI.escapeURIComponent(user.signature_url)
             img = cloud_img + src + query
           end
           img
         end
 
         def taxon_image(taxon, size=nil)
           img = nil
           query = "&width=64"
           if size == "thumbnail"
             query = "&width=24"
           end
           taxon_image = TaxonImage.find_by_family(taxon) rescue nil
           if taxon_image
             src = "?src=" + CGI.escapeURIComponent(Settings.base_url + "/images/taxa/" + taxon_image.file_name)
             img = cloud_img + src + query
           end
           img
         end
 
       end
     end
   end
 end
 