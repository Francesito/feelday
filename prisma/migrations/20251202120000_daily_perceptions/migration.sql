-- Migración para pasar de percepciones semanales a diarias.

DROP TABLE IF EXISTS `DailyPerception`;

CREATE TABLE `DailyPerception` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `studentId` INT NOT NULL,
    `classId` INT NOT NULL,
    `subjectId` INT NOT NULL,
    `perceptionDate` DATETIME(3) NOT NULL,
    `level` VARCHAR(50) NOT NULL,
    `note` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    UNIQUE INDEX `DailyPerception_studentId_classId_perceptionDate_key`(`studentId`, `classId`, `perceptionDate`),
    INDEX `DailyPerception_perceptionDate_idx`(`perceptionDate`),
    INDEX `DailyPerception_studentId_idx`(`studentId`),
    INDEX `DailyPerception_classId_idx`(`classId`),
    INDEX `DailyPerception_subjectId_idx`(`subjectId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Migra datos previos usando la fecha de creación como día de percepción.
INSERT INTO `DailyPerception` (`studentId`, `classId`, `subjectId`, `perceptionDate`, `level`, `note`, `createdAt`)
SELECT
  `studentId`,
  `classId`,
  `subjectId`,
  DATE(IFNULL(`createdAt`, NOW())) AS `perceptionDate`,
  ANY_VALUE(`level`) AS `level`,
  ANY_VALUE(`note`) AS `note`,
  MIN(`createdAt`) AS `createdAt`
FROM `WeeklyPerception`
GROUP BY `studentId`, `classId`, `subjectId`, DATE(IFNULL(`createdAt`, NOW()));

-- Limpia tabla obsoleta.
DROP TABLE IF EXISTS `WeeklyPerception`;

-- Llaves foráneas
ALTER TABLE `DailyPerception` ADD CONSTRAINT `DailyPerception_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `DailyPerception` ADD CONSTRAINT `DailyPerception_classId_fkey` FOREIGN KEY (`classId`) REFERENCES `Class`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `DailyPerception` ADD CONSTRAINT `DailyPerception_subjectId_fkey` FOREIGN KEY (`subjectId`) REFERENCES `Subject`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
