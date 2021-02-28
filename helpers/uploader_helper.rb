# encoding: utf-8

module Sinatra
  module Bionomia
    module Helper
      module UploaderHelper

        def upload_file(user_id:, created_by:)
          @record_count = 0

          if !params[:file] || !params[:file][:tempfile]
            raise ArgumentError.new('No file was uploaded')
          end

          tempfile = params[:file][:tempfile]
          filename = params[:file][:filename]
          mime_encoding = detect_mime_encoding(tempfile.path)

          if !["text/csv", "text/plain", "application/octet-stream"].include?(mime_encoding[0]) || tempfile.size > 5_000_000
            tempfile.unlink
            raise IOError.new('Only files of type text/csv or text/plain less than 5MB are accepted.')
          end

          contents = File.read(tempfile)
          detection = CharlockHolmes::EncodingDetector.detect(contents)

          items = []
          CSV.foreach(tempfile, headers: true, header_converters: :symbol, encoding: "#{detection[:encoding]}:utf-8") do |row|
            if !row.headers.include?(:gbifid)
              tempfile.unlink
              raise RuntimeError.new("Missing a gbifID column header")
            end
            action = row[:action].gsub(/\s+/, "") rescue nil
            next if action.blank? && row[:not_me].blank?
            if UserOccurrence.accepted_actions.include?(action)
              action = (action == "identified,recorded") ? "recorded,identified" : action
              items << UserOccurrence.new({
                occurrence_id: row[:gbifid],
                user_id: user_id,
                created_by: created_by,
                action: action,
                visible: 1,
                created: Time.now
              })
              @record_count += 1
            elsif (row[:not_me] && row[:not_me].downcase == "true" || row[:not_me] == 1)
              items << UserOccurrence.new({
                occurrence_id: row[:gbifid],
                user_id: user_id,
                created_by: created_by,
                action: nil,
                visible: 0,
                created: Time.now
              })
              @record_count += 1
            end
          end
          UserOccurrence.transaction do
            UserOccurrence.import items, batch_size: 250, validate: false, on_duplicate_key_ignore: true
          end
          tempfile.unlink
        end

        def upload_image(root)
          new_name = nil
          if params[:file] && params[:file][:tempfile]
            tempfile = params[:file][:tempfile]
            filename = params[:file][:filename]
            mime_encoding = detect_mime_encoding(tempfile.path)
            if ["image/jpeg", "image/png"].include?(mime_encoding[0]) && tempfile.size <= 5_000_000
              extension = File.extname(tempfile.path)
              filename = File.basename(tempfile.path, extension)
              new_name = Digest::MD5.hexdigest(filename) + extension
              FileUtils.chmod 0755, tempfile
              FileUtils.mv(tempfile, File.join(root, "public", "images", "users", new_name))
            else
              tempfile.unlink
            end
          end
          new_name
        end

        def csv_stream_headers(file_name = "download")
          content_type "application/csv", charset: 'utf-8'
          attachment !params[:id].nil? ? "#{params[:id]}.csv" : "#{file_name}.csv"
          cache_control :no_cache
          headers.delete("Content-Length")
        end

        # from https://stackoverflow.com/questions/24897465/determining-encoding-for-a-file-in-ruby
        def detect_mime_encoding(file_path)
          mt = FileMagic.new(:mime_type)
          me = FileMagic.new(:mime_encoding)
          [mt.file(file_path), me.file(file_path)]
        end

      end
    end
  end
end
