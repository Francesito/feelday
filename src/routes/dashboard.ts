import { Router } from 'express';
import { prisma } from '../prisma';
import { AuthenticatedRequest } from '../types';
import { requireAuth, requireRole } from '../middleware/auth';

const router = Router();

function isoWeekKey(date: Date): string {
  const target = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()));
  const dayNr = target.getUTCDay() || 7;
  target.setUTCDate(target.getUTCDate() + 4 - dayNr);
  const yearStart = new Date(Date.UTC(target.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((target.getTime() - yearStart.getTime()) / 86400000 + 1) / 7);
  return `${target.getUTCFullYear()}-W${String(weekNo).padStart(2, '0')}`;
}

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

    const perceptions = await prisma.dailyPerception.findMany({
      where: { classId: { in: classIds } },
      include: { subject: true },
    });
    const stressBySubject: Record<string, number> = {};
    const weeklyPerceptionBuckets: Record<string, { total: number; stress: number }> = {};
    perceptions.forEach((p) => {
      const key = p.subject.name;
      const level = p.level.toLowerCase();
      const weight = level.includes('estr') || level.includes('stress') ? 2 : 1;
      stressBySubject[key] = (stressBySubject[key] ?? 0) + weight;

      const weekKey = isoWeekKey(new Date(p.perceptionDate));
      const bucket = weeklyPerceptionBuckets[weekKey] ?? { total: 0, stress: 0 };
      bucket.total += 1;
      if (weight > 1) bucket.stress += 1;
      weeklyPerceptionBuckets[weekKey] = bucket;
    });
    const topStressSubjects = Object.entries(stressBySubject)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 3)
      .map(([subject, score]) => ({ subject, score }));

    const weeklyPerceptionSummary = Object.entries(weeklyPerceptionBuckets)
      .map(([week, stats]) => ({ week, total: stats.total, stress: stats.stress }))
      .sort((a, b) => (a.week > b.week ? -1 : 1));

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
      weeklyPerceptionSummary,
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
