import { Router } from 'express';
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
            orderBy: { createdAt: 'desc' },
          })
        : await prisma.justificante.findMany({
            where: { studentId: req.user.userId },
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
    const { classId, reason, imageUrl, imageName } = req.body;
    if (!classId || !reason || !imageUrl || !imageName) {
      return res.status(400).json({ error: 'Faltan campos' });
    }
    const enrollment = await prisma.classEnrollment.findFirst({
      where: { classId: Number(classId), studentId: req.user.userId },
    });
    if (!enrollment) {
      return res.status(403).json({ error: 'No estás inscrito en esta clase' });
    }
    const justificante = await prisma.justificante.create({
      data: {
        classId: Number(classId),
        studentId: req.user.userId,
        reason,
        imageUrl,
        imageName,
      },
    });
    return res.status(201).json(justificante);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
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
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

export default router;
