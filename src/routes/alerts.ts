import { Router } from 'express';
import { prisma } from '../prisma';
import { AuthenticatedRequest } from '../types';
import { requireAuth, requireRole } from '../middleware/auth';

const router = Router();

router.get('/', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const alerts =
      req.user.role === 'teacher'
        ? await prisma.alert.findMany({
            where: { class: { teacherId: req.user.userId } },
            include: {
              student: { select: { id: true, fullName: true, email: true } },
              class: { select: { id: true, name: true } },
            },
            orderBy: { createdAt: 'desc' },
          })
        : await prisma.alert.findMany({
            where: { studentId: req.user.userId },
            include: {
              class: { select: { id: true, name: true } },
            },
            orderBy: { createdAt: 'desc' },
          });
    return res.json(alerts);
  } catch (err) {
    console.error('[alerts] list error', err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.patch('/:id/resolve', requireAuth, requireRole('teacher'), async (req: AuthenticatedRequest, res) => {
  try {
    const id = Number(req.params.id);
    const alert = await prisma.alert.findUnique({
      where: { id },
      include: { class: true, student: true },
    });
    if (!alert) return res.status(404).json({ error: 'No encontrado' });
    if (alert.class && alert.class.teacherId !== req.user!.userId) {
      return res.status(403).json({ error: 'No tienes permiso' });
    }
    const updated = await prisma.alert.update({
      where: { id },
      data: { resolved: true },
    });
    return res.json(updated);
  } catch (err) {
    console.error('[alerts] resolve error', err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

export default router;
