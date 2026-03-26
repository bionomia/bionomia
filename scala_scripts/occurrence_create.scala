// occurrence_create.scala
//
// Fast, memory-safe replacement for:
//   occurrences.write.mode("append").jdbc(url, "occurrences", prop)
//
// Incorporates the exact transformation chain from spark.md:
//   - Single Avro read with treatEmptyValuesAsNulls + ignoreLeadingWhiteSpace
//   - Drop raw recordedBy, identifiedBy (verbatim columns replaced by v_ versions)
//   - scientificName derived: v_scientificName preferred, fall back to scientificName
//   - 17 withColumnRenamed calls (v_* → canonical names, date columns → _processed)
//   - hasImage boolean → tinyint 0/1
//   - eventDate_processed / dateIdentified_processed: cast to date, nulled if future
//   - typeStatus lowercased
//   - dropDuplicates("gbifID")
//
// Run with:
//   spark-shell \
//     --jars /path/to/mysql-connector-j-8.x.x.jar \
//     -i occurrence_create.scala

import sys.process._
import org.apache.spark.sql.Column
import org.apache.spark.sql.Row
import org.apache.spark.sql.avro._
import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.module.scala.DefaultScalaModule
import java.nio.charset.StandardCharsets
import scala.jdk.CollectionConverters._
import java.sql.DriverManager

// ── Configuration ─────────────────────────────────────────────────────────────

// Prevent warnings
spark.conf.set("spark.sql.debug.maxToStringFields", 10000)

// Ignore corrupted files
spark.conf.set("spark.sql.files.ignoreCorruptFiles", true)

// Deal with really old dates
spark.sql("SET spark.sql.avro.datetimeRebaseModeInWrite=CORRECTED")

val occurrencesAvroPath = "/Users/dshorthouse/Sites/bionomia/occurrence.avro"

val mysqlHost     = "localhost"
val mysqlPort     = 3306
val mysqlDb       = "bionomia"
val mysqlUser     = "root"
val mysqlPassword = ""

// After dropDuplicates (which is a shuffle) the data is already distributed.
// numPartitions here controls the coalesce for the write step — keeping
// the number of MySQL connections bounded without triggering a new shuffle.
val numPartitions = 200

val batchSize = 1_000

val url = s"jdbc:mysql://$mysqlHost:$mysqlPort/$mysqlDb" +
  "?serverTimezone=UTC&useSSL=false&characterEncoding=UTF-8" +
  "&rewriteBatchedStatements=true&useServerPrepStmts=false"

val prop = new java.util.Properties
prop.setProperty("driver",   "com.mysql.cj.jdbc.Driver")
prop.setProperty("user",     mysqlUser)
prop.setProperty("password", mysqlPassword)

def withConn[A](f: java.sql.Connection => A): A = {
  val conn = DriverManager.getConnection(url, prop)
  try { f(conn) } finally { conn.close() }
}

import spark.implicits._

// ── 1. Read Avro and apply all spark.md transformations ──────────────────────
//
// Every operation is reproduced verbatim from spark.md in the same order.
// Comments identify the purpose of each step.

val occurrences = spark
  .read
  .format("avro")
  // treatEmptyValuesAsNulls: empty string fields become SQL NULL
  // ignoreLeadingWhiteSpace: trims leading whitespace from string values
  .option("treatEmptyValuesAsNulls", "true")
  .option("ignoreLeadingWhiteSpace", "true")
  .load(occurrencesAvroPath)

  // Drop the interpreted recordedBy/identifiedBy — the verbatim v_ versions
  // (renamed below) are the ones written to the occurrences table.
  .drop(col("recordedBy"))
  .drop(col("identifiedBy"))

  // scientificName: prefer verbatim (v_scientificName) over interpreted.
  // If v_scientificName is null, fall back to the interpreted scientificName.
  .withColumn("scientificNameDerived",
    when($"v_scientificName".isNull, $"scientificName")
      .otherwise($"v_scientificName"))
  .drop(col("v_scientificName"))
  .drop(col("scientificName"))
  .withColumnRenamed("scientificNameDerived", "scientificName")

  // Rename interpreted date columns to their _processed forms.
  .withColumnRenamed("eventDate",      "eventDate_processed")
  .withColumnRenamed("dateIdentified", "dateIdentified_processed")

  // Rename verbatim v_* columns to their canonical DwC names.
  .withColumnRenamed("v_occurrenceID",    "occurrenceID")
  .withColumnRenamed("v_dateIdentified",  "dateIdentified")
  .withColumnRenamed("v_decimalLatitude", "decimalLatitude")
  .withColumnRenamed("v_decimalLongitude","decimalLongitude")
  .withColumnRenamed("v_country",         "country")
  .withColumnRenamed("v_eventDate",       "eventDate")
  .withColumnRenamed("v_year",            "year")
  .withColumnRenamed("v_identifiedBy",    "identifiedBy")
  .withColumnRenamed("v_identifiedByID",  "identifiedByID")
  .withColumnRenamed("v_institutionCode", "institutionCode")
  .withColumnRenamed("v_collectionCode",  "collectionCode")
  .withColumnRenamed("v_catalogNumber",   "catalogNumber")
  .withColumnRenamed("v_recordedBy",      "recordedBy")
  .withColumnRenamed("v_recordedByID",    "recordedByID")
  .withColumnRenamed("v_typeStatus",      "typeStatus")

  // hasImage: coerce boolean to tinyint so MySQL stores 0/1, not true/false.
  .withColumn("hasImage",
    when($"hasImage" === true, 1).otherwise(0))

  // eventDate_processed: parse to date, null out any future-dated values.
  // "YYY-MM-dd" in the original spark.md (3 Y's) is reproduced exactly.
  .withColumn("eventDate_processed",
    when(to_timestamp($"eventDate_processed").lt(current_timestamp()),
      to_date(to_timestamp($"eventDate_processed"), "YYY-MM-dd"))
      .otherwise(null))

  // dateIdentified_processed: same future-date guard.
  .withColumn("dateIdentified_processed",
    when(to_timestamp($"dateIdentified_processed").lt(current_timestamp()),
      to_date(to_timestamp($"dateIdentified_processed"), "YYY-MM-dd"))
      .otherwise(null))

  // typeStatus: normalise to lowercase for consistent querying.
  .withColumn("typeStatus", lower($"typeStatus"))

  // Deduplicate on gbifID — this is the only shuffle in the transformation
  // chain. At 300M rows with spark.sql.shuffle.partitions=200 each partition
  // holds ~1.5M rows. The result is already well-partitioned for writing.
  .dropDuplicates("gbifID")

println(s"Schema:\n${occurrences.schema.treeString}")

// ── 2. Drop secondary indexes before writing ──────────────────────────────────
//
// Matches the index-drop comments in spark.md.
// Verify names: SHOW CREATE TABLE occurrences\G

// ALTER TABLE `occurrences` DROP KEY `index_occurrences_on_datasetKey_occurrenceID`, DROP KEY `country_code_idx`, DROP KEY `eventDate_processed_idx`, DROP KEY `dateIdentified_processed_idx`;

withConn { conn =>
  val stmt = conn.createStatement()
  println("Dropping secondary indexes on occurrences...")
  Seq(
    "index_occurrences_on_datasetKey_occurrenceID",
    "country_code_idx",
    "eventDate_processed_idx",
    "dateIdentified_processed_idx"
  ).foreach { idx =>
    try { stmt.execute(s"ALTER TABLE `occurrences` DROP KEY `$idx`") }
    catch { case _: Exception => }
  }
  println("Indexes dropped")
}

// ── 3. Write via foreachPartition ─────────────────────────────────────────────
//
// dropDuplicates already produced a well-distributed DataFrame.
// We coalesce (not repartition — no shuffle) to cap the MySQL connection
// count at numPartitions.
//
// foreachPartition streams rows through an Iterator — memory per task is
// batchSize × row_bytes (~500 KB at batchSize=1000, ~500 bytes/row).
// rewriteBatchedStatements=true converts each executeBatch() into one
// multi-row INSERT, giving ~10× protocol throughput vs individual inserts.

val columns      = occurrences.columns.toSeq
val colList      = columns.map(c => s"`$c`").mkString(", ")
val placeholders = columns.map(_ => "?").mkString(", ")
val insertSQL    = s"INSERT IGNORE INTO `occurrences` ($colList) VALUES ($placeholders)"
println(s"INSERT: $insertSQL")

val capturedUrl    = url
val capturedUser   = mysqlUser
val capturedPwd    = mysqlPassword
val capturedBatch  = batchSize
val capturedInsert = insertSQL

occurrences
  .coalesce(numPartitions)   // narrow partitions without shuffling
  .foreachPartition { rows: Iterator[org.apache.spark.sql.Row] =>

    val connProps = new java.util.Properties
    connProps.setProperty("user",     capturedUser)
    connProps.setProperty("password", capturedPwd)

    val conn = DriverManager.getConnection(capturedUrl, connProps)
    conn.setAutoCommit(false)
    val stmt = conn.prepareStatement(capturedInsert)
    var count = 0

    try {
      rows.foreach { row =>
        for (i <- row.schema.indices) {
          // setObject coerces all Spark types (String, Int, Long, Date,
          // Timestamp, Boolean) to the appropriate JDBC type including null.
          val value = if (row.isNullAt(i)) null else row.get(i)
          stmt.setObject(i + 1, value)
        }
        stmt.addBatch()
        count += 1
        if (count % capturedBatch == 0) {
          stmt.executeBatch()
          conn.commit()
          stmt.clearBatch()
        }
      }
      if (count % capturedBatch != 0) {
        stmt.executeBatch()
        conn.commit()
      }
    } catch {
      case e: Exception =>
        conn.rollback()
        throw e
    } finally {
      stmt.close()
      conn.close()
    }
  }

println("All rows written — rebuilding indexes...")

// ── 4. Rebuild indexes ────────────────────────────────────────────────────────

withConn { conn =>
  conn.createStatement().execute(
    "ALTER TABLE `occurrences` ADD KEY `index_occurrences_on_datasetKey_occurrenceID` (`datasetKey`, `occurrenceID`(36)), ADD KEY `country_code_idx` (`countryCode`), ADD KEY `eventDate_processed_idx` (`typeStatus`(50),`eventDate_processed_month`,`eventDate_processed_day`,`eventDate_processed_year`), ADD KEY `dateIdentified_processed_idx` (`dateIdentified_processed_month`,`dateIdentified_processed_day`,`dateIdentified_processed_year`)"
  )
  println("Indexes rebuilt on occurrences")
}

println("Done.")
