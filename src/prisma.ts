import { Prisma, PrismaClient } from '@prisma/client';

const logLevels: Prisma.LogLevel[] = ['error', 'warn'];

if (process.env.PRISMA_LOG_QUERIES === 'true') {
  logLevels.push('info', 'query');
}

export const prisma = new PrismaClient({ log: logLevels });
