import { Request } from 'express';

export interface JwtPayload {
  userId: number;
  role: 'student' | 'teacher';
  email: string;
}

export interface AuthenticatedRequest extends Request {
  user?: JwtPayload;
}
