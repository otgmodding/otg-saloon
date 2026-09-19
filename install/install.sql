CREATE TABLE IF NOT EXISTS `otg_saloon_businesses` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `slug` varchar(64) NOT NULL,
  `label` varchar(100) NOT NULL,
  `job` varchar(64) NOT NULL,
  `owner_citizenid` varchar(64) DEFAULT NULL,
  `balance` decimal(12,2) NOT NULL DEFAULT 0.00,
  `storage_weight` int unsigned NOT NULL DEFAULT 500000,
  `storage_slots` int unsigned NOT NULL DEFAULT 80,
  `blip_x` double DEFAULT NULL,
  `blip_y` double DEFAULT NULL,
  `blip_z` double DEFAULT NULL,
  `blip_sprite` int DEFAULT NULL,
  `blip_scale` float NOT NULL DEFAULT 0.2,
  `active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_otg_saloon_slug` (`slug`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `otg_saloon_stations` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `business_id` int unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `label` varchar(100) NOT NULL,
  `x` double NOT NULL,
  `y` double NOT NULL,
  `z` double NOT NULL,
  `heading` float NOT NULL DEFAULT 0,
  `min_grade` int NOT NULL DEFAULT 0,
  `settings` longtext DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_station_business` (`business_id`),
  CONSTRAINT `fk_station_business` FOREIGN KEY (`business_id`) REFERENCES `otg_saloon_businesses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `otg_saloon_recipes` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `business_id` int unsigned NOT NULL,
  `label` varchar(100) NOT NULL,
  `result_item` varchar(64) NOT NULL,
  `result_amount` int unsigned NOT NULL DEFAULT 1,
  `craft_ms` int unsigned NOT NULL DEFAULT 5000,
  `min_grade` int NOT NULL DEFAULT 0,
  `ingredients` longtext NOT NULL,
  `item_weight` int unsigned NOT NULL DEFAULT 100,
  `item_image` varchar(255) DEFAULT NULL,
  `item_description` varchar(255) DEFAULT NULL,
  `dynamic_item` tinyint(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  KEY `idx_recipe_business` (`business_id`),
  CONSTRAINT `fk_recipe_business` FOREIGN KEY (`business_id`) REFERENCES `otg_saloon_businesses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `otg_saloon_shipments` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `business_id` int unsigned NOT NULL,
  `depot` varchar(64) NOT NULL,
  `status` varchar(32) NOT NULL DEFAULT 'ready',
  `crate_count` int unsigned NOT NULL DEFAULT 1,
  `picked_crates` int unsigned NOT NULL DEFAULT 0,
  `delivered_crates` int unsigned NOT NULL DEFAULT 0,
  `contents` longtext NOT NULL,
  `ordered_by` varchar(64) NOT NULL,
  `assigned_to` varchar(64) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `completed_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_shipment_business` (`business_id`),
  CONSTRAINT `fk_shipment_business` FOREIGN KEY (`business_id`) REFERENCES `otg_saloon_businesses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `otg_saloon_contracts` (
  `id` int unsigned NOT NULL AUTO_INCREMENT,
  `shipment_id` int unsigned NOT NULL,
  `business_id` int unsigned NOT NULL,
  `payment` decimal(12,2) NOT NULL DEFAULT 0.00,
  `status` varchar(32) NOT NULL DEFAULT 'open',
  `contractor_citizenid` varchar(64) DEFAULT NULL,
  `accepted_at` timestamp NULL DEFAULT NULL,
  `completed_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_contract_shipment` (`shipment_id`),
  CONSTRAINT `fk_contract_shipment` FOREIGN KEY (`shipment_id`) REFERENCES `otg_saloon_shipments` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_contract_business` FOREIGN KEY (`business_id`) REFERENCES `otg_saloon_businesses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `otg_saloon_stock` (
  `business_id` int unsigned NOT NULL,
  `item` varchar(64) NOT NULL,
  `amount` int unsigned NOT NULL DEFAULT 0,
  PRIMARY KEY (`business_id`,`item`),
  CONSTRAINT `fk_stock_business` FOREIGN KEY (`business_id`) REFERENCES `otg_saloon_businesses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `otg_saloon_transactions` (
  `id` bigint unsigned NOT NULL AUTO_INCREMENT,
  `business_id` int unsigned NOT NULL,
  `type` varchar(32) NOT NULL,
  `amount` decimal(12,2) NOT NULL DEFAULT 0.00,
  `description` varchar(255) NOT NULL,
  `citizenid` varchar(64) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  KEY `idx_tx_business` (`business_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- OTG Saloon V2 additive recipe/menu fields.
ALTER TABLE `otg_saloon_recipes`
  ADD COLUMN IF NOT EXISTS `price` decimal(12,2) NOT NULL DEFAULT 0.00,
  ADD COLUMN IF NOT EXISTS `image_url` varchar(1024) DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `category` varchar(64) NOT NULL DEFAULT 'General',
  ADD COLUMN IF NOT EXISTS `effects` longtext DEFAULT NULL,
  ADD COLUMN IF NOT EXISTS `consumption` longtext DEFAULT NULL;


CREATE TABLE IF NOT EXISTS `otg_saloon_permissions` (
  `business_id` int unsigned NOT NULL,
  `citizenid` varchar(64) NOT NULL,
  `permission` varchar(64) NOT NULL,
  `granted_by` varchar(64) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`business_id`,`citizenid`,`permission`),
  CONSTRAINT `fk_otg_permission_business` FOREIGN KEY (`business_id`) REFERENCES `otg_saloon_businesses` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- V2.4.1 existing-install migration:
-- RDR3/RedM blip hashes may be represented as signed 32-bit integers.
-- Run once on databases created with an UNSIGNED blip_sprite column:
-- ALTER TABLE `otg_saloon_businesses` MODIFY COLUMN `blip_sprite` INT NULL;

-- V2.5 legacy default blip repair (server also performs this targeted migration):
UPDATE `otg_saloon_businesses` SET `blip_sprite` = 1879260108 WHERE `blip_sprite` = -1861245094;
