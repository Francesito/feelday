-- Permitir múltiples inscripciones por alumno en el mismo cuatrimestre
-- Si el índice no existe (bases viejas o ya modificado), el bloque es no-op.
SET @idx := (
  SELECT INDEX_NAME
  FROM INFORMATION_SCHEMA.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'ClassEnrollment'
    AND INDEX_NAME = 'ClassEnrollment_studentId_term_key'
  LIMIT 1
);

SET @stmt := IF(
  @idx IS NOT NULL,
  'ALTER TABLE `ClassEnrollment` DROP INDEX `ClassEnrollment_studentId_term_key`',
  'SELECT 1'
);

PREPARE drop_stmt FROM @stmt;
EXECUTE drop_stmt;
DEALLOCATE PREPARE drop_stmt;
