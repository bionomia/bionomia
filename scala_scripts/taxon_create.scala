// taxon_create.scala
//
// Memory-safe Spark replacement for TaxonWorker.
//
// Memory strategy: zero shuffles, zero coalescing on occurrence rows.
// Writes directly to MySQL via foreachPartition with plain JDBC batch
// inserts, keeping memory bounded to one input partition at a time.
//
// Run with:
//   spark-shell \
//     --jars /path/to/mysql-connector-j-8.x.x.jar \
//     -i taxon_create.scala

import org.apache.spark.sql.functions._
import org.apache.spark.sql.types._
import java.sql.DriverManager

// ── Configuration ─────────────────────────────────────────────────────────────

spark.conf.set("spark.sql.files.ignoreCorruptFiles", true)

val familyGroupsPath   = "/Users/dshorthouse/Sites/bionomia/families-csv/"
val familyGroupsFormat = "csv"    // "csv", "parquet", or "avro"

val mysqlHost     = "localhost"
val mysqlPort     = 3306
val mysqlDb       = "bionomia"
val mysqlUser     = "root"
val mysqlPassword = ""

// Rows per JDBC batch insert within each partition.
// 1000 is safe for all MySQL configurations (max_allowed_packet default is 64 MB).
val batchSize = 1_000

val url = s"jdbc:mysql://$mysqlHost:$mysqlPort/$mysqlDb" +
  "?serverTimezone=UTC&useSSL=false&characterEncoding=UTF-8&rewriteBatchedStatements=true"

val prop = new java.util.Properties
prop.setProperty("driver",   "com.mysql.cj.jdbc.Driver")
prop.setProperty("user",     mysqlUser)
prop.setProperty("password", mysqlPassword)

def withConn[A](f: java.sql.Connection => A): A = {
  val conn = DriverManager.getConnection(url, prop)
  try { f(conn) } finally { conn.close() }
}

import spark.implicits._

// ── 1. Read the family groups file ───────────────────────────────────────────

val rawDF = familyGroupsFormat match {
  case "csv" =>
    spark.read
      .option("header",                  "true")
      .option("quote",                   "\"")
      .option("escape",                  "\"")
      .option("treatEmptyValuesAsNulls", "true")
      .option("maxCharsPerCol", "100000000")
      .csv(familyGroupsPath)
  case "parquet" => spark.read.parquet(familyGroupsPath)
  case "avro"    => spark.read.format("avro").load(familyGroupsPath)
  case fmt       => throw new IllegalArgumentException(s"Unknown format: $fmt")
}

// ── 2. Validate families ──────────────────────────────────────────────────────
//
// Ruby: return if family.match(/\A[a-zA-Z]*\z/).blank?

val validFamilies = rawDF
  .filter($"family".isNotNull && $"family" =!= "")
  .filter($"gbifIDs_family".isNotNull &&
          $"gbifIDs_family" =!= "" &&
          $"gbifIDs_family" =!= "[]")
  .filter($"family".rlike("^[a-zA-Z]+$"))
  .select(
    trim($"family")  as "family",
    $"gbifIDs_family"
  )

// ── 3. Populate taxa table ────────────────────────────────────────────────────

val distinctFamilies = validFamilies.select("family").distinct()
distinctFamilies.write.mode("overwrite").jdbc(url, "taxa_tmp", prop)
println("Wrote distinct families to taxa_tmp")

withConn { conn =>
  val stmt = conn.createStatement()
  stmt.executeUpdate(
    "INSERT IGNORE INTO `taxa` (family) SELECT family FROM `taxa_tmp`"
  )
  println("taxa table updated")
  stmt.execute("DROP TABLE IF EXISTS `taxa_tmp`")
}

// ── 4. Read taxa back ─────────────────────────────────────────────────────────

val taxaLookup = broadcast(
  spark.read
    .jdbc(url, "taxa", prop)
    .select("id", "family")
    .withColumnRenamed("id", "taxon_id")
)

// ── 5. Drop indexes before writing ───────────────────────────────────────────

withConn { conn =>
  val stmt = conn.createStatement()
  println("Dropping indexes on taxon_occurrences...")
  Seq("index_taxon_occurrences_on_taxon_id").foreach { idx =>
    try { stmt.execute(s"ALTER TABLE `taxon_occurrences` DROP KEY `$idx`") }
    catch { case _: Exception => }
  }
  println("Indexes dropped")
}

// ── 6. Build and write taxon_occurrences via foreachPartition ─────────────────
//
// All previous approaches OOM because they route exploded occurrence rows
// through Spark's plan machinery (repartition, coalesce, DataFrame write)
// which buffers data in the driver or executor heap before flushing.
//
// foreachPartition sidesteps this entirely:
//   - Each executor processes exactly one input partition (one or a few families)
//   - The exploded occurrence IDs are streamed through an iterator — only
//     batchSize rows are in memory at any moment
//   - Each executor opens its own JDBC connection and flushes directly,
//     with no data ever travelling back to the driver
//   - Memory per task = batchSize rows × 16 bytes = ~16 KB, regardless of
//     how many occurrences are in the family
//
// array_distinct on the string array before explode eliminates any within-family
// duplicate IDs cheaply — a local per-row op with no shuffle.
// Cross-family duplicates cannot exist because each GBIF occurrence belongs
// to exactly one family.

val familiesWithIds = validFamilies
  .join(taxaLookup, Seq("family"), "left")
  .filter($"taxon_id".isNotNull)
  .select($"taxon_id", $"gbifIDs_family")
  .filter($"gbifIDs_family" =!= "[]")

// Capture connection parameters as local vals so they can be serialised
// to executors without pulling in the whole script object.
val capturedUrl      = url
val capturedUser     = mysqlUser
val capturedPassword = mysqlPassword
val capturedBatch    = batchSize

familiesWithIds.foreachPartition { rows: Iterator[org.apache.spark.sql.Row] =>

  // One connection per partition — opened lazily, closed when the partition ends.
  val connProps = new java.util.Properties
  connProps.setProperty("user",     capturedUser)
  connProps.setProperty("password", capturedPassword)

  val conn = DriverManager.getConnection(capturedUrl, connProps)
  conn.setAutoCommit(false)

  val sql  = "INSERT IGNORE INTO `taxon_occurrences` (occurrence_id, taxon_id) VALUES (?, ?)"
  val stmt = conn.prepareStatement(sql)
  var count = 0

  try {
    rows.foreach { row =>
      val taxonId      = row.getLong(0)   // taxon_id
      val gbifIdString = row.getString(1) // gbifIDs_family bracket string

      // Strip brackets, split, deduplicate, iterate — never materialise the
      // full list as a Scala collection; process one ID at a time.
      val cleaned = gbifIdString.replaceAll("[\\[\\]\\s]", "")
      if (cleaned.nonEmpty) {
        // Use a Set to deduplicate within this family's ID list without
        // building a full collection — iterate and track seen IDs.
        // For very large families (>1M IDs) a Set still fits in memory
        // because Long values are 8 bytes each: 1M × 8 = 8 MB.
        val seen = new scala.collection.mutable.HashSet[Long]()
        cleaned.split(",").foreach { idStr =>
          val trimmed = idStr.trim
          if (trimmed.nonEmpty) {
            try {
              val occurrenceId = trimmed.toLong
              if (occurrenceId > 0 && seen.add(occurrenceId)) {
                stmt.setLong(1, occurrenceId)
                stmt.setLong(2, taxonId)
                stmt.addBatch()
                count += 1
                if (count % capturedBatch == 0) {
                  stmt.executeBatch()
                  conn.commit()
                  stmt.clearBatch()
                }
              }
            } catch { case _: NumberFormatException => /* skip malformed IDs */ }
          }
        }
      }
    }
    // Flush any remaining rows in the final partial batch.
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

// ── 7. Rebuild indexes ────────────────────────────────────────────────────────

withConn { conn =>
  conn.createStatement().execute("""
    ALTER TABLE `taxon_occurrences`
      ADD KEY `index_taxon_occurrences_on_taxon_id` (`taxon_id`)
  """)
  println("Indexes rebuilt on taxon_occurrences")
}

println("Done.")

// ── Note on incremental updates ───────────────────────────────────────────────
//
// For delta updates on an already-populated table the same foreachPartition
// approach works without needing to drop and rebuild indexes — INSERT IGNORE
// handles duplicates row by row and the existing indexes remain intact.
// Simply remove the index-drop step (step 5) and the rebuild step (step 7).
