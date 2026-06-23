// 数据库兼容性迁移 — 从 db/index.ts 拆分，保持独立可维护

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type DB = any; // DB 等价类型，避免循环引用

export const COLUMN_MIGRATIONS = [
  'ALTER TABLE users ADD COLUMN department_id INTEGER',
  "ALTER TABLE daily_inspections ADD COLUMN toolkit_check TEXT DEFAULT ''",
  'ALTER TABLE daily_inspections ADD COLUMN start_hours REAL DEFAULT 0',
  'ALTER TABLE monthly_ledger ADD COLUMN hourly_fuel_consumption REAL DEFAULT 0',
  'ALTER TABLE daily_inspections ADD COLUMN end_hours REAL DEFAULT 0',
  'ALTER TABLE daily_inspections ADD COLUMN fuel_amount REAL DEFAULT 0',
  "ALTER TABLE daily_inspections ADD COLUMN attendance_symbol TEXT DEFAULT ''",
  "ALTER TABLE daily_inspections ADD COLUMN parking_location TEXT DEFAULT ''",
  "ALTER TABLE daily_inspections ADD COLUMN updated_at DATETIME DEFAULT CURRENT_TIMESTAMP",
  "ALTER TABLE departments ADD COLUMN dept_key TEXT DEFAULT ''",
  "ALTER TABLE vehicles ADD COLUMN purchase_date TEXT DEFAULT ''",
  "ALTER TABLE driver_attendance ADD COLUMN overtime_start TEXT DEFAULT ''",
  "ALTER TABLE driver_attendance ADD COLUMN overtime_end TEXT DEFAULT ''",
  'ALTER TABLE parts_requisitions ADD COLUMN vehicle_id INTEGER',
  "ALTER TABLE daily_inspections ADD COLUMN photos TEXT DEFAULT '[]'",
  "ALTER TABLE daily_inspections ADD COLUMN videos TEXT DEFAULT '[]'",
  "ALTER TABLE repair_quotes ADD COLUMN damage_photos TEXT DEFAULT '[]'",
  "ALTER TABLE repair_quotes ADD COLUMN new_photos TEXT DEFAULT '[]'",
  'ALTER TABLE vehicles ADD COLUMN asset_value REAL DEFAULT 0',
  'ALTER TABLE vehicles ADD COLUMN hourly_rate REAL DEFAULT 0',
  "ALTER TABLE hazards ADD COLUMN rectify_desc TEXT DEFAULT ''",
  "ALTER TABLE hazards ADD COLUMN reject_reason TEXT DEFAULT ''",
  "ALTER TABLE assessments ADD COLUMN photos TEXT DEFAULT '[]'",
  "ALTER TABLE parts_inventory ADD COLUMN unit_price REAL DEFAULT 0",
  'ALTER TABLE parts_inventory ADD COLUMN threshold INTEGER DEFAULT 5',
  "ALTER TABLE monthly_ledger ADD COLUMN revenue REAL DEFAULT 0",
  "ALTER TABLE monthly_ledger ADD COLUMN profit REAL DEFAULT 0",
  // 公里保养
  'ALTER TABLE vehicle_archives ADD COLUMN maintenance_interval_km INTEGER DEFAULT 0',
  'ALTER TABLE vehicle_archives ADD COLUMN next_maintenance_km INTEGER DEFAULT 0',
  'ALTER TABLE vehicle_archives ADD COLUMN current_km INTEGER DEFAULT 0',
  'ALTER TABLE daily_inspections ADD COLUMN current_km REAL DEFAULT 0',
  "ALTER TABLE driver_attendance ADD COLUMN vehicle_type TEXT DEFAULT ''",
  "ALTER TABLE driver_attendance ADD COLUMN plate_number TEXT DEFAULT ''",
  "ALTER TABLE assessments ADD COLUMN assess_date TEXT DEFAULT ''",
  'ALTER TABLE daily_inspections ADD COLUMN start_km REAL DEFAULT 0',
  'ALTER TABLE maintenance_records ADD COLUMN current_km INTEGER DEFAULT 0',
  "ALTER TABLE vehicle_archives ADD COLUMN purchase_date TEXT DEFAULT ''",
  'ALTER TABLE vehicle_archives ADD COLUMN hourly_rate REAL DEFAULT 0',
  'ALTER TABLE vehicle_archives ADD COLUMN asset_value REAL DEFAULT 0',
  'ALTER TABLE daily_inspections ADD COLUMN evening_check_count INTEGER DEFAULT 0',
  "ALTER TABLE machinery_applications ADD COLUMN fee_provider TEXT DEFAULT ''",
  "ALTER TABLE daily_inspections ADD COLUMN mental_state TEXT DEFAULT ''",
  "ALTER TABLE daily_inspections ADD COLUMN ppe_wearing TEXT DEFAULT ''",
  'ALTER TABLE daily_inspections ADD COLUMN blood_pressure_high INTEGER DEFAULT 0',
  'ALTER TABLE daily_inspections ADD COLUMN blood_pressure_low INTEGER DEFAULT 0',
];

export const TABLE_MIGRATIONS = [
  `CREATE TABLE IF NOT EXISTS sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    device_type TEXT NOT NULL CHECK(device_type IN ('pc','mobile')),
    jti TEXT NOT NULL UNIQUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE TABLE IF NOT EXISTS safety_incidents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicle_id INTEGER,
    reporter_id INTEGER,
    incident_time DATETIME NOT NULL,
    title TEXT DEFAULT '',
    description TEXT DEFAULT '',
    severity TEXT DEFAULT '一般' CHECK(severity IN ('低','一般','高','紧急')),
    status TEXT DEFAULT 'open' CHECK(status IN ('open','investigating','resolved')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE TABLE IF NOT EXISTS assessments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    assess_no TEXT NOT NULL,
    issuer_id INTEGER NOT NULL,
    target_id INTEGER NOT NULL,
    title TEXT NOT NULL DEFAULT '',
    content TEXT DEFAULT '',
    assess_type TEXT DEFAULT '通报' CHECK(assess_type IN ('表扬','通报','警告','处罚')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE TABLE IF NOT EXISTS vehicle_archives (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    plate_number TEXT NOT NULL UNIQUE,
    department TEXT DEFAULT '总调度室',
    vehicle_type TEXT DEFAULT '',
    model TEXT DEFAULT '',
    manufacture_date TEXT DEFAULT '',
    vin TEXT DEFAULT '',
    insurance_expiry TEXT DEFAULT '',
    inspection_date TEXT DEFAULT '',
    maintenance_interval INTEGER DEFAULT 500,
    next_maintenance_hours INTEGER DEFAULT 0,
    current_hours INTEGER DEFAULT 0,
    has_behavior_monitor INTEGER DEFAULT 0,
    has_360_camera INTEGER DEFAULT 0,
    photos TEXT DEFAULT '[]',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`,
];

export const LEDGER_TABLES = [
  `CREATE TABLE IF NOT EXISTS fuel_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicle_id INTEGER NOT NULL,
    record_date TEXT NOT NULL,
    fuel_amount REAL DEFAULT 0,
    fuel_cost REAL DEFAULT 0,
    hour_meter INTEGER DEFAULT 0,
    station TEXT DEFAULT '',
    operator_id INTEGER,
    remark TEXT DEFAULT '',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE TABLE IF NOT EXISTS part_replacements (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicle_id INTEGER NOT NULL,
    part_name TEXT NOT NULL,
    part_type TEXT DEFAULT 'other' CHECK(part_type IN ('tire','engine','hydraulic','transmission','brake','other')),
    replace_date TEXT NOT NULL,
    cost REAL DEFAULT 0,
    current_hours INTEGER DEFAULT 0,
    reason TEXT DEFAULT '',
    operator_id INTEGER,
    remark TEXT DEFAULT '',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`,
  `CREATE TABLE IF NOT EXISTS monthly_ledger (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicle_id INTEGER NOT NULL,
    year_month TEXT NOT NULL,
    fuel_cost REAL DEFAULT 0,
    repair_cost REAL DEFAULT 0,
    parts_cost REAL DEFAULT 0,
    labor_cost REAL DEFAULT 0,
    work_days INTEGER DEFAULT 0,
    total_hours REAL DEFAULT 0,
    mileage REAL DEFAULT 0,
    work_volume REAL DEFAULT 0,
    total_cost REAL DEFAULT 0,
    status TEXT DEFAULT 'draft' CHECK(status IN ('draft','submitted','approved')),
    submitted_by INTEGER,
    approved_by INTEGER,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(vehicle_id, year_month)
  )`,
  `CREATE TABLE IF NOT EXISTS kpi_scores (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicle_id INTEGER NOT NULL,
    year_month TEXT NOT NULL,
    fuel_cost_per_unit REAL DEFAULT 0,
    repair_rate REAL DEFAULT 0,
    utilization_rate REAL DEFAULT 0,
    unit_cost REAL DEFAULT 0,
    availability_rate REAL DEFAULT 0,
    safety_score REAL DEFAULT 100,
    total_score REAL DEFAULT 0,
    rank INTEGER DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(vehicle_id, year_month)
  )`,
  `CREATE TABLE IF NOT EXISTS kpi_thresholds (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicle_type TEXT NOT NULL,
    kpi_key TEXT NOT NULL,
    upper_limit REAL DEFAULT 0,
    lower_limit REAL DEFAULT 0,
    penalty_amount REAL DEFAULT 0,
    reward_amount REAL DEFAULT 0,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(vehicle_type, kpi_key)
  )`,
  `CREATE TABLE IF NOT EXISTS maintenance_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    vehicle_id INTEGER NOT NULL,
    maintenance_date TEXT NOT NULL,
    current_hours REAL DEFAULT 0,
    current_km INTEGER DEFAULT 0,
    maintenance_type TEXT DEFAULT 'regular' CHECK(maintenance_type IN ('regular','major','repair')),
    description TEXT DEFAULT '',
    cost REAL DEFAULT 0,
    parts_info TEXT DEFAULT '[]',
    operator_name TEXT DEFAULT '',
    remark TEXT DEFAULT '',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`,
];

// 修复旧数据
export const DATA_FIXES = [
  "UPDATE users SET status = 1 WHERE status = '' OR status IS NULL",
  "UPDATE repair_shops SET status = 1 WHERE status = '' OR status IS NULL",
  "UPDATE departments SET status = 1 WHERE status = '' OR status IS NULL",
];

export function runColumnMigrations(db: DB): void {
  for (const sql of COLUMN_MIGRATIONS) {
    try { db.exec(sql); } catch (_) { /* 列/表已存在 */ }
  }
}

export function runTableMigrations(db: DB): void {
  for (const sql of [...TABLE_MIGRATIONS, ...LEDGER_TABLES]) {
    try { db.exec(sql); } catch (_) { /* 表已存在 */ }
  }
}

export function runDataFixes(db: DB): void {
  for (const sql of DATA_FIXES) {
    try { db.exec(sql); } catch (_) { /* ignore */ }
  }
}

export function runRoleMigration(db: DB): void {
  const allRoles = "'driver','repair_shop','leader','admin','safety_officer','dispatcher','applicant'";
  let needsUserMigration = false;
  try {
    db.exec("INSERT INTO users (name, phone, role) VALUES ('_migration_test_', '_migration_test_', 'dispatcher')");
    db.exec("DELETE FROM users WHERE phone = '_migration_test_'");
  } catch (_) { needsUserMigration = true; }
  if (!needsUserMigration) {
    try {
      db.exec("INSERT INTO users (name, phone, role) VALUES ('_migration_test_', '_migration_test_', 'applicant')");
      db.exec("DELETE FROM users WHERE phone = '_migration_test_'");
    } catch (_) { needsUserMigration = true; }
  }
  if (needsUserMigration) {
    console.log('[DB] Migrating users table to support new roles...');
    db.exec(`
      CREATE TABLE IF NOT EXISTS users_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT DEFAULT '',
        role TEXT NOT NULL CHECK(role IN (${allRoles})),
        repair_shop_id INTEGER,
        department_id INTEGER,
        avatar_url TEXT DEFAULT '',
        status INTEGER DEFAULT 1,
        password TEXT DEFAULT '',
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      );
      INSERT INTO users_new SELECT * FROM users;
      DROP TABLE users;
      ALTER TABLE users_new RENAME TO users;
    `);
    console.log('[DB] Users table migrated successfully');
  }
}

export function runMachineryMigration(db: DB): void {
  const maCols = db.prepare("PRAGMA table_info('machinery_applications')").all() as Record<string, unknown>[];
  if (maCols.length > 0) {
    const hasNewFields = maCols.some(c => c.name === 'applicant_dept');
    if (!hasNewFields) {
      console.log('[DB] Migrating machinery_applications table (old format)...');
      db.exec('DROP TABLE IF EXISTS machinery_applications');
    } else if (!maCols.some(c => c.name === 'application_type')) {
      try { db.exec("ALTER TABLE machinery_applications ADD COLUMN application_type TEXT DEFAULT 'short_term' CHECK(application_type IN ('short_term','long_term'))"); } catch (_) { /* ignore */ }
    }
    if (maCols.length > 0 && !maCols.some(c => c.name === 'vehicle_type')) {
      try { db.exec("ALTER TABLE machinery_applications ADD COLUMN vehicle_type TEXT DEFAULT ''"); } catch (_) { /* ignore */ }
    }
  }
  db.exec(`CREATE TABLE IF NOT EXISTS machinery_applications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    application_no TEXT NOT NULL UNIQUE,
    applicant_id INTEGER NOT NULL,
    applicant_dept TEXT DEFAULT '',
    applicant_name TEXT DEFAULT '',
    applicant_phone TEXT DEFAULT '',
    vehicle_type TEXT DEFAULT '',
    application_type TEXT DEFAULT 'short_term' CHECK(application_type IN ('short_term','long_term')),
    scheduled_start TEXT DEFAULT '',
    scheduled_end TEXT DEFAULT '',
    work_location TEXT DEFAULT '',
    work_altitude TEXT DEFAULT '',
    work_purpose TEXT DEFAULT '',
    is_hazardous INTEGER DEFAULT 0,
    urgency TEXT DEFAULT 'normal' CHECK(urgency IN ('normal','urgent','emergency')),
    briefing_method TEXT DEFAULT '',
    briefing_files TEXT DEFAULT '[]',
    status TEXT DEFAULT 'pending' CHECK(status IN ('pending','assigned','in_progress','completed','early_completed','cancelled')),
    assigned_vehicle_id INTEGER,
    assigned_driver_id INTEGER,
    dispatcher_id INTEGER,
    actual_end_time TEXT DEFAULT '',
    settlement_end_time TEXT DEFAULT '',
    working_hours REAL DEFAULT 0,
    hourly_rate REAL DEFAULT 0,
    total_cost REAL DEFAULT 0,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);
}

export function seedKpiThresholds(db: DB): void {
  const thresholdCount = db.prepare('SELECT COUNT(*) as c FROM kpi_thresholds').get() as { c: number };
  if (thresholdCount.c > 0) return;

  const vehicleTypes = ['挖掘机', '装载机', '矿用卡车', '推土机'];
  const kpiKeys = ['fuel_cost_per_unit','repair_rate','utilization_rate','unit_cost','availability_rate','safety_score'];
  const defaults: Record<string, Record<string, [number,number,number,number]>> = {
    '挖掘机': { fuel_cost_per_unit:[150,80,300,200], repair_rate:[10,3,500,300], utilization_rate:[85,60,200,150], unit_cost:[120,50,300,200], availability_rate:[95,80,200,150], safety_score:[90,100,500,300] },
    '装载机': { fuel_cost_per_unit:[120,60,300,200], repair_rate:[8,2,500,300], utilization_rate:[85,60,200,150], unit_cost:[100,40,300,200], availability_rate:[95,80,200,150], safety_score:[90,100,500,300] },
    '矿用卡车': { fuel_cost_per_unit:[200,100,300,200], repair_rate:[12,4,500,300], utilization_rate:[80,55,200,150], unit_cost:[150,60,300,200], availability_rate:[90,75,200,150], safety_score:[90,100,500,300] },
    '推土机': { fuel_cost_per_unit:[130,70,300,200], repair_rate:[10,3,500,300], utilization_rate:[85,60,200,150], unit_cost:[110,45,300,200], availability_rate:[95,80,200,150], safety_score:[90,100,500,300] },
  };
  for (const vt of vehicleTypes) {
    for (const kk of kpiKeys) {
      const [up, low, p, r] = defaults[vt][kk];
      db.prepare('INSERT INTO kpi_thresholds (vehicle_type, kpi_key, upper_limit, lower_limit, penalty_amount, reward_amount) VALUES (?,?,?,?,?,?)').run(vt, kk, up, low, p, r);
    }
  }
  console.log('[DB] KPI thresholds seeded');
}

export function runKpiMigration(db: DB): void {
  try { db.exec("UPDATE kpi_thresholds SET vehicle_type = '履带挖掘机' WHERE vehicle_type = '挖掘机'"); } catch (_) { /* ignore */ }
  try { db.exec("DELETE FROM kpi_thresholds WHERE vehicle_type IN ('矿用卡车','推土机')"); } catch (_) { /* ignore */ }
}

export function seedConfigDefaults(db: DB): void {
  const fuelCfg = db.prepare("SELECT id FROM system_config WHERE config_key = 'fuel_unit_price'").get();
  if (!fuelCfg) {
    db.prepare("INSERT INTO system_config (config_key, config_value) VALUES ('fuel_unit_price', '8.5')").run();
    console.log('[DB] Fuel unit price seeded (8.5 元/升)');
  }
  const wdCfg = db.prepare("SELECT id FROM system_config WHERE config_key = 'monthly_work_days'").get();
  if (!wdCfg) {
    db.prepare("INSERT INTO system_config (config_key, config_value) VALUES ('monthly_work_days', '26')").run();
  }
}
