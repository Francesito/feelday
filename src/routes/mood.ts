import { Router } from 'express';
import { prisma } from '../prisma';
import { AuthenticatedRequest } from '../types';
import { requireAuth, requireRole } from '../middleware/auth';

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
    const todayStart = new Date();
    todayStart.setHours(0, 0, 0, 0);
    const todayEnd = new Date(todayStart);
    todayEnd.setDate(todayEnd.getDate() + 1);
    // Ensure student is enrolled
    const enrollment = await prisma.classEnrollment.findFirst({
      where: { classId: Number(classId), studentId: req.user.userId },
    });
    if (!enrollment || enrollment.status !== 'approved') {
      return res
        .status(403)
        .json({ error: 'No estás inscrito en esta clase o falta aprobación del profesor' });
    }
    // Enforce 1 check-in diario
    const existingToday = await prisma.moodEntry.findFirst({
      where: {
        classId: Number(classId),
        studentId: req.user.userId,
        moodDate: { gte: todayStart, lt: todayEnd },
      },
    });
    if (existingToday) {
      return res.status(400).json({ error: 'Ya registraste tu estado de ánimo hoy en esta clase.' });
    }
    const created = await prisma.moodEntry.create({
      data: {
        classId: Number(classId),
        studentId: req.user.userId,
        moodDate: new Date(),
        moodValue: Number(moodValue),
        comment,
        dayLabel,
        scheduleFileName,
      },
    });
    // Generar alerta por ánimo bajo
    if (Number(moodValue) <= 40) {
      await prisma.alert.create({
        data: {
          studentId: req.user.userId,
          classId: Number(classId),
          type: 'low_mood',
          description: `Ánimo bajo (${moodValue}) reportado`,
          severity: Number(moodValue) <= 20 ? 'high' : 'medium',
        },
      });
    }
    return res.status(201).json(created);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.patch('/:id/read', requireAuth, requireRole('teacher'), async (req: AuthenticatedRequest, res) => {
  try {
    const id = Number(req.params.id);
    const entry = await prisma.moodEntry.findUnique({
      where: { id },
      include: { class: true },
    });
    if (!entry) return res.status(404).json({ error: 'No encontrado' });
    if (entry.class.teacherId !== req.user!.userId) {
      return res.status(403).json({ error: 'No tienes permiso para esta clase' });
    }
    const updated = await prisma.moodEntry.update({
      where: { id },
      data: { teacherRead: true },
    });
    return res.json(updated);
  } catch (err) {
    console.error('[mood] Error marcando como leído', err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

export default router;
