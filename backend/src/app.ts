import express from 'express';
import path from 'path';
import pinoHttp from 'pino-http';
import logger from './utils/logger';
import { errorHandler } from './middleware/error-handler';

// 路由模块
import authRoutes from './routes/auth.routes';
import vehicleRoutes from './routes/vehicle.routes';
import repairRoutes from './routes/repair.routes';
import inspectionRoutes from './routes/inspection.routes';
import notificationRoutes from './routes/notification.routes';
import adminRoutes from './routes/admin.routes';
import quizRoutes from './routes/quiz.routes';
import uploadRoutes from './routes/upload.routes';
import safetyRoutes from './routes/safety.routes';
import hazardsRoutes from './routes/hazards.routes';
import ledgerRoutes from './routes/ledger.routes';
import machineryRoutes from './routes/machinery.routes';
import weatherRoutes from './routes/weather.routes';
import externalRepairRoutes from './routes/external-repair.routes';
import vehicleArchiveRoutes from './routes/vehicle-archive.routes';
import maintenanceRoutes from './routes/maintenance.routes';
import photosRoutes from './routes/photos.routes';
import versionRoutes from './routes/version.routes';

const app = express();
app.use(express.json({ limit: '10mb' }));

// 请求日志
app.use(pinoHttp({ logger }));

// CORS
app.use((_req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  if (_req.method === 'OPTIONS') { res.sendStatus(200); return; }
  next();
});

// 上传文件静态服务
app.use('/uploads', express.static(path.join(__dirname, '../uploads')));

// 路由
app.use('/api/auth', authRoutes);
app.use('/api/vehicles', vehicleRoutes);
app.use('/api/repair', repairRoutes);
app.use('/api/inspection', inspectionRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/quiz', quizRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api/safety', safetyRoutes);
app.use('/api/hazards', hazardsRoutes);
app.use('/api/ledger', ledgerRoutes);
app.use('/api/machinery', machineryRoutes);
app.use('/api/weather', weatherRoutes);
app.use('/api/external-repair', externalRepairRoutes);
app.use('/api/vehicle-archives', vehicleArchiveRoutes);
app.use('/api/maintenance', maintenanceRoutes);
app.use('/api/photos', photosRoutes);
app.use('/api/app-version', versionRoutes);

// APK 下载目录
app.use('/app', express.static(path.join(__dirname, '../public/app')));

// API 404 — 未匹配的 /api/* 返回 JSON
app.use('/api', (_req, res) => {
  res.status(404).json({ code: 404, msg: `接口不存在: ${_req.method} ${_req.originalUrl}` });
});

// 根路径
app.get('/', (_req, res) => {
  res.json({ code: 200, msg: '矿山维修系统 API', version: '2.0.0' });
});

// 其余路径 404
app.use('*', (_req, res) => {
  res.status(404).json({ code: 404, msg: 'Not Found' });
});

// 统一错误处理
app.use(errorHandler);

export default app;
