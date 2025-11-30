import { Router } from 'express';
import { prisma } from '../prisma';
import { AuthenticatedRequest } from '../types';
import { requireAuth, requireRole } from '../middleware/auth';

const router = Router();

router.get('/', requireAuth, async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    if (req.user.role === 'student') {
      const enrollments = await prisma.classEnrollment.findMany({
        where: { studentId: req.user.userId, status: 'approved' },
      });
      const classIds = enrollments.map((e) => e.classId);
      const messages = await prisma.message.findMany({
        where: { OR: [{ toStudentId: req.user.userId }, { classId: { in: classIds } }] },
        include: {
          class: { select: { id: true, name: true } },
          fromTutor: { select: { id: true, fullName: true, email: true } },
        },
        orderBy: { createdAt: 'desc' },
      });
      return res.json(messages);
    }
    // tutor
    const messages = await prisma.message.findMany({
      where: {
        OR: [
          { fromTutorId: req.user.userId },
          { class: { teacherId: req.user.userId } },
        ],
      },
      include: {
        class: { select: { id: true, name: true } },
        toStudent: { select: { id: true, fullName: true, email: true } },
      },
      orderBy: { createdAt: 'desc' },
    });
    return res.json(messages);
  } catch (err) {
    console.error('[messages] list error', err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.post('/', requireAuth, requireRole('teacher'), async (req: AuthenticatedRequest, res) => {
  try {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    const { classId, toStudentId, title, body } = req.body;
    if (!title || !body) {
      return res.status(400).json({ error: 'Título y cuerpo son requeridos' });
    }
    if (!classId && !toStudentId) {
      return res.status(400).json({ error: 'Debes enviar a un alumno o a un grupo' });
    }
    if (classId) {
      const cls = await prisma.class.findUnique({ where: { id: Number(classId) } });
      if (!cls || cls.teacherId !== req.user.userId) {
        return res.status(403).json({ error: 'No tienes permiso en esta clase' });
      }
    }
    if (toStudentId) {
      const enrollment = await prisma.classEnrollment.findFirst({
        where: {
          studentId: Number(toStudentId),
          class: { teacherId: req.user.userId },
          status: 'approved',
        },
      });
      if (!enrollment) {
        return res.status(403).json({ error: 'El alumno no pertenece a tus grupos' });
      }
    }
    const created = await prisma.message.create({
      data: {
        classId: classId ? Number(classId) : null,
        toStudentId: toStudentId ? Number(toStudentId) : null,
        fromTutorId: req.user.userId,
        title: title.toString(),
        body: body.toString(),
      },
    });
    return res.status(201).json(created);
  } catch (err) {
    console.error('[messages] create error', err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

export default router;
