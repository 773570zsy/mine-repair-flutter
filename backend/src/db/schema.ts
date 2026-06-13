// 数据库完整Schema（与旧系统兼容）
export const SCHEMA_SQL = `
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  phone TEXT DEFAULT '',
  role TEXT NOT NULL CHECK(role IN ('driver','repair_shop','leader','admin','safety_officer','dispatcher','applicant','external_repair')),
  repair_shop_id INTEGER,
  department_id INTEGER,
  avatar_url TEXT DEFAULT '',
  status INTEGER DEFAULT 1,
  password TEXT DEFAULT '',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS repair_shops (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  contact_person TEXT DEFAULT '',
  contact_phone TEXT DEFAULT '',
  remark TEXT DEFAULT '',
  status INTEGER DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vehicles (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  plate_number TEXT NOT NULL UNIQUE,
  vehicle_type TEXT DEFAULT '',
  model TEXT DEFAULT '',
  buy_date TEXT DEFAULT '',
  current_driver_id INTEGER,
  status TEXT DEFAULT 'normal' CHECK(status IN ('normal','repairing','scrapped')),
  next_maintenance_hours INTEGER DEFAULT 0,
  maintenance_interval_hours INTEGER DEFAULT 500,
  initial_engine_hours INTEGER DEFAULT 0,
  purchase_date TEXT DEFAULT '',
  asset_value REAL DEFAULT 0,
  hourly_rate REAL DEFAULT 0,
  remark TEXT DEFAULT '',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vehicle_archives (
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
  maintenance_interval_km INTEGER DEFAULT 0,
  next_maintenance_km INTEGER DEFAULT 0,
  current_km INTEGER DEFAULT 0,
  purchase_date TEXT DEFAULT '',
  has_behavior_monitor INTEGER DEFAULT 0,
  has_360_camera INTEGER DEFAULT 0,
  hourly_rate REAL DEFAULT 0,
  photos TEXT DEFAULT '[]',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS driver_vehicle_bindings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  driver_id INTEGER NOT NULL,
  vehicle_id INTEGER NOT NULL,
  bind_date TEXT NOT NULL,
  unbind_date TEXT,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS repair_orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_no TEXT NOT NULL UNIQUE,
  vehicle_id INTEGER NOT NULL,
  driver_id INTEGER NOT NULL,
  repair_shop_id INTEGER,
  fault_description TEXT DEFAULT '',
  fault_images TEXT DEFAULT '[]',
  status TEXT DEFAULT 'pending_accept' CHECK(status IN (
    'pending_accept','pending_quote','pending_approval',
    'approved','rejected','repairing','completed','accepted','cancelled'
  )),
  reject_reason TEXT DEFAULT '',
  is_urgent INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS repair_quotes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  repair_shop_id INTEGER NOT NULL,
  quote_amount REAL NOT NULL DEFAULT 0,
  parts_cost REAL DEFAULT 0,
  labor_cost REAL DEFAULT 0,
  hours_cost REAL DEFAULT 0,
  parts_list TEXT DEFAULT '[]',
  quote_detail TEXT DEFAULT '',
  estimated_days INTEGER,
  damage_photos TEXT DEFAULT '[]',
  new_photos TEXT DEFAULT '[]',
  leader_id INTEGER,
  approved_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS repair_progress (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  action TEXT NOT NULL,
  content TEXT DEFAULT '',
  images TEXT DEFAULT '[]',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS external_repair_orders (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_no TEXT NOT NULL UNIQUE,
  department_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  repair_shop_id INTEGER,
  vehicle_name TEXT DEFAULT '',
  fault_description TEXT DEFAULT '',
  fault_images TEXT DEFAULT '[]',
  status TEXT DEFAULT 'pending_accept' CHECK(status IN (
    'pending_accept','pending_approval','approved','rejected','repairing','completed','accepted','cancelled'
  )),
  quote_amount REAL DEFAULT 0,
  parts_cost REAL DEFAULT 0,
  labor_cost REAL DEFAULT 0,
  hours_cost REAL DEFAULT 0,
  parts_list TEXT DEFAULT '[]',
  quote_detail TEXT DEFAULT '',
  estimated_days INTEGER,
  reject_reason TEXT DEFAULT '',
  is_urgent INTEGER DEFAULT 0,
  leader_id INTEGER,
  approved_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS external_repair_progress (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  order_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  action TEXT NOT NULL,
  content TEXT DEFAULT '',
  images TEXT DEFAULT '[]',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS daily_inspections (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  vehicle_id INTEGER NOT NULL,
  driver_id INTEGER NOT NULL,
  inspection_date TEXT NOT NULL,
  oil_level TEXT DEFAULT '',
  coolant_level TEXT DEFAULT '',
  appearance TEXT DEFAULT '',
  tire_condition TEXT DEFAULT '',
  toolkit_check TEXT DEFAULT '',
  overall_status TEXT DEFAULT 'normal',
  abnormal_desc TEXT DEFAULT '',
  notes TEXT DEFAULT '',
  engine_hours INTEGER DEFAULT 0,
  start_hours REAL DEFAULT 0,
  end_hours REAL DEFAULT 0,
  fuel_amount REAL DEFAULT 0,
  attendance_symbol TEXT DEFAULT '',
  parking_location TEXT DEFAULT '',
  start_km REAL DEFAULT 0,
  current_km REAL DEFAULT 0,
  photos TEXT DEFAULT '[]',
  videos TEXT DEFAULT '[]',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS parts_inventory (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  part_name TEXT NOT NULL,
  part_code TEXT DEFAULT '',
  quantity INTEGER DEFAULT 0,
  unit TEXT DEFAULT '个',
  unit_price REAL DEFAULT 0,
  threshold INTEGER DEFAULT 5,
  remark TEXT DEFAULT '',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS parts_requisitions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  part_id INTEGER NOT NULL,
  vehicle_id INTEGER,
  quantity INTEGER NOT NULL DEFAULT 1,
  reason TEXT DEFAULT '',
  status TEXT DEFAULT 'pending' CHECK(status IN ('pending','approved','completed','rejected')),
  approved_by INTEGER,
  picked_up_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  content TEXT DEFAULT '',
  order_id INTEGER,
  is_read INTEGER DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS departments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE,
  contact_person TEXT DEFAULT '',
  contact_phone TEXT DEFAULT '',
  dept_key TEXT DEFAULT '',
  status INTEGER DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS driver_attendance (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  driver_id INTEGER NOT NULL,
  attendance_date TEXT NOT NULL,
  attendance_symbol TEXT DEFAULT '',
  overtime_hours REAL DEFAULT 0,
  overtime_start TEXT DEFAULT '',
  overtime_end TEXT DEFAULT '',
  overtime_location TEXT DEFAULT '',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(driver_id, attendance_date)
);

CREATE TABLE IF NOT EXISTS assessments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  assess_no TEXT NOT NULL,
  issuer_id INTEGER NOT NULL,
  target_id INTEGER NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  content TEXT DEFAULT '',
  assess_type TEXT DEFAULT '通报' CHECK(assess_type IN ('表扬','通报','警告','处罚')),
  photos TEXT DEFAULT '[]',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS quiz_questions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  question TEXT NOT NULL,
  type TEXT DEFAULT 'choice' CHECK(type IN ('choice','truefalse')),
  options TEXT NOT NULL,
  answer TEXT NOT NULL,
  explanation TEXT DEFAULT '',
  category TEXT DEFAULT '安全操作'
);

CREATE TABLE IF NOT EXISTS quiz_results (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  quiz_date TEXT NOT NULL,
  score INTEGER NOT NULL DEFAULT 0,
  total INTEGER NOT NULL DEFAULT 5,
  answers TEXT DEFAULT '[]',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, quiz_date)
);

CREATE TABLE IF NOT EXISTS quiz_likes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  target_user_id INTEGER NOT NULL,
  liker_user_id INTEGER NOT NULL,
  month TEXT NOT NULL,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(target_user_id, liker_user_id, month)
);

CREATE TABLE IF NOT EXISTS hazards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  hazard_no TEXT NOT NULL UNIQUE,
  reporter_id INTEGER NOT NULL,
  location TEXT DEFAULT '',
  description TEXT DEFAULT '',
  severity TEXT DEFAULT '一般' CHECK(severity IN ('低','一般','高','紧急')),
  responsible_id INTEGER,
  deadline TEXT DEFAULT '',
  status TEXT DEFAULT 'reported' CHECK(status IN ('reported','assigned','rectifying','completed','verified')),
  photos_before TEXT DEFAULT '[]',
  photos_after TEXT DEFAULT '[]',
  rectify_desc TEXT DEFAULT '',
  reject_reason TEXT DEFAULT '',
  verified_by INTEGER,
  verified_at DATETIME,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS safety_incidents (
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
);

CREATE TABLE IF NOT EXISTS system_config (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  config_key TEXT NOT NULL UNIQUE,
  config_value TEXT DEFAULT '',
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ==================== 工程机械申请与指派 ====================

CREATE TABLE IF NOT EXISTS machinery_applications (
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
);

-- ==================== 单车核算模块 ====================

CREATE TABLE IF NOT EXISTS fuel_records (
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
);

CREATE TABLE IF NOT EXISTS part_replacements (
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
);

CREATE TABLE IF NOT EXISTS monthly_ledger (
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
  hourly_fuel_consumption REAL DEFAULT 0,
  revenue REAL DEFAULT 0,
  profit REAL DEFAULT 0,
  status TEXT DEFAULT 'draft' CHECK(status IN ('draft','submitted','approved')),
  submitted_by INTEGER,
  approved_by INTEGER,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(vehicle_id, year_month)
);

CREATE TABLE IF NOT EXISTS kpi_scores (
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
);

CREATE TABLE IF NOT EXISTS kpi_thresholds (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  vehicle_type TEXT NOT NULL,
  kpi_key TEXT NOT NULL,
  upper_limit REAL DEFAULT 0,
  lower_limit REAL DEFAULT 0,
  penalty_amount REAL DEFAULT 0,
  reward_amount REAL DEFAULT 0,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(vehicle_type, kpi_key)
);

-- ==================== 维修预算管理 ====================

CREATE TABLE IF NOT EXISTS budget_vehicle_config (
  vehicle_type TEXT PRIMARY KEY,
  annual_increase_rate REAL DEFAULT 0.05,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS vehicle_budget_baseline (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  vehicle_id INTEGER NOT NULL,
  base_year TEXT NOT NULL,
  total_annual_cost REAL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(vehicle_id, base_year)
);

CREATE TABLE IF NOT EXISTS vehicle_monthly_budget (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  vehicle_id INTEGER NOT NULL,
  year_month TEXT NOT NULL,
  budget_amount REAL DEFAULT 0,
  actual_amount REAL DEFAULT 0,
  variance REAL DEFAULT 0,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(vehicle_id, year_month)
);

-- ==================== 保养管理 ====================

CREATE TABLE IF NOT EXISTS maintenance_records (
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
);

-- ==================== 天气预警系统 ====================

CREATE TABLE IF NOT EXISTS weather_zones (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  zone_name TEXT NOT NULL,
  zone_code TEXT NOT NULL UNIQUE,
  latitude REAL DEFAULT 0,
  longitude REAL DEFAULT 0,
  altitude TEXT DEFAULT '',
  description TEXT DEFAULT '',
  status INTEGER DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS weather_data (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  zone_id INTEGER NOT NULL,
  source TEXT DEFAULT 'api' CHECK(source IN ('api','sensor','manual')),
  data_type TEXT NOT NULL,
  value REAL NOT NULL,
  unit TEXT DEFAULT '',
  recorded_at TEXT NOT NULL,
  raw_data TEXT DEFAULT '',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS weather_thresholds (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  zone_id INTEGER,
  weather_type TEXT NOT NULL,
  level TEXT NOT NULL CHECK(level IN ('blue','yellow','orange','red')),
  threshold_value REAL NOT NULL,
  threshold_unit TEXT DEFAULT '',
  duration_minutes INTEGER DEFAULT 30,
  enabled INTEGER DEFAULT 1,
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS weather_warnings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  warning_no TEXT NOT NULL UNIQUE,
  zone_id INTEGER NOT NULL,
  weather_type TEXT NOT NULL,
  level TEXT NOT NULL CHECK(level IN ('blue','yellow','orange','red')),
  title TEXT NOT NULL,
  description TEXT DEFAULT '',
  measured_value REAL,
  measured_unit TEXT DEFAULT '',
  status TEXT DEFAULT 'active' CHECK(status IN ('active','acknowledged','resolved','cancelled')),
  triggered_at TEXT NOT NULL,
  resolved_at TEXT,
  resolved_by INTEGER,
  auto_actions TEXT DEFAULT '[]',
  created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS weather_warning_actions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  warning_id INTEGER NOT NULL,
  action_type TEXT NOT NULL,
  action_detail TEXT DEFAULT '',
  executed_by INTEGER,
  executed_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  result TEXT DEFAULT ''
);
`;

// 初始化种子数据
export const SEED_SQL = `
INSERT INTO repair_shops (name, contact_person, contact_phone, remark) VALUES
  ('西藏桦翔','','','矿山机械综合维修'),
  ('西藏海陆','','','工程设备专业维修');

INSERT INTO users (name, phone, password, role, repair_shop_id) VALUES
  ('张思远','15129505737','8fa34d04f1f403fa9eb20e2ef6403f9b4f088af09abbf6ff42e60a6e7a7f80f8','admin',null),
  ('张三','13900000001','8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92','driver',null),
  ('李四','13900000002','8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92','driver',null),
  ('王五','13900000003','8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92','driver',null),
  ('桦翔-赵师傅','13900000011','8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92','repair_shop',1),
  ('海陆-钱师傅','13900000022','8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92','repair_shop',2),
  ('刘科长','13900000099','8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92','leader',null),
  ('管理员','13900000000','8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92','admin',null),
  ('安全员','13900000111','8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92','safety_officer',null),
  ('调度员','13900000123','8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92','dispatcher',null),
  ('申请人','13900000222','8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92','applicant',null);

UPDATE users SET department_id=-1 WHERE phone='15129505737';

-- 测试车辆已清空，请通过"在编车辆档案"页面录入正式车辆

INSERT INTO parts_inventory (part_name, part_code, quantity, unit) VALUES
  ('机油滤芯','JL-001',15,'个'),('柴油滤芯','JL-002',20,'个'),('空气滤芯','JL-003',10,'个'),
  ('液压油','JL-004',8,'桶'),('齿轮油','JL-005',6,'桶'),('刹车片','JL-006',12,'副'),
  ('轮胎','JL-007',4,'条'),('雨刮片','JL-008',20,'个'),('保险丝','JL-009',30,'个'),('反光镜','JL-010',8,'个');

INSERT INTO departments (name, contact_person, contact_phone) VALUES
  ('总调度室','',''),('西藏桦翔','',''),('西藏海陆','',''),
  ('调度室重机一班','',''),('调度室重机二班','','');

-- KPI阈值默认数据（按车型配置）
-- 车型列表: 履带挖掘机, 装载机, 轮式挖掘机, 汽车吊, 吊车
INSERT OR IGNORE INTO kpi_thresholds (vehicle_type, kpi_key, upper_limit, lower_limit, penalty_amount, reward_amount) VALUES
  ('履带挖掘机','fuel_cost_per_unit',150,80,300,200),
  ('履带挖掘机','repair_rate',10,3,500,300),
  ('履带挖掘机','utilization_rate',85,60,200,150),
  ('履带挖掘机','unit_cost',120,50,300,200),
  ('履带挖掘机','availability_rate',95,80,200,150),
  ('履带挖掘机','safety_score',90,100,500,300),
  ('装载机','fuel_cost_per_unit',120,60,300,200),
  ('装载机','repair_rate',8,2,500,300),
  ('装载机','utilization_rate',85,60,200,150),
  ('装载机','unit_cost',100,40,300,200),
  ('装载机','availability_rate',95,80,200,150),
  ('装载机','safety_score',90,100,500,300),
  ('轮式挖掘机','fuel_cost_per_unit',130,65,300,200),
  ('轮式挖掘机','repair_rate',9,3,500,300),
  ('轮式挖掘机','utilization_rate',85,60,200,150),
  ('轮式挖掘机','unit_cost',110,45,300,200),
  ('轮式挖掘机','availability_rate',95,80,200,150),
  ('轮式挖掘机','safety_score',90,100,500,300),
  ('汽车吊','fuel_cost_per_unit',100,50,300,200),
  ('汽车吊','repair_rate',6,2,500,300),
  ('汽车吊','utilization_rate',80,55,200,150),
  ('汽车吊','unit_cost',90,35,300,200),
  ('汽车吊','availability_rate',95,80,200,150),
  ('汽车吊','safety_score',90,100,500,300),
  ('吊车','fuel_cost_per_unit',100,50,300,200),
  ('吊车','repair_rate',6,2,500,300),
  ('吊车','utilization_rate',80,55,200,150),
  ('吊车','unit_cost',90,35,300,200),
  ('吊车','availability_rate',95,80,200,150),
  ('吊车','safety_score',90,100,500,300);

-- 默认天气预警区域（巨龙铜矿实地坐标）
INSERT OR IGNORE INTO weather_zones (zone_name, zone_code, latitude, longitude, altitude, description) VALUES
  ('甲马乡生活区','ZONE-001',29.77,91.65,'~3800m','矿区生活及办公区域'),
  ('甲玛乡尾矿库','ZONE-002',29.77,91.66,'~4190m','一期甲玛沟尾矿库'),
  ('驱龙第一选矿厂','ZONE-003',29.69,91.61,'~4300m','一期选矿工业场地'),
  ('K28路段','ZONE-004',29.64,91.60,'~4500m','矿区运输主干道K28'),
  ('第二选矿厂','ZONE-005',29.61,91.59,'~4500m','二期选矿工业场地'),
  ('知不拉铜多金属矿','ZONE-006',29.59,91.61,'~5050m','知不拉矿区采场'),
  ('三号排土场','ZONE-007',29.63,91.57,'~4700m','废石排放区域'),
  ('德庆普尾矿库','ZONE-008',29.62,91.56,'~5218m','二期德庆普尾矿库');

-- 默认天气预警阈值（全局默认，zone_id=NULL，基于中国气象局标准）
-- 暴雨: 1小时降雨量(mm/h)
INSERT OR IGNORE INTO weather_thresholds (zone_id, weather_type, level, threshold_value, threshold_unit, duration_minutes) VALUES
  (NULL,'rainstorm','blue',15,'mm/h',60),
  (NULL,'rainstorm','yellow',30,'mm/h',60),
  (NULL,'rainstorm','orange',50,'mm/h',60),
  (NULL,'rainstorm','red',70,'mm/h',60);

-- 大风: 平均风速(m/s)
INSERT OR IGNORE INTO weather_thresholds (zone_id, weather_type, level, threshold_value, threshold_unit, duration_minutes) VALUES
  (NULL,'strong_wind','blue',10.8,'m/s',30),
  (NULL,'strong_wind','yellow',17.2,'m/s',30),
  (NULL,'strong_wind','orange',24.5,'m/s',30),
  (NULL,'strong_wind','red',32.7,'m/s',30);

-- 暴雪: 12小时降雪量(mm)
INSERT OR IGNORE INTO weather_thresholds (zone_id, weather_type, level, threshold_value, threshold_unit, duration_minutes) VALUES
  (NULL,'snowstorm','blue',4,'mm/12h',720),
  (NULL,'snowstorm','yellow',6,'mm/12h',720),
  (NULL,'snowstorm','orange',10,'mm/12h',720),
  (NULL,'snowstorm','red',15,'mm/12h',720);

-- 沙尘暴: 能见度(m)
INSERT OR IGNORE INTO weather_thresholds (zone_id, weather_type, level, threshold_value, threshold_unit, duration_minutes) VALUES
  (NULL,'sandstorm','blue',3000,'m',30),
  (NULL,'sandstorm','yellow',1000,'m',30),
  (NULL,'sandstorm','orange',500,'m',30),
  (NULL,'sandstorm','red',50,'m',30);

-- 雷电: 10分钟内闪电次数
INSERT OR IGNORE INTO weather_thresholds (zone_id, weather_type, level, threshold_value, threshold_unit, duration_minutes) VALUES
  (NULL,'thunderstorm','blue',1,'strikes/10min',10),
  (NULL,'thunderstorm','yellow',10,'strikes/10min',10),
  (NULL,'thunderstorm','orange',30,'strikes/10min',10),
  (NULL,'thunderstorm','red',100,'strikes/10min',10);

-- 低能见度/大雾: 能见度(m)
INSERT OR IGNORE INTO weather_thresholds (zone_id, weather_type, level, threshold_value, threshold_unit, duration_minutes) VALUES
  (NULL,'low_visibility','blue',1000,'m',30),
  (NULL,'low_visibility','yellow',500,'m',30),
  (NULL,'low_visibility','orange',200,'m',30),
  (NULL,'low_visibility','red',50,'m',30);

-- 维修预算车型默认配置（年增幅率 5%）
INSERT OR IGNORE INTO budget_vehicle_config (vehicle_type, annual_increase_rate) VALUES
  ('履带挖掘机',0.05),('轮式挖掘机',0.05),('压路机',0.05),('装载机',0.05),('平地机',0.05),
  ('夹爪机',0.05),('汽车吊',0.05),('25吨吊车',0.05),('50吨吊车',0.05),('70吨吊车',0.05),
  ('100吨吊车',0.05),('200吨吊车',0.05),('300吨吊车',0.05),('500吨履带吊',0.05),('登高车',0.05);

-- 系统配置：天气API默认值（Open-Meteo免费API，无需Key）
INSERT OR IGNORE INTO system_config (config_key, config_value) VALUES
  ('weather_api_url','https://api.open-meteo.com/v1/forecast'),
  ('weather_sensor_token','sensor_token_change_me'),
  ('weather_poll_interval_minutes','10');
`;
