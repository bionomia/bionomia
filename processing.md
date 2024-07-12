## Processing Preamble

There are occasional hiccups at either the data publisher's end or at GBIF. BEFORE each successive data refresh routine outlined below, first produce a list of datasets whose total number of records here are greater than what is currently available at GBIF. If they are, this is a first indication that republication has gone wrong, harvesting at GBIF's end has skipped a number of records, or a dataset has recently been unpublished. The script below assumes a previous, full round of data processing has already been executed and that there are counts on datasets produced from Step 7.

    $ RACK_ENV=production bundle exec ./bin/gbif_datasets.rb --verify

## Steps to Import Data & Execute Parsing / Clustering

### Step 1:  Import Data

See the Apache Spark recipes [here](spark.md) for quickly importing into MySQL the occurrence csv from a DwC Archive downloaded from [GBIF](https://www.gbif.org) from a custom Bionomia download. Apache Spark is used to produce the necessary source csv files for the "Parse & Populate Agents" and "Populate Taxa" steps below.

### Step 2: Check for Dramatic Changes in gbifIDs

Unfortunately, gbifIDs are not persistent. These occasionally disappear through processing at GBIF's end. As a result, claims may no longer point to existing occurrence records. The following produces a csv file for how many claims and attributions will be orphaned. An alternative, more efficient process is found in an Apache Spark [script](spark.md).

      $ RACK_ENV=production bundle exec ./bin/csv_dump.rb -d ~/Desktop -o

### Step 3: Parse & Populate Agents

      $ RACK_ENV=production bundle exec ./bin/parse_agents.rb --queue
      # Can start 2+ workers, each with 40 threads to help speed-up processing
      $ RACK_ENV=production bundle exec sidekiq -C config/settings/sidekiq.yml -c 40 -r ./application.rb

      $ RACK_ENV=production bundle exec ./bin/populate_agents.rb --truncate --queue
      # Can start 2+ workers, each with 40 threads to help speed-up processing
      $ RACK_ENV=production bundle exec sidekiq -C config/settings/sidekiq.yml -c 40 -r ./application.rb

### Step 4: Populate Taxa

     $ RACK_ENV=production bundle exec ./bin/populate_taxa.rb --truncate --directory /directory-to-spark-csv-files/
     # Can start 2+ workers, each with 40 threads to help speed-up processing
     $ RACK_ENV=production bundle exec sidekiq -C config/settings/sidekiq.yml -c 40 -r ./application.rb

### Step 5: Import Existing recordedByID and identifiedByID

First, import all users and user_occurrences content from production.

     $ RACK_ENV=production bundle exec ./bin/populate_existing_claims.rb --truncate --directory /directory-to-spark-csv-files/
     # might need to increase ulimit
     $ ulimit -n 8192
     $ RACK_ENV=production bundle exec sidekiq -C config/settings/sidekiq.yml -c 2 -r ./application.rb

Export a csv pivot table (for import performance) of all claims made by User::GBIF_AGENT_ID.

     $ RACK_ENV=production bundle exec ./bin/populate_existing_claims.rb --export "gbif_claims.csv"

Finally, import the bulk claims on production (will create users & make public if wikidata):

     $ RACK_ENV=production bundle exec ./bin/bulk_claim.rb --file "gbif_claims.csv"

The above recreates the caches and so cached file permissions may need to be set prior to its execution.

### Step 6: Populate Search in Elasticsearch

     $ RACK_ENV=production bundle exec ./bin/populate_search.rb --indices agent,taxon

Or from scratch:

     $ RACK_ENV=production ./bin/populate_search.rb --rebuild

### Step 7: Populate dataset metadata

     $ RACK_ENV=production bundle exec ./bin/gbif_datasets.rb --new
     $ RACK_ENV=production bundle exec ./bin/gbif_datasets.rb --flush
     $ RACK_ENV=production bundle exec ./bin/gbif_datasets.rb --remove-without-agents
     $ RACK_ENV=production bundle exec ./bin/gbif_datasets.rb --counter

Or from scratch:

     $ RACK_ENV=production bundle exec ./bin/gbif_datasets.rb --populate

### Step 8: Repopulate the occurrence_counts table in support of the help-others specimen widget

     # For best performance, first rebuild the Elasticsearch user index
     # RACK_ENV=production bundle exec ./bin/populate_search.rb --indices user
     $ RACK_ENV=production bundle exec ./bin/populate_occurrence_count.rb -t -a -j
     # Can start 2+ workers, each with 40 threads to help speed-up processing
     $ RACK_ENV=production bundle exec sidekiq -C config/settings/sidekiq.yml -c 40 -r ./application.rb

### Step 9: Rebuild the Frictionless Data Packages

    $ RACK_ENV=production bundle exec ./bin/frictionless_dataset.rb -d /var/www/bionomia/public/data -s -a

## Successive Data Migrations

Unfortunately, gbifIDs are not persistent. These occasionally disappear through processing at GBIF's end. As a result, claims may no longer point to an existing occurrence record and these must then be purged from the user_occurrences table. The following are a few methods to produce a csv file of affected users and to then delete the orphans:

     # csv dump requires approx. 15min for 20M attributions
     $ RACK_ENV=production bundle exec ./bin/orphaned_user_occurrences.rb -d ~/Desktop -o

Then use this orphaned.csv file to run through the orphaned records and delete them:

     $ RACK_ENV=production bundle exec ./bin/orphaned_user_occurrences.rb -f orphaned.csv

This misses the ignored attributions, so also execute:

     DELETE user_occurrences FROM user_occurrences LEFT JOIN occurrences ON user_occurrences.occurrence_id = occurrences.gbifID WHERE occurrences.gbifID IS NULL AND user_occurrences.visible = false;
     DELETE article_occurrences FROM article_occurrences LEFT JOIN occurrences ON article_occurrences.occurrence_id = occurrences.gbifID WHERE occurrences.gbifID IS NULL;

To migrate tables, use mydumper and myloader. But for even faster data migration, drop indices before mydumper then recreate indices after myloader. This is especially true for the two largest tables: occurrences and occurrence_agents whose indices are (almost) larger than the tables themselves.

     $ brew install mydumper

     $ mydumper --user root --password <PASSWORD> --database bionomia --tables-list bionomia.agents,bionomia.occurrences,bionomia.occurrence_agents,bionomia.occurrence_counts,bionomia.taxa,bionomia.taxon_occurrences --compress --threads 8 --rows 1000000 --clear --outputdir /Users/dshorthouse/Documents/bionomia_dump

     $ apt-get install mydumper
     $ nohup myloader --database bionomia_restore --user bionomia --password <PASSWORD> --threads 2 --queries-per-transaction 100 --compress-protocol --overwrite-tables --verbose 0 --directory /home/dshorthouse/bionomia_restore &

     mysql>

     RENAME TABLE bionomia_restore.agents TO bionomia.agents_new;
     RENAME TABLE bionomia_restore.taxa TO bionomia.taxa_new;
     RENAME TABLE bionomia_restore.occurrences TO bionomia.occurrences_new;
     RENAME TABLE bionomia_restore.occurrence_agents TO bionomia.occurrence_agents_new;
     RENAME TABLE bionomia_restore.occurrence_counts TO bionomia.occurrence_counts_new;
     RENAME TABLE bionomia_restore.taxon_occurrences TO bionomia.taxon_occurrences_new;

     DROP TABLE bionomia.agents;
     DROP TABLE bionomia.taxa;
     DROP TABLE bionomia.occurrences;
     DROP TABLE bionomia.occurrence_agents;
     DROP TABLE bionomia.occurrence_counts;
     DROP TABLE bionomia.taxon_occurrences;

     RENAME TABLE bionomia.agents_new TO bionomia.agents;
     RENAME TABLE bionomia.taxa_new TO bionomia.taxa;
     RENAME TABLE bionomia.occurrences_new TO bionomia.occurrences;
     RENAME TABLE bionomia.occurrence_agents_new TO bionomia.occurrence_agents;
     RENAME TABLE bionomia.occurrence_counts_new TO bionomia.occurrence_counts;
     RENAME TABLE bionomia.taxon_occurrences_new TO bionomia.taxon_occurrences;

     DROP DATABASE bionomia_restore;