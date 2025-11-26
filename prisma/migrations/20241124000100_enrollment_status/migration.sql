-- Add status to ClassEnrollment for approval flow
ALTER TABLE `ClassEnrollment`
  ADD COLUMN `status` ENUM('pending','approved','rejected') NOT NULL DEFAULT 'pending';
