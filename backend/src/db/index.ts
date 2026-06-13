// better-sqlite3 — 原生同步 SQLite，写入自动持久化，无需手动 saveDB
// 薄包装层保持与旧 sql.js 相同的 Record<string,unknown> 返回类型
import Database from 'better-sqlite3';
import fs from 'fs';
import path from 'path';
import logger from '../utils/logger';
import { SCHEMA_SQL, SEED_SQL } from './schema';
import {
  runColumnMigrations,
  runTableMigrations,
  runDataFixes,
  runRoleMigration,
  runMachineryMigration,
  runKpiMigration,
  seedKpiThresholds,
  seedConfigDefaults,
} from './migrations';

/** 延迟求值：确保 vitest 设置 process.env.DB_PATH 后生效，而非模块加载时固化 */
function getDBPath(): string {
  return process.env.DB_PATH || path.join(__dirname, '../../data/mine_repair.db');
}

// 类型兼容包装：better-sqlite3 的返回值类型较严格，统一转为 Record<string,unknown>
interface Statement {
  run(...params: unknown[]): { lastInsertRowid: number; changes: number };
  get(...params: unknown[]): Record<string, unknown> | undefined;
  all(...params: unknown[]): Record<string, unknown>[];
}

export interface WrappedDB {
  prepare(sql: string): Statement;
  exec(sql: string): void;
  close(): void;
}

let db: WrappedDB;
let rawDb: Database.Database | null = null;

function wrap(raw: Database.Database): WrappedDB {
  return {
    prepare(sql: string): Statement {
      const stmt = raw.prepare(sql);
      return {
        run(...params: unknown[]) {
          const info = stmt.run(...params);
          return { lastInsertRowid: Number(info.lastInsertRowid), changes: info.changes };
        },
        get(...params: unknown[]) {
          // better-sqlite3 .get() returns unknown, wrap to Record<string,unknown>
          const row = stmt.get(...params);
          return row as Record<string, unknown> | undefined;
        },
        all(...params: unknown[]) {
          return stmt.all(...params) as Record<string, unknown>[];
        },
      };
    },
    exec(sql: string): void { raw.exec(sql); },
    close(): void { raw.close(); },
  };
}

export function initDB(): WrappedDB {
  // 幂等守卫：防止多测试文件重复初始化创建多个连接
  if (db) {
    console.log('[DB] Already initialized, reusing existing connection');
    return db;
  }

  const dbPath = getDBPath();
  const dataDir = path.dirname(dbPath);
  if (!fs.existsSync(dataDir)) {
    fs.mkdirSync(dataDir, { recursive: true });
  }

  rawDb = new Database(dbPath);
  rawDb.pragma('journal_mode = WAL');
  rawDb.pragma('foreign_keys = ON');
  db = wrap(rawDb);

  // 创建表结构
  db.exec(SCHEMA_SQL);

  // 兼容旧数据库：添加可能缺失的列
  runCompatibilityMigrations();

  // 插入默认数据
  seedDefaultData();

  console.log('[DB] SQLite initialized (better-sqlite3):', dbPath);
  return db;
}

export function getDB(): WrappedDB {
  if (!db) throw new Error('Database not initialized. Call initDB() first.');
  return db;
}

/** 兼容性迁移：为旧数据库添加缺失列/表/数据修正 */
function runCompatibilityMigrations(): void {
  runColumnMigrations(db);
  runTableMigrations(db);
  runDataFixes(db);
  runRoleMigration(db);
  runMachineryMigration(db);
  runKpiMigration(db);
  seedKpiThresholds(db);
  seedConfigDefaults(db);
  seedWeatherDefaults();
}

/** 插入默认数据（仅当数据库为空时） */
function seedDefaultData(): void {
  // 用 departments 表判断（而非 users），因为 runCompatibilityMigrations 会先插入用户
  const row = db.prepare('SELECT COUNT(*) as c FROM departments').get() as { c: number } | undefined;
  if (row && Number(row.c) > 0) return;

  db.exec(SEED_SQL);
  seedQuizQuestions();
  console.log('[DB] Default data seeded');
}

/** 种子题库数据 */
function seedQuizQuestions(): void {
  const questions: [string, string, string, string, string, string][] = [
    ['挖掘机作业前，操作人员首先应检查什么？', 'choice', '["液压系统","工作装置","机油液位和冷却液","外观清洁"]', 'C', '机油和冷却液位是每日必检项目。', '安全操作'],
    ['装载机在坡道上作业时，铲斗应保持什么状态？', 'choice', '["高举","平放贴近地面","任意位置","朝下翻斗"]', 'B', '坡道作业铲斗平放贴近地面降低重心，防止倾翻。', '安全操作'],
    ['矿用卡车下坡时应使用什么制动方式？', 'choice', '["仅脚刹","发动机制动+脚刹","手刹","倒挡制动"]', 'B', '配合发动机制动和脚刹避免刹车过热失效。', '安全操作'],
    ['推土机在接近边坡作业时应保持多少安全距离？', 'choice', '["0.5米","1米","2米以上","贴着边"]', 'C', '边坡作业至少保持2米安全距离防止滑坡坠落。', '安全操作'],
    ['发动机机油报警灯亮起后应如何处理？', 'choice', '["继续工作","立即停机检查","加点油门","等下班再看"]', 'B', '机油报警必须立即停机检查。', '故障判断'],
    ['发现液压系统漏油时应首先做什么？', 'choice', '["用布擦掉继续干","立即停机并报告","加点液压油继续用","不管它"]', 'B', '液压油泄漏有火灾和污染风险。', '故障判断'],
    ['车辆启动后发现有异常噪音应该怎么做？', 'choice', '["继续工作","立即停机排查原因","加大油门看看","记录但不停机"]', 'B', '异常噪音可能是部件损坏前兆。', '故障判断'],
    ['挖掘机履带张紧度应该多久检查一次？', 'choice', '["一年","一个月","每周或每班前","不用检查"]', 'C', '履带张紧度应每周或每班前检查。', '日常保养'],
    ['空气滤芯堵塞会导致什么问题？', 'choice', '["动力增加","油耗降低","动力下降冒黑烟","不影响"]', 'C', '空气滤芯堵塞导致进气不足。', '日常保养'],
    ['柴油滤芯应多久更换一次？', 'choice', '["永远不换","每300小时或按手册","每天换","只清洗不换"]', 'B', '柴油滤芯应每300小时更换确保燃油清洁。', '日常保养'],
    ['矿车在弯道行驶时速度不应超过多少？', 'choice', '["60km/h","30km/h","15km/h","随意"]', 'C', '矿区道路复杂弯道限速15km/h。', '安全操作'],
    ['高温天气发动机水温过高首先应怎么做？', 'choice', '["立即打开水箱盖","停机怠速降温","浇冷水","继续工作"]', 'B', '水温高时应停机怠速降温，严禁开盖防烫伤。', '故障判断'],
    ['作业人员进入维修区域必须穿戴什么？', 'choice', '["便装","安全帽和反光背心","拖鞋","随意"]', 'B', '矿区维修区域必须穿戴安全帽和反光背心。', '安全操作'],
    ['车辆轮胎出现鼓包应如何处理？', 'choice', '["继续用","降低气压继续用","立即更换","等下次检修"]', 'C', '轮胎鼓包有爆胎风险必须立即更换。', '故障判断'],
    ['工作结束后车辆应停放在什么位置？', 'choice', '["坡道上","安全平坦处拉手刹","任何地方","路边"]', 'B', '停放应选平坦处拉紧手刹锁好门窗关闭电源。', '安全操作'],
    ['灭火器使用的正确顺序是什么？', 'choice', '["喷向火焰顶部","拔销对准按压扫射","直接按压","摇晃后使用"]', 'B', '口诀：拔销、对准根部、按压手柄、扫射灭火。', '安全操作'],
    ['发动机机油应多久检查一次？', 'choice', '["一年","只在保养时","每天作业前","故障时"]', 'C', '每日作业前检查机油能避免大部分发动机故障。', '日常保养'],
    ['液压系统超压工作会导致什么后果？', 'choice', '["效率提高","油管爆裂密封损坏","没有影响","更省油"]', 'B', '超压会导致油管爆裂密封损坏甚至火灾。', '故障判断'],
    ['润滑脂加注过多的后果是什么？', 'choice', '["没事","导致油封损坏和浪费","更润滑","不用管"]', 'B', '黄油过多会导致油封胀破造成泄漏和污染。', '日常保养'],
    ['粉尘环境中空气滤芯应多久检查一次？', 'choice', '["每月","每周","每天或每班","不用管"]', 'C', '粉尘环境滤芯易堵塞需每天或每班检查。', '日常保养'],
    ['"一分钟安全确认"适用于哪些车辆？', 'choice', '["仅工程机械","矿区大型运输车、工程机械、通勤车等","仅通勤车辆","仅小型车辆"]', 'B', '适用于矿区大型运输车辆、工程机械、通勤车辆。', '公司制度'],
    ['驾驶员上车前进行"一分钟安全确认"，正确的方法是？', 'choice', '["直接上车启动","绕车一周检查设备和周边环境","按喇叭即可","只看后视镜"]', 'B', '必须绕车一周检查设备情况和周边环境。', '公司制度'],
    ['驾驶员确认安全上车后应如何起步？', 'choice', '["立刻起步","鸣笛提醒，启动发动机3秒后起步","直接加速","不用鸣笛"]', 'B', '确认安全后鸣笛提醒，3秒后起步。', '公司制度'],
    ['重载车辆临时停放在坡道，重新起步前应如何做？', 'choice', '["直接开走","由地面指挥人员确认安全","按喇叭走","加速冲上去"]', 'B', '由地面指挥人员确认安全。', '公司制度'],
    ['工程机械到达作业地点后，第一个步骤是什么？', 'choice', '["立刻开始作业","熄火拉手刹拔钥匙","先检查油水","先鸣笛"]', 'B', '停车熄火、拉紧手刹、拔出车辆钥匙。', '公司制度'],
    ['斜坡停车时除了熄火拉手刹，还应做什么？', 'choice', '["什么都不做","垫好三角木","加大油门","挂倒挡"]', 'B', '斜坡停车还应垫好三角木防止溜车。', '公司制度'],
    ['"一分钟安全确认"的核心理念是什么？', 'choice', '["提高速度","先确认安全再操作","节省时间","减少工序"]', 'B', '先确认安全再操作，通过绕车检查防止事故。', '公司制度'],
    ['汽车吊卷筒上的钢丝绳应保留几圈？', 'choice', '["全部放完","至少三圈","一圈","五圈"]', 'B', '不准把卷筒上钢丝绳全部放完，应保留三圈。', '汽车吊'],
    ['装载机启动时间不应超过多少秒？', 'choice', '["10秒","5秒","3秒","15秒"]', 'B', '启动时间不应超过5秒，严禁长时间启动。', '装载机'],
    ['装载机铲装作业时车速不超过多少？', 'choice', '["4公里/小时","10公里/小时","8公里/小时","20公里/小时"]', 'A', '铲装作业车速不超过4公里/小时。', '装载机'],
  ];

  const insertStmt = db.prepare(
    'INSERT INTO quiz_questions (question, type, options, answer, explanation, category) VALUES (?, ?, ?, ?, ?, ?)'
  );
  for (const q of questions) {
    insertStmt.run(...q);
  }
}

/** 种子天气预警默认数据（兼容旧数据库） */
function seedWeatherDefaults(): void {
  // 迁移：旧表加 latitude/longitude 列
  try {
    const cols = db.prepare('PRAGMA table_info(weather_zones)').all() as Array<{ name: string }>;
    const hasLat = cols.some(c => c.name === 'latitude');
    const hasLon = cols.some(c => c.name === 'longitude');
    if (!hasLat) { db.exec('ALTER TABLE weather_zones ADD COLUMN latitude REAL DEFAULT 0'); console.log('[DB] weather_zones: added latitude column'); }
    if (!hasLon) { db.exec('ALTER TABLE weather_zones ADD COLUMN longitude REAL DEFAULT 0'); console.log('[DB] weather_zones: added longitude column'); }
  } catch (e) { /* columns may already exist */ }

  // 天气区域
  const zoneCount = db.prepare('SELECT COUNT(*) as c FROM weather_zones').get() as { c: number };
  if (zoneCount.c === 0) {
    const zones: Array<[string, string, number, number, string, string]> = [
      ['甲马乡生活区','ZONE-001',29.77,91.65,'~3800m','矿区生活及办公区域'],
      ['甲玛乡尾矿库','ZONE-002',29.77,91.66,'~4190m','一期甲玛沟尾矿库'],
      ['驱龙第一选矿厂','ZONE-003',29.69,91.61,'~4300m','一期选矿工业场地'],
      ['K28路段','ZONE-004',29.64,91.60,'~4500m','矿区运输主干道K28'],
      ['第二选矿厂','ZONE-005',29.61,91.59,'~4500m','二期选矿工业场地'],
      ['知不拉铜多金属矿','ZONE-006',29.59,91.61,'~5050m','知不拉矿区采场'],
      ['三号排土场','ZONE-007',29.63,91.57,'~4700m','废石排放区域'],
      ['德庆普尾矿库','ZONE-008',29.62,91.56,'~5218m','二期德庆普尾矿库'],
    ];
    for (const z of zones) {
      db.prepare('INSERT INTO weather_zones (zone_name, zone_code, latitude, longitude, altitude, description) VALUES (?,?,?,?,?,?)').run(z[0], z[1], z[2], z[3], z[4], z[5]);
    }
    console.log('[DB] Weather zones seeded (8 zones with coordinates)');
  }

  // 天气阈值
  const thresholdCount = db.prepare('SELECT COUNT(*) as c FROM weather_thresholds').get() as { c: number };
  if (thresholdCount.c === 0) {
    const thresholds: Array<[string, string, number, string, number]> = [
      // 暴雨: 1小时降雨量(mm/h)
      ['rainstorm','blue',15,'mm/h',60],
      ['rainstorm','yellow',30,'mm/h',60],
      ['rainstorm','orange',50,'mm/h',60],
      ['rainstorm','red',70,'mm/h',60],
      // 大风: 平均风速(m/s)
      ['strong_wind','blue',10.8,'m/s',30],
      ['strong_wind','yellow',17.2,'m/s',30],
      ['strong_wind','orange',24.5,'m/s',30],
      ['strong_wind','red',32.7,'m/s',30],
      // 暴雪: 12小时降雪量(mm)
      ['snowstorm','blue',4,'mm/12h',720],
      ['snowstorm','yellow',6,'mm/12h',720],
      ['snowstorm','orange',10,'mm/12h',720],
      ['snowstorm','red',15,'mm/12h',720],
      // 沙尘暴: 能见度(m)
      ['sandstorm','blue',3000,'m',30],
      ['sandstorm','yellow',1000,'m',30],
      ['sandstorm','orange',500,'m',30],
      ['sandstorm','red',50,'m',30],
      // 雷电: 10分钟内闪电次数
      ['thunderstorm','blue',1,'strikes/10min',10],
      ['thunderstorm','yellow',10,'strikes/10min',10],
      ['thunderstorm','orange',30,'strikes/10min',10],
      ['thunderstorm','red',100,'strikes/10min',10],
      // 低能见度/大雾: 能见度(m)
      ['low_visibility','blue',1000,'m',30],
      ['low_visibility','yellow',500,'m',30],
      ['low_visibility','orange',200,'m',30],
      ['low_visibility','red',50,'m',30],
    ];
    for (const t of thresholds) {
      db.prepare(
        'INSERT INTO weather_thresholds (zone_id, weather_type, level, threshold_value, threshold_unit, duration_minutes) VALUES (NULL,?,?,?,?,?)'
      ).run(t[0], t[1], t[2], t[3], t[4]);
    }
    console.log('[DB] Weather thresholds seeded (24 defaults)');
  }

  // 天气系统配置
  const weatherCfg = db.prepare("SELECT id FROM system_config WHERE config_key = 'weather_api_url'").get();
  if (!weatherCfg) {
    const configs: Array<[string, string]> = [
      ['weather_api_url', 'https://api.open-meteo.com/v1/forecast'],
      ['weather_sensor_token', 'sensor_token_change_me'],
      ['weather_poll_interval_minutes', '10'],
    ];
    for (const c of configs) {
      db.prepare("INSERT INTO system_config (config_key, config_value) VALUES (?, ?)").run(c[0], c[1]);
    }
    console.log('[DB] Weather system config seeded');
  }
}

export { SCHEMA_SQL } from './schema';
