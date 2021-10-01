# encoding: utf-8

module Bionomia
  class GbifTracker

    def initialize(args = {})
      @url = "https://www.gbif.org/api/resource/search?contentType=literature&literatureType=journal&literatureType=working_paper&relevance=GBIF_USED&peerReview=true&limit=200&offset="
      @package_url = "http://api.gbif.org/v1/occurrence/download/request/"
      args = defaults.merge(args)
      @first_page_only = args[:first_page_only]
      @max_size = args[:max_size]
      Zip.on_exists_proc = true
    end

    def create_package_records
      citation_downloads_enum.each do |item|
        begin
          Article.create item
        rescue ActiveRecord::RecordNotUnique
          next
        end
      end
    end

    def datapackage_file_size(key)
      begin
        response = RestClient::Request.execute(
          method: :get,
          url: "https://www.gbif.org/api/occurrence/download/#{key}"
        )
        result = JSON.parse(response, :symbolize_names => true)
        result[:size]
      rescue
        @max_size
      end
    end

    def process_article(article_id)
      article = Article.find(article_id)
      process_data_packages(article)
      flush_irrelevant_entries(article_id: article.id)
      article.processed = true
      article.save

      article.claimants.each do |user|
        user.flush_caches
      end
    end

    def process_articles
      Article.where(processed: [false, nil]).find_each do |article|
        process_data_packages(article)
        flush_irrelevant_entries(article_id: article.id)
        article.processed = true
        article.save

        article.claimants.each do |user|
          user.flush_caches
        end
      end
    end

    def citation_downloads_enum
      Enumerator.new do |yielder|
        offset = 0
        loop do
          response = RestClient::Request.execute(
            method: :get,
            url: "#{@url}#{offset}"
          )
          results = JSON.parse(response, :symbolize_names => true)[:results] rescue []
          if results.size > 0
            results.each do |result|
              begin
                if result[:identifiers][:doi] && !result[:gbifDownloadKey].empty?
                  yielder << {
                    doi: result[:identifiers][:doi],
                    abstract: result[:abstract],
                    gbif_dois: result[:_gbifDOIs].map{ |d| d.sub("doi:","") },
                    gbif_downloadkeys: result[:gbifDownloadKey],
                    created: result[:created]
                  }
                end
              rescue
              end
            end
          else
            raise StopIteration
          end
          break if @first_page_only
          offset += 200
        end
      end.lazy
    end

    def flush_irrelevant_entries(article_id: nil)
      sql = delete_entries_sql
      if article_id
        sql << " AND article_occurrences.article_id = #{article_id}"
      end
      ActiveRecord::Base.connection.execute(sql)
    end

    private

    def delete_entries_sql
      "DELETE
          article_occurrences
       FROM
          article_occurrences
       LEFT JOIN
          occurrences ON article_occurrences.occurrence_id = occurrences.gbifID
       WHERE
          occurrences.gbifID IS NULL"
    end

    def defaults
      { first_page_only: false, max_size: 100_000_000 }
    end

    def process_data_packages(article)
      article.gbif_downloadkeys.each do |key|
        if datapackage_file_size(key) < @max_size
          tmp_file = Tempfile.new(['gbif', '.zip'])
          zip = RestClient.get("#{@package_url}#{key}.zip") rescue nil
          next if zip.nil?
          File.open(tmp_file, 'wb') do |output|
            output.write zip
          end

          begin
            dwc = DarwinCore.new(tmp_file.path)
            gbifID = dwc.core.fields.select{|term| term[:term].include?("gbifID")}[0][:index]
            basisOfRecord = dwc.core.fields.select{|term| term[:term].include?("basisOfRecord")}[0][:index]
            dwc.core.read(1000) do |data, errors|
              records = data.map{|a| { article_id: article.id, occurrence_id: a[gbifID].to_i } if a[basisOfRecord] != "HUMAN_OBSERVATION" }
                            .compact
              ArticleOccurrence.import records, batch_size: 1_000, on_duplicate_key_ignore: true, validate: true
            end
          rescue
            tmp_csv = Tempfile.new(['gbif_csv', '.zip'])
            Zip::File.open(tmp_file) do |zip_file|
              entry = zip_file.glob('*.csv').first
              if entry
                entry.extract(tmp_csv)
                #WARNING: requires GNU parallel to split CSV files
                system("cat #{tmp_csv.path} | parallel --header : --pipe -N 50000 'cat > #{tmp_csv.path}-{#}.csv' > /dev/null 2>&1")
                items = []
                all_files = Dir.glob(File.dirname(tmp_csv) + "/**/#{File.basename(tmp_csv.path)}*.csv")
                all_files.each do |csv|
                  CSV.foreach(csv, headers: :first_row, col_sep: "\t", liberal_parsing: true, quote_char: "\x00") do |row|
                    occurrence_id = row["gbifid"] || row["gbifID"]
                    next if occurrence_id.nil? || row["basisOfRecord"] == "HUMAN_OBSERVATION"
                    items << ArticleOccurrence.new(article_id: article.id, occurrence_id: occurrence_id)
                  end
                  ArticleOccurrence.import items, batch_size: 10_000, on_duplicate_key_ignore: true, validate: true
                  File.unlink(csv)
                end
              end
            end
            tmp_csv.unlink
          end

          tmp_file.unlink
          GC.compact
        end
      end
    end

  end
end
