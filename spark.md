# Apache Spark Bulk Import Data and Aggregations into MySQL

The following script written in Scala illustrates how to rapidly import into MySQL a massive GBIF occurrence csv file extracted from a custom Bionomia download like this one: [https://doi.org/10.15468/dl.p9q8hh](https://doi.org/10.15468/dl.gyp78m).

The download request sent to GBIF looks like this using [@bionomia_gbif_request.json](bionomia_gbif_request.json):

```bash
$ curl -i --user davidpshorthouse:***password*** -H "Content-Type:application/json" -X POST -d @bionomia_gbif_request.json https://api.gbif.org/v1/occurrence/download/request
```

- Create the database using the [schema in /db](db/bionomia.sql)
- Ensure that MySQL has utf8mb4 collation. See [https://mathiasbynens.be/notes/mysql-utf8mb4](https://mathiasbynens.be/notes/mysql-utf8mb4) to set server connection
- Get the mysql-connector-j (Connector/J) from [https://dev.mysql.com/downloads/connector/j/9.1.html](https://dev.mysql.com/downloads/connector/j/9.1.html).

On a Mac with Homebrew:

```bash
$ spark-shell --jars /usr/local/opt/mysql-connector-java/libexec/mysql-connector-j-9.4.0.jar --packages org.apache.spark:spark-avro_2.13:4.0.0 --driver-memory 12G
```

```scala
import sys.process._
import org.apache.spark.sql.Column
import org.apache.spark.sql.Row
import org.apache.spark.sql.types._
import org.apache.spark.sql.functions._
import org.apache.spark.sql.avro._
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.scala.DefaultScalaModule
import java.net.URI
import java.net.http.{HttpClient, HttpRequest, HttpResponse}
import java.nio.charset.StandardCharsets
import scala.jdk.CollectionConverters._

// ── Configuration ─────────────────────────────────────────────────────────────

val mysqlHost        = "localhost"
val mysqlPort        = 3306
val mysqlDb          = "bionomia"
val mysqlUser        = "root"
val mysqlPassword    = ""

// Prevent warnings
spark.conf.set("spark.sql.debug.maxToStringFields", 10000)

// Ignore corrupted files
spark.conf.set("spark.sql.files.ignoreCorruptFiles", true)

// Deal with really old dates
spark.sql("SET spark.sql.avro.datetimeRebaseModeInWrite=CORRECTED")

val occurrences = spark.
    read.
    format("avro").
    option("treatEmptyValuesAsNulls", "true").
    option("ignoreLeadingWhiteSpace", "true").
    load("occurrence.avro").
    drop(col("recordedBy")).
    drop(col("identifiedBy")).
    withColumn("scientificNameDerived", when($"v_scientificName".isNull, $"scientificName").otherwise($"v_scientificName")).
    drop(col("v_scientificName")).
    drop(col("scientificName")).
    withColumnRenamed("scientificNameDerived", "scientificName").
    withColumnRenamed("eventDate","eventDate_processed").
    withColumnRenamed("dateIdentified","dateIdentified_processed").
    withColumnRenamed("v_occurrenceID","occurrenceID").
    withColumnRenamed("v_dateIdentified","dateIdentified").
    withColumnRenamed("v_decimalLatitude","decimalLatitude").
    withColumnRenamed("v_decimalLongitude","decimalLongitude").
    withColumnRenamed("v_country","country").
    withColumnRenamed("v_eventDate","eventDate").
    withColumnRenamed("v_year","year").
    withColumnRenamed("v_identifiedBy","identifiedBy").
    withColumnRenamed("v_identifiedByID","identifiedByID").
    withColumnRenamed("v_institutionCode","institutionCode").
    withColumnRenamed("v_collectionCode","collectionCode").
    withColumnRenamed("v_catalogNumber","catalogNumber").
    withColumnRenamed("v_recordedBy","recordedBy").
    withColumnRenamed("v_recordedByID","recordedByID").
    withColumnRenamed("v_typeStatus","typeStatus").
    withColumn("hasImage", when($"hasImage" === true, 1).otherwise(0)).
    withColumn("eventDate_processed", when(to_timestamp($"eventDate_processed").lt(current_timestamp()), to_date(to_timestamp($"eventDate_processed"), "YYY-MM-dd")).otherwise(null)).
    withColumn("dateIdentified_processed", when(to_timestamp($"dateIdentified_processed").lt(current_timestamp()), to_date(to_timestamp($"dateIdentified_processed"), "YYY-MM-dd")).otherwise(null)).
    withColumn("typeStatus", lower($"typeStatus")).
    dropDuplicates("gbifID")

//set some properties for a MySQL connection
val prop = new java.util.Properties
prop.setProperty("driver",   "com.mysql.cj.jdbc.Driver")
prop.setProperty("user",     mysqlUser)
prop.setProperty("password", mysqlPassword)

val url = s"jdbc:mysql://$mysqlHost:$mysqlPort/$mysqlDb" +
  "?serverTimezone=UTC&allowPublicKeyRetrieval=true&useSSL=false&useServerPrepStmts=false&characterEncoding=UTF-8&rewriteBatchedStatements=true"

//check new occurrences against existing user_occurrences table to see how many orphaned occurrences we have
val user_occurrences = spark.read.jdbc(url, "user_occurrences", prop)

val missing = occurrences.
    join(user_occurrences, $"gbifID" === $"occurrence_id", "rightouter").
    select($"occurrence_id").
    where("visible = true").
    where("gbifID IS NULL").
    distinct

//write to "missing" table then do additional querying there
//such as make a unique list of datasetKeys whose caches later need flushing
missing.write.mode("append").jdbc(url, "missing", prop)

// Check if sources have mistakenly dropped all their existing claims/attributions
val existing_counts = spark.read.jdbc(url, "datasets", prop).where("source_attribution_count > 0")
val new_counts = occurrences.where("recordedByID IS NOT NULL OR identifiedByID IS NOT NULL").
    groupBy("datasetKey").count()

val differences = existing_counts.
    join(new_counts, existing_counts("datasetKey") === new_counts("datasetKey"), "leftouter").
    select(existing_counts("datasetKey").cast("STRING"), existing_counts("source_attribution_count"), new_counts("count")).
    where("count IS NULL").
    show(50, false)

def stringify(c: Column) = concat(lit("["), concat_ws(",", c), lit("]"))

val identifiers = spark.
    read.
    format("avro").
    load("identifiers.avro")

identifiers.select("identifier", "gbifIDsRecordedByID", "gbifIDsIdentifiedByID").
    withColumn("gbifIDsRecordedByID", stringify($"gbifIDsRecordedByID")).
    withColumn("gbifIDsIdentifiedByID", stringify($"gbifIDsIdentifiedByID")).
    withColumnRenamed("identifier","agentIDs").
    withColumnRenamed("gbifIDsRecordedByID","gbifIDs_recordedByID").
    withColumnRenamed("gbifIDsIdentifiedByID","gbifIDs_identifiedByID").
    write.
    mode("overwrite").
    option("header", "true").
    option("quote", "\"").
    option("escape", "\"").
    csv("identifiers-csv")

val families = spark.
    read.
    format("avro").
    load("families.avro")

// Note: Fabaceae caused errors to be thrown Nov 13, 2025 & so had to also use:
// where("family == 'Fabaceae'").
families.select("family", "gbifIDsFamily").
    withColumnRenamed("gbifIDsFamily","gbifIDs_family").
    withColumn("gbifIDs_family", stringify($"gbifIDs_family")).
    write.
    mode("overwrite").
    option("header", "true").
    option("quote", "\"").
    option("escape", "\"").
    csv("families-csv")

// ── Go sidecar call ───────────────────────────────────────────────────────────
//
// Sends an entire partition's agent strings in one HTTP POST to /parse_batch
// and returns the parsed JSON array string for each input, in the same order.
// One HTTP round-trip per partition instead of one per row.

val capturedPort = 7654

def callSidecar(inputs: Seq[String]): Seq[String] = {
  if (inputs.isEmpty) return Seq.empty

  val mapper  = new ObjectMapper().registerModule(DefaultScalaModule)
  val body    = mapper.writeValueAsString(Map("inputs" -> inputs))
  val client  = HttpClient.newHttpClient()
  val request = HttpRequest.newBuilder()
    .uri(URI.create(s"http://127.0.0.1:$capturedPort/parse_batch"))
    .header("Content-Type", "application/json")
    .POST(HttpRequest.BodyPublishers.ofString(body, StandardCharsets.UTF_8))
    .build()

  val response = client.send(request, HttpResponse.BodyHandlers.ofString())
  if (response.statusCode() != 200)
    throw new RuntimeException(
      s"dwcagent-server error ${response.statusCode()}: ${response.body().take(200)}")

  val root = mapper.readTree(response.body())
  root.elements().asScala.map(_.get("parsed").toString).toSeq
}

val agents = spark.
    read.
    format("avro").
    load("agents.avro")

// TUNCATE TABLE agent_jobs

val agentColIndex = agents.columns.indexOf("agent")
val outputSchema = agents.schema.add("parsed", StringType, nullable = true)

// How many rows to send to the sidecar in each HTTP call.
// Tune this down if you still see memory pressure, up if throughput is low.
val capturedBatchSize = 500

val parsedRDD = agents.rdd.mapPartitions { partition =>

  // grouped() is lazy — it reads from the iterator batchSize rows at a time
  // without buffering the rest of the partition.
  partition.grouped(capturedBatchSize).flatMap { batch =>

    val inputs = batch.map { row =>
      if (row.isNullAt(agentColIndex)) "" else row.getString(agentColIndex)
    }

    val parsed = callSidecar(inputs)

    batch.zip(parsed).map { case (row, json) =>
      Row.fromSeq(row.toSeq :+ json)
    }
  }
}

val result = spark.createDataFrame(parsedRDD, outputSchema)

result.select("agent", "gbifIDsRecordedBy", "gbifIDsIdentifiedBy", "parsed").
    withColumn("gbifIDsRecordedBy", stringify($"gbifIDsRecordedBy")).
    withColumn("gbifIDsIdentifiedBy", stringify($"gbifIDsIdentifiedBy")).
    withColumnRenamed("agent","agents").
    withColumnRenamed("gbifIDsRecordedBy","gbifIDs_recordedBy").
    withColumnRenamed("gbifIDsIdentifiedBy","gbifIDs_identifiedBy").
    write.mode("append").jdbc(url, "agent_jobs", prop)

// Best to drop indices then recreate later
// ALTER TABLE `occurrences` DROP KEY `index_occurrences_on_datasetKey_occurrenceID`, DROP KEY `country_code_idx`, DROP KEY `eventDate_processed_idx`, DROP KEY `dateIdentified_processed_idx`;

occurrences.write.mode("append").jdbc(url, "occurrences", prop)

// Recreate indices
// ALTER TABLE `occurrences` ADD KEY `index_occurrences_on_datasetKey_occurrenceID` (`datasetKey`, `occurrenceID`(36)), ADD KEY `country_code_idx` (`countryCode`), ADD KEY `eventDate_processed_idx` (`typeStatus`(50),`eventDate_processed_month`,`eventDate_processed_day`,`eventDate_processed_year`), ADD KEY `dateIdentified_processed_idx` (`dateIdentified_processed_month`,`dateIdentified_processed_day`,`dateIdentified_processed_year`);
```
