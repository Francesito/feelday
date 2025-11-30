import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import dotenv from 'dotenv';
import authRoutes from './routes/auth';
import classRoutes from './routes/classes';
import moodRoutes from './routes/mood';
import scheduleRoutes from './routes/schedules';
import justificantesRoutes from './routes/justificantes';
import perceptionRoutes from './routes/perceptions';
import messageRoutes from './routes/messages';
import alertRoutes from './routes/alerts';
import dashboardRoutes from './routes/dashboard';

dotenv.config();

const app = express();
app.use(helmet());
app.use(cors());
app.use(express.json({ limit: '5mb' }));

app.get('/health', (_req, res) => res.json({ ok: true }));

app.use('/auth', authRoutes);
app.use('/classes', classRoutes);
app.use('/mood', moodRoutes);
app.use('/schedules', scheduleRoutes);
app.use('/justificantes', justificantesRoutes);
app.use('/perceptions', perceptionRoutes);
app.use('/messages', messageRoutes);
app.use('/alerts', alertRoutes);
app.use('/dashboard', dashboardRoutes);

const port = process.env.PORT || 3000;
app.listen(port, () => {
  console.log(`feelday backend escuchando en puerto ${port}`);
  if (process.env.NODE_ENV === 'production') {
    console.log('Ambiente: produccion (Render)');
  } else {
    console.log(`Ambiente: ${process.env.NODE_ENV || 'desarrollo'}`);
  }
});
