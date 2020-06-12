SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET AUTOCOMMIT = 0;
START TRANSACTION;
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;


CREATE TABLE `agents` (
  `id` int(11) NOT NULL,
  `family` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT '',
  `given` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL DEFAULT ''
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `articles` (
  `id` int(11) NOT NULL,
  `doi` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `citation` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `abstract` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `gbif_dois` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `gbif_downloadkeys` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `processed` tinyint(1) DEFAULT NULL,
  `mail_sent` tinyint(1) NOT NULL DEFAULT '0',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `article_occurrences` (
  `article_id` int(11) NOT NULL,
  `occurrence_id` bigint(11) UNSIGNED NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `ar_internal_metadata` (
  `key` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `value` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `created_at` datetime(6) NOT NULL,
  `updated_at` datetime(6) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `datasets` (
  `id` bigint(20) NOT NULL,
  `datasetKey` binary(36) NOT NULL,
  `title` text COLLATE utf8mb4_bin,
  `description` text COLLATE utf8mb4_bin,
  `doi` tinytext COLLATE utf8mb4_bin,
  `license` tinytext COLLATE utf8mb4_bin,
  `image_url` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `destroyed_users` (
  `id` int(11) NOT NULL,
  `identifier` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL,
  `redirect_to` varchar(25) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `messages` (
  `id` bigint(20) NOT NULL,
  `user_id` int(11) NOT NULL,
  `recipient_id` int(11) NOT NULL,
  `read` tinyint(1) DEFAULT '0',
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `occurrences` (
  `gbifID` bigint(11) UNSIGNED NOT NULL,
  `datasetKey` binary(36) DEFAULT NULL,
  `occurrenceID` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `dateIdentified` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `decimalLatitude` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `decimalLongitude` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `country` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `countryCode` varchar(4) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `eventDate` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `year` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `family` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `identifiedBy` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `institutionCode` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `collectionCode` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `catalogNumber` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `recordedBy` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `scientificName` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `typeStatus` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `dateIdentified_processed` datetime DEFAULT NULL,
  `eventDate_processed` datetime DEFAULT NULL,
  `hasImage` tinyint(1) DEFAULT NULL,
  `recordedByID` text COLLATE utf8mb4_bin,
  `identifiedByID` text COLLATE utf8mb4_bin
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `occurrence_determiners` (
  `occurrence_id` bigint(11) UNSIGNED NOT NULL,
  `agent_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `occurrence_recorders` (
  `occurrence_id` bigint(11) UNSIGNED NOT NULL,
  `agent_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `organizations` (
  `id` int(11) NOT NULL,
  `isni` varchar(120) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `ringgold` int(11) DEFAULT NULL,
  `grid` varchar(50) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
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

CREATE TABLE `taxa` (
  `id` int(11) NOT NULL,
  `family` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `taxon_occurrences` (
  `occurrence_id` bigint(11) UNSIGNED NOT NULL,
  `taxon_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;

CREATE TABLE `users` (
  `id` int(11) NOT NULL,
  `family` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `given` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `particle` varchar(50) DEFAULT NULL,
  `orcid` varchar(25) DEFAULT NULL,
  `wikidata` varchar(50) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `other_names` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `country` varchar(255) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL,
  `country_code` varchar(50) DEFAULT NULL,
  `keywords` text CHARACTER SET utf8mb4 COLLATE utf8mb4_bin,
  `twitter` varchar(50) DEFAULT NULL,
  `image_url` text,
  `signature_url` varchar(255) DEFAULT NULL,
  `date_born` date DEFAULT NULL,
  `date_born_precision` varchar(255) DEFAULT NULL,
  `date_died` date DEFAULT NULL,
  `date_died_precision` varchar(255) DEFAULT NULL,
  `is_public` tinyint(1) DEFAULT '0',
  `can_comment` tinyint(1) NOT NULL DEFAULT '1',
  `made_public` timestamp NULL DEFAULT NULL,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated` timestamp NULL DEFAULT NULL,
  `visited` timestamp NULL DEFAULT NULL,
  `is_admin` tinyint(1) NOT NULL DEFAULT '0',
  `zenodo_access_token` text,
  `zenodo_doi` varchar(255) DEFAULT NULL,
  `zenodo_concept_doi` varchar(255) DEFAULT NULL,
  `wants_mail` tinyint(1) NOT NULL DEFAULT '0',
  `mail_last_sent` timestamp NULL DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `user_occurrences` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `occurrence_id` bigint(11) UNSIGNED NOT NULL,
  `action` varchar(100) CHARACTER SET utf8 COLLATE utf8_bin DEFAULT NULL,
  `visible` tinyint(1) NOT NULL DEFAULT '1',
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated` timestamp NULL DEFAULT NULL,
  `created_by` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE TABLE `user_organizations` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `organization_id` int(11) NOT NULL,
  `start_year` int(11) DEFAULT NULL,
  `start_month` int(11) DEFAULT NULL,
  `start_day` int(11) DEFAULT NULL,
  `end_year` int(11) DEFAULT NULL,
  `end_month` int(11) DEFAULT NULL,
  `end_day` int(11) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_bin;


ALTER TABLE `agents`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `full_name` (`family`,`given`) USING BTREE;

ALTER TABLE `articles`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `doi_idx` (`doi`);

ALTER TABLE `article_occurrences`
  ADD PRIMARY KEY (`article_id`,`occurrence_id`),
  ADD UNIQUE KEY `occurrence_article_idx` (`occurrence_id`,`article_id`);

ALTER TABLE `ar_internal_metadata`
  ADD PRIMARY KEY (`key`);

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
  ADD KEY `typeStatus_idx` (`typeStatus`(256)),
  ADD KEY `index_occurrences_on_datasetKey` (`datasetKey`);

ALTER TABLE `occurrence_determiners`
  ADD PRIMARY KEY (`agent_id`,`occurrence_id`),
  ADD UNIQUE KEY `occurrence_agent_idx` (`occurrence_id`,`agent_id`);

ALTER TABLE `occurrence_recorders`
  ADD PRIMARY KEY (`agent_id`,`occurrence_id`),
  ADD UNIQUE KEY `occurrence_agent_idx` (`occurrence_id`,`agent_id`);

ALTER TABLE `organizations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `ringgold_idx` (`ringgold`),
  ADD KEY `grid_idx` (`grid`),
  ADD KEY `isni_idx` (`isni`),
  ADD KEY `wikidata` (`wikidata`);

ALTER TABLE `schema_migrations`
  ADD UNIQUE KEY `unique_schema_migrations` (`version`);

ALTER TABLE `taxa`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `family_idx` (`family`);

ALTER TABLE `taxon_occurrences`
  ADD PRIMARY KEY (`occurrence_id`) USING BTREE;

ALTER TABLE `users`
  ADD PRIMARY KEY (`id`),
  ADD KEY `orcid_idx` (`orcid`) USING BTREE,
  ADD KEY `wikidata_idx` (`wikidata`) USING BTREE,
  ADD KEY `country_code` (`country_code`);

ALTER TABLE `user_occurrences`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `user_occurrence_idx` (`occurrence_id`,`user_id`),
  ADD KEY `created_by_idx` (`created_by`),
  ADD KEY `user_created_idx` (`user_id`,`created`),
  ADD KEY `user_created_by_idx` (`user_id`,`created_by`) USING BTREE;

ALTER TABLE `user_organizations`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_idx` (`user_id`),
  ADD KEY `organization_idx` (`organization_id`);


ALTER TABLE `agents`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `articles`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `datasets`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

ALTER TABLE `destroyed_users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `messages`
  MODIFY `id` bigint(20) NOT NULL AUTO_INCREMENT;

ALTER TABLE `organizations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `taxa`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `user_occurrences`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `user_organizations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
