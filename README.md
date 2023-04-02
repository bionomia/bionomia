# Bionomia
Sinatra app to parse people names from structured biodiversity occurrence data, apply basic regular expressions and heuristics to disambiguate them, and then allow them to be claimed by authenticated users via [ORCID](https://orcid.org). Authenticated users may also help other users that have either ORCID or Wikidata identifiers. The web application lives at [https://bionomia.net](https://bionomia.net).

[![Build Status](https://github.com/bionomia/bionomia/actions/workflows/ruby.yml/badge.svg)](https://github.com/bionomia/bionomia/actions)

## Translations

Strings of text in the user interface are translatable via [config/locales](config/locales). Large pages of text are fully translatable in the [views/static_i18n/](views/static_i18n/) directory.

[![Crowdin](https://badges.crowdin.net/bionomia/localized.svg)](https://crowdin.com/project/bionomia)

## Requirements

1. ruby 3.2.1+
2. Elasticsearch 7.5.0+
3. MySQL 8.0.21
4. Redis 4.0.9+
5. Apache Spark 3+
6. Unix-based operating system to use GNU parallel to process GBIF downloads

## Installation

     $ git clone https://github.com/bionomia/bionomia.git
     $ cd bionomia
     $ gem install bundler
     $ bundle install
     $ mysql -u root bionomia < db/bionomia.sql
     $ cp config/settings/development.yml.sample config/settings/development.yml
     # Adjust content of development.yml
     # Copy and edit production.yml and test.yml as above
     $ rackup -p 4567 config.ru

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

      $ RACK_ENV=production bundle exec ./bin/populate_agents.rb --truncate --directory /directory-to-spark-csv-files/
      # Can start 2+ workers, each with 40 threads to help speed-up processing
      $ RACK_ENV=production bundle exec sidekiq -c 40 -q agent -r ./application.rb
      # For remote client, point to the server REDIS_URL and likewise, adjust MySQL connection strings in config
      $ REDIS_URL=redis://192.168.2.4:6379 RACK_ENV=production bundle exec sidekiq -c 40 -q agent -r ./application.rb

### Step 4: Populate Taxa

     $ RACK_ENV=production bundle exec ./bin/populate_taxa.rb --truncate --directory /directory-to-spark-csv-files/
     # Can start 2+ workers, each with 40 threads to help speed-up processing
     $ RACK_ENV=production bundle exec sidekiq -c 40 -q taxon -r ./application.rb

### Step 5: Import Existing recordedByID and identifiedByID

First, import all users and user_occurrences content from production.

     $ RACK_ENV=production bundle exec ./bin/populate_existing_claims.rb --truncate --directory /directory-to-spark-csv-files/
     # Can start 2+ workers, each with 40 threads to help speed-up processing
     # might need to increase ulimit
     $ ulimit -n 8192
     $ RACK_ENV=production bundle exec sidekiq -c 2 -q existing_claims -r ./application.rb

Export a csv pivot table (for import performance) of all claims made by User::GBIF_AGENT_ID.

     $ RACK_ENV=production bundle exec ./bin/populate_existing_claims.rb --export "gbif_claims.csv"

Finally, import the bulk claims on production (will create users & make public if wikidata):

     $ RACK_ENV=production bundle exec ./bin/bulk_claim.rb --file "gbif_claims.csv"

The above recreates the caches and so cached file permissions may need to be set prior to its execution. The above also deletes records that originated from the source, which sometimes is extremely show to execute. One way to speed this up is to do:

     mysql> DELETE FROM user_occurrences WHERE created_by = 2 ORDER BY id DESC;

### Step 6: Populate Search in Elasticsearch

     $ RACK_ENV=production bundle exec ./bin/populate_search.rb --index agent
     $ RACK_ENV=production bundle exec ./bin/populate_search.rb --index taxon

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
     # RACK_ENV=production bundle exec ./bin/populate_search.rb --index user
     $ RACK_ENV=production bundle exec ./bin/populate_occurrence_count.rb -t -a -j
     # Can start 2+ workers, each with 40 threads to help speed-up processing
     $ RACK_ENV=production bundle exec sidekiq -c 40 -q occurrence_count -r ./application.rb

### Step 9: Rebuild the Frictionless Data Packages

    $ RACK_ENV=production bundle exec ./bin/frictionless_dataset.rb -d /var/www/bionomia/public/data -s -a

## Successive Data Migrations

Unfortunately, gbifIDs are not persistent. These occasionally disappear through processing at GBIF's end. As a result, claims may no longer point to an existing occurrence record and these must then be purged from the user_occurrences table. The following are a few methods to produce a csv file of affected users and to then delete the orphans:

     # csv dump requires approx. 15min for 20M attributions
     $ RACK_ENV=production bundle exec ./bin/orphaned_user_occurrences.rb -d ~/Desktop -o

Then use this orphaned.csv file to run through the orphaned records and delete them:

     $ RACK_ENV=production bundle exec ./bin/orphaned_user_occurrences.rb -f orphaned.csv

This misses the ignored attributions, so also execute:

     mysql> DELETE user_occurrences FROM user_occurrences LEFT JOIN occurrences ON user_occurrences.occurrence_id = occurrences.gbifID WHERE occurrences.gbifID IS NULL AND user_occurrences.visible = false;
     mysql> DELETE article_occurrences FROM article_occurrences LEFT JOIN occurrences ON article_occurrences.occurrence_id = occurrences.gbifID WHERE occurrences.gbifID IS NULL;

To migrate tables, use mydumper and myloader. But for even faster data migration, drop indices before mydumper then recreate indices after myloader. This is especially true for the three largest tables: occurrences, occurrence_recorders, and occurrence_determiners whose indices are (almost) larger than the tables themselves.

     $ brew install mydumper

     $ mydumper --user root --password <PASSWORD> --database bionomia --tables-list bionomia.agents,bionomia.occurrences,bionomia.occurrence_recorders,bionomia.occurrence_determiners,bionomia.occurrence_counts,bionomia.taxa,bionomia.taxon_occurrences --compress --threads 8 --rows 1000000  --outputdir /Users/dshorthouse/Documents/bionomia_dump

     $ apt-get install mydumper
     $ nohup myloader --database bionomia_restore --user bionomia --password <PASSWORD> --threads 2 --queries-per-transaction 100 --compress-protocol --overwrite-tables --verbose 0 --directory /home/dshorthouse/bionomia_restore &

One way to make this even faster is to copy database files from one database to another rather than dropping/truncating and importing, but this has to be done with a bit of care.

Take site offline and in the bionomia database, remove the tablespaces from the tables that will be overwritten. Before removing, it's a good idea to keep the \*.ibd files on-hand in the event something bad happens and they need to be restored.

In the source database:

      mysql> FLUSH TABLES `agents`, `occurrences`, `occurrence_determiners`, `occurrence_recorders`, `occurrence_counts`, `taxa`, `taxon_occurrences` FOR EXPORT;

Now copy the \*.ibd, and \*.cfg files for the above 6 tables from the bionomia_restore database into the bionomia database data directory, reset the permissions.

      mysql> UNLOCK TABLES;

In the destination database:

      mysql> ALTER TABLE `agents` DISCARD TABLESPACE;
      mysql> ALTER TABLE `occurrences` DISCARD TABLESPACE;
      mysql> ALTER TABLE `occurrence_determiners` DISCARD TABLESPACE;
      mysql> ALTER TABLE `occurrence_recorders` DISCARD TABLESPACE;
      mysql> ALTER TABLE `occurrence_counts` DISCARD TABLESPACE;
      mysql> ALTER TABLE `taxa` DISCARD TABLESPACE;
      mysql> ALTER TABLE `taxon_occurrences` DISCARD TABLESPACE;

      mysql> ALTER TABLE `agents` IMPORT TABLESPACE;
      mysql> ALTER TABLE `occurrences` IMPORT TABLESPACE;
      mysql> ALTER TABLE `occurrence_determiners` IMPORT TABLESPACE;
      mysql> ALTER TABLE `occurrence_recorders` IMPORT TABLESPACE;
      mysql> ALTER TABLE `occurrence_counts` IMPORT TABLESPACE;
      mysql> ALTER TABLE `taxa` IMPORT TABLESPACE;
      mysql> ALTER TABLE `taxon_occurrences` IMPORT TABLESPACE;

## License

The MIT License (MIT)

Copyright (c) David P. Shorthouse

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
