import { createServer } from 'http';
import path from 'path';
import fs from 'fs';
import dayjs from 'dayjs';
import app from './app';
import { initDB, getDB } from './db';
import config from './config';
import logger from './utils/logger';

function start() {
  initDB();
  logger.info('Database initialized');

  const port = config.port;
  createServer(app).listen(port, () => {
    logger.info({ port }, 'Server started — 总调度室综合管理系统 v2 (better-sqlite3)');
  });

  // 每5分钟检查：自动结束已到时间的用车申请
  const autoCompleteMachinery = () => {
    try {
      const now = dayjs();
      const apps = getDB().prepare(
        `SELECT * FROM machinery_applications WHERE status = 'assigned' AND scheduled_end != ''`
      ).all() as Array<Record<string, unknown>>;
      for (const app of apps) {
        const endStr = String(app.scheduled_end);
        const endTime = endStr.includes('-') ? dayjs(endStr) : dayjs(dayjs().format('YYYY-MM-DD') + ' ' + endStr);
        if (!endTime.isValid() || endTime.isAfter(now)) continue;

        const startStr = String(app.scheduled_start || '');
        const startTime = startStr.includes('-') ? dayjs(startStr) : dayjs(dayjs().format('YYYY-MM-DD') + ' ' + (startStr || '08:00'));
        const diffHours = endTime.diff(startTime, 'hour', true);
        const workingHours = Math.round(Math.max(0, diffHours) * 100) / 100;
        const totalCost = Math.round(workingHours * (Number(app.hourly_rate) || 0) * 100) / 100;

        getDB().prepare(`UPDATE machinery_applications
          SET status = 'completed', actual_end_time = ?, settlement_end_time = ?,
              working_hours = ?, total_cost = ?, updated_at = datetime('now')
          WHERE id = ?`).run(endStr, endStr, workingHours, totalCost, app.id);
      }
    } catch { /* 静默 */ }
  };
  setInterval(autoCompleteMachinery, 5 * 60 * 1000);
  autoCompleteMachinery();

  // 天气预警：定时采集第三方数据 + 运行规则引擎
  const { fetchWeatherData, runWarningEngine, getSystemWeatherConfig } = require('./services/weather.service');
  let weatherPollMs = 10 * 60 * 1000;
  try {
    const wc = getSystemWeatherConfig();
    weatherPollMs = wc.pollInterval * 60 * 1000;
  } catch { /* 默认10分钟 */ }
  const runEngine = () => {
    try { runWarningEngine(); } catch (e) { logger.error({ err: e }, 'Weather rule engine error'); }
  };
  setInterval(runEngine, 5 * 60 * 1000);
  runEngine();
  const fetchWeather = () => {
    try { fetchWeatherData(); } catch (e) { logger.error({ err: e }, 'Weather data fetch error'); }
  };
  setInterval(fetchWeather, weatherPollMs);
  fetchWeather();

  // 每日自动备份，保留最近7份
  const BACKUP_DIR = path.join(__dirname, '../data/backups');
  const MAX_BACKUPS = 7;
  const autoBackup = () => {
    try {
      if (!fs.existsSync(BACKUP_DIR)) fs.mkdirSync(BACKUP_DIR, { recursive: true });
      const src = path.join(__dirname, '../data/mine_repair.db');
      if (!fs.existsSync(src)) return;
      const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
      const dst = path.join(BACKUP_DIR, `mine_repair_${ts}.db`);
      fs.copyFileSync(src, dst);
      const files = fs.readdirSync(BACKUP_DIR)
        .filter((f: string) => f.startsWith('mine_repair_') && f.endsWith('.db'))
        .sort()
        .reverse();
      for (let i = MAX_BACKUPS; i < files.length; i++) {
        fs.unlinkSync(path.join(BACKUP_DIR, files[i]));
      }
      logger.info({ file: `mine_repair_${ts}.db` }, 'Auto backup completed');
    } catch { /* 静默 */ }
  };
  autoBackup();
  setInterval(autoBackup, 24 * 60 * 60 * 1000);

  // 优雅退出
  const shutdown = () => {
    logger.info('Server shutting down...');
    try { getDB().close(); } catch { /* already closed */ }
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

start();
