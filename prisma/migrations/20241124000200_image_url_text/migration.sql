-- Allow large data URLs for justificantes images
ALTER TABLE `Justificante` MODIFY COLUMN `imageUrl` TEXT NOT NULL;
