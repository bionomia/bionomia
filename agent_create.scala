// agent_create.scala
//
// Memory-safe replacement for AgentCreateWorker + its import method.
// Processes agent_jobs in partitioned batches so the full table is never
// held in memory at once.
//
// Run with:
//   spark-shell \
//     --jars /path/to/mysql-connector-j-8.x.x.jar \
//     -i agent_create.scala

import org.apache.spark.sql.functions._
import org.apache.spark.sql.types._
import org.apache.spark.sql.{DataFrame, SparkSession}

// ── Configuration ─────────────────────────────────────────────────────────────

val mysqlHost        = "localhost"
val mysqlPort        = 3306
val mysqlDb          = "bionomia"
val mysqlUser        = "root"
val mysqlPassword    = ""

// Number of parallel JDBC partitions when reading agent_jobs.
// Controls how many MySQL reader connections run in parallel.
// Each partition should contain 50k–200k rows — tune with:
//   numPartitions = ceil(totalRows / 100_000)
val numPartitions    = 40

// The id column used to split agent_jobs into partitions.
val partitionColumn  = "id"

// Shuffle partitions — controls how many buckets Spark uses during
// distinct(), join(), and groupBy() operations.
//
// The critical operation here is distinct() on ~500M occurrence_agents rows.
// Rule of thumb: target 100–200MB per shuffle partition.
// At ~20 bytes/row, 500M rows ≈ 10GB shuffled data:
//   10,000MB ÷ 150MB per partition × 3 (safety factor) ≈ 200 partitions
//
// If you still see "Failed to allocate a page" warnings, increase toward 400.
// If the job is fast but creating too many small files, reduce toward 100.
spark.conf.set("spark.sql.shuffle.partitions", "200")

val url = s"jdbc:mysql://$mysqlHost:$mysqlPort/$mysqlDb" +
  "?serverTimezone=UTC&useSSL=false&characterEncoding=UTF-8&rewriteBatchedStatements=true"

val prop = new java.util.Properties
prop.setProperty("driver",   "com.mysql.cj.jdbc.Driver")
prop.setProperty("user",     mysqlUser)
prop.setProperty("password", mysqlPassword)

// ── Helper ────────────────────────────────────────────────────────────────────

def withConn[A](f: java.sql.Connection => A): A = {
  val conn = java.sql.DriverManager.getConnection(url, prop)
  try { f(conn) } finally { conn.close() }
}

// ── Fetch id bounds so Spark can split the table into even partitions ─────────
//
// spark.read.jdbc with lowerBound/upperBound/numPartitions issues numPartitions
// parallel SELECT queries each covering a sub-range of the id column.
// No row is held in memory beyond what one partition needs at a time.

val (minId, maxId) = withConn { conn =>
  val rs = conn.createStatement()
    .executeQuery(s"SELECT MIN($partitionColumn), MAX($partitionColumn) FROM agent_jobs")
  rs.next()
  (rs.getLong(1), rs.getLong(2))
}
println(s"agent_jobs id range: $minId – $maxId")

// ── Read agent_jobs in partitions — no cache, no count ───────────────────────

val agentJobs = spark.read.jdbc(
  url,
  "agent_jobs",
  partitionColumn,
  lowerBound    = minId,
  upperBound    = maxId,
  numPartitions = numPartitions,
  prop
).select("id", "agents", "parsed", "gbifIDs_recordedBy", "gbifIDs_identifiedBy")
 .na.fill("[]", Seq("gbifIDs_recordedBy", "gbifIDs_identifiedBy"))

// ── Schema for the agents_parsed JSON array ───────────────────────────────────

val nameSchema = ArrayType(StructType(Seq(
  StructField("family",            StringType),
  StructField("given",             StringType),
  StructField("particle",          StringType),
  StructField("appellation",       StringType),
  StructField("title",             StringType),
  StructField("suffix",            StringType),
  StructField("nick",              StringType),
  StructField("dropping_particle", StringType)
)))

import spark.implicits._

// ── Explode parsed names, apply missing_features logic, normalise fields ──────
//
// This is a single lazy transformation chain — Spark only materialises one
// partition at a time when writing, so memory use is bounded by partition size.

val normalised = agentJobs
  // Parse the JSON array and explode so each name becomes its own row.
  .withColumn("parsed_array", from_json($"parsed", nameSchema))
  .withColumn("name",         explode_outer($"parsed_array"))
  .select(
    $"id"                          as "job_id",
    $"agents"                      as "raw_agents",
    $"gbifIDs_recordedBy",
    $"gbifIDs_identifiedBy",
    $"name.family"                 as "family",
    $"name.given"                  as "given",
    $"name.particle"               as "particle",
    $"name.appellation"            as "appellation",
    $"name.title"                  as "title",
    $"name.suffix"                 as "suffix",
    $"name.nick"                   as "nick",
    $"name.dropping_particle"      as "dropping_particle"
  )
  // missing_features logic — mirrors the Ruby worker exactly.
  .withColumn("is_unparsed",
    $"family".isNull || $"family" === "" ||
    length($"family") > 40 ||
    (length($"family") - length(regexp_replace($"family", "\\.", ""))) > 4 ||
    ($"given".isNotNull && length($"given") > 40) ||
    ($"given".isNotNull && (length($"given") - length(regexp_replace($"given", "\\.", ""))) > 5)
  )
  // Build display_order for the unparsed fallback (mirrors Ruby worker).
  .withColumn("given_part",
    trim(concat_ws(" ",
      when($"given".isNotNull     && $"given"              =!= "", $"given"),
      when($"dropping_particle".isNotNull && $"dropping_particle" =!= "", $"dropping_particle")
    )))
  .withColumn("family_part",
    trim(concat_ws(" ",
      when($"particle".isNotNull && $"particle" =!= "", $"particle"),
      when($"family".isNotNull   && $"family"   =!= "", $"family")
    )))
  .withColumn("display_order",
    trim(concat_ws(" ",
      when($"given_part"  =!= "", $"given_part"),
      when($"family_part" =!= "", $"family_part"),
      when($"suffix".isNotNull && $"suffix" =!= "", $"suffix")
    )))
  // Final agent key fields — blank everything out for unparsed agents.
  .withColumn("a_family",
    when($"is_unparsed", lit("")).otherwise(
      trim(regexp_replace(coalesce($"family",            lit("")), "\\s+", " "))))
  .withColumn("a_given",
    when($"is_unparsed", lit("")).otherwise(
      trim(regexp_replace(coalesce($"given",             lit("")), "\\s+", " "))))
  .withColumn("a_particle",
    when($"is_unparsed", lit("")).otherwise(
      trim(regexp_replace(coalesce($"particle",          lit("")), "\\s+", " "))))
  .withColumn("a_appellation",
    when($"is_unparsed", lit("")).otherwise(
      trim(regexp_replace(coalesce($"appellation",       lit("")), "\\s+", " "))))
  .withColumn("a_title",
    when($"is_unparsed", lit("")).otherwise(
      trim(regexp_replace(coalesce($"title",             lit("")), "\\s+", " "))))
  .withColumn("a_suffix",
    when($"is_unparsed", lit("")).otherwise(
      trim(regexp_replace(coalesce($"suffix",            lit("")), "\\s+", " "))))
  .withColumn("a_nick",
    when($"is_unparsed", lit("")).otherwise(
      trim(regexp_replace(coalesce($"nick",              lit("")), "\\s+", " "))))
  .withColumn("a_dropping_particle",
    when($"is_unparsed", lit("")).otherwise(
      trim(regexp_replace(coalesce($"dropping_particle", lit("")), "\\s+", " "))))
  .withColumn("a_unparsed",
    when($"is_unparsed", substring(trim($"display_order"), 1, 150))
      .otherwise(lit("")))

// ── Step 1: Populate agents table ────────────────────────────────────────────
//
// Write only the distinct agent key tuples to a temp table, then
// INSERT IGNORE into agents.  Distinct on 4M exploded rows is still
// manageable because Spark shuffles by the key columns, not the gbifID arrays.

val distinctAgents = normalised
  .select(
    $"a_family"            as "family",
    $"a_given"             as "given",
    $"a_particle"          as "particle",
    $"a_appellation"       as "appellation",
    $"a_title"             as "title",
    $"a_suffix"            as "suffix",
    $"a_nick"              as "nick",
    $"a_dropping_particle" as "dropping_particle",
    $"a_unparsed"          as "unparsed"
  )
  .distinct()

distinctAgents.write.mode("overwrite").jdbc(url, "agents_tmp", prop)
println("Wrote distinct agents to agents_tmp")

withConn { conn =>
  val stmt = conn.createStatement()
  stmt.executeUpdate("""
    INSERT IGNORE INTO `agents`
      (family, given, particle, appellation, title, suffix,
       nick, dropping_particle, unparsed)
    SELECT family, given, particle, appellation, title, suffix,
           nick, dropping_particle, unparsed
    FROM   `agents_tmp`
  """)
  stmt.execute("DROP TABLE IF EXISTS `agents_tmp`")
  println("agents table updated")
}

// ── Step 2: Populate occurrence_agents ───────────────────────────────────────
//
// We need the database-assigned agent id for each name tuple.
// Read agents back (id + key columns only), broadcast it since it is much
// smaller than the exploded occurrence rows, then join and explode gbifIDs.
//
// Broadcasting agents avoids a full shuffle of the large occurrences side.

val agentsLookup = spark.read
  .jdbc(url, "agents", prop)
  .select("id", "family", "given", "particle", "appellation",
          "title", "suffix", "nick", "dropping_particle", "unparsed")
  .withColumnRenamed("id", "agent_id")

// agents is typically much smaller than the exploded gbifID rows — broadcast it.
val agentsBroadcast = broadcast(agentsLookup)

val withAgentId = normalised
  .join(
    agentsBroadcast,
    normalised("a_family")            === agentsBroadcast("family")            &&
    normalised("a_given")             === agentsBroadcast("given")             &&
    normalised("a_particle")          === agentsBroadcast("particle")          &&
    normalised("a_appellation")       === agentsBroadcast("appellation")       &&
    normalised("a_title")             === agentsBroadcast("title")             &&
    normalised("a_suffix")            === agentsBroadcast("suffix")            &&
    normalised("a_nick")              === agentsBroadcast("nick")              &&
    normalised("a_dropping_particle") === agentsBroadcast("dropping_particle") &&
    normalised("a_unparsed")          === agentsBroadcast("unparsed"),
    "left"
  )
  .select("agent_id", "gbifIDs_recordedBy", "gbifIDs_identifiedBy")

// Explode gbifID arrays into individual occurrence_id rows.
// explode must be in its own withColumn call — it cannot be nested inside
// a cast or any other expression in the same select (Spark AnalysisException).
def toOccurrenceAgents(df: DataFrame, gbifCol: String, role: Boolean): DataFrame =
  df.filter(col(gbifCol).isNotNull && col(gbifCol) =!= "[]" && col(gbifCol) =!= "")
    // Step 1: strip brackets/whitespace and split into a string array column.
    .withColumn("gbif_id_strings",
      split(regexp_replace(col(gbifCol), "[\\[\\]\\s]", ""), ","))
    // Step 2: explode the array — one row per element, still as String.
    .withColumn("gbif_id_str", explode($"gbif_id_strings"))
    // Step 3: cast to Long in a separate withColumn so no nesting occurs.
    .withColumn("occurrence_id", $"gbif_id_str".cast(LongType))
    .filter($"occurrence_id".isNotNull && $"occurrence_id" > 0)
    .select(
      $"occurrence_id",
      $"agent_id",
      lit(role).cast(BooleanType) as "agent_role"
    )

// ── Build occurrence_agents rows ──────────────────────────────────────────────
//
// Deduplication strategy: we cannot use distinct() on 500M rows (OOM), but we
// must eliminate duplicates before writing to a table with no unique index.
//
// Solution: repartition by (occurrence_id, agent_id, agent_role) using
// spark.sql.shuffle.partitions (already set to 200 above). Within each
// partition every row with the same key lands on the same executor, so
// dropDuplicates() is a purely local hash-table operation on at most
// 500M/200 = 2.5M rows per partition — well within memory.
//
// This is cheaper than a full sort-based distinct() because:
//   - repartition does a hash shuffle (writes/reads shuffle files once)
//   - dropDuplicates inside each partition uses a local hash set, not a sort
//
// The resulting DataFrame has exactly the rows that will be inserted, with
// no duplicates, and the index-drop strategy is safe to use.

val occurrenceAgents = toOccurrenceAgents(withAgentId, "gbifIDs_recordedBy",   true)
  .union(toOccurrenceAgents(withAgentId, "gbifIDs_identifiedBy", false))
  .filter($"agent_id".isNotNull)
  .repartition($"occurrence_id", $"agent_id", $"agent_role")
  .dropDuplicates("occurrence_id", "agent_id", "agent_role")

// ── Write occurrence_agents — index-drop strategy ─────────────────────────────
//
// With duplicates eliminated in Spark, we can safely:
//   1. Drop all indexes so MySQL inserts are uncontested sequential appends.
//   2. Write directly from Spark — 10-50x faster than indexed inserts.
//   3. Rebuild all indexes in one ALTER TABLE bulk pass at the end.
//
// The ADD UNIQUE KEY step will now succeed because Spark already removed dupes.

withConn { conn =>
  val stmt = conn.createStatement()
  println("Dropping indexes on occurrence_agents for fast bulk insert...")
  // Drop each index separately so a missing index does not abort the others.
  // Adjust names to match your schema: SHOW CREATE TABLE occurrence_agents\G
  Seq("agent_idx", "occurrence_idx", "unique_occurrence_agent").foreach { idx =>
    try { stmt.execute(s"ALTER TABLE `occurrence_agents` DROP KEY `$idx`") }
    catch { case _: Exception => /* index may not exist yet */ }
  }
  println("Indexes dropped")
}

// coalesce after repartition keeps the number of MySQL connections bounded.
// sortWithinPartitions orders rows by occurrence_id so InnoDB page splits
// are minimised during the index rebuild.
occurrenceAgents
  .sortWithinPartitions($"occurrence_id", $"agent_id")
  .coalesce(numPartitions)
  .write
  .mode("append")
  .jdbc(url, "occurrence_agents", prop)

println("Rows written — rebuilding indexes (this will take a few minutes)...")

withConn { conn =>
  // Single ALTER TABLE rebuilds all indexes in one bulk sort-and-build pass.
  // Adjust key names and columns to match your schema exactly.
  conn.createStatement().execute("""
    ALTER TABLE `occurrence_agents`
      ADD KEY        `agent_idx`               (`agent_id`),
      ADD KEY        `occurrence_idx`          (`occurrence_id`),
      ADD UNIQUE KEY `unique_occurrence_agent` (`occurrence_id`, `agent_id`, `agent_role`)
  """)
  println("Indexes rebuilt on occurrence_agents")
}

println("Done.")

// ── Note on incremental updates ───────────────────────────────────────────────
//
// The index-drop strategy above is designed for a full refresh where
// occurrence_agents is either empty or being completely replaced.
//
// If you ever need to add only new rows to an already-populated table
// (e.g. processing a delta of new agent_jobs rows), the safe approach is
// to write the new rows to a staging table with no indexes, then merge in
// batches small enough to keep the index lookup fast:
//
//   val batchSize = 1_000_000
//   val maxId = withConn { conn =>
//     val rs = conn.createStatement()
//       .executeQuery("SELECT MAX(id) FROM occurrence_agents_staging")
//     rs.next(); rs.getLong(1)
//   }
//   (0L to maxId by batchSize).foreach { offset =>
//     withConn { conn =>
//       conn.createStatement().executeUpdate(s"""
//         INSERT IGNORE INTO occurrence_agents (occurrence_id, agent_id, agent_role)
//         SELECT occurrence_id, agent_id, agent_role
//         FROM   occurrence_agents_staging
//         WHERE  id > $offset AND id <= ${offset + batchSize}
//       """)
//     }
//   }
