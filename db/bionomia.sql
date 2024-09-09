SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;


CREATE TABLE `agents` (
  `id` int NOT NULL,
  `family` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `given` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `unparsed` varchar(150) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin ROW_FORMAT=COMPRESSED;

CREATE TABLE `agent_jobs` (
  `id` int NOT NULL,
  `agents` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `gbifIDs_recordedBy` mediumtext COLLATE utf8mb4_bin,
  `gbifIDs_identifiedBy` mediumtext COLLATE utf8mb4_bin,
  `parsed` mediumtext COLLATE utf8mb4_bin
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `articles` (
  `id` bigint UNSIGNED NOT NULL,
  `doi` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `citation` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `abstract` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `gbif_dois` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `gbif_downloadkeys` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `processed` tinyint(1) DEFAULT NULL,
  `process_status` int DEFAULT '0',
  `mail_sent` tinyint(1) NOT NULL DEFAULT '0',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `article_occurrences` (
  `id` bigint UNSIGNED NOT NULL,
  `article_id` bigint UNSIGNED NOT NULL,
  `occurrence_id` bigint UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin KEY_BLOCK_SIZE=8 ROW_FORMAT=COMPRESSED;

CREATE TABLE `bulk_attribution_queries` (
  `id` bigint NOT NULL,
  `user_id` int NOT NULL,
  `created_by` int NOT NULL,
  `query` text COLLATE utf8mb4_bin,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `datasets` (
  `id` bigint NOT NULL,
  `datasetKey` binary(36) NOT NULL,
  `title` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `doi` tinytext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `license` tinytext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `image_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `dataset_type` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT NULL,
  `frictionless_created_at` timestamp NULL DEFAULT NULL,
  `occurrences_count` int UNSIGNED NOT NULL DEFAULT '0',
  `source_attribution_count` int UNSIGNED NOT NULL DEFAULT '0',
  `zenodo_doi` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `zenodo_concept_doi` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `destroyed_users` (
  `id` int NOT NULL,
  `identifier` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `redirect_to` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `reason` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `messages` (
  `id` bigint NOT NULL,
  `user_id` int UNSIGNED NOT NULL,
  `recipient_id` int UNSIGNED NOT NULL,
  `read` tinyint(1) DEFAULT '0',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `occurrences` (
  `gbifID` bigint UNSIGNED NOT NULL,
  `datasetKey` binary(36) DEFAULT NULL,
  `license` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `occurrenceID` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `basisOfRecord` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `dateIdentified` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `decimalLatitude` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `decimalLongitude` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `country` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `countryCode` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `eventDate` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `year` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `kingdom` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `family` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `identifiedBy` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `institutionCode` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `collectionCode` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `catalogNumber` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `recordedBy` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `scientificName` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `typeStatus` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `dateIdentified_processed` date DEFAULT NULL,
  `dateIdentified_processed_year` int GENERATED ALWAYS AS (year(`dateIdentified_processed`)) STORED,
  `dateIdentified_processed_month` int GENERATED ALWAYS AS (month(`dateIdentified_processed`)) STORED,
  `dateIdentified_processed_day` int GENERATED ALWAYS AS (dayofmonth(`dateIdentified_processed`)) STORED,
  `eventDate_processed` date DEFAULT NULL,
  `eventDate_processed_year` int GENERATED ALWAYS AS (year(`eventDate_processed`)) STORED,
  `eventDate_processed_month` int GENERATED ALWAYS AS (month(`eventDate_processed`)) STORED,
  `eventDate_processed_day` int GENERATED ALWAYS AS (dayofmonth(`eventDate_processed`)) STORED,
  `hasImage` tinyint(1) DEFAULT NULL,
  `recordedByID` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `identifiedByID` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin ROW_FORMAT=COMPRESSED;

CREATE TABLE `occurrence_agents` (
  `id` bigint UNSIGNED NOT NULL,
  `occurrence_id` bigint NOT NULL,
  `agent_id` int NOT NULL,
  `agent_role` tinyint(1) NOT NULL DEFAULT '1'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin ROW_FORMAT=COMPRESSED;

CREATE TABLE `occurrence_counts` (
  `id` bigint NOT NULL,
  `occurrence_id` bigint UNSIGNED NOT NULL,
  `agent_count` int UNSIGNED DEFAULT NULL,
  `user_count` int UNSIGNED DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `organizations` (
  `id` int NOT NULL,
  `isni` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `ringgold` int DEFAULT NULL,
  `grid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `ror` varchar(9) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `address` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `institution_codes` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `wikidata` varchar(100) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `latitude` float DEFAULT NULL,
  `longitude` float DEFAULT NULL,
  `image_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `website` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `schema_migrations` (
  `version` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `source_attributions` (
  `id` bigint NOT NULL,
  `user_id` int NOT NULL,
  `occurrence_id` bigint NOT NULL,
  `action` varchar(255) COLLATE utf8mb4_bin NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `source_users` (
  `id` bigint NOT NULL,
  `identifier` varchar(255) COLLATE utf8mb4_bin NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `taxa` (
  `id` int NOT NULL,
  `family` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `taxon_images` (
  `id` int NOT NULL,
  `family` varchar(255) COLLATE utf8mb4_bin NOT NULL,
  `file_name` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `credit` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL,
  `licenseURL` varchar(255) COLLATE utf8mb4_bin DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `taxon_occurrences` (
  `occurrence_id` bigint UNSIGNED NOT NULL,
  `taxon_id` int UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin ROW_FORMAT=COMPRESSED;

CREATE TABLE `users` (
  `id` int NOT NULL,
  `family` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `given` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `particle` varchar(50) DEFAULT NULL,
  `orcid` varchar(25) DEFAULT NULL,
  `wikidata` varchar(50) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `other_names` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `country` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `country_code` varchar(100) DEFAULT NULL,
  `keywords` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `description` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `image_url` text,
  `signature_url` text,
  `youtube_id` varchar(255) DEFAULT NULL,
  `locale` varchar(2) DEFAULT NULL,
  `date_born` date DEFAULT NULL,
  `date_born_precision` varchar(255) DEFAULT NULL,
  `date_died` date DEFAULT NULL,
  `date_died_precision` varchar(255) DEFAULT NULL,
  `is_public` tinyint(1) DEFAULT '0',
  `made_public` timestamp NULL DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated` timestamp NULL DEFAULT NULL,
  `visited` timestamp NULL DEFAULT NULL,
  `is_admin` tinyint(1) NOT NULL DEFAULT '0',
  `zenodo_access_token` text,
  `zenodo_doi` varchar(255) DEFAULT NULL,
  `zenodo_concept_doi` varchar(255) DEFAULT NULL,
  `wants_mail` tinyint(1) NOT NULL DEFAULT '0',
  `mail_last_sent` timestamp NULL DEFAULT NULL,
  `wiki_sitelinks` text,
  `label` varchar(255) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE `user_occurrences` (
  `id` int NOT NULL,
  `user_id` int UNSIGNED NOT NULL,
  `occurrence_id` bigint UNSIGNED NOT NULL,
  `action` varchar(100) CHARACTER SET utf8mb3 COLLATE utf8mb3_bin DEFAULT NULL,
  `visible` tinyint(1) NOT NULL DEFAULT '1',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated` timestamp NULL DEFAULT NULL,
  `created_by` int UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE `user_organizations` (
  `id` int NOT NULL,
  `user_id` int UNSIGNED NOT NULL,
  `organization_id` int UNSIGNED NOT NULL,
  `start_year` int UNSIGNED DEFAULT NULL,
  `start_month` int UNSIGNED DEFAULT NULL,
  `start_day` int UNSIGNED DEFAULT NULL,
  `end_year` int UNSIGNED DEFAULT NULL,
  `end_month` int UNSIGNED DEFAULT NULL,
  `end_day` int UNSIGNED DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


ALTER TABLE `agents`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `full_name` (`family`,`given`,`unparsed`) USING BTREE;

ALTER TABLE `agent_jobs`
  ADD PRIMARY KEY (`id`);

ALTER TABLE `articles`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `doi_idx` (`doi`);

ALTER TABLE `article_occurrences`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `occurrence_article_idx` (`occurrence_id`,`article_id`),
  ADD KEY `article_idx` (`article_id`);

ALTER TABLE `bulk_attribution_queries`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_idx` (`user_id`),
  ADD KEY `created_by_idx` (`created_by`);

ALTER TABLE `datasets`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `index_datasets_on_datasetKey` (`datasetKey`);

ALTER TABLE `destroyed_users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `identifier_idx` (`identifier`);

ALTER TABLE `messages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `index_messages_on_user_id` (`user_id`),
  ADD KEY `index_messages_on_recipient_id` (`recipient_id`);

ALTER TABLE `occurrences`
  ADD PRIMARY KEY (`gbifID`) USING BTREE,
  ADD KEY `typeStatus_idx` (`typeStatus`(50),`hasImage`),
  ADD KEY `index_occurrences_on_datasetKey_occurrenceID` (`datasetKey`,`occurrenceID`(36)),
  ADD KEY `country_code_idx` (`countryCode`),
  ADD KEY `eventDate_processed_idx` (`eventDate_processed_year`,`eventDate_processed_month`,`eventDate_processed_day`),
  ADD KEY `dateIdentified_processed_idx` (`dateIdentified_processed_year`,`dateIdentified_processed_month`,`dateIdentified_processed_day`);

ALTER TABLE `occurrence_agents`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `agent_occurrence_idx` (`agent_id`,`agent_role`,`occurrence_id`),
  ADD KEY `occurrence_idx` (`occurrence_id`);

ALTER TABLE `occurrence_counts`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `occurrence_id` (`occurrence_id`),
  ADD KEY `agent_count_idx` (`agent_count`);

ALTER TABLE `organizations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `ringgold_idx` (`ringgold`),
  ADD KEY `grid_idx` (`grid`),
  ADD KEY `isni_idx` (`isni`),
  ADD KEY `wikidata` (`wikidata`),
  ADD KEY `index_organizations_on_ror` (`ror`);

ALTER TABLE `schema_migrations`
  ADD UNIQUE KEY `unique_schema_migrations` (`version`);

ALTER TABLE `source_attributions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `source_attributions_composite` (`user_id`,`occurrence_id`,`action`);

ALTER TABLE `source_users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `index_source_users_on_identifier` (`identifier`);

ALTER TABLE `taxa`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `family_idx` (`family`);

ALTER TABLE `taxon_images`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `index_taxon_images_on_family` (`family`) USING BTREE;

ALTER TABLE `taxon_occurrences`
  ADD PRIMARY KEY (`occurrence_id`) USING BTREE,
  ADD KEY `index_taxon_occurrences_on_taxon_id` (`taxon_id`) USING BTREE;

ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD KEY `orcid_idx` (`orcid`) USING BTREE,
  ADD KEY `wikidata_idx` (`wikidata`) USING BTREE,
  ADD KEY `country_code` (`country_code`),
  ADD KEY `index_users_on_is_public` (`is_public`);

ALTER TABLE `user_occurrences`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `user_occurrence_idx` (`occurrence_id`,`user_id`),
  ADD KEY `user_created_idx` (`user_id`,`created`),
  ADD KEY `user_created_by_idx` (`user_id`,`created_by`) USING BTREE,
  ADD KEY `created_by_user_visible_idx` (`created_by`,`user_id`,`visible`);

ALTER TABLE `user_organizations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_idx` (`user_id`),
  ADD KEY `organization_idx` (`organization_id`);


ALTER TABLE `agents`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

ALTER TABLE `agent_jobs`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

ALTER TABLE `articles`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

ALTER TABLE `article_occurrences`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

ALTER TABLE `bulk_attribution_queries`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

ALTER TABLE `datasets`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

ALTER TABLE `destroyed_users`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

ALTER TABLE `messages`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

ALTER TABLE `occurrence_agents`
  MODIFY `id` bigint UNSIGNED NOT NULL AUTO_INCREMENT;

ALTER TABLE `occurrence_counts`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

ALTER TABLE `organizations`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

ALTER TABLE `source_attributions`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

ALTER TABLE `source_users`
  MODIFY `id` bigint NOT NULL AUTO_INCREMENT;

ALTER TABLE `taxa`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

ALTER TABLE `taxon_images`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

ALTER TABLE `users`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

ALTER TABLE `user_occurrences`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;

ALTER TABLE `user_organizations`
  MODIFY `id` int NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
