-- Create database objects for feelday

CREATE TABLE `User` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `email` VARCHAR(190) NOT NULL,
  `password` VARCHAR(255) NOT NULL,
  `fullName` VARCHAR(190) NOT NULL,
  `role` ENUM('student','teacher') NOT NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `User_email_key`(`email`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `Class` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `teacherId` INT NOT NULL,
  `name` VARCHAR(190) NOT NULL,
  `code` CHAR(8) NOT NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `Class_code_key`(`code`),
  INDEX `Class_teacherId_idx`(`teacherId`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `ClassEnrollment` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `classId` INT NOT NULL,
  `studentId` INT NOT NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `ClassEnrollment_classId_studentId_key`(`classId`, `studentId`),
  INDEX `ClassEnrollment_classId_idx`(`classId`),
  INDEX `ClassEnrollment_studentId_idx`(`studentId`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `Schedule` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `classId` INT NOT NULL,
  `studentId` INT NOT NULL,
  `fileName` VARCHAR(255) NOT NULL,
  `fileUrl` VARCHAR(500) NOT NULL,
  `uploadedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `Schedule_classId_studentId_key`(`classId`, `studentId`),
  INDEX `Schedule_classId_idx`(`classId`),
  INDEX `Schedule_studentId_idx`(`studentId`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `MoodEntry` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `classId` INT NOT NULL,
  `studentId` INT NOT NULL,
  `dayLabel` VARCHAR(40) NOT NULL,
  `moodValue` INT NOT NULL,
  `comment` TEXT NULL,
  `scheduleFileName` VARCHAR(255) NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX `MoodEntry_classId_idx`(`classId`),
  INDEX `MoodEntry_studentId_idx`(`studentId`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `Justificante` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `classId` INT NOT NULL,
  `studentId` INT NOT NULL,
  `imageName` VARCHAR(255) NOT NULL,
  `imageUrl` VARCHAR(500) NOT NULL,
  `reason` TEXT NOT NULL,
  `status` ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updatedAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3) ON UPDATE CURRENT_TIMESTAMP(3),
  INDEX `Justificante_classId_idx`(`classId`),
  INDEX `Justificante_studentId_idx`(`studentId`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `PasswordReset` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `userId` INT NOT NULL,
  `token` CHAR(64) NOT NULL,
  `expiresAt` DATETIME NOT NULL,
  `used` BOOLEAN NOT NULL DEFAULT false,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `PasswordReset_token_key`(`token`),
  INDEX `PasswordReset_userId_idx`(`userId`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `Class` ADD CONSTRAINT `Class_teacherId_fkey` FOREIGN KEY (`teacherId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `ClassEnrollment` ADD CONSTRAINT `ClassEnrollment_classId_fkey` FOREIGN KEY (`classId`) REFERENCES `Class`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `ClassEnrollment` ADD CONSTRAINT `ClassEnrollment_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `Schedule` ADD CONSTRAINT `Schedule_classId_fkey` FOREIGN KEY (`classId`) REFERENCES `Class`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `Schedule` ADD CONSTRAINT `Schedule_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `MoodEntry` ADD CONSTRAINT `MoodEntry_classId_fkey` FOREIGN KEY (`classId`) REFERENCES `Class`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `MoodEntry` ADD CONSTRAINT `MoodEntry_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `Justificante` ADD CONSTRAINT `Justificante_classId_fkey` FOREIGN KEY (`classId`) REFERENCES `Class`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `Justificante` ADD CONSTRAINT `Justificante_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE `PasswordReset` ADD CONSTRAINT `PasswordReset_userId_fkey` FOREIGN KEY (`userId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
