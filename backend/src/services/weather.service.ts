import { getDB } from '../db';
import dayjs from 'dayjs';
import { WeatherType, WarningLevel } from '../models';

// ==================== 天气类型和等级映射 ====================

const WEATHER_TYPE_MAP: Record<string, string> = {
  rain: 'rainstorm', snow: 'snowstorm', wind: 'strong_wind',
  visibility: 'low_visibility', dust: 'sandstorm', lightning: 'thunderstorm',
};

const LEVEL_ORDER: WarningLevel[] = ['blue', 'yellow', 'orange', 'red'];

const WEATHER_LABELS: Record<string, string> = {
  rainstorm: '暴雨', thunderstorm: '雷电', strong_wind: '大风',
  snowstorm: '暴雪', sandstorm: '沙尘暴', low_visibility: '大雾/低能见度',
};

const LEVEL_LABELS: Record<string, string> = {
  blue: '蓝色预警', yellow: '黄色预警', orange: '橙色预警', red: '红色预警',
};

// ==================== 数据采集 ====================

/** 从 Open-Meteo 免费天气API拉取数据（无需API Key） */
export async function fetchWeatherData(): Promise<void> {
  try {
    const config = getSystemWeatherConfig();
    const apiUrl = config.apiUrl;

    // 获取所有启用的zone（直接从记录读取经纬度）
    const zones = getDB().prepare('SELECT * FROM weather_zones WHERE status = 1').all() as Array<{ id: number; zone_name: string; latitude: number; longitude: number }>;

    for (const zone of zones) {
      try {
        const lat = zone.latitude || 29.6;
        const lon = zone.longitude || 91.6;

        // Open-Meteo 免费API：current + hourly（无需API Key）
        const currentParams = 'temperature_2m,relative_humidity_2m,wind_speed_10m,precipitation,rain,showers,snowfall,weather_code,cloud_cover,surface_pressure,wind_gusts_10m';
        const hourlyParams = 'visibility';
        const url = `${apiUrl}?latitude=${lat}&longitude=${lon}&current=${currentParams}&hourly=${hourlyParams}&timezone=Asia/Shanghai`;

        const resp = await fetch(url, { signal: AbortSignal.timeout(10000) });
        const json = await resp.json() as any;

        if (json.current) {
          const c = json.current;
          const recordedAt = dayjs().format('YYYY-MM-DD HH:mm:ss');
          const weatherEntries: Array<{ type: string; value: number; unit: string }> = [];

          // 温度
          if (c.temperature_2m != null) weatherEntries.push({ type: 'temperature', value: c.temperature_2m, unit: '℃' });
          // 风速 (km/h → 规则引擎会归一化为 m/s)
          if (c.wind_speed_10m != null) weatherEntries.push({ type: 'wind_speed', value: c.wind_speed_10m, unit: 'km/h' });
          // 阵风
          if (c.wind_gusts_10m != null) weatherEntries.push({ type: 'wind_gust', value: c.wind_gusts_10m, unit: 'km/h' });
          // 湿度
          if (c.relative_humidity_2m != null) weatherEntries.push({ type: 'humidity', value: c.relative_humidity_2m, unit: '%' });
          // 降水量
          if (c.precipitation != null) weatherEntries.push({ type: 'rainfall', value: c.precipitation, unit: 'mm/h' });
          // 降雪量
          if (c.snowfall != null) weatherEntries.push({ type: 'snowfall', value: c.snowfall, unit: 'mm/h' });
          // 气压
          if (c.surface_pressure != null) weatherEntries.push({ type: 'pressure', value: c.surface_pressure, unit: 'hPa' });
          // 云量
          if (c.cloud_cover != null) weatherEntries.push({ type: 'cloud_cover', value: c.cloud_cover, unit: '%' });
          // 天气码 (WMO code → 用于判断雷暴/沙尘等)
          if (c.weather_code != null) weatherEntries.push({ type: 'weather_code', value: c.weather_code, unit: 'wmo' });

          // 能见度从hourly取当前小时的值
          if (json.hourly && json.hourly.visibility && json.hourly.time) {
            const nowHour = dayjs().format('YYYY-MM-DDTHH:00');
            const hourIdx = json.hourly.time.findIndex((t: string) => t === nowHour);
            if (hourIdx >= 0 && json.hourly.visibility[hourIdx] != null) {
              weatherEntries.push({ type: 'visibility', value: json.hourly.visibility[hourIdx], unit: 'm' });
            }
          }

          // 从天气码推导雷暴/沙尘
          const wmoCode = c.weather_code;
          if (wmoCode != null) {
            // 雷暴: WMO 95(小雷暴), 96(小雷暴+冰雹), 99(大雷暴+冰雹)
            if (wmoCode >= 95 && wmoCode <= 99) {
              const lightningIntensity = wmoCode === 99 ? 100 : wmoCode === 96 ? 30 : 10;
              weatherEntries.push({ type: 'lightning', value: lightningIntensity, unit: 'strikes/10min' });
            }
            // 沙尘: WMO 6(扬尘), 7(浮尘), 8(沙/尘暴), 9(沙尘暴), 30-35(沙尘暴各级)
            if ([6, 7, 8, 9, 30, 31, 32, 33, 34, 35].includes(wmoCode)) {
              const dustLevel = wmoCode >= 34 ? 500 : wmoCode >= 31 ? 1000 : wmoCode >= 9 ? 2000 : 5000;
              weatherEntries.push({ type: 'dust', value: dustLevel, unit: 'μg/m³' });
            }
          }

          for (const entry of weatherEntries) {
            getDB().prepare(
              `INSERT INTO weather_data (zone_id, source, data_type, value, unit, recorded_at, raw_data)
               VALUES (?, 'api', ?, ?, ?, ?, ?)`
            ).run(zone.id, entry.type, entry.value, entry.unit, recordedAt, JSON.stringify(json));
          }

          console.log(`[Weather] 区域「${zone.zone_name}」数据采集完成: ${weatherEntries.length}项 (Open-Meteo)`);
        }
      } catch (e: unknown) {
        const msg = e instanceof Error ? e.message : String(e);
        console.log(`[Weather] 区域「${zone.zone_name}」采集失败: ${msg}`);
      }
    }
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error('[Weather] 数据采集异常:', msg);
  }
}

// ==================== IoT传感器数据摄入 ====================

export interface SensorDataItem {
  zone_code: string;
  data_type: string;
  value: number;
  unit?: string;
  recorded_at?: string;
}

export function ingestSensorData(items: SensorDataItem[]): { success: number; failed: number } {
  let sc = 0, fc = 0;
  const zoneMap = new Map<string, number>();

  for (const item of items) {
    try {
      // 缓存zone查找
      if (!zoneMap.has(item.zone_code)) {
        const zone = getDB().prepare('SELECT id FROM weather_zones WHERE zone_code = ? AND status = 1').get(item.zone_code) as { id: number } | undefined;
        if (!zone) { fc++; continue; }
        zoneMap.set(item.zone_code, zone.id);
      }
      const zoneId = zoneMap.get(item.zone_code)!;
      const recordedAt = item.recorded_at || dayjs().format('YYYY-MM-DD HH:mm:ss');

      getDB().prepare(
        `INSERT INTO weather_data (zone_id, source, data_type, value, unit, recorded_at, raw_data)
         VALUES (?, 'sensor', ?, ?, ?, ?, '')`
      ).run(zoneId, item.data_type, item.value, item.unit || '', recordedAt);
      sc++;
    } catch {
      fc++;
    }
  }
  return { success: sc, failed: fc };
}

// ==================== 规则引擎 ====================

/** 运行预警规则引擎：检查最新数据 → 触发/升级/解除预警 */
export function runWarningEngine(): void {
  try {
    const now = dayjs();
    const zones = getDB().prepare('SELECT * FROM weather_zones WHERE status = 1').all() as Array<{ id: number; zone_name: string; zone_code: string }>;

    for (const zone of zones) {
      // 获取该zone最近30分钟的各类型最新数据
      const cutoff = now.subtract(30, 'minute').format('YYYY-MM-DD HH:mm:ss');
      const latestData = getDB().prepare(
        `SELECT data_type, MAX(value) as max_value, unit
         FROM weather_data
         WHERE zone_id = ? AND recorded_at >= ?
         GROUP BY data_type`
      ).all(zone.id, cutoff) as Array<{ data_type: string; max_value: number; unit: string }>;

      if (!latestData.length) continue;

      // 获取该zone的阈值配置（zone级优先，无则用全局NULL）
      for (const data of latestData) {
        const weatherType = mapDataTypeToWeatherType(data.data_type);
        if (!weatherType) continue;

        // 归一化数值（不同数据源单位可能不同）
        const normalized = normalizeValue(data.data_type, data.max_value, data.unit);

        // 获取阈值
        const thresholds = getThresholdsForZone(zone.id, weatherType);
        if (!thresholds.length) continue;

        // 从高到低依次检查（红→橙→黄→蓝）
        let matchedLevel: WarningLevel | null = null;
        for (let i = LEVEL_ORDER.length - 1; i >= 0; i--) {
          const level = LEVEL_ORDER[i];
          const threshold = thresholds.find(t => t.level === level);
          if (!threshold) continue;

          // 根据天气类型判断比较方向
          const triggered = isThresholdExceeded(weatherType, normalized, threshold.threshold_value);
          if (triggered) {
            matchedLevel = level;
            break;
          }
        }

        // 检查该zone该类型是否有活跃预警
        const activeWarning = getDB().prepare(
          `SELECT * FROM weather_warnings
           WHERE zone_id = ? AND weather_type = ? AND status IN ('active','acknowledged')
           ORDER BY triggered_at DESC LIMIT 1`
        ).get(zone.id, weatherType) as Record<string, unknown> | undefined;

        if (matchedLevel) {
          if (!activeWarning) {
            // 新触发
            triggerWarning(zone, weatherType, matchedLevel, normalized, data.unit, now);
          } else {
            const currentLevel = activeWarning.level as WarningLevel;
            if (LEVEL_ORDER.indexOf(matchedLevel) > LEVEL_ORDER.indexOf(currentLevel)) {
              // 升级：关旧开新
              getDB().prepare(
                "UPDATE weather_warnings SET status = 'resolved', resolved_at = ?, resolved_by = NULL WHERE id = ?"
              ).run(now.format('YYYY-MM-DD HH:mm:ss'), activeWarning.id);
              triggerWarning(zone, weatherType, matchedLevel, normalized, data.unit, now);
            }
          }
        } else {
          // 无匹配 → 检查是否需要自动解除
          // 条件：活跃预警存在 且 连续2个周期低于蓝色阈值
          if (activeWarning) {
            const blueThreshold = thresholds.find(t => t.level === 'blue');
            if (!blueThreshold) continue;

            // 检查前一个周期的数据也低于蓝色阈值
            const prevCutoff = now.subtract(60, 'minute').format('YYYY-MM-DD HH:mm:ss');
            const prevData = getDB().prepare(
              `SELECT MAX(value) as max_value, unit FROM weather_data
               WHERE zone_id = ? AND data_type = ? AND recorded_at >= ? AND recorded_at < ?`
            ).get(zone.id, data.data_type, prevCutoff, cutoff) as { max_value: number; unit: string } | undefined;

            const prevNormalized = prevData ? normalizeValue(data.data_type, prevData.max_value, prevData.unit) : 999999;
            const bothBelow = !isThresholdExceeded(weatherType, prevNormalized, blueThreshold.threshold_value);

            if (bothBelow) {
              resolveWarning(Number(activeWarning.id), null, '实测值已连续低于蓝色预警阈值，系统自动解除');
            }
          }
        }
      }
    }
  } catch (e: unknown) {
    const msg = e instanceof Error ? e.message : String(e);
    console.error('[Weather] 规则引擎异常:', msg);
  }
}

// ==================== 预警触发 ====================

function triggerWarning(
  zone: { id: number; zone_name: string; zone_code: string },
  weatherType: WeatherType,
  level: WarningLevel,
  measuredValue: number,
  unit: string,
  now: dayjs.Dayjs
): void {
  const no = 'WJ' + now.format('YYYYMMDD') + String(Date.now()).slice(-4);
  const title = `${zone.zone_name} ${WEATHER_LABELS[weatherType] || weatherType} ${LEVEL_LABELS[level] || level}`;
  const description = `实测${WEATHER_LABELS[weatherType]}: ${measuredValue}${unit}，达到${LEVEL_LABELS[level]}标准，请立即采取防护措施。`;

  const autoActions: string[] = [];

  // 红色预警联动
  if (level === 'red') {
    autoActions.push('suspend_dispatch'); // 暂停该区域车辆调度
    autoActions.push('recall_drivers');    // 通知驾驶员回撤

    // 通知该区域相关驾驶员
    try {
      const drivers = getDB().prepare(
        `SELECT DISTINCT u.id FROM users u
         JOIN driver_vehicle_bindings dvb ON u.id = dvb.driver_id AND dvb.unbind_date IS NULL
         JOIN vehicles v ON dvb.vehicle_id = v.id
         WHERE u.role = 'driver' AND u.status = 1`
      ).all() as { id: number }[];
      for (const driver of drivers) {
        getDB().prepare(
          `INSERT INTO notifications (user_id, type, title, content)
           VALUES (?, 'weather_warning', ?, ?)`
        ).run(driver.id, `🔴 红色预警：${title}`, `${description}\n请立即停止作业，返回安全区域。`);
      }
    } catch { /* 通知非关键 */ }
  }

  // 橙/黄/蓝预警通知管理员+安全员+调度员
  const managers = getDB().prepare(
    "SELECT id FROM users WHERE role IN ('admin','safety_officer','dispatcher') AND status = 1"
  ).all() as { id: number }[];
  const emoji = level === 'red' ? '🔴' : level === 'orange' ? '🟠' : level === 'yellow' ? '🟡' : '🔵';
  for (const m of managers) {
    try {
      getDB().prepare(
        `INSERT INTO notifications (user_id, type, title, content)
         VALUES (?, 'weather_warning', ?, ?)`
      ).run(m.id, `${emoji} ${LEVEL_LABELS[level]}: ${zone.zone_name}${WEATHER_LABELS[weatherType]}预警`,
        `${description}\n区域: ${zone.zone_name} (${zone.zone_code})`);
    } catch { /* 通知非关键 */ }
  }

  getDB().prepare(
    `INSERT INTO weather_warnings (warning_no, zone_id, weather_type, level, title, description, measured_value, measured_unit, status, triggered_at, auto_actions)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?)`
  ).run(no, zone.id, weatherType, level, title, description, measuredValue, unit, now.format('YYYY-MM-DD HH:mm:ss'), JSON.stringify(autoActions));

  // 记录自动动作
  const warningId = (getDB().prepare('SELECT last_insert_rowid() as id').get() as { id: number }).id;
  for (const action of autoActions) {
    getDB().prepare(
      `INSERT INTO weather_warning_actions (warning_id, action_type, action_detail, result)
       VALUES (?, ?, ?, ?)`
    ).run(warningId, action, `系统自动触发: ${LEVEL_LABELS[level]}`, 'executed');
  }

  console.log(`[Weather] 预警触发: ${title}`);
}

/** 解除预警 */
export function resolveWarning(warningId: number, userId: number | null, reason: string): void {
  const now = dayjs().format('YYYY-MM-DD HH:mm:ss');
  getDB().prepare(
    "UPDATE weather_warnings SET status = 'resolved', resolved_at = ?, resolved_by = ? WHERE id = ?"
  ).run(now, userId, warningId);

  getDB().prepare(
    `INSERT INTO weather_warning_actions (warning_id, action_type, action_detail, executed_by, result)
     VALUES (?, 'resolve', ?, ?, 'resolved')`
  ).run(warningId, reason, userId);

  // 通知管理员
  const warning = getDB().prepare('SELECT * FROM weather_warnings WHERE id = ?').get(warningId) as Record<string, unknown> | undefined;
  if (warning) {
    const admins = getDB().prepare("SELECT id FROM users WHERE role IN ('admin','safety_officer') AND status = 1").all() as { id: number }[];
    for (const admin of admins) {
      try {
        getDB().prepare(
          `INSERT INTO notifications (user_id, type, title, content)
           VALUES (?, 'weather_resolved', ?, ?)`
        ).run(admin.id, `✅ 预警已解除: ${warning.title}`, reason || '预警已手动/自动解除');
      } catch { /* 通知非关键 */ }
    }
  }
}

// ==================== 调度检查 ====================

/** 检查指定区域是否可以派车（红色预警时禁止） */
export function checkZoneForDispatch(zoneId: number): { blocked: boolean; reason?: string } {
  const redWarning = getDB().prepare(
    `SELECT * FROM weather_warnings
     WHERE zone_id = ? AND level = 'red' AND status IN ('active','acknowledged')
     ORDER BY triggered_at DESC LIMIT 1`
  ).get(zoneId) as Record<string, unknown> | undefined;

  if (redWarning) {
    return {
      blocked: true,
      reason: `该区域处于红色预警（${redWarning.title}），禁止派车。预警时间: ${redWarning.triggered_at}`,
    };
  }
  return { blocked: false };
}

// ==================== 辅助函数 ====================

function getSystemWeatherConfig(): { apiUrl: string; sensorToken: string; pollInterval: number; qweatherKey: string; qweatherHost: string } {
  const rows = getDB().prepare("SELECT config_key, config_value FROM system_config WHERE config_key LIKE 'weather_%'").all() as Array<{ config_key: string; config_value: string }>;
  const map: Record<string, string> = {};
  for (const r of rows) { map[r.config_key] = r.config_value; }
  return {
    apiUrl: map['weather_api_url'] || 'https://api.open-meteo.com/v1/forecast',
    sensorToken: map['weather_sensor_token'] || 'sensor_token_change_me',
    pollInterval: parseInt(map['weather_poll_interval_minutes'] || '10', 10),
    qweatherKey: map['weather_qweather_key'] || '',
    qweatherHost: map['weather_qweather_host'] || 'devapi.qweather.com',
  };
}

function getConfigValue(key: string, defaultVal: string): string {
  const row = getDB().prepare('SELECT config_value FROM system_config WHERE config_key = ?').get(key) as { config_value: string } | undefined;
  return row?.config_value || defaultVal;
}

/** 将传感器数据类型映射到天气预警类型 */
function mapDataTypeToWeatherType(dataType: string): WeatherType | null {
  const map: Record<string, WeatherType> = {
    rainfall: 'rainstorm',
    rain: 'rainstorm',
    wind_speed: 'strong_wind',
    wind: 'strong_wind',
    snowfall: 'snowstorm',
    snow: 'snowstorm',
    visibility: 'low_visibility',
    dust: 'sandstorm',
    pm10: 'sandstorm',
    lightning: 'thunderstorm',
    thunderstorm: 'thunderstorm',
  };
  return map[dataType] || null;
}

/** 归一化数值到标准单位 */
function normalizeValue(dataType: string, value: number, unit: string): number {
  // 风速: km/h → m/s
  if ((dataType === 'wind_speed' || dataType === 'wind') && unit === 'km/h') {
    return value / 3.6;
  }
  // 能见度: km → m
  if (dataType === 'visibility' && (unit === 'km' || unit === '公里')) {
    return value * 1000;
  }
  return value;
}

/** 获取zone的阈值配置（zone级优先 → 全局默认） */
function getThresholdsForZone(zoneId: number, weatherType: string): Array<{ level: WarningLevel; threshold_value: number }> {
  // 先查zone级
  let thresholds = getDB().prepare(
    `SELECT level, threshold_value FROM weather_thresholds
     WHERE zone_id = ? AND weather_type = ? AND enabled = 1
     ORDER BY CASE level WHEN 'red' THEN 4 WHEN 'orange' THEN 3 WHEN 'yellow' THEN 2 WHEN 'blue' THEN 1 END DESC`
  ).all(zoneId, weatherType) as Array<{ level: WarningLevel; threshold_value: number }>;

  // 无zone级 → 用全局默认
  if (!thresholds.length) {
    thresholds = getDB().prepare(
      `SELECT level, threshold_value FROM weather_thresholds
       WHERE zone_id IS NULL AND weather_type = ? AND enabled = 1
       ORDER BY CASE level WHEN 'red' THEN 4 WHEN 'orange' THEN 3 WHEN 'yellow' THEN 2 WHEN 'blue' THEN 1 END DESC`
    ).all(weatherType) as Array<{ level: WarningLevel; threshold_value: number }>;
  }

  return thresholds;
}

/** 判断阈值是否被超过（考虑不同天气类型的比较方向） */
function isThresholdExceeded(weatherType: string, value: number, threshold: number): boolean {
  // 能见度类：低于阈值才触发（visibility/sandstorm）
  if (weatherType === 'low_visibility' || weatherType === 'sandstorm') {
    return value <= threshold;
  }
  // 其他：高于阈值触发（rainfall/wind/snow/lightning）
  return value >= threshold;
}

export { WEATHER_LABELS, LEVEL_LABELS, LEVEL_ORDER, WEATHER_TYPE_MAP };
export { getSystemWeatherConfig, mapDataTypeToWeatherType, normalizeValue };
