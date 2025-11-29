-- Add teacherRead flag to mood entries
ALTER TABLE `MoodEntry` ADD COLUMN `teacherRead` BOOLEAN NOT NULL DEFAULT false;
