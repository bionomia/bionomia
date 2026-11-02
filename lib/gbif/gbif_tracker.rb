# encoding: utf-8

module Bionomia
  class GbifTracker

    def initialize(args = {})
      @url = "#{Settings.gbif.api}literature/search?literatureType=JOURNAL&literatureType=WORKING_PAPER&relevance=GBIF_USED&peerReview=true&limit=200"
      @package_url = "#{Settings.gbif.api}occurrence/download/request/"
      args = defaults.merge(args)
      @from = args[:from]
      @max_size = args[:max_size]
      Zip.on_exists_proc = true
    end

    def by_doi(doi)
      @url = "#{Settings.gbif.api}literature/search?doi=#{doi}"
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
          url: "#{Settings.gbif.api}occurrence/download/#{key}"
        )
        result = JSON.parse(response, :symbolize_names => true)
        result[:size]
      rescue
        @max_size
      end
    end

    def process_article(article)
      article.process_status = 1
      article.save
      process_data_packages(article)
      flush_irrelevant_entries(article_id: article.id)
      article.process_status = 2
      article.processed = true
      article.save
    end

    def process_articles
      Article.where(processed: [false, nil]).find_each do |article|
        process_article(article)
      end
    end

    def citation_downloads_enum
      if @from
        @url += "&added=#{@from},#{Date.today.to_s}"
      end
      Enumerator.new do |yielder|
        offset = 0
        loop do
          response = RestClient::Request.execute(
            method: :get,
            url: "#{@url}&offset=#{offset}"
          )
          results = JSON.parse(response, :symbolize_names => true)[:results] rescue []
          if results.size > 0
            results.each do |result|
              next if Article.find_by_doi(result[:identifiers][:doi]) || result[:gbifDownloadKey].empty?
              occurrence_count = downloadkey_occurrences(keys: result[:gbifDownloadKey])
              yielder << {
                doi: result[:identifiers][:doi],
                abstract: result[:abstract],
                gbif_dois: result[:tags].map{ |d| d.sub("gbifDOI:","") if d[0..7] == "gbifDOI:" }.compact,
                gbif_downloadkeys: result[:gbifDownloadKey],
                gbif_occurrence_count: occurrence_count,
                created: result[:added]
              }
            end
          else
            raise StopIteration
          end
          offset += 200
        end
      end.lazy
    end

    def downloadkey_occurrences(keys:)
      count = 0
      keys.each do |key|
        response = RestClient::Request.execute(
          method: :get,
          url: "#{Settings.gbif.api}occurrence/download/#{key}"
        )
        count += JSON.parse(response, :symbolize_names => true)[:totalRecords] rescue 0
      end
      count
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
      { first_page_only: false, max_size: KeyValue.get("gbif_download_max_size").to_i }
    end

    def process_data_packages(article)
      article.gbif_downloadkeys.each do |key|
        Thread.pass

        if datapackage_file_size(key) < @max_size
          raw = RestClient::Request.execute(
                  method: :get,
                  url: "#{@package_url}#{key}.zip",
                  raw_response: true) rescue nil
          next if raw.nil?

          tmp_file = Tempfile.new(['gbif', '.zip'])
          FileUtils.mv(raw.file.path, tmp_file.path)

          tmp_dir = Dir.mktmpdir

          begin          
            dwc = DarwinCore.new(tmp_file.path)
            gbifID = dwc.core.fields.select{|term| term[:term].include?("gbifID")}[0][:index]
            basisOfRecord = dwc.core.fields.select{|term| term[:term].include?("basisOfRecord")}[0][:index]
            dwc.core.read(2_500) do |data, errors|
              records = data.map{|a| { article_id: article.id, occurrence_id: a[gbifID].to_i } if a[basisOfRecord] != "HUMAN_OBSERVATION" }
                            .compact
              ArticleOccurrence.import records, on_duplicate_key_ignore: true, validate: false
            end
          rescue
            Zip::File.open(tmp_file.path) do |zip_file|
              zip_file.extract_all(tmp_dir)
            end

            csv_file = Dir.glob(File.join(tmp_dir, "*.csv")).first

            #WARNING: requires GNU parallel to split CSV files
            system("cat #{csv_file} | parallel --header : --pipe -N 50000 'cat > #{tmp_dir}/partial-{#}.csv' > /dev/null 2>&1")
            
            File.unlink(csv_file) if csv_file && File.exist?(csv_file)

            Dir.glob(File.join(tmp_dir, "*.csv")).each do |csv|
              items = []
              CSV.foreach(csv, headers: :first_row, col_sep: "\t", liberal_parsing: true, quote_char: "\x00") do |row|
                occurrence_id = row["gbifid"] || row["gbifID"]
                next if occurrence_id.nil? || row["basisOfRecord"] == "HUMAN_OBSERVATION"
                items << [ article.id, occurrence_id ]
              end
              items.each_slice(2_500) do |group|
                ArticleOccurrence.import [:article_id, :occurrence_id], group, on_duplicate_key_ignore: true, validate: false
              end
              items = []
              File.unlink(csv)
            end
          ensure
            File.unlink(tmp_file) if tmp_file && File.exist?(tmp_file)
            FileUtils.remove_entry(tmp_dir) if tmp_dir && Dir.exist?(tmp_dir)
          end

        end
      end
    end

  end
end
