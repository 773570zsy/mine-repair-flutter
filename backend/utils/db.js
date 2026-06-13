const initSqlJs = require('sql.js');
const fs = require('fs');
const path = require('path');

const dbPath = path.join(__dirname, '..', 'data', 'mine_repair.db');
const dataDir = path.dirname(dbPath);
if (!fs.existsSync(dataDir)) fs.mkdirSync(dataDir, { recursive: true });

let db = null;

// SQL脚本
const SCHEMA_SQL = `
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    phone TEXT DEFAULT '',
    role TEXT NOT NULL CHECK(role IN ('driver','repair_shop','leader','admin','external','external_approver','safety_officer')),
    repair_shop_id INTEGER,
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
    remark TEXT DEFAULT '',
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
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  );
`;

// 初始化数据库
async function initDB() {
  const SQL = await initSqlJs();
  if (fs.existsSync(dbPath)) {
    const buf = fs.readFileSync(dbPath);
    db = new SQL.Database(buf);
  } else {
    db = new SQL.Database();
  }

  db.run('PRAGMA foreign_keys = ON;');
  db.run(SCHEMA_SQL);

  // 兼容旧数据库：添加可能缺失的列
  try { db.run('ALTER TABLE users ADD COLUMN department_id INTEGER'); } catch(e) {}
  try { db.run('ALTER TABLE daily_inspections ADD COLUMN toolkit_check TEXT DEFAULT \'\''); } catch(e) {}
  try { db.run('ALTER TABLE daily_inspections ADD COLUMN start_hours REAL DEFAULT 0'); } catch(e) {}
  try { db.run('ALTER TABLE daily_inspections ADD COLUMN end_hours REAL DEFAULT 0'); } catch(e) {}
  try { db.run('ALTER TABLE daily_inspections ADD COLUMN fuel_amount REAL DEFAULT 0'); } catch(e) {}
  try { db.run('ALTER TABLE daily_inspections ADD COLUMN attendance_symbol TEXT DEFAULT \'\''); } catch(e) {}
  try { db.run('ALTER TABLE daily_inspections ADD COLUMN parking_location TEXT DEFAULT \'\''); } catch(e) {}
  try { db.run('ALTER TABLE daily_inspections ADD COLUMN updated_at DATETIME DEFAULT CURRENT_TIMESTAMP'); } catch(e) {}
  try { db.run('ALTER TABLE departments ADD COLUMN dept_key TEXT DEFAULT \'\''); } catch(e) {}
  try { db.run('ALTER TABLE vehicles ADD COLUMN purchase_date TEXT DEFAULT \'\''); } catch(e) {}
  try { db.run('ALTER TABLE driver_attendance ADD COLUMN overtime_start TEXT DEFAULT \'\''); } catch(e) {}
  try { db.run('ALTER TABLE driver_attendance ADD COLUMN overtime_end TEXT DEFAULT \'\''); } catch(e) {}
  try { db.run('ALTER TABLE parts_requisitions ADD COLUMN vehicle_id INTEGER'); } catch(e) {}
  try { db.run('ALTER TABLE daily_inspections ADD COLUMN photos TEXT DEFAULT \'[]\''); } catch(e) {}
  try { db.run('ALTER TABLE daily_inspections ADD COLUMN videos TEXT DEFAULT \'[]\''); } catch(e) {}
  try { db.run('ALTER TABLE repair_quotes ADD COLUMN damage_photos TEXT DEFAULT \'[]\''); } catch(e) {}
  try { db.run('ALTER TABLE repair_quotes ADD COLUMN new_photos TEXT DEFAULT \'[]\''); } catch(e) {}

  db.run(`CREATE TABLE IF NOT EXISTS driver_attendance (
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
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS quiz_questions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    question TEXT NOT NULL,
    type TEXT DEFAULT 'choice' CHECK(type IN ('choice','truefalse')),
    options TEXT NOT NULL,
    answer TEXT NOT NULL,
    explanation TEXT DEFAULT '',
    category TEXT DEFAULT '安全操作'
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS quiz_results (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    quiz_date TEXT NOT NULL,
    score INTEGER NOT NULL DEFAULT 0,
    total INTEGER NOT NULL DEFAULT 5,
    answers TEXT DEFAULT '[]',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, quiz_date)
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS quiz_likes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    result_id INTEGER NOT NULL,
    user_id INTEGER NOT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(result_id, user_id)
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS safety_incidents (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_no TEXT NOT NULL UNIQUE,
    reporter_id INTEGER NOT NULL,
    location TEXT DEFAULT '',
    incident_time TEXT DEFAULT '',
    description TEXT DEFAULT '',
    severity TEXT DEFAULT '一般' CHECK(severity IN ('轻微','一般','严重','重大')),
    status TEXT DEFAULT 'pending' CHECK(status IN ('pending','investigating','rectifying','closed')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS incident_investigations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id INTEGER NOT NULL,
    investigator_id INTEGER,
    root_cause TEXT DEFAULT '',
    findings TEXT DEFAULT '',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS incident_actions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    incident_id INTEGER NOT NULL,
    action_desc TEXT DEFAULT '',
    responsible_id INTEGER,
    due_date TEXT DEFAULT '',
    completed_at DATETIME,
    status TEXT DEFAULT 'pending' CHECK(status IN ('pending','completed')),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS hazards (
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
    verified_by INTEGER,
    verified_at DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS operation_logs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    user_name TEXT DEFAULT '',
    action TEXT NOT NULL,
    detail TEXT DEFAULT '',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  db.run(`CREATE TABLE IF NOT EXISTS system_config (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    config_key TEXT NOT NULL UNIQUE,
    config_value TEXT DEFAULT '',
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
  )`);

  // 插入默认数据
  const count = db.exec('SELECT COUNT(*) as c FROM users');
  const userCount = count[0]?.values[0]?.[0] || 0;

  if (userCount === 0) {
    db.run("INSERT INTO repair_shops (name, contact_person, contact_phone, remark) VALUES ('西藏桦翔','','','矿山机械综合维修'), ('西藏海陆','','','工程设备专业维修')");
    db.run("INSERT INTO users (name, phone, role, repair_shop_id) VALUES ('张思远','15129505737','admin',null),('张三','13900000001','driver',null),('李四','13900000002','driver',null),('王五','13900000003','driver',null),('桦翔-赵师傅','13900000011','repair_shop',1),('海陆-钱师傅','13900000022','repair_shop',2),('刘科长','13900000099','leader',null),('管理员','13900000000','admin',null),('外部审批员','13900000088','external_approver',null),('安全员','13900000111','safety_officer',null)");
    db.run("UPDATE users SET department_id=-1 WHERE phone='15129505737'");
    db.run("INSERT INTO vehicles (plate_number, vehicle_type, model, maintenance_interval_hours, next_maintenance_hours) VALUES ('矿A-001','挖掘机','小松PC360-7',500,480),('矿A-002','装载机','柳工ZL50CN',500,450),('矿B-003','矿用卡车','北重TR100',500,490),('矿B-004','推土机','山推SD32',500,500)");
    db.run("INSERT INTO driver_vehicle_bindings (driver_id, vehicle_id, bind_date) VALUES (1,1,'2026-05-01'),(1,2,'2026-05-01'),(2,3,'2026-05-01'),(3,4,'2026-05-01')");
    db.run("UPDATE vehicles SET current_driver_id=1 WHERE id=1");
    db.run("UPDATE vehicles SET current_driver_id=1 WHERE id=2");
    db.run("UPDATE vehicles SET current_driver_id=2 WHERE id=3");
    db.run("UPDATE vehicles SET current_driver_id=3 WHERE id=4");
    db.run("INSERT INTO parts_inventory (part_name, part_code, quantity, unit) VALUES ('机油滤芯','JL-001',15,'个'),('柴油滤芯','JL-002',20,'个'),('空气滤芯','JL-003',10,'个'),('液压油','JL-004',8,'桶'),('齿轮油','JL-005',6,'桶'),('刹车片','JL-006',12,'副'),('轮胎','JL-007',4,'条'),('雨刮片','JL-008',20,'个'),('保险丝','JL-009',30,'个'),('反光镜','JL-010',8,'个')");
    db.run("INSERT INTO departments (name, contact_person, contact_phone) VALUES ('总调度室','',''),('西藏桦翔','',''),('西藏海陆','',''),('第一选矿厂精尾车间','',''),('第一选矿厂浮选车间','',''),('第一选矿厂重机班','',''),('第二选矿厂重机班','',''),('甲玛乡尾矿库重机班','',''),('巨龙铜业采矿场','',''),('知不拉铜多金属矿','','')");
    db.run("INSERT INTO users (name, phone, role, department_id) VALUES ('精尾车间','13900000101','external',4),('浮选车间','13900000102','external',5),('第一选重机班','13900000103','external',6),('第二选重机班','13900000104','external',7),('尾矿库重机班','13900000105','external',8),('采矿场','13900000106','external',9),('知不拉铜矿','13900000107','external',10)");
    seedQuizQuestions(db);
    saveDB();
  }
}

function seedQuizQuestions(db) {
  const qs = [
    ['挖掘机作业前，操作人员首先应检查什么？','choice','["液压系统","工作装置","机油液位和冷却液","外观清洁"]','C','机油和冷却液位是每日必检项目。','安全操作'],
    ['装载机在坡道上作业时，铲斗应保持什么状态？','choice','["高举","平放贴近地面","任意位置","朝下翻斗"]','B','坡道作业铲斗平放贴近地面降低重心，防止倾翻。','安全操作'],
    ['矿用卡车下坡时应使用什么制动方式？','choice','["仅脚刹","发动机制动+脚刹","手刹","倒挡制动"]','B','配合发动机制动和脚刹避免刹车过热失效。','安全操作'],
    ['推土机在接近边坡作业时应保持多少安全距离？','choice','["0.5米","1米","2米以上","贴着边"]','C','边坡作业至少保持2米安全距离防止滑坡坠落。','安全操作'],
    ['发动机机油报警灯亮起后应如何处理？','choice','["继续工作","立即停机检查","加点油门","等下班再看"]','B','机油报警必须立即停机检查，继续运转会导致发动机报废。','故障判断'],
    ['发现液压系统漏油时应首先做什么？','choice','["用布擦掉继续干","立即停机并报告","加点液压油继续用","不管它"]','B','液压油泄漏有火灾和污染风险，必须停机报告。','故障判断'],
    ['车辆启动后发现有异常噪音应该怎么做？','choice','["继续工作","立即停机排查原因","加大油门看看","记录但不停机"]','B','异常噪音可能是部件损坏前兆，必须立即排查。','故障判断'],
    ['挖掘机履带张紧度应该多久检查一次？','choice','["一年","一个月","每周或每班前","不用检查"]','C','履带张紧度应每周或每班前检查，过松易脱轨。','日常保养'],
    ['空气滤芯堵塞会导致什么问题？','choice','["动力增加","油耗降低","动力下降冒黑烟","不影响"]','C','空气滤芯堵塞导致进气不足、燃烧不充分。','日常保养'],
    ['柴油滤芯应多久更换一次？','choice','["永远不换","每300小时或按手册","每天换","只清洗不换"]','B','柴油滤芯应每300小时更换确保燃油清洁。','日常保养'],
    ['矿车在弯道行驶时速度不应超过多少？','choice','["60km/h","30km/h","15km/h","随意"]','C','矿区道路复杂弯道限速15km/h确保安全。','安全操作'],
    ['高温天气发动机水温过高首先应怎么做？','choice','["立即打开水箱盖","停机怠速降温","浇冷水","继续工作"]','B','水温高时应停机怠速降温，严禁开盖防烫伤。','故障判断'],
    ['作业人员进入维修区域必须穿戴什么？','choice','["便装","安全帽和反光背心","拖鞋","随意"]','B','矿区维修区域必须穿戴安全帽和反光背心。','安全操作'],
    ['车辆轮胎出现鼓包应如何处理？','choice','["继续用","降低气压继续用","立即更换","等下次检修"]','C','轮胎鼓包有爆胎风险必须立即更换。','故障判断'],
    ['工作结束后车辆应停放在什么位置？','choice','["坡道上","安全平坦处拉手刹","任何地方","路边"]','B','停放应选平坦处拉紧手刹锁好门窗关闭电源。','安全操作'],
    ['灭火器使用的正确顺序是什么？','choice','["喷向火焰顶部","拔销对准按压扫射","直接按压","摇晃后使用"]','B','口诀：拔销、对准根部、按压手柄、扫射灭火。','安全操作'],
    ['发动机机油应多久检查一次？','choice','["一年","只在保养时","每天作业前","故障时"]','C','每日作业前检查机油能避免大部分发动机故障。','日常保养'],
    ['液压系统超压工作会导致什么后果？','choice','["效率提高","油管爆裂密封损坏","没有影响","更省油"]','B','超压会导致油管爆裂密封损坏甚至火灾。','故障判断'],
    ['润滑脂(黄油)加注过多的后果是什么？','choice','["没事","导致油封损坏和浪费","更润滑","不用管"]','B','黄油过多会导致油封胀破造成泄漏和污染。','日常保养'],
    ['粉尘环境中空气滤芯应多久检查一次？','choice','["每月","每周","每天或每班","不用管"]','C','粉尘环境滤芯易堵塞需每天或每班检查。','日常保养'],
    ['车辆涉水后应立即检查什么？','choice','["车身外观","刹车系统和电气线路","轮胎花纹","方向盘"]','B','涉水后刹车可能失灵电气线路可能短路必须立即检查。','安全操作'],
    ['破碎锤正确操作应注意什么？','choice','["随意敲打","钎杆垂直工作面均匀用力","斜着打","用锤头撞墙"]','B','钎杆应垂直于工作面均匀用力斜打会损坏设备。','安全操作'],
    ['驾驶员连续工作超过多少小时应强制休息？','choice','["24小时","12小时","8小时","不用休息"]','B','连续工作不得超过12小时防止疲劳作业。','安全操作'],
    ['刹车失灵时第一反应应该做什么？','choice','["跳车","利用发动机制动和手刹","加速","关发动机"]','B','刹车失灵应利用发动机制动和手刹减速，严禁跳车。','安全操作'],
    ['挖掘机工作半径内允许站人吗？','choice','["允许","不允许","没人的时候可以","无所谓"]','B','挖掘机工作半径内严禁站人是最基本的安全规则。','安全操作'],
    // 公司规章制度
    ['"一分钟安全确认"适用于哪些车辆？','choice','["仅工程机械","矿区大型运输车、工程机械、通勤车等","仅通勤车辆","仅小型车辆"]','B','一分钟安全确认适用于矿区大型运输车辆、工程机械、通勤车辆及复杂条件下的小型车辆。','公司制度'],
    ['驾驶员上车前进行"一分钟安全确认"，正确的方法是？','choice','["直接上车启动","绕车一周检查设备和周边环境","按喇叭即可","只看后视镜"]','B','必须绕车一周检查设备情况，检查周边环境是否有人或障碍物，确认安全方可上车。','公司制度'],
    ['驾驶员确认安全上车后应如何起步？','choice','["立刻起步","鸣笛提醒，启动发动机3秒后起步","直接加速","不用鸣笛"]','B','确认安全后上车鸣笛提醒，启动发动机3秒后起步行驶或作业。','公司制度'],
    ['根据规定，驾驶员未下车，哪种情况需由地面指挥人员进行安全确认？','choice','["正常行驶中","检查维修后重新起步前","停车等人时","加油时"]','B','检查或维修人员在检查修理结束后，重新起步前由检查维修人员确认并向驾驶员发出安全指示。','公司制度'],
    ['重载车辆临时停放在坡道，重新起步前应如何做？','choice','["直接开走","由地面指挥人员确认安全","按喇叭走","加速冲上去"]','B','重载车辆、轮式机械临时停放在坡道，由地面指挥人员确认安全。','公司制度'],
    ['工程机械铲斗提升等待作业时，谁负责安全确认？','choice','["驾驶员自己","地面指挥人员","任何路人","不需要确认"]','B','工程机械铲斗提升等待作业过程中，由地面指挥人员确认安全。','公司制度'],
    ['已设立警戒范围的作业区域，等待装车过程中是否必须进行一分钟安全确认？','choice','["必须做","可不必做","每天做一次","根据心情"]','B','已经设立警戒范围的作业区域，驾驶员必须服从指挥，等待作业过程可不必进行一分钟安全确认。','公司制度'],
    ['"一分钟安全确认"适用于哪种情形？','choice','["仅倒车时","驾驶员重新上车前、视线不明倒车前","仅坡道停车时","仅雨天"]','B','适用于驾驶员重新上车前、视线不明倒车前、停车时间较长需要重新起步等情形。','公司制度'],
    ['工程机械到达作业地点后，第一个步骤是什么？','choice','["立刻开始作业","熄火拉手刹拔钥匙","先检查油水","先鸣笛"]','B','第一步：停车熄火、拉紧手刹、拔出车辆钥匙，斜坡停车还应垫好三角木。','公司制度'],
    ['工程机械停稳后操作人员应做什么安全确认？','choice','["直接开始作业","绕机械一周进行风险辨识","检查油量","给领导汇报"]','B','操作人员应绕工程机械一周，对周围环境全面风险辨识，如高压线、电缆、地面稳固性等。','公司制度'],
    ['安全确认完成后，操作人员必须在影响范围内做什么？','choice','["直接作业","拉设警戒线","离开现场","找工具"]','B','必须在工程机械、车辆施工影响范围内拉设警戒线，禁止无关人员进入警戒区域。','公司制度'],
    ['工程机械作业期间应指派什么人？','choice','["不需要人","专人指挥和现场安全监护","两个驾驶员","维修工"]','B','工程机械作业期间应指派专人指挥和现场安全监护，落实警戒引导责任。','公司制度'],
    ['斜坡停车时除了熄火拉手刹，还应做什么？','choice','["什么都不做","垫好三角木","加大油门","挂倒挡"]','B','斜坡停车除了熄火拉手刹拔出钥匙，还应垫好三角木防止溜车。','公司制度'],
    ['"一分钟安全确认"的核心理念是什么？','choice','["提高速度","先确认安全再操作","节省时间","减少工序"]','B','核心是先确认安全再操作，通过绕车检查和环境确认，防止事故。','公司制度'],
    // 13.1 汽车吊
    ['汽车吊起吊卸运时操作人员是否可以离开？','choice','["可以短期离开","严禁离开","吃饭时可以离开","无所谓"]','B','起吊卸运时必须听从指挥，操作人员不得离开。','汽车吊'],
    ['汽车吊卷筒上的钢丝绳应保留几圈？','choice','["全部放完","至少三圈","一圈","五圈"]','B','不准把卷筒上钢丝绳全部放完，应保留三圈。','汽车吊'],
    ['汽车吊起重作业时能否斜吊斜拉？','choice','["可以","不准斜吊斜拉","偶尔可以","轻物可以"]','B','吊动重物时应先估计好起重高度，不准斜吊斜拉。','汽车吊'],
    ['汽车吊在带电线路附近作业时安全距离至少多少？','choice','["1米","2米","3米","5米"]','C','起重机在带电线路四周工作时，应与其保持安全距离≥3米，雨雾天气加大至1.3倍以上。','汽车吊'],
    ['汽车吊占道作业前必须先做什么？','choice','["直接占道","向管理部门申请审批并做好警戒","先干活再说","通知工友即可"]','B','占道作业时必须向管理部门申请，经审批同意后方可作业并做好现场警戒。','汽车吊'],
    // 13.2 装载机
    ['装载机启动时间不应超过多少秒？','choice','["10秒","5秒","3秒","15秒"]','B','启动时间不应超过5秒，前后两次启动间隔不少于2分钟，严禁长时间启动以免烧毁马达。','装载机'],
    ['装载机待气压达到多少以上方可起步？','choice','["2公斤","3公斤","4.5公斤","6公斤"]','C','待气压达到4.5公斤以上方可起步。','装载机'],
    ['装载机铲装作业时车速不超过多少？','choice','["10公里/小时","4公里/小时","8公里/小时","20公里/小时"]','A','铲装作业车速不超过4公里/小时，装卸物料动作缓和低卸轻放。','装载机'],
    ['装载机拖动物体时钢丝绳长度不应小于几米？','choice','["2米","3米","5米","10米"]','C','拖动物体时钢丝绳长度不应小于5米，应拴在铲斗铰点上。','装载机'],
    ['装载机驾驶室可以搭乘人员吗？','choice','["可以","严禁搭乘","没人看见时可以","偶尔可以"]','B','驾驶室、铲斗等任何部位严禁搭乘人员，严禁发动机熄火和空挡滑行。','装载机'],
    // 13.3 挖掘机
    ['挖掘机铲装作业安全防护沟的标准是？','choice','["深1米上宽2米","深1.8米上宽3米","深2米上宽4米","不需要"]','B','铲装作业时要做好安全防护沟深1.8米上宽3米或作业平台高不低于2米，严禁掏采洞采。','挖掘机'],
    ['挖掘机装车时卸料高度不应高于多少？','choice','["1米","50公分","2米","无所谓"]','B','装车时卸料高度不高于50公分，不得铲装超过2米长度的大块岩石。','挖掘机'],
    ['两台挖掘机上下台阶作业时安全间距不得小于多少？','choice','["20米","30米","50米","100米"]','C','两台挖掘机上下台阶及同台阶作业时作业间距不得小于50米。','挖掘机'],
    ['挖掘机铲斗能否从车辆驾驶室上方通过？','choice','["可以","禁止","快速通过可以","空斗可以"]','B','禁止铲斗从车辆的驾驶室上方通过，防止落物伤人。','挖掘机'],
    ['挖掘机检查或维护保养时发动机应处于什么状态？','choice','["怠速","熄火","高速","无所谓"]','B','检查或维护保养时必须熄火，确保安全。','挖掘机'],
    ['挖掘机启动前检查过程有什么特殊要求？','choice','["不需要记录","录制视频备查并填写安全确认表","口头汇报即可","拍照即可"]','B','检查过程必须录制视频备查并如实填写安全确认表。','挖掘机'],
    // 13.4 压路机
    ['振动压路机在改变行驶方向或减速前应先做什么？','choice','["加速","停止振动","按喇叭","熄火"]','B','振动压路机在改变行驶方向、减速或停驶前应先停止振动。','压路机'],
    ['压路机能在惯性滚动的状况下变换方向吗？','choice','["可以","不允许","急弯可以","慢弯可以"]','B','必须在规定碾压段外转向，应平稳改变运行方向，不允许惯性滚动时变换方向。','压路机']
  ];
  qs.forEach(function(q) {
    db.run("INSERT INTO quiz_questions (question,type,options,answer,explanation,category) VALUES ('" + q[0].replace(/'/g,"''") + "','" + q[1] + "','" + q[2].replace(/'/g,"''") + "','" + q[3] + "','" + q[4].replace(/'/g,"''") + "','" + q[5] + "')");
  });
}

function saveDB() {
  const data = db.export();
  const buffer = Buffer.from(data);
  fs.writeFileSync(dbPath, buffer);
}

// 查询辅助
function query(sql, params = []) {
  const stmt = db.prepare(sql);
  if (params.length) stmt.bind(params);
  const isSelect = sql.trim().toUpperCase().startsWith('SELECT') || sql.trim().toUpperCase().startsWith('WITH');
  if (isSelect) {
    const rows = [];
    while (stmt.step()) rows.push(stmt.getAsObject());
    stmt.free();
    return rows;
  } else {
    stmt.step();
    const changes = db.getRowsModified();
    const lastID = db.exec("SELECT last_insert_rowid()")[0]?.values[0]?.[0] || 0;
    stmt.free();
    saveDB();
    return { lastInsertRowid: lastID, changes };
  }
}

function queryOne(sql, params = []) {
  const rows = query(sql, params);
  return rows.length > 0 ? rows[0] : null;
}

module.exports = { initDB, query, queryOne, saveDB };
