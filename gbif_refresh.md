Steps to proceed with db refresh for bionomia:

1. mysql> CREATE DATABASE bionomia_restore;
2. scp mydumper files from laptop to /home/dshorthouse/bionomia_restore
3. create a screen and then: myloader --database bionomia_restore --user <USER> --password <PASSWORD> --threads 4 --queries-per-transaction 1000 --compress-protocol --overwrite-tables --innodb-optimize-keys=AFTER_IMPORT_ALL_TABLES --verbose 0 --directory /home/dshorthouse/bionomia_restore

4. take site offline, ./bionimia-offline.sh

5. Kill MySQL processes that might prevent DROP TABLE:
mysql> SHOW PROCESSLIST; # THEN mysql> KILL <processid> 

6. mysql -u root -p < move_tables.sql
7. RACK_ENV=production RUBY_YJIT_ENABLE=true bundle exec ./bin/populate_search.rb --indices agent,taxon

8. sudo ./bionomia_refresh_scripts/permissions.sh

9. start a screen session
10. RACK_ENV=production RUBY_YJIT_ENABLE=true bundle exec ./bin/bulk_claim.rb --file /home/dshorthouse/gbif_claims.csv

11. mysql -u <USER> -p bionomia < remove_settings.sql
12. Bring site back online ./bionomia-online.sh

13. RACK_ENV=production RUBY_YJIT_ENABLE=true bundle exec ./bin/gbif_datasets.rb --new
14. RACK_ENV=production RUBY_YJIT_ENABLE=true bundle exec ./bin/gbif_datasets.rb --counter

15. RACK_ENV=production RUBY_YJIT_ENABLE=true bundle exec ./bin/orphaned_user_occurrences.rb -d /home/dshorthouse -o
16. RACK_ENV=production RUBY_YJIT_ENABLE=true bundle exec ./bin/orphaned_user_occurrences.rb -f /home/dshorthouse/orphaned.csv

17. DELETE user_occurrences FROM user_occurrences LEFT JOIN occurrences ON user_occurrences.occurrence_id = occurrences.gbifID WHERE occurrences.gbifID IS NULL AND user_occurrences.visible = false;
18. DELETE article_occurrences FROM article_occurrences LEFT JOIN occurrences ON article_occurrences.occurrence_id = occurrences.gbifID WHERE occurrences.gbifID IS NULL;

19. RACK_ENV=production RUBY_YJIT_ENABLE=true bundle exec ./bin/frictionless_dataset.rb -d /var/www/bionomia/public/data -s -a