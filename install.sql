-- otg-saloons Database Tables
-- Run this SQL file to set up the database tables for the saloon system

CREATE TABLE IF NOT EXISTS `otg_saloons` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `saloon_id` VARCHAR(64) NOT NULL,
    `label` VARCHAR(255) NOT NULL,
    `owner` VARCHAR(64) DEFAULT NULL,
    `stock` LONGTEXT NOT NULL,
    `cash_balance` DECIMAL(10,2) DEFAULT 0,
    `music_track` INT DEFAULT 0,
    `music_volume` DECIMAL(3,2) DEFAULT 0.5,
    `music_enabled` TINYINT(1) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_saloon` (`saloon_id`)
);

CREATE TABLE IF NOT EXISTS `otg_saloon_employees` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `saloon_id` VARCHAR(64) NOT NULL,
    `citizenid` VARCHAR(64) NOT NULL,
    `role` VARCHAR(32) DEFAULT 'bartender',
    `wage` DECIMAL(10,2) DEFAULT 25,
    `clocked_in` TINYINT(1) DEFAULT 0,
    `clock_in_time` TIMESTAMP NULL DEFAULT NULL,
    `total_hours` DECIMAL(10,2) DEFAULT 0,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_employee` (`saloon_id`, `citizenid`)
);

CREATE TABLE IF NOT EXISTS `otg_saloon_sales` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `saloon_id` VARCHAR(64) NOT NULL,
    `item` VARCHAR(64) NOT NULL,
    `amount` INT DEFAULT 1,
    `price` DECIMAL(10,2) DEFAULT 0,
    `buyer` VARCHAR(64) DEFAULT NULL,
    `seller` VARCHAR(64) DEFAULT NULL,
    `sale_type` VARCHAR(32) DEFAULT 'counter',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS `otg_saloon_orders` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `saloon_id` VARCHAR(64) NOT NULL,
    `customer` VARCHAR(64) NOT NULL,
    `item` VARCHAR(64) NOT NULL,
    `amount` INT DEFAULT 1,
    `status` VARCHAR(32) DEFAULT 'pending',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- New table for saloon interactions (prompts) that can be edited in-game using PolyZone
CREATE TABLE IF NOT EXISTS `otg_saloon_interactions` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `saloon_id` VARCHAR(64) NOT NULL,
    `name` VARCHAR(64) NOT NULL,
    `label` VARCHAR(255) NOT NULL,
    `event` VARCHAR(255) NOT NULL,
    `args` JSON NULL,
    `color` VARCHAR(64) DEFAULT 'main',
    `zone_type` ENUM('point', 'box', 'circle', 'polygon') NOT NULL DEFAULT 'point',
    `zone_data` JSON NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_saloon_interaction` (`saloon_id`, `name`),
    FOREIGN KEY (`saloon_id`) REFERENCES `otg_saloons`(`saloon_id`) ON DELETE CASCADE
);

-- Table for storing per-saloon recipes
CREATE TABLE IF NOT EXISTS `otg_saloon_recipes` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `saloon_id` VARCHAR(64) NOT NULL,
    `recipe_name` VARCHAR(64) NOT NULL,
    `recipe_data` JSON NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY `unique_saloon_recipe` (`saloon_id`, `recipe_name`),
    FOREIGN KEY (`saloon_id`) REFERENCES `otg_saloons`(`saloon_id`) ON DELETE CASCADE
);

-- Table for tracking employee wages and clock-in/out
CREATE TABLE IF NOT EXISTS `otg_saloon_payroll` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `saloon_id` VARCHAR(64) NOT NULL,
    `citizenid` VARCHAR(64) NOT NULL,
    `amount` DECIMAL(10,2) NOT NULL,
    `hours_worked` DECIMAL(10,2) DEFAULT 0,
    `payment_type` VARCHAR(32) DEFAULT 'wage',
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (`saloon_id`) REFERENCES `otg_saloons`(`saloon_id`) ON DELETE CASCADE
);