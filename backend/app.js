const express = require('express');
const path = require('path');
const https = require('https');
const http = require('http');
const fs = require('fs');
const { initDB } = require('./utils/db');
const config = require('./config');

const app = express();
app.use(express.json());

// CORS
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  res.header('Access-Control-Allow-Methods', 'GET,POST,PUT,DELETE,OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});

// 静态文件
app.use(express.static(path.join(__dirname, 'public')));

// API路由（数据库初始化后再加载）
let serverReady = false;

async function start() {
  await initDB();
  console.log('数据库已初始化');

  const authRoutes = require('./routes/auth');
  const vehicleRoutes = require('./routes/vehicles');
  const repairRoutes = require('./routes/repair');
  const inspectionRoutes = require('./routes/inspection');
  const notificationRoutes = require('./routes/notifications');
  const adminRoutes = require('./routes/admin');
  const externalRoutes = require('./routes/external');

  app.use('/api/auth', authRoutes);
  app.use('/api/vehicles', vehicleRoutes);
  app.use('/api/repair', repairRoutes);
  app.use('/api/inspection', inspectionRoutes);
  app.use('/api/notifications', notificationRoutes);
  app.use('/api/admin', adminRoutes);
  app.use('/api/external', externalRoutes);
  app.use('/api/quiz', require('./routes/quiz'));
  app.use('/api/upload', require('./routes/upload'));
  app.use('/api/safety', require('./routes/safety'));
  app.use('/api/hazards', require('./routes/hazards'));

  // SPA fallback
  app.get('*', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
  });

  app.use((err, req, res, next) => {
    console.error(err);
    res.status(500).json({ code: 500, msg: '服务器内部错误' });
  });

  const port = config.port || 3000;

  // HTTP
  http.createServer(app).listen(port, () => {
    console.log('');
    console.log('========================================');
    console.log('  总调度室综合管理系统 已启动');
    console.log(`  HTTP:  http://localhost:${port}`);
    console.log(`  手机:  http://192.168.1.5:${port}`);
    console.log('========================================');
    console.log('');
  });

  // HTTPS (自签证书，浏览器会有安全提示，正式部署替换为真实证书)
  const sslPath = path.join(__dirname, 'ssl');
  try {
    const sslOptions = {
      key: fs.readFileSync(path.join(sslPath, 'key.pem')),
      cert: fs.readFileSync(path.join(sslPath, 'cert.pem'))
    };
    https.createServer(sslOptions, app).listen(443, () => {
      console.log(`  HTTPS: https://localhost`);
      console.log('  (自签证书，浏览器提示不安全属正常，正式部署替换真实证书)');
    });
  } catch (e) {
    console.log('  HTTPS未启用：SSL证书文件不存在，部署到服务器后配置');
  }
}

start().catch(err => { console.error('启动失败:', err); process.exit(1); });
