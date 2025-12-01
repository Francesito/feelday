import { Router } from 'express';
import { prisma } from '../prisma';
import { AuthenticatedRequest } from '../types';
import { requireAuth, requireRole } from '../middleware/auth';

const router = Router();

router.get('/', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const perceptions =
      req.user.role === 'teacher'
        ? await prisma.weeklyPerception.findMany({
            where: { class: { teacherId: req.user.userId } },
            include: {
              class: { select: { id: true, name: true } },
              student: { select: { id: true, email: true, fullName: true } },
              subject: true,
            },
            orderBy: { createdAt: 'desc' },
          })
        : await prisma.weeklyPerception.findMany({
            where: { studentId: req.user.userId },
            include: {
              class: { select: { id: true, name: true } },
              student: { select: { id: true, email: true, fullName: true } },
              subject: true,
            },
            orderBy: { createdAt: 'desc' },
          });
    return res.json(perceptions);
  } catch (err) {
    console.error('[perceptions] list error', err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.post('/', requireAuth, requireRole('student'), async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const { classId, week, level, note } = req.body;
    if (!classId || week === undefined || !level) {
      return res.status(400).json({ error: 'Faltan campos (classId, semana, nivel)' });
    }
    const enrollment = await prisma.classEnrollment.findFirst({
      where: { classId: Number(classId), studentId: req.user.userId, status: 'approved' },
    });
    if (!enrollment) {
      return res.status(403).json({ error: 'No estás aprobado en esta clase' });
    }
    const cls = await prisma.class.findUnique({ where: { id: Number(classId) } });
    if (!cls) return res.status(404).json({ error: 'Clase no encontrada' });
    // Usa la propia clase como materia; crea si no existe.
    const subject = await prisma.subject.upsert({
      where: { name: cls.name },
      update: {},
      create: { name: cls.name },
    });
    const existing = await prisma.weeklyPerception.findFirst({
      where: {
        studentId: req.user.userId,
        classId: Number(classId),
        week: Number(week),
      },
    });
    if (existing) {
      return res.status(400).json({ error: 'Ya registraste percepción para esta materia y semana.' });
    }
    const created = await prisma.weeklyPerception.create({
      data: {
        studentId: req.user.userId,
        classId: Number(classId),
        subjectId: subject.id,
        week: Number(week),
        level: level.toString(),
        note,
      },
    });
    // Alerta si nivel sugiere estrés
    const levelLower = level.toString().toLowerCase();
    if (levelLower.includes('estr') || levelLower.includes('stress')) {
      await prisma.alert.create({
        data: {
          studentId: req.user.userId,
          classId: Number(classId),
          type: 'low_mood',
          description: `Percepción alta de estrés en semana ${week}`,
          severity: 'medium',
        },
      });
    }
    return res.status(201).json(created);
  } catch (err) {
    console.error('[perceptions] create error', err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.get('/subjects', requireAuth, async (_req, res) => {
  try {
    const subjects = await prisma.subject.findMany();
    return res.json(subjects);
  } catch (err) {
    console.error('[perceptions] subjects error', err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

export default router;
