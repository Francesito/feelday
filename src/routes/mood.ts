import { Router } from 'express';
import { prisma } from '../prisma';
import { AuthenticatedRequest } from '../types';
import { requireAuth } from '../middleware/auth';

const router = Router();

router.get('/', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const entries =
      req.user.role === 'teacher'
        ? await prisma.moodEntry.findMany({
            where: { class: { teacherId: req.user.userId } },
            include: {
              class: { select: { id: true, name: true } },
              student: { select: { id: true, email: true, fullName: true } },
            },
            orderBy: { createdAt: 'desc' },
          })
        : await prisma.moodEntry.findMany({
            where: { studentId: req.user.userId },
            include: {
              class: { select: { id: true, name: true } },
              student: { select: { id: true, email: true, fullName: true } },
            },
            orderBy: { createdAt: 'desc' },
          });
    return res.json(entries);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.post('/', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const { classId, moodValue, comment, dayLabel, scheduleFileName } = req.body;
    if (!classId || moodValue === undefined || !dayLabel) {
      return res.status(400).json({ error: 'Faltan campos' });
    }
    // Ensure student is enrolled
    const enrollment = await prisma.classEnrollment.findFirst({
      where: { classId: Number(classId), studentId: req.user.userId },
    });
    if (!enrollment || enrollment.status !== 'approved') {
      return res
        .status(403)
        .json({ error: 'No estás inscrito en esta clase o falta aprobación del profesor' });
    }
    const created = await prisma.moodEntry.create({
      data: {
        classId: Number(classId),
        studentId: req.user.userId,
        moodValue: Number(moodValue),
        comment,
        dayLabel,
        scheduleFileName,
      },
    });
    return res.status(201).json(created);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

export default router;
