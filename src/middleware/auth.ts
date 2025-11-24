import { NextFunction, Response } from 'express';
import jwt from 'jsonwebtoken';
import { AuthenticatedRequest, JwtPayload } from '../types';

const secret = process.env.JWT_SECRET || 'changeme';

export function requireAuth(req: AuthenticatedRequest, res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'No autorizado' });
  }
  const token = header.slice(7);
  try {
    const payload = jwt.verify(token, secret) as JwtPayload;
    req.user = payload;
    return next();
  } catch {
    return res.status(401).json({ error: 'Token inválido' });
  }
}

export function requireRole(role: JwtPayload['role']) {
  return (req: AuthenticatedRequest, res: Response, next: NextFunction) => {
    if (!req.user) return res.status(401).json({ error: 'No autorizado' });
    if (req.user.role !== role) {
      return res.status(403).json({ error: 'Permiso denegado' });
    }
    return next();
  };
}
