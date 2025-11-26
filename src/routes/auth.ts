import { Router } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { randomBytes } from 'crypto';
import { Prisma } from '@prisma/client';
import { prisma } from '../prisma';

const router = Router();
const secret = process.env.JWT_SECRET || 'changeme';

router.post('/register', async (req, res) => {
  try {
    const { email, password, fullName, role } = req.body;
    if (!email || !password || !fullName || !role) {
      return res.status(400).json({ error: 'Faltan campos' });
    }
    if (!['student', 'teacher'].includes(role)) {
      return res.status(400).json({ error: 'Rol inválido' });
    }

    const existing = await prisma.user.findUnique({ where: { email } });
    if (existing) {
      return res.status(409).json({ error: 'Correo ya registrado' });
    }

    const hashed = await bcrypt.hash(password, 10);
    const user = await prisma.user.create({
      data: { email, password: hashed, fullName, role },
      select: { id: true, email: true, fullName: true, role: true },
    });
    const token = jwt.sign(
      { userId: user.id, role: user.role, email: user.email },
      secret,
      { expiresIn: '7d' },
    );
    return res.json({ user, token });
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : 'Error desconocido';
    console.error('[auth/register] Error registrando usuario', {
      email: req.body?.email,
      role: req.body?.role,
      message,
      stack: err instanceof Error ? err.stack : undefined,
    });

    if (err instanceof Prisma.PrismaClientKnownRequestError) {
      if (err.code === 'P2002') {
        return res.status(409).json({
          error: 'Correo ya registrado (conflicto unique)',
          code: err.code,
          target: err.meta?.target,
        });
      }
      if (err.code === 'P1001') {
        return res.status(503).json({
          error: 'No se pudo conectar a la base de datos (timeout)',
          detail: err.message,
        });
      }
      if (err.code === 'P1002') {
        return res.status(503).json({
          error: 'Base de datos en modo de espera o no accesible',
          detail: err.message,
        });
      }
      return res.status(400).json({
        error: 'Error al guardar en base de datos',
        code: err.code,
        meta: err.meta,
        detail: err.message,
      });
    }

    if (err instanceof Prisma.PrismaClientInitializationError) {
      return res.status(503).json({
        error: 'No se pudo inicializar Prisma (conexión/driver)',
        detail: err.message,
      });
    }

    if (err instanceof Prisma.PrismaClientValidationError) {
      return res.status(400).json({
        error: 'Datos inválidos para registrar usuario',
        detail: message,
      });
    }

    return res.status(500).json({ error: 'Error interno al registrar', detail: message });
  }
});

router.post('/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ error: 'Faltan credenciales' });
    }
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) return res.status(401).json({ error: 'Credenciales inválidas' });
    const ok = await bcrypt.compare(password, user.password);
    if (!ok) return res.status(401).json({ error: 'Credenciales inválidas' });
    const token = jwt.sign(
      { userId: user.id, role: user.role, email: user.email },
      secret,
      { expiresIn: '7d' },
    );
    return res.json({
      user: { id: user.id, email: user.email, fullName: user.fullName, role: user.role },
      token,
    });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

router.post('/forgot', async (req, res) => {
  try {
    const { email } = req.body;
    if (!email) return res.status(400).json({ error: 'Correo requerido' });
    const user = await prisma.user.findUnique({ where: { email } });
    if (!user) return res.status(200).json({ message: 'Si existe, enviamos correo (simulado)' });
    const token = randomBytes(32).toString('hex');
    const expiresAt = new Date(Date.now() + 1000 * 60 * 60); // 1h
    await prisma.passwordReset.create({
      data: { userId: user.id, token, expiresAt },
    });
    return res.status(200).json({ message: 'Token generado (simulado)', token });
  } catch (err) {
    console.error(err);
    return res.status(500).json({ error: 'Error interno' });
  }
});

export default router;
