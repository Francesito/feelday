import { Router } from 'express';
import { prisma } from '../prisma';
import { AuthenticatedRequest } from '../types';
import { requireAuth, requireRole } from '../middleware/auth';

const router = Router();

router.get('/', requireAuth, requireRole('teacher'), async (req: AuthenticatedRequest, res) => {
  try {
    const classes = await prisma.class.findMany({
      where: { teacherId: req.user!.userId },
      include: {
        enrollments: { where: { status: 'approved' } },
      },
    });
    const classIds = classes.map((c) => c.id);
    const studentCount = classes.reduce((sum, c) => sum + c.enrollments.length, 0);

    const lastWeek = new Date();
    lastWeek.setDate(lastWeek.getDate() - 7);

    const moods = await prisma.moodEntry.findMany({
      where: { classId: { in: classIds }, createdAt: { gte: lastWeek } },
    });
    const checkInRate =
      studentCount === 0 ? 0 : Math.min(1, moods.length / (studentCount * 7));

    const perceptions = await prisma.weeklyPerception.findMany({
      where: { classId: { in: classIds } },
      include: { subject: true },
    });
    const stressBySubject: Record<string, number> = {};
    perceptions.forEach((p) => {
      const key = p.subject.name;
      const level = p.level.toLowerCase();
      const weight = level.includes('estr') || level.includes('stress') ? 2 : 1;
      stressBySubject[key] = (stressBySubject[key] ?? 0) + weight;
    });
    const topStressSubjects = Object.entries(stressBySubject)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([subject, score]) => ({ subject, score }));

    const justificantes = await prisma.justificante.groupBy({
      by: ['type'],
      where: { classId: { in: classIds } },
      _count: { _all: true },
    });
    const justificanteHistogram = justificantes.map((j) => ({
      type: j.type,
      count: j._count._all,
    }));

    const lowMoodCount = moods.filter((m) => m.moodValue <= 40).length;

    return res.json({
      studentCount,
      checkInRate,
      lowMoodCount,
      topStressSubjects,
      justificanteHistogram,
    });
  } catch (err) {
    console.error('[dashboard] error', err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.get('/report', requireAuth, requireRole('teacher'), async (req: AuthenticatedRequest, res) => {
  try {
    // Simulación de exporte
    return res.json({ ok: true, message: 'Reporte generado (simulado). Descarga en construcción.' });
  } catch (err) {
    console.error('[dashboard] report error', err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

export default router;
