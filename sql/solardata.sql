CREATE TABLE `solardata` (
	`id` INT(11) NOT NULL AUTO_INCREMENT,
	`dt_created` DATETIME NULL DEFAULT current_timestamp(),
	`processdata` LONGTEXT NULL DEFAULT NULL COLLATE 'utf8mb4_bin',
	PRIMARY KEY (`id`) USING BTREE,
	INDEX `dt_created` (`dt_created`) USING BTREE,
	CONSTRAINT `processdata` CHECK (json_valid(`processdata`))
)
COLLATE='utf8mb4_general_ci'
ENGINE=InnoDB
;
