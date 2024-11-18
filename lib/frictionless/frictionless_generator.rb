# encoding: utf-8

module Bionomia
  class FrictionlessGenerator

    def initialize(dataset:, output_directory: nil)
      @dataset = dataset
      output_dir = output_directory || File.join(BIONOMIA.settings.root, BIONOMIA.settings.public_folder, "data")
      @folder = File.join(output_dir, @dataset.uuid)
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
        doi: (@dataset.zenodo_concept_doi ? "https://doi.org/#{@dataset.zenodo_concept_doi}" : nil),
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
      FileUtils.mkdir(@folder) unless File.exist?(@folder)
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
=begin
      # Dammit this only works with the mysql2 gem; the trilogy client has no option to stream
      query = Occurrence.select(:gbifID, :visible)
                        .joins(:user_occurrences)
                        .where(datasetKey: @dataset.uuid)
                        .unscope(:order)
                        .to_sql
      db = ActiveRecord::Base.connection.instance_variable_get(:@raw_connection)
      rows = db.query(query, stream: true, cache_rows: false)
      tmp_csv = File.new(File.join(@folder, "frictionless_tmp.csv"), "ab")
      CSV.open(tmp_csv.path, 'w') do |csv|
        rows.each { |row| csv << [row[0]] if row[1] == 1 }
      end
      tmp_csv.close
=end

      tmp_csv = File.new(File.join(@folder, "frictionless_tmp.csv"), "ab")
      CSV.open(tmp_csv.path, 'w') do |csv|
        Occurrence.select(:gbifID, :visible)
          .joins(:user_occurrences)
          .where(datasetKey: @dataset.uuid)
          .find_in_batches(batch_size: 10_000) do |group|
            group.each { |row| csv << [row.id] if row.visible }
          end
      end
      tmp_csv.close

      system("sort -n #{tmp_csv.path} | uniq > #{tmp_csv.path}.tmp && mv #{tmp_csv.path}.tmp #{tmp_csv.path} > /dev/null 2>&1")
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
      Parallel.each(FrictionlessTable.subclasses, in_threads: 3) do |_class|
        # Hard-coded skipping if there are no attributions made at the source
        if !@dataset.has_local_attributions?
          next if _class == FrictionlessTableUnresolvedUser || _class == FrictionlessTableMissingAttribution
        end

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
      FrictionlessTable.subclasses.each do |_class|
        # Hard-coded skipping if there are no attributions made at the source
        if !@dataset.has_local_attributions?
          next if _class == FrictionlessTableUnresolvedUser || _class == FrictionlessTableMissingAttribution
        end

        obj = _class.new
        resource = obj.resource
        resource[:path] = "https://bionomia.net/dataset/#{@dataset.uuid}/#{obj.file}.zip"
        resource[:compression] = "zip"
        bytes = File.size(File.join(@folder, obj.file + ".zip"))
        resource[:bytes] = bytes
        resource[:hash] = Digest::MD5.file(File.join(@folder, obj.file + ".zip")).hexdigest
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
