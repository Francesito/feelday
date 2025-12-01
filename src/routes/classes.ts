import { Router } from 'express';
import { prisma } from '../prisma';
import { AuthenticatedRequest } from '../types';
import { requireAuth, requireRole } from '../middleware/auth';

const router = Router();

router.get('/', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const classes =
      req.user.role === 'teacher'
        ? await prisma.class.findMany({
            where: { teacherId: req.user.userId },
            include: {
              teacher: { select: { id: true, email: true, fullName: true } },
              enrollments: {
                include: { student: { select: { id: true, email: true, fullName: true } } },
              },
            },
          })
        : await prisma.class.findMany({
            include: {
              teacher: { select: { id: true, email: true, fullName: true } },
              enrollments: {
                where: { studentId: req.user.userId },
                include: { student: { select: { id: true, email: true, fullName: true } } },
              },
            },
          });
    return res.json(classes);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.post('/', requireAuth, requireRole('teacher'), async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const { name } = req.body;
    if (!name) return res.status(400).json({ error: 'Nombre requerido' });
    const code = generateCode();
    const cls = await prisma.class.create({
      data: { name, code, teacherId: req.user.userId },
    });
    return res.status(201).json(cls);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.post('/join', requireAuth, requireRole('student'), async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const { code } = req.body;
    if (!code) return res.status(400).json({ error: 'Código requerido' });
    const cls = await prisma.class.findUnique({ where: { code } });
    if (!cls) return res.status(404).json({ error: 'Clase no encontrada' });
    const term = currentTerm();
    const enrollment = await prisma.classEnrollment.upsert({
      where: { classId_studentId: { classId: cls.id, studentId: req.user.userId } },
      update: { status: 'pending', term },
      create: { classId: cls.id, studentId: req.user.userId, status: 'pending', term },
    });
    return res.json({ class: cls, enrollment, message: 'Solicitud enviada, pendiente de aprobación' });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.get('/:id/members', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const id = Number(req.params.id);
    const cls = await prisma.class.findUnique({ where: { id }, select: { teacherId: true } });
    if (!cls) return res.status(404).json({ error: 'Clase no encontrada' });
    if (req.user.role !== 'teacher' || cls.teacherId !== req.user.userId) {
      return res.status(403).json({ error: 'Solo el profesor de la clase puede ver los alumnos' });
    }
    const members = await prisma.classEnrollment.findMany({
      where: { classId: id },
      include: { student: { select: { id: true, email: true, fullName: true } } },
      orderBy: [{ createdAt: 'asc' }, { student: { fullName: 'asc' } }],
    });
    return res.json(members);
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.patch(
  '/enrollments/:id',
  requireAuth,
  requireRole('teacher'),
  async (req: AuthenticatedRequest, res) => {
    try {
      if (!req.user) return res.status(401).json({ error: 'No autorizado' });
      const id = Number(req.params.id);
      const { status } = req.body;
      if (!['approved', 'rejected', 'pending'].includes(status)) {
        return res.status(400).json({ error: 'Estado inválido' });
      }
      const enrollment = await prisma.classEnrollment.findUnique({
        where: { id },
        include: { class: true, student: true },
      });
      if (!enrollment) return res.status(404).json({ error: 'No encontrado' });
      if (enrollment.class.teacherId !== req.user.userId) {
        return res.status(403).json({ error: 'No tienes permisos en esta clase' });
      }
      const updated = await prisma.classEnrollment.update({
        where: { id },
        data: { status },
        include: { student: true },
      });
      return res.json(updated);
    } catch (err) {
      console.error('[classes] Error actualizando enrollment', err);
      return res.status(500).json({
        error: 'Error interno al aprobar/rechazar',
        detail: err instanceof Error ? err.message : String(err),
      });
    }
  },
);

function generateCode() {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let result = '';
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

function currentTerm() {
  const now = new Date();
  const quarter = Math.floor(now.getMonth() / 3) + 1;
  return `${now.getFullYear()}Q${quarter}`;
}

export default router;
