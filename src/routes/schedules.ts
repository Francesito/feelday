import { Router } from 'express';
import { prisma } from '../prisma';
import { AuthenticatedRequest } from '../types';
import { requireAuth } from '../middleware/auth';

const router = Router();

router.get('/', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const schedules =
      req.user.role === 'teacher'
        ? await prisma.schedule.findMany({
            where: { class: { teacherId: req.user.userId } },
            orderBy: { uploadedAt: 'desc' },
          })
        : await prisma.schedule.findMany({
            where: { studentId: req.user.userId },
            orderBy: { uploadedAt: 'desc' },
          });
    return res.json(schedules);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.post('/', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const { classId, fileUrl, fileName } = req.body;
    if (!classId || !fileUrl || !fileName) {
      return res.status(400).json({ error: 'Faltan campos' });
    }
    const enrollment = await prisma.classEnrollment.findFirst({
      where: { classId: Number(classId), studentId: req.user.userId },
    });
    if (!enrollment) {
      return res.status(403).json({ error: 'No estás inscrito en esta clase' });
    }
    const schedule = await prisma.schedule.upsert({
      where: { classId_studentId: { classId: Number(classId), studentId: req.user.userId } },
      update: { fileUrl, fileName },
      create: { classId: Number(classId), studentId: req.user.userId, fileUrl, fileName },
    });
    return res.status(201).json(schedule);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

export default router;
