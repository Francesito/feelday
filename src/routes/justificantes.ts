import { Router } from 'express';
import { Prisma } from '@prisma/client';
import { prisma } from '../prisma';
import { AuthenticatedRequest } from '../types';
import { requireAuth } from '../middleware/auth';

const router = Router();

router.get('/', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const items =
      req.user.role === 'teacher'
        ? await prisma.justificante.findMany({
            where: { class: { teacherId: req.user.userId } },
            include: {
              class: { select: { id: true, name: true } },
              student: { select: { id: true, email: true, fullName: true } },
            },
            orderBy: { createdAt: 'desc' },
          })
        : await prisma.justificante.findMany({
            where: { studentId: req.user.userId },
            include: {
              class: { select: { id: true, name: true } },
              student: { select: { id: true, email: true, fullName: true } },
            },
            orderBy: { createdAt: 'desc' },
          });
    return res.json(items);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.post('/', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const { classId, reason, imageUrl, imageName, type } = req.body;
    if (!classId || !reason || !imageUrl || !imageName) {
      return res.status(400).json({ error: 'Faltan campos' });
    }
    const justificanteType = (type as string | undefined)?.toLowerCase() ?? 'otro';
    const term = currentTerm();
    // Permitir data URLs de imágenes; rechazar tamaños excesivos
    if (typeof imageUrl === 'string' && imageUrl.startsWith('data:image/')) {
      if (imageUrl.length > 2_000_000) {
        return res.status(413).json({ error: 'Imagen demasiado grande (>2MB)' });
      }
    }
    const enrollment = await prisma.classEnrollment.findFirst({
      where: { classId: Number(classId), studentId: req.user.userId },
    });
    // Si la inscripción existe pero tiene status distinto a approved, bloquea; si no hay status (DB vieja), permite.
    if (!enrollment) {
      return res.status(403).json({ error: 'No estás inscrito en esta clase' });
    }
    if ('status' in enrollment && (enrollment as any).status !== 'approved') {
      return res
        .status(403)
        .json({ error: 'No estás inscrito en esta clase o falta aprobación del profesor' });
    }
    // Límite de 2 por cuatrimestre
    const countInTerm = await prisma.justificante.count({
      where: { studentId: req.user.userId, term },
    });
    if (countInTerm >= 2) {
      return res.status(400).json({ error: 'Límite de 2 justificantes por cuatrimestre alcanzado.' });
    }
    const justificante = await prisma.justificante.create({
      data: {
        classId: Number(classId),
        studentId: req.user.userId,
        type: justificanteType,
        reason,
        imageUrl: imageUrl.toString(),
        imageName: imageName.toString(),
        term,
      },
    });
    return res.status(201).json(justificante);
  } catch (err) {
    console.error('[justificantes] Error creando', err);
    if (err instanceof Prisma.PrismaClientKnownRequestError) {
      // P2021/P2022 se dan cuando la columna status no existe en DB
      if (err.code === 'P2021' || err.code === 'P2022') {
        return res.status(500).json({
          error: 'La columna status en ClassEnrollment no existe en la base. Aplica la migración de inscripciones.',
          detail: err.message,
        });
      }
    }
    return res.status(500).json({
      error: 'Error interno al crear justificante',
      detail: err instanceof Error ? err.message : String(err),
    });
  }
});

router.patch('/:id', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const id = Number(req.params.id);
    const { status } = req.body;
    if (!['approved', 'rejected', 'pending'].includes(status)) {
      return res.status(400).json({ error: 'Estado inválido' });
    }
    const justificante = await prisma.justificante.findUnique({
      where: { id },
      include: { class: true },
    });
    if (!justificante) return res.status(404).json({ error: 'No encontrado' });
    if (req.user.role !== 'teacher' || justificante.class.teacherId !== req.user.userId) {
      return res.status(403).json({ error: 'Permiso denegado' });
    }
    const updated = await prisma.justificante.update({
      where: { id },
      data: { status },
    });
    return res.json(updated);
  } catch (err) {
    console.error('[justificantes] Error actualizando', err);
    if (err instanceof Prisma.PrismaClientKnownRequestError) {
      if (err.code === 'P2021' || err.code === 'P2022') {
        return res.status(500).json({
          error: 'La columna status en ClassEnrollment no existe en la base. Aplica la migración de inscripciones.',
          detail: err.message,
        });
      }
    }
    return res.status(500).json({ error: 'Error interno', detail: err instanceof Error ? err.message : String(err) });
  }
});

function currentTerm() {
  const now = new Date();
  const quarter = Math.floor(now.getMonth() / 3) + 1;
  return `${now.getFullYear()}Q${quarter}`;
}

export default router;
