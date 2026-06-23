import { Router, Request, Response } from 'express';
import { auth, requireRole } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';
import dayjs from 'dayjs';
import {
  ingestSensorData,
  resolveWarning,
  checkZoneForDispatch,
  getSystemWeatherConfig,
  WEATHER_LABELS,
  LEVEL_LABELS,
} from '../services/weather.service';
import { validate } from '../middleware/validate';
import {
  weatherZoneCreateSchema,
  weatherZoneUpdateSchema,
  weatherThresholdCreateSchema,
  weatherThresholdUpdateSchema,
  weatherDataIngestSchema,
  weatherWarningResolveSchema,
  weatherSmsSchema,
} from '../schemas/weather.schemas';

const router = Router();

// ==================== 区域管理 ====================

// 区域列表
router.get('/zones', auth, asyncHandler(async (_req: Request, res: Response) => {
  const zones = getDB().prepare('SELECT * FROM weather_zones ORDER BY id').all();
  res.json({ code: 200, data: zones });
}));

// 新增区域
router.post('/zones', auth, requireRole('admin'), validate(weatherZoneCreateSchema), asyncHandler(async (req: Request, res: Response) => {
  const { zone_name, zone_code, latitude, longitude, altitude, description } = req.body;
  const exist = getDB().prepare('SELECT id FROM weather_zones WHERE zone_code = ?').get(zone_code);
  if (exist) { res.json({ code: 400, msg: '区域编码已存在' }); return; }
  getDB().prepare(
    'INSERT INTO weather_zones (zone_name, zone_code, latitude, longitude, altitude, description) VALUES (?, ?, ?, ?, ?, ?)'
  ).run(zone_name, zone_code, latitude || 0, longitude || 0, altitude || '', description || '');
  res.json({ code: 200, msg: '新增成功' });
}));

// 编辑区域
router.put('/zones/:id', auth, requireRole('admin'), validate(weatherZoneUpdateSchema), asyncHandler(async (req: Request, res: Response) => {
  const z = getDB().prepare('SELECT * FROM weather_zones WHERE id = ?').get(req.params.id) as Record<string, unknown>;
  if (!z) { res.json({ code: 404, msg: '区域不存在' }); return; }
  const { zone_name, zone_code, latitude, longitude, altitude, description, status } = req.body;
  getDB().prepare(
    `UPDATE weather_zones SET zone_name = ?, zone_code = ?, latitude = ?, longitude = ?, altitude = ?, description = ?, status = ? WHERE id = ?`
  ).run(
    zone_name || z.zone_name,
    zone_code || z.zone_code,
    latitude ?? z.latitude ?? 0,
    longitude ?? z.longitude ?? 0,
    altitude ?? z.altitude ?? '',
    description ?? z.description ?? '',
    status ?? z.status ?? 1,
    req.params.id
  );
  res.json({ code: 200, msg: '更新成功' });
}));

// 删除区域
router.delete('/zones/:id', auth, requireRole('admin'), asyncHandler(async (req: Request, res: Response) => {
  const z = getDB().prepare('SELECT * FROM weather_zones WHERE id = ?').get(req.params.id);
  if (!z) { res.json({ code: 404, msg: '区域不存在' }); return; }
  getDB().prepare('DELETE FROM weather_data WHERE zone_id = ?').run(req.params.id);
  getDB().prepare('DELETE FROM weather_thresholds WHERE zone_id = ?').run(req.params.id);
  getDB().prepare('DELETE FROM weather_warnings WHERE zone_id = ?').run(req.params.id);
  getDB().prepare('DELETE FROM weather_zones WHERE id = ?').run(req.params.id);
  res.json({ code: 200, msg: '已删除' });
}));

// ==================== 阈值管理 ====================

// 阈值列表
router.get('/thresholds', auth, asyncHandler(async (req: Request, res: Response) => {
  const { zone_id } = req.query;
  let sql = `SELECT t.*, z.zone_name FROM weather_thresholds t LEFT JOIN weather_zones z ON t.zone_id = z.id WHERE 1=1`;
  const params: (string | number)[] = [];
  if (zone_id) { sql += ' AND (t.zone_id = ? OR t.zone_id IS NULL)'; params.push(Number(zone_id)); }
  sql += " ORDER BY t.weather_type, CASE t.level WHEN 'red' THEN 4 WHEN 'orange' THEN 3 WHEN 'yellow' THEN 2 WHEN 'blue' THEN 1 END DESC";
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 新增阈值
router.post('/thresholds', auth, requireRole('admin'), validate(weatherThresholdCreateSchema), asyncHandler(async (req: Request, res: Response) => {
  const { zone_id, weather_type, level, threshold_value, threshold_unit, duration_minutes, enabled } = req.body;
  getDB().prepare(
    `INSERT INTO weather_thresholds (zone_id, weather_type, level, threshold_value, threshold_unit, duration_minutes, enabled)
     VALUES (?, ?, ?, ?, ?, ?, ?)`
  ).run(zone_id || null, weather_type, level, threshold_value, threshold_unit || '', duration_minutes || 30, enabled ?? 1);
  res.json({ code: 200, msg: '新增成功' });
}));

// 编辑阈值
router.put('/thresholds/:id', auth, requireRole('admin'), validate(weatherThresholdUpdateSchema), asyncHandler(async (req: Request, res: Response) => {
  const t = getDB().prepare('SELECT * FROM weather_thresholds WHERE id = ?').get(req.params.id) as Record<string, unknown> | undefined;
  if (!t) { res.json({ code: 404, msg: '阈值不存在' }); return; }
  const { zone_id, weather_type, level, threshold_value, threshold_unit, duration_minutes, enabled } = req.body;
  getDB().prepare(
    `UPDATE weather_thresholds SET
      zone_id = ?, weather_type = ?, level = ?, threshold_value = ?,
      threshold_unit = ?, duration_minutes = ?, enabled = ?,
      updated_at = datetime('now')
     WHERE id = ?`
  ).run(
    zone_id ?? t.zone_id ?? null,
    weather_type || t.weather_type,
    level || t.level,
    threshold_value ?? t.threshold_value,
    threshold_unit ?? t.threshold_unit ?? '',
    duration_minutes ?? t.duration_minutes ?? 30,
    enabled ?? t.enabled ?? 1,
    req.params.id
  );
  res.json({ code: 200, msg: '更新成功' });
}));

// 删除阈值
router.delete('/thresholds/:id', auth, requireRole('admin'), asyncHandler(async (req: Request, res: Response) => {
  const t = getDB().prepare('SELECT * FROM weather_thresholds WHERE id = ?').get(req.params.id);
  if (!t) { res.json({ code: 404, msg: '阈值不存在' }); return; }
  getDB().prepare('DELETE FROM weather_thresholds WHERE id = ?').run(req.params.id);
  res.json({ code: 200, msg: '已删除' });
}));

// ==================== 天气数据 ====================

// 天气数据查询
router.get('/data', auth, asyncHandler(async (req: Request, res: Response) => {
  const { zone_id, type, from, to } = req.query;
  let sql = `SELECT wd.*, wz.zone_name FROM weather_data wd JOIN weather_zones wz ON wd.zone_id = wz.id WHERE 1=1`;
  const params: (string | number)[] = [];
  if (zone_id) { sql += ' AND wd.zone_id = ?'; params.push(Number(zone_id)); }
  if (type) { sql += ' AND wd.data_type = ?'; params.push(String(type)); }
  if (from) { sql += ' AND wd.recorded_at >= ?'; params.push(String(from)); }
  if (to) { sql += ' AND wd.recorded_at <= ?'; params.push(String(to) + ' 23:59:59'); }
  sql += ' ORDER BY wd.recorded_at DESC LIMIT 200';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// IoT传感器数据摄入（独立token认证）
router.post('/data/ingest', validate(weatherDataIngestSchema), asyncHandler(async (req: Request, res: Response) => {
  const config = getSystemWeatherConfig();
  const token = req.headers['x-sensor-token'] as string || '';
  if (!token || token !== config.sensorToken) {
    res.json({ code: 403, msg: '传感器token无效' }); return;
  }
  const { items } = req.body;
  const result = ingestSensorData(items);
  res.json({ code: 200, msg: `处理完成: 成功${result.success}条, 失败${result.failed}条`, data: result });
}));

// ==================== 预警管理 ====================

// 预警列表
router.get('/warnings', auth, asyncHandler(async (req: Request, res: Response) => {
  const { status, zone_id, weather_type, level } = req.query;
  let sql = `SELECT w.*, wz.zone_name, wz.zone_code, u.name as resolver_name
    FROM weather_warnings w
    JOIN weather_zones wz ON w.zone_id = wz.id
    LEFT JOIN users u ON w.resolved_by = u.id
    WHERE 1=1`;
  const params: (string | number)[] = [];
  if (status) { sql += ' AND w.status = ?'; params.push(String(status)); }
  if (zone_id) { sql += ' AND w.zone_id = ?'; params.push(Number(zone_id)); }
  if (weather_type) { sql += ' AND w.weather_type = ?'; params.push(String(weather_type)); }
  if (level) { sql += ' AND w.level = ?'; params.push(String(level)); }
  sql += ' ORDER BY w.created_at DESC LIMIT 100';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 当前活跃预警
router.get('/warnings/active', auth, asyncHandler(async (_req: Request, res: Response) => {
  const data = getDB().prepare(
    `SELECT w.*, wz.zone_name, wz.zone_code
     FROM weather_warnings w
     JOIN weather_zones wz ON w.zone_id = wz.id
     WHERE w.status IN ('active','acknowledged')
     ORDER BY
       CASE w.level WHEN 'red' THEN 4 WHEN 'orange' THEN 3 WHEN 'yellow' THEN 2 WHEN 'blue' THEN 1 END DESC,
       w.triggered_at DESC`
  ).all();
  res.json({ code: 200, data });
}));

// 预警详情
router.get('/warnings/:id', auth, asyncHandler(async (req: Request, res: Response) => {
  const w = getDB().prepare(
    `SELECT w.*, wz.zone_name, wz.zone_code, u.name as resolver_name
     FROM weather_warnings w
     JOIN weather_zones wz ON w.zone_id = wz.id
     LEFT JOIN users u ON w.resolved_by = u.id
     WHERE w.id = ?`
  ).get(req.params.id);
  if (!w) { res.json({ code: 404, msg: '预警不存在' }); return; }
  const actions = getDB().prepare(
    'SELECT * FROM weather_warning_actions WHERE warning_id = ? ORDER BY executed_at'
  ).all(req.params.id);
  (w as Record<string, unknown>).actions = actions;
  res.json({ code: 200, data: w });
}));

// 确认收到预警
router.post('/warnings/:id/acknowledge', auth, asyncHandler(async (req: Request, res: Response) => {
  const w = getDB().prepare("SELECT * FROM weather_warnings WHERE id = ? AND status = 'active'").get(req.params.id);
  if (!w) { res.json({ code: 404, msg: '预警不存在或已处理' }); return; }
  getDB().prepare("UPDATE weather_warnings SET status = 'acknowledged' WHERE id = ?").run(req.params.id);
  getDB().prepare(
    `INSERT INTO weather_warning_actions (warning_id, action_type, action_detail, executed_by, result)
     VALUES (?, 'acknowledge', '预警已确认收到', ?, 'acknowledged')`
  ).run(req.params.id, req.user.id);
  res.json({ code: 200, msg: '已确认收到' });
}));

// 解除预警
router.post('/warnings/:id/resolve', auth, requireRole('admin', 'safety_officer', 'dispatcher'), validate(weatherWarningResolveSchema), asyncHandler(async (req: Request, res: Response) => {
  const w = getDB().prepare("SELECT * FROM weather_warnings WHERE id = ? AND status IN ('active','acknowledged')").get(req.params.id);
  if (!w) { res.json({ code: 404, msg: '预警不存在或已解除' }); return; }
  const { reason } = req.body;
  resolveWarning(Number(req.params.id), req.user.id, reason || '人工解除');
  res.json({ code: 200, msg: '预警已解除' });
}));

// ==================== 仪表盘 ====================

router.get('/dashboard', auth, asyncHandler(async (_req: Request, res: Response) => {
  // 所有zone
  const zones = getDB().prepare('SELECT * FROM weather_zones WHERE status = 1 ORDER BY id').all() as Array<Record<string, unknown>>;

  // 活跃预警
  const activeWarnings = getDB().prepare(
    `SELECT w.*, wz.zone_name, wz.zone_code
     FROM weather_warnings w
     JOIN weather_zones wz ON w.zone_id = wz.id
     WHERE w.status IN ('active','acknowledged')
     ORDER BY CASE w.level WHEN 'red' THEN 4 WHEN 'orange' THEN 3 WHEN 'yellow' THEN 2 WHEN 'blue' THEN 1 END DESC`
  ).all();

  // 各zone最新天气数据
  const dashboardZones = [];
  for (const zone of zones) {
    const latestData = getDB().prepare(
      `SELECT data_type, value, unit, recorded_at FROM weather_data
       WHERE zone_id = ? AND recorded_at >= datetime('now', '-1 hour')
       ORDER BY recorded_at DESC LIMIT 20`
    ).all(zone.id) as Array<Record<string, unknown>>;
    const zoneWarnings = (activeWarnings as Array<Record<string, unknown>>).filter(w => Number(w.zone_id) === Number(zone.id));
    dashboardZones.push({
      zone,
      latestData,
      warnings: zoneWarnings,
      warningCount: zoneWarnings.length,
      hasRedWarning: zoneWarnings.some(w => w.level === 'red'),
    });
  }

  // 统计
  const totalActive = (activeWarnings as Array<Record<string, unknown>>).length;
  const redCount = (activeWarnings as Array<Record<string, unknown>>).filter(w => w.level === 'red').length;
  const orangeCount = (activeWarnings as Array<Record<string, unknown>>).filter(w => w.level === 'orange').length;

  res.json({
    code: 200,
    data: {
      zones: dashboardZones,
      activeWarnings,
      summary: { totalActive, redCount, orangeCount },
    },
  });
}));

// ==================== 调度检查 ====================

router.post('/check-zone', auth, asyncHandler(async (req: Request, res: Response) => {
  const { zone_id } = req.body;
  if (!zone_id) { res.json({ code: 400, msg: '请指定区域' }); return; }
  const result = checkZoneForDispatch(zone_id);
  res.json({ code: 200, data: result });
}));

// ==================== 短信通知（预留接口） ====================

router.post('/send-sms', auth, requireRole('admin'), validate(weatherSmsSchema), asyncHandler(async (req: Request, res: Response) => {
  const { phones, content } = req.body;
  // TODO: 对接短信网关
  console.log('[Weather SMS] 待发送:', phones, content);
  res.json({ code: 200, msg: '短信接口已预留，待对接短信网关' });
}));

// ==================== 天气类型/等级字典 ====================

router.get('/dict', auth, asyncHandler(async (_req: Request, res: Response) => {
  res.json({
    code: 200, data: {
      weatherTypes: Object.entries(WEATHER_LABELS).map(([key, label]) => ({ key, label })),
      levels: Object.entries(LEVEL_LABELS).map(([key, label]) => ({ key, label })),
    },
  });
}));

// ==================== 本地天气（手机天气卡片） ====================

// 和风天气 icon → emoji
const QW_ICON_MAP: Record<string, string> = {
  '100': '☀️', '101': '⛅', '102': '🌤️', '103': '🌤️', '104': '☁️',
  '150': '🌙', '151': '🌙', '152': '🌙', '153': '🌙', '154': '☁️',
  '300': '🌦️', '301': '🌦️', '302': '⛈️', '303': '⛈️', '304': '⛈️',
  '305': '🌦️', '306': '🌧️', '307': '🌧️', '308': '🌧️', '309': '🌧️',
  '310': '🌧️', '311': '🌧️', '312': '🌧️', '313': '🌧️', '314': '🌧️',
  '315': '🌧️', '316': '🌧️', '317': '🌧️', '318': '🌧️',
  '400': '🌨️', '401': '🌨️', '402': '❄️', '403': '❄️', '404': '❄️',
  '405': '❄️', '406': '🌨️', '407': '🌨️', '408': '🌨️', '409': '🌨️', '410': '🌨️',
  '500': '🌫️', '501': '🌫️', '502': '🌪️', '503': '🌪️', '504': '🌪️',
  '507': '🌪️', '508': '🌪️',
};

// 星期几
function dayLabel(dateStr: string): string {
  const d = new Date(dateStr.replace(/-/g, '/'));
  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const target = new Date(d);
  target.setHours(0, 0, 0, 0);
  const diff = Math.round((target.getTime() - today.getTime()) / 86400000);
  if (diff === 0) return '今天';
  if (diff === 1) return '明天';
  if (diff === 2) return '后天';
  const weekdays = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
  return weekdays[d.getDay()];
}

// 内存缓存
const localWeatherCache = new Map<string, { data: any; expires: number }>();

router.get('/local', auth, asyncHandler(async (req: Request, res: Response) => {
  const lat = parseFloat(req.query.lat as string);
  const lon = parseFloat(req.query.lon as string);
  if (isNaN(lat) || isNaN(lon)) {
    res.json({ code: 400, msg: '请提供有效经纬度 (lat, lon)' }); return;
  }

  const cacheKey = `${lat.toFixed(2)},${lon.toFixed(2)}`;
  const cached = localWeatherCache.get(cacheKey);
  if (cached && cached.expires > Date.now()) {
    res.json({ code: 200, data: cached.data }); return;
  }

  try {
    const config = getSystemWeatherConfig();
    const host = config.qweatherHost;
    const key = config.qweatherKey;
    const locStr = `${lon},${lat}`;

    // 并行请求：天气 + 预报 + 城市名
    const [nowResp, dayResp, geoResp] = await Promise.all([
      fetch(`https://${host}/v7/weather/now?location=${locStr}&key=${key}`, { signal: AbortSignal.timeout(8000) }),
      fetch(`https://${host}/v7/weather/3d?location=${locStr}&key=${key}`, { signal: AbortSignal.timeout(8000) }),
      fetch(`https://${host}/geo/v2/city/lookup?location=${locStr}&key=${key}`, { signal: AbortSignal.timeout(5000) }),
    ]);
    const nowJson = await nowResp.json() as any;
    const dayJson = await dayResp.json() as any;
    const geoJson = await geoResp.json() as any;

    if (nowJson?.code !== '200' || !nowJson.now) {
      res.json({ code: 500, msg: '获取天气数据失败' }); return;
    }

    const n = nowJson.now;

    // 当前天气（原生中文，无需翻译）
    const current = {
      temp: Math.round(Number(n.temp) || 0),
      feelsLike: Math.round(Number(n.feelsLike) || 0),
      humidity: Math.round(Number(n.humidity) || 0),
      pressure: Math.round(Number(n.pressure) || 0),
      weatherDesc: (n.text as string) || '未知',
      weatherIcon: QW_ICON_MAP[n.icon as string] || '🌡️',
      windDesc: `${n.windDir || ''}${n.windScale || ''}级`,
      windDir: (n.windDir as string) || '',
    };

    // 城市名：GeoAPI 反查
    let city = '当前位置';
    if (geoJson?.code === '200' && geoJson?.location?.length > 0) {
      const loc = geoJson.location[0];
      const adm1 = (loc.adm1 || '') as string;
      const adm2 = (loc.adm2 || '') as string;
      const name = (loc.name || '') as string;
      // 直辖市/省级市: "北京市东城区"  普通: "西藏拉萨市城关区"
      const sameRegion = adm1.includes(adm2) || adm2.includes(adm1);
      city = sameRegion ? `${adm1}${name}` : `${adm1}${adm2}${name}`;
    }

    // 3天预报
    const forecast: any[] = [];
    if (dayJson?.code === '200' && dayJson.daily) {
      for (let i = 0; i < dayJson.daily.length; i++) {
        const d = dayJson.daily[i];
        forecast.push({
          dayLabel: dayLabel(d.fxDate as string),
          date: d.fxDate,
          weatherDesc: (d.textDay as string) || '',
          weatherIcon: QW_ICON_MAP[d.iconDay as string] || '🌡️',
          tempMax: Math.round(Number(d.tempMax) || 0),
          tempMin: Math.round(Number(d.tempMin) || 0),
          precipProb: Math.round(Number(d.precip) || 0),
        });
      }
    }

    const data = { city, current, forecast };

    localWeatherCache.set(cacheKey, { data, expires: Date.now() + 15 * 60 * 1000 });

    // 定期清理过期缓存
    if (Math.random() < 0.01) {
      const now = Date.now();
      for (const [k, v] of localWeatherCache) {
        if (v.expires <= now) localWeatherCache.delete(k);
      }
    }

    res.json({ code: 200, data });
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error('[Weather] 本地天气获取失败:', msg);
    res.json({ code: 500, msg: '天气服务暂不可用' });
  }
}));

export default router;
