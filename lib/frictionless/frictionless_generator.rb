# encoding: utf-8

module Bionomia
  class FrictionlessGenerator

    def initialize(dataset:, output_directory:)
      @dataset = dataset
      @folder = File.join(output_directory, @dataset.uuid)
      @created = Time.now
      @occurrence_files = []
      raise ArgumentError, 'Dataset not found' if !@dataset.is_a?(Dataset)
    end

    def descriptor
      license_name = ""
      if @dataset.license.include?("/zero/1.0/")
        license_name = "public-domain-dedication"
      elsif @dataset.license.include?("/by/4.0/")
        license_name = "cc-by-4.0"
      elsif @dataset.license.include?("/by-nc/4.0/")
        license_name = "cc-by-nc-4.0"
      end

      {
        name: "bionomia-attributions",
        id: @dataset.uuid,
        licenses: [
          {
            name: license_name,
            path: @dataset.license
          }
        ],
        profile: "tabular-data-package",
        title: "ATTRIBUTIONS MADE FOR: #{@dataset.title}",
        description: "#{@dataset.description}",
        datasetKey: @dataset.uuid,
        homepage: "https://bionomia.net/dataset/#{@dataset.uuid}",
        created: @created.to_time.iso8601,
        sources: [
          {
            title: "#{@dataset.title}",
            path: "https://doi.org/#{@dataset.doi}"
          }
        ],
        keywords: [
          "specimen",
          "museum",
          "collection",
          "credit",
          "attribution",
          "bionomia"
        ],
        image: "https://bionomia.net/images/logo.png",
        resources: []
      }
    end

    def create
      create_folder
      flush_folder
      create_occurrence_files
      create_tables
      flush_occurrence_files
      write_descriptor
      update_created_at
      puts "Completed in #{Time.now - @created} seconds".green
    end

    def create_folder
      FileUtils.mkdir(@folder) unless File.exists?(@folder)
    end

    def flush_folder
      Dir.foreach(@folder) do |f|
        fn = File.join(@folder, f)
        File.delete(fn) if f != '.' && f != '..'
      end
    end

    # Creates a bunch of csv files containing gbifIDs in groups of 100,000 and
    # makes an instance, @occurrence_files that each FrictionlessTable child class may use.
    # This is a bit bizarre, but is more performant than heaps of
    # expensive activerecord objects that each require these same gbifIDs
    def create_occurrence_files
      query = Occurrence.select(:gbifID)
                        .joins(:user_occurrences)
                        .where(datasetKey: @dataset.uuid)
                        .where(user_occurrences: { visible: true })
                        .distinct
                        .to_sql
      mysql2 = ActiveRecord::Base.connection.instance_variable_get(:@connection)
      rows = mysql2.query(query, stream: true, cache_rows: false)
      tmp_csv = File.new(File.join(@folder, "frictionless_tmp.csv"), "ab")
      CSV.open(tmp_csv.path, 'w') do |csv|
        rows.each { |row| csv << row }
      end
      tmp_csv.close
      system("sort -n #{tmp_csv.path} > #{tmp_csv.path}.tmp && mv #{tmp_csv.path}.tmp #{tmp_csv.path} > /dev/null 2>&1")
      system("cat #{tmp_csv.path} | parallel --pipe -N 100000 'cat > #{tmp_csv.path}-{#}.csv' > /dev/null 2>&1")
      @occurrence_files = Dir.glob(File.dirname(tmp_csv) + "/**/#{File.basename(tmp_csv.path)}*.csv")
      File.unlink(tmp_csv.path)
    end

    def flush_occurrence_files
      @occurrence_files.each do |csv|
        File.unlink(csv)
      end
    end

    # Use the parallel gem to create the csv files and then zip them up
    def create_tables
      Parallel.each(FrictionlessTable.descendants, in_threads: 3) do |_class|
        # Hard-coded skipping of FrictionlessTableMissingAttribution if there are no attributions made at the source
        next if _class == FrictionlessTableMissingAttribution && !@dataset.has_local_attributions?

        obj = _class.new
        file_path = File.join(@folder, obj.file)

        file = File.open(file_path, "wb")
        file << CSV::Row.new(obj.header, obj.header, true).to_s
        # Pass the array of occurrence_files containing gbifIDs and the file handle to each class
        obj = _class.new(occurrence_files: @occurrence_files, csv_handle: file)
        puts "writing #{obj.class.name}"
        obj.write_table_rows
        file.close

        Zip::File.open(file_path + ".zip", Zip::File::CREATE) do |zipfile|
          zipfile.add(File.basename(file_path), File.join(@folder, File.basename(file_path)))
        end

        File.delete(file_path)
      end
    end

    def write_descriptor
      desc = descriptor
      Parallel.each(FrictionlessTable.descendants, in_threads: 3) do |_class|
        # Hard-coded skipping of FrictionlessTableMissingAttribution if there are no attributions made at the source
        next if _class == FrictionlessTableMissingAttribution && !@dataset.has_local_attributions?

        obj = _class.new
        resource = obj.resource
        resource[:path] = "https://bionomia.net/dataset/#{@dataset.uuid}/#{obj.file}.zip"
        resource[:compression] = "zip"
        bytes = File.size(File.join(@folder, obj.file + ".zip"))
        resource[:bytes] = bytes
        desc[:resources] << resource
      end
      File.open(File.join(@folder, "datapackage.json"), 'wb') do |file|
        file.write(JSON.pretty_generate(desc))
      end
    end

    def update_created_at
      @dataset.skip_callbacks = true
      @dataset.frictionless_created_at = @created
      @dataset.save
    end

  end
end
