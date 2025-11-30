/*
  Warnings:

  - A unique constraint covering the columns `[studentId,term]` on the table `ClassEnrollment` will be added. If there are existing duplicate values, this will fail.
  - A unique constraint covering the columns `[studentId,moodDate]` on the table `MoodEntry` will be added. If there are existing duplicate values, this will fail.

*/
-- AlterTable
ALTER TABLE `ClassEnrollment` ADD COLUMN `term` VARCHAR(20) NOT NULL DEFAULT '2024Q1';

-- AlterTable
ALTER TABLE `Justificante` ADD COLUMN `term` VARCHAR(20) NOT NULL DEFAULT '2024Q1',
    ADD COLUMN `type` VARCHAR(50) NOT NULL DEFAULT 'otro',
    MODIFY `reason` VARCHAR(191) NOT NULL,
    ALTER COLUMN `updatedAt` DROP DEFAULT;

-- AlterTable
ALTER TABLE `MoodEntry` ADD COLUMN `moodDate` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    MODIFY `comment` VARCHAR(191) NULL;

-- AlterTable
ALTER TABLE `PasswordReset` MODIFY `expiresAt` DATETIME(3) NOT NULL;

-- AlterTable
ALTER TABLE `User` ALTER COLUMN `updatedAt` DROP DEFAULT;

-- CreateTable
CREATE TABLE `Subject` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(190) NOT NULL,

    UNIQUE INDEX `Subject_name_key`(`name`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `WeeklyPerception` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `studentId` INTEGER NOT NULL,
    `classId` INTEGER NOT NULL,
    `subjectId` INTEGER NOT NULL,
    `week` INTEGER NOT NULL,
    `level` VARCHAR(50) NOT NULL,
    `note` VARCHAR(191) NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Message` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `classId` INTEGER NULL,
    `toStudentId` INTEGER NULL,
    `fromTutorId` INTEGER NOT NULL,
    `title` VARCHAR(190) NOT NULL,
    `body` VARCHAR(191) NOT NULL,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `Alert` (
    `id` INTEGER NOT NULL AUTO_INCREMENT,
    `studentId` INTEGER NOT NULL,
    `classId` INTEGER NULL,
    `type` ENUM('low_mood', 'absences', 'low_average', 'custom') NOT NULL,
    `description` VARCHAR(191) NOT NULL,
    `severity` ENUM('low', 'medium', 'high') NOT NULL DEFAULT 'low',
    `resolved` BOOLEAN NOT NULL DEFAULT false,
    `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE UNIQUE INDEX `ClassEnrollment_studentId_term_key` ON `ClassEnrollment`(`studentId`, `term`);

-- CreateIndex
CREATE UNIQUE INDEX `MoodEntry_studentId_moodDate_key` ON `MoodEntry`(`studentId`, `moodDate`);

-- AddForeignKey
ALTER TABLE `WeeklyPerception` ADD CONSTRAINT `WeeklyPerception_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `WeeklyPerception` ADD CONSTRAINT `WeeklyPerception_classId_fkey` FOREIGN KEY (`classId`) REFERENCES `Class`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `WeeklyPerception` ADD CONSTRAINT `WeeklyPerception_subjectId_fkey` FOREIGN KEY (`subjectId`) REFERENCES `Subject`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Message` ADD CONSTRAINT `Message_classId_fkey` FOREIGN KEY (`classId`) REFERENCES `Class`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Message` ADD CONSTRAINT `Message_toStudentId_fkey` FOREIGN KEY (`toStudentId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Message` ADD CONSTRAINT `Message_fromTutorId_fkey` FOREIGN KEY (`fromTutorId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Alert` ADD CONSTRAINT `Alert_studentId_fkey` FOREIGN KEY (`studentId`) REFERENCES `User`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `Alert` ADD CONSTRAINT `Alert_classId_fkey` FOREIGN KEY (`classId`) REFERENCES `Class`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
