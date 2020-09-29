# Apache Spark Bulk Import Data and Aggregations into MySQL

The following script written in Scala illustrates how to rapidly import into MySQL a massive GBIF occurrence csv file extracted from a Darwin Core Archive download like this one: [https://doi.org/10.15468/dl.gyp78m](https://doi.org/10.15468/dl.gyp78m). Other methods here produce aggregates of these same occurrence data for rapid import into relational tables. The goal here is to produce a unique list of agents as a union of recordedBy and identifiedBy Darwin Core fields while retaining their occurrence record memberships. This greatly accelerates processing and parsing steps prior to storing graphs of people names in Neo4j. Aggregating identifiedBy and recordedBy fields from a raw occurrence csv file containing 190M records takes approx. 1 hr using 12GB of memory.

- Create the database using the [schema in /db](db/bionomia.sql)
- Ensure that MySQL has utf8mb4 collation. See [https://mathiasbynens.be/notes/mysql-utf8mb4](https://mathiasbynens.be/notes/mysql-utf8mb4) to set server connection
- Get the mysql-connector-java (Connector/J) from [https://dev.mysql.com/downloads/connector/j/8.0.html](https://dev.mysql.com/downloads/connector/j/8.0.html).

On a Mac with Homebrew:

```bash
$ brew install apache-spark
$ spark-shell --jars /usr/local/opt/mysql-connector-java/libexec/mysql-connector-java-8.0.20.jar --packages org.apache.spark:spark-avro_2.12:3.0.0 --driver-memory 12G
```

```scala
import sys.process._
import org.apache.spark.sql.Column
import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._
import org.apache.spark.sql.avro._

# Deal with really old dates
spark.sql("SET spark.sql.legacy.avro.datetimeRebaseModeInWrite=CORRECTED")

val verbatimTerms = List(
  "gbifID",
  "occurrenceID",
  "dateIdentified",
  "decimalLatitude",
  "decimalLongitude",
  "country",
  "eventDate",
  "year",
  "identifiedBy",
  "institutionCode",
  "collectionCode",
  "catalogNumber",
  "recordedBy",
  "scientificName",
  "typeStatus",
  "recordedByID",
  "identifiedByID"
)

//load a big, verbatim tsv file from a DwC-A download
val df1 = spark.
    read.
    format("csv").
    option("header", "true").
    option("mode", "DROPMALFORMED").
    option("delimiter", "\t").
    option("quote", "\"").
    option("escape", "\"").
    option("treatEmptyValuesAsNulls", "true").
    option("ignoreLeadingWhiteSpace", "true").
    load("/Users/dshorthouse/Downloads/GBIF/verbatim.txt").
    select(verbatimTerms.map(col):_*).
    filter(coalesce($"identifiedBy",$"recordedBy").isNotNull).
    where(!$"scientificName".contains("BOLD:")).
    where(!$"scientificName".contains("BOLD-")).
    where(!$"scientificName".contains("BIOUG"))

//optionally save the DataFrame to disk so we don't have to do the above again
df1.write.mode("overwrite").format("avro").save("verbatim")

//load the saved DataFrame, can later skip the above processes and start from here
val df1 = spark.
    read.
    format("avro").
    load("verbatim")

val processedTerms = List(
  "gbifID",
  "datasetKey",
  "countryCode",
  "dateIdentified",
  "eventDate",
  "mediaType",
  "family",
  "recordedBy",
  "identifiedBy",
  "scientificName"
)

val df2 = spark.
    read.
    format("csv").
    option("header", "true").
    option("mode", "DROPMALFORMED").
    option("delimiter", "\t").
    option("quote", "\"").
    option("escape", "\"").
    option("treatEmptyValuesAsNulls", "true").
    option("ignoreLeadingWhiteSpace", "true").
    load("/Users/dshorthouse/Downloads/GBIF/occurrence.txt").
    select(processedTerms.map(col):_*).
    filter(coalesce($"identifiedBy",$"recordedBy").isNotNull).
    where(!$"scientificName".contains("BOLD:")).
    where(!$"scientificName".contains("BOLD-")).
    where(!$"scientificName".contains("BIOUG")).
    withColumnRenamed("dateIdentified","dateIdentified_processed").
    withColumnRenamed("eventDate", "eventDate_processed").
    withColumnRenamed("mediaType", "hasImage").
    withColumn("eventDate_processed", to_timestamp($"eventDate_processed")).
    withColumn("dateIdentified_processed", to_timestamp($"dateIdentified_processed")).
    withColumn("hasImage", when($"hasImage".contains("StillImage"), 1).otherwise(0)).
    drop("recordedBy", "identifiedBy", "scientificName")

df2.write.mode("overwrite").format("avro").save("processed")

//load the saved DataFrame, can later skip the above processes and start from here
val df2 = spark.
    read.
    format("avro").
    load("processed")

val occurrences = df1.join(df2, Seq("gbifID"), "inner").orderBy($"gbifID").distinct

occurrences.write.mode("overwrite").format("avro").save("occurrences")

//load the saved DataFrame, can later skip the above processes and start from here
val occurrences = spark.
    read.
    format("avro").
    load("occurrences")

//set some properties for a MySQL connection
val prop = new java.util.Properties
prop.setProperty("driver", "com.mysql.cj.jdbc.Driver")
prop.setProperty("user", "root")
prop.setProperty("password", "")

val url = "jdbc:mysql://localhost:3306/bionomia?serverTimezone=UTC&useSSL=false"

//check new occurrences against existing user_occurrences table to see how many orphaned occurrences we have
val user_occurrences = spark.read.jdbc(url, "user_occurrences", prop)

val missing = occurrences.
    join(user_occurrences, $"gbifID" === $"occurrence_id", "rightouter").
    where("visible = true").
    where("gbifID IS NULL").
    count

//make a list of missing occurrence_ids
val missing_occurrences = occurrences.
      join(user_occurrences, $"gbifID" === $"occurrence_id", "rightouter").
      select("occurrence_id").
      where("visible = true").
      where("gbifID IS NULL").
      repartition(1).
      write.
      mode("overwrite").
      option("header", "true").
      option("quote", "\"").
      option("escape", "\"").
      csv("missing-claims")

//check user_occurrences against new occurrences table to see how many orphaned claims we have
val user_occurrences = spark.read.jdbc(url, "user_occurrences", prop)
val missing = user_occurrences.
      join(occurrences, $"occurrence_id" === $"gbifID", "leftouter").
      where("occurrence_id IS NULL").
      count

// Best to drop indices then recreate later
// ALTER TABLE `occurrences` DROP KEY `typeStatus_idx`, DROP KEY `index_occurrences_on_datasetKey`;

//write occurrences data to the database
occurrences.write.mode("append").jdbc(url, "occurrences", prop)

// Recreate indices
// ALTER TABLE `occurrences` ADD KEY `typeStatus_idx` (`typeStatus`(256)), ADD KEY `index_occurrences_on_datasetKey` (`datasetKey`);

//aggregate recordedBy
val recordedByGroups = occurrences.
    select($"gbifID", $"recordedBy").
    filter($"recordedBy".isNotNull).
    groupBy($"recordedBy" as "agents").
    agg(collect_set($"gbifID") as "gbifIDs_recordedBy").
    withColumn("gbifIDs_identifiedBy", lit(null))

//aggregate identifiedBy
val identifiedByGroups = occurrences.
    select($"gbifID", $"identifiedBy").
    filter($"identifiedBy".isNotNull).
    groupBy($"identifiedBy" as "agents").
    agg(collect_set($"gbifID") as "gbifIDs_identifiedBy").
    withColumn("gbifIDs_recordedBy", lit(null))

//union identifiedBy and recordedBy entries & groupBy gbifID
val unioned = recordedByGroups.
    unionByName(identifiedByGroups).
    groupBy($"agents").
    agg(flatten(collect_set($"gbifIDs_recordedBy")) as "gbifIDs_recordedBy", flatten(collect_set($"gbifIDs_identifiedBy")) as "gbifIDs_identifiedBy")

//concatenate arrays into strings
def stringify(c: Column) = concat(lit("["), concat_ws(",", c), lit("]"))

//write aggregated agents to csv files for the Populate Agents script, /bin/populate_agents.rb
unioned.select("agents", "gbifIDs_recordedBy", "gbifIDs_identifiedBy").
    withColumn("gbifIDs_recordedBy", stringify($"gbifIDs_recordedBy")).
    withColumn("gbifIDs_identifiedBy", stringify($"gbifIDs_identifiedBy")).
    write.
    mode("overwrite").
    option("header", "true").
    option("quote", "\"").
    option("escape", "\"").
    csv("agents-unioned-csv")

//aggregate recordedByID
val recordedByIDGroups = occurrences.
    select($"gbifID", $"recordedByID").
    filter($"recordedByID".isNotNull).
    groupBy($"recordedByID" as "agentIDs").
    agg(collect_set($"gbifID") as "gbifIDs_recordedByIDs").
    withColumn("gbifIDs_identifiedByIDs", lit(null))

//aggregate identifiedByID
val identifiedByIDGroups = occurrences.
    select($"gbifID", $"identifiedByID").
    filter($"identifiedByID".isNotNull).
    groupBy($"identifiedByID" as "agentIDs").
    agg(collect_set($"gbifID") as "gbifIDs_identifiedByIDs").
    withColumn("gbifIDs_recordedByIDs", lit(null))

//union identifiedByID, recordedByID entries then group by agentIDs
val unioned2 = recordedByIDGroups.
    unionByName(identifiedByIDGroups).
    groupBy($"agentIDs").
    agg(flatten(collect_set($"gbifIDs_recordedByIDs")) as "gbifIDs_recordedByIDs", flatten(collect_set($"gbifIDs_identifiedByIDs")) as "gbifIDs_identifiedByIDs")

//write aggregated agentIDs to csv files for the Populate Existing Claims script, /bin/populate_existing_claims.rb
unioned2.select("agentIDs", "gbifIDs_recordedByIDs", "gbifIDs_identifiedByIDs").
    withColumn("gbifIDs_recordedByIDs", stringify($"gbifIDs_recordedByIDs")).
    withColumn("gbifIDs_identifiedByIDs", stringify($"gbifIDs_identifiedByIDs")).
    write.
    mode("overwrite").  
    option("header", "true").
    option("quote", "\"").
    option("escape", "\"").
    csv("claims-unioned-csv")

//aggregate families (Taxa)
val familyGroups = occurrences.
    filter($"family".isNotNull).
    groupBy($"family").
    agg(collect_set($"gbifID") as "gbifIDs_family")

//write aggregated Families to csv files for the Populate Taxa script, /bin/populate_taxa.rb
familyGroups.select("family", "gbifIDs_family").
    withColumn("gbifIDs_family", stringify($"gbifIDs_family")).
    write.
    mode("overwrite").
    option("header", "true").
    option("quote", "\"").
    option("escape", "\"").
    csv("family-csv")
```
