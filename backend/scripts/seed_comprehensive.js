/**
 * 综合数据灌入脚本 — 覆盖所有模块的逼真测试数据
 * 用法: node scripts/seed_comprehensive.js
 */
const initSqlJs = require('sql.js');
const fs = require('fs');

function rand(min, max) { return Math.floor(Math.random() * (max - min + 1)) + min; }
function pick(arr) { return arr[rand(0, arr.length - 1)]; }
function fmtDate(y, m, d) { return `${y}-${String(m).padStart(2, '0')}-${String(d).padStart(2, '0')}`; }
function now() { return new Date().toISOString().slice(0, 19).replace('T', ' '); }

(async () => {
  const SQL = await initSqlJs();
  const buf = fs.readFileSync('data/mine_repair.db');
  const db = new SQL.Database(buf);
  const t = now();

  // ============ 先清空测试数据（保留基础配置和用户） ============
  console.log('清理旧测试数据...');
  const tables = ['repair_quotes','repair_progress','repair_orders',
    'external_repair_progress','external_repair_orders',
    'machinery_applications','daily_inspections','driver_attendance',
    'parts_requisitions','hazards','assessments',
    'fuel_records','part_replacements','monthly_ledger','kpi_scores',
    'notifications','weather_data','weather_warnings','weather_warning_actions'];
  for (const t of tables) {
    db.run(`DELETE FROM ${t}`);
    db.run(`DELETE FROM sqlite_sequence WHERE name='${t}'`);
  }
  // 保留配件库存但重置数量
  db.run("UPDATE parts_inventory SET quantity=20 WHERE id IN (1,2,3)");
  db.run("UPDATE parts_inventory SET quantity=10 WHERE id IN (4,5,6)");
  db.run("UPDATE parts_inventory SET quantity=6 WHERE id IN (7,8,9,10)");

  // ============ 添加更多车辆 ============
  console.log('添加车辆...');
  const vehicleData = [
    ['藏A-L0812','履带挖掘机','CAT 390F',28000,5200,800,'总调度室'],
    ['藏A-L0815','装载机','徐工 ZL50G',15000,1800,400,'总调度室'],
    ['藏A-L0818','矿用卡车','同力 TL875',42000,3200,900,'总调度室'],
    ['藏A-L0820','轮式挖掘机','日立 ZX330',22000,3800,650,'总调度室'],
    ['藏A-L0825','推土机','山推 SD32',18000,2800,500,'西藏恒骏'],
  ];
  for (const [plate, vtype, model, hours, km, rate, dept] of vehicleData) {
    db.run(`INSERT OR IGNORE INTO vehicles (plate_number, vehicle_type, model, hourly_rate) VALUES (?,?,?,?)`,
      [plate, vtype, model, rate]);
    const vid = db.exec("SELECT last_insert_rowid()")[0].values[0][0];
    db.run(`INSERT OR IGNORE INTO vehicle_archives (plate_number, department, vehicle_type, model, current_hours, current_km, next_maintenance_hours, maintenance_interval)
      VALUES (?,?,?,?,?,?,?,?)`,
      [plate, dept, vtype, model, hours, km, hours + 500, 500]);
  }
  // 给 KM-TEST 补充数据
  db.run(`UPDATE vehicle_archives SET current_hours=8500, current_km=32000, next_maintenance_hours=9000 WHERE plate_number='KM-TEST'`);

  // ============ 添加更多部门和申请人 ============
  console.log('添加部门...');
  const deptData = [
    ['第一选矿厂重机班','王班长','13900000141'],
    ['第二选矿厂重机班','李班长','13900000142'],
    ['甲玛乡尾矿库重机班','陈班长','13900000143'],
    ['巨龙铜业采矿场','赵队长','13900000144'],
    ['驱龙第一选矿厂','刘工','13900000145'],
  ];
  for (const [name, person, phone] of deptData) {
    db.run(`INSERT OR IGNORE INTO departments (name, contact_person, contact_phone) VALUES (?,?,?)`,[name, person, phone]);
  }

  // 给现有用户分配部门
  db.run("UPDATE users SET department_id=1 WHERE phone='13900000001'"); // 张三→总调度室
  db.run("UPDATE users SET department_id=2 WHERE phone='13900000002'"); // 李四→西藏桦翔
  db.run("UPDATE users SET department_id=5 WHERE phone='13900000222'"); // 申请人→驱龙第一选矿厂

  // ============ 维修工单（24条，覆盖所有状态，1-6月分布） ============
  console.log('生成维修工单...');
  const faultDescs = [
    ['发动机异响，机油压力不足',1], ['液压油管爆裂，系统压力骤降',1],
    ['变速箱挂挡困难，3档异响严重',1], ['制动系统失灵，刹车片磨损超标',2],
    ['转向油缸漏油，方向盘沉重',2], ['冷却系统高温，水箱漏水',2],
    ['履带松脱，行走跑偏严重',3], ['铲斗焊缝开裂，结构变形',3],
    ['电气系统故障，仪表盘全黑',4], ['空调压缩机异响，制冷失效',4],
    ['排气管断裂，噪音严重超标',1], ['燃油泵供油不足，动力明显下降',2],
    ['支重轮轴承损坏，行驶抖动',5], ['回转支承异响，回转无力',5],
    ['驾驶室密封条老化，进灰严重',3], ['液压泵异响，流量不足',3],
    ['发电机不充电，电瓶亏电',1], ['斗齿磨损严重，装载效率下降',4],
    ['涡轮增压器漏油，冒蓝烟',2], ['传动轴万向节磨损，跑偏',2],
    ['油缸活塞杆拉伤，漏油',5], ['水泵密封损坏，冷却液泄漏',5],
    ['起动机无力，冷车启动困难',4], ['多路阀卡滞，动作不协调',3],
  ];
  const statuses = [
    'pending_accept','pending_accept','pending_quote','pending_approval',
    'approved','approved','repairing','repairing','completed','completed',
    'accepted','accepted','accepted','accepted','accepted','accepted',
    'rejected','accepted','accepted','repairing','completed','accepted','accepted','accepted'
  ];
  const driverIds = [6,7,6,7,6,7,6,7,6,7,6,7,6,7,6,7,6,7,6,7,6,7,6,7]; // 张三、李四
  const shopIds = [1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2,1,2];

  const partsPool = [
    [{name:'活塞环',qty:3,price:280},{name:'机油',qty:2,price:450},{name:'密封垫',qty:1,price:120}],
    [{name:'液压油管',qty:2,price:850},{name:'密封圈',qty:4,price:180},{name:'液压油',qty:1,price:1200}],
    [{name:'变速箱油',qty:3,price:600},{name:'同步器',qty:1,price:2200},{name:'密封垫',qty:2,price:150}],
    [{name:'刹车片',qty:4,price:650},{name:'制动总泵',qty:1,price:1800}],
    [{name:'转向泵',qty:1,price:3200},{name:'液压油',qty:2,price:800}],
    [{name:'水泵',qty:1,price:1500},{name:'冷却液',qty:3,price:400},{name:'水管',qty:2,price:180}],
    [{name:'支重轮',qty:2,price:1800},{name:'履带板螺栓',qty:10,price:45}],
    [{name:'焊条',qty:5,price:60},{name:'钢板',qty:1,price:2800}],
    [{name:'线束总成',qty:1,price:3500},{name:'传感器',qty:3,price:420}],
    [{name:'空调压缩机',qty:1,price:2800},{name:'制冷剂',qty:2,price:350}],
    [{name:'排气管垫',qty:2,price:280},{name:'卡箍',qty:4,price:45}],
    [{name:'输油泵',qty:1,price:1800},{name:'柴油滤芯',qty:2,price:320}],
    [{name:'支重轮',qty:3,price:1800},{name:'黄油',qty:5,price:80}],
    [{name:'回转支承',qty:1,price:8500},{name:'密封圈',qty:2,price:220}],
    [{name:'密封条',qty:10,price:35},{name:'空调滤芯',qty:1,price:180}],
    [{name:'液压泵总成',qty:1,price:6800},{name:'液压油',qty:3,price:800}],
    [{name:'发电机',qty:1,price:2200},{name:'皮带',qty:1,price:280}],
    [{name:'斗齿',qty:5,price:350},{name:'齿座',qty:3,price:480},{name:'销轴',qty:4,price:120}],
    [{name:'涡轮增压器',qty:1,price:5500},{name:'机油管',qty:2,price:220}],
    [{name:'传动轴总成',qty:1,price:4800},{name:'万向节',qty:2,price:650}],
    [{name:'活塞杆',qty:1,price:1800},{name:'密封组件',qty:1,price:850},{name:'防尘圈',qty:2,price:90}],
    [{name:'水泵总成',qty:1,price:1500},{name:'密封圈',qty:3,price:80}],
    [{name:'起动机',qty:1,price:2600},{name:'电瓶',qty:1,price:900}],
    [{name:'多路阀修理包',qty:1,price:1800},{name:'液压油',qty:2,price:800},{name:'滤芯',qty:2,price:350}],
  ];

  // 时间分布：1月-6月
  const months = ['2026-01','2026-02','2026-03','2026-04','2026-05','2026-06'];

  for (let i = 0; i < 24; i++) {
    const no = 'WO-' + months[Math.floor(i/4)] + '-' + String(i + 1).padStart(3, '0');
    const monthIdx = Math.floor(i / 4);
    const m = months[monthIdx];
    const d = String(rand(1, 25)).padStart(2, '0');
    const reportDate = `${m}-${d} ${String(rand(6,10)).padStart(2,'0')}:${String(rand(0,59)).padStart(2,'0')}:00`;
    const status = statuses[i];
    const vid = (i % 5) + 1;
    const did = driverIds[i];
    const sid = shopIds[i];

    db.run(`INSERT INTO repair_orders (order_no, vehicle_id, driver_id, repair_shop_id, fault_description, status, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?)`,
      [no, vid, did, sid, faultDescs[i][0], status, reportDate, reportDate]);

    const oid = db.exec("SELECT last_insert_rowid()")[0].values[0][0];
    const parts = partsPool[i];
    const pc = parts.reduce((s,p) => s + p.qty * p.price, 0);
    const lc = Math.floor(pc * 0.4);
    const hc = Math.floor(pc * 0.3);
    const total = pc + lc + hc;
    const days = rand(1, 7);

    // 除 pending_accept/pending_quote 外都生成报价
    if (!['pending_accept','pending_quote'].includes(status)) {
      db.run(`INSERT INTO repair_quotes (order_id, repair_shop_id, quote_amount, parts_cost, labor_cost, hours_cost, parts_list, quote_detail, estimated_days, approved_at) VALUES (?,?,?,?,?,?,?,?,?,?)`,
        [oid, sid, total, pc, lc, hc, JSON.stringify(parts), faultDescs[i][0], days,
         status === 'pending_approval' ? null : `${m}-${String(Math.min(Number(d)+3, 28)).padStart(2,'0')} 14:00:00`]);
    }

    // 生成进度记录
    if (status === 'pending_quote') {
      db.run(`INSERT INTO repair_progress (order_id, user_id, action, content, created_at) VALUES (?,?,?,?,?)`,
        [oid, sid === 1 ? 9 : 10, 'accepted_order', '已接单，准备检查', reportDate]);
    }
    if (status === 'pending_approval' || status === 'approved' || status === 'repairing' || status === 'completed' || status === 'accepted') {
      db.run(`INSERT INTO repair_progress (order_id, user_id, action, content, created_at) VALUES (?,?,?,?,?)`,
        [oid, sid === 1 ? 9 : 10, 'accepted_order', '已接单', reportDate]);
      db.run(`INSERT INTO repair_progress (order_id, user_id, action, content, created_at) VALUES (?,?,?,?,?)`,
        [oid, sid === 1 ? 9 : 10, 'quote_submitted', `报价¥${total}，预计${days}天`, `${m}-${String(Math.min(Number(d)+1, 28)).padStart(2,'0')} 09:00:00`]);
    }
    if (status === 'repairing' || status === 'completed' || status === 'accepted') {
      db.run(`INSERT INTO repair_progress (order_id, user_id, action, content, created_at) VALUES (?,?,?,?,?)`,
        [oid, sid === 1 ? 9 : 10, 'progress_update', '已开始维修，正在更换故障部件', `${m}-${String(Math.min(Number(d)+3, 28)).padStart(2,'0')} 10:00:00`]);
    }
    if (status === 'completed' || status === 'accepted') {
      db.run(`INSERT INTO repair_progress (order_id, user_id, action, content, created_at) VALUES (?,?,?,?,?)`,
        [oid, sid === 1 ? 9 : 10, 'completed', '维修完成，等待验收', `${m}-${String(Math.min(Number(d)+5, 28)).padStart(2,'0')} 16:00:00`]);
    }
    if (status === 'accepted') {
      db.run(`INSERT INTO repair_progress (order_id, user_id, action, content, created_at) VALUES (?,?,?,?,?)`,
        [oid, did, 'accepted', '验收合格，车辆恢复正常', `${m}-${String(Math.min(Number(d)+6, 28)).padStart(2,'0')} 10:30:00`]);
    }
  }

  // ============ 外部维修（8条） ============
  console.log('生成外部维修...');
  const extData = [
    ['球磨机','主轴轴承异响，振动值超标',7,1,5200],
    ['浮选机','叶轮磨损严重，选矿效率下降',7,2,3800],
    ['破碎机','传动皮带断裂，设备停机',7,1,6500],
    ['磁选机','磁系退磁，精矿品位下降',8,2,4200],
    ['分级机','槽体衬板脱落，搅拌不均匀',8,1,2900],
    ['过滤机','滤布破损，过滤效果差',8,2,3500],
    ['浓缩机','耙架变形，底流浓度不稳',5,1,5800],
    ['搅拌槽','减速机异响，搅拌轴弯曲',5,2,4700],
  ];
  for (let e = 0; e < 8; e++) {
    const [vname, fault, deptId, sid, cost] = extData[e];
    const m = months[Math.floor(e * 6 / 8)];
    const d = String(rand(1, 25)).padStart(2, '0');
    const no = 'EWO-' + m + '-' + String(e + 1).padStart(3, '0');
    const pc = Math.floor(cost * 0.55);
    const lc = Math.floor(cost * 0.3);
    const hc = cost - pc - lc;

    const euid = rand(6,7);
    db.run(`INSERT INTO external_repair_orders (order_no, department_id, user_id, repair_shop_id, vehicle_name, fault_description, status, quote_amount, parts_cost, labor_cost, hours_cost, parts_list, quote_detail, estimated_days, approved_at, created_at, updated_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [no, deptId, euid, sid, vname, fault, 'accepted', cost, pc, lc, hc,
       JSON.stringify([{name:'配件',qty:rand(1,3),price:Math.floor(cost*0.4)}]),
       fault, rand(2,6), `${m}-${d} 14:00:00`,
       `${m}-${d} 08:00:00`, `${m}-${d} 16:00:00`]);
  }

  // ============ 工程机械派车申请（20条，各种状态） ============
  console.log('生成派车申请...');
  const appNames = ['王工','李工','陈主任','赵队','刘工','钱调度'];
  const appDepts = ['第一选矿厂重机班','第二选矿厂重机班','甲玛乡尾矿库重机班','巨龙铜业采矿场','驱龙第一选矿厂'];
  const vtypes = ['挖掘机','装载机','推土机','矿用卡车','汽车吊'];
  const locations = ['一号采矿区','二号采矿区','一号排土场','K28路段','驱龙第一选矿厂','知不拉铜多金属矿','三号排土场'];
  const purposes = ['矿石装车','废石清运','道路平整','材料运输','设备吊装','边坡修整','尾矿筑坝','炸药运输'];

  for (let m = 0; m < 20; m++) {
    const no = 'MA-' + months[Math.floor(m * 6 / 20)] + '-' + String(m + 1).padStart(3, '0');
    const monthIdx = Math.floor(m * 6 / 20);
    const month = months[monthIdx];
    const day = String(rand(1, 25)).padStart(2, '0');
    const dateStr = `${month}-${day}`;
    const sh = rand(7, 9);
    const eh = sh + rand(6, 10);
    const hours = eh - sh;
    const rate = rand(250, 600);
    const status = m < 3 ? 'pending' : m < 6 ? 'assigned' : m < 9 ? 'in_progress' : (m < 18 ? 'completed' : 'early_completed');
    const vid = rand(1, 5);
    const did = rand(6, 7);

    db.run(`INSERT INTO machinery_applications (application_no, applicant_id, applicant_name, applicant_dept, vehicle_type, work_location, scheduled_start, scheduled_end, status, assigned_vehicle_id, assigned_driver_id, working_hours, hourly_rate, total_cost, work_purpose, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
      [no, 15, pick(appNames), pick(appDepts), pick(vtypes), pick(locations),
       `${dateStr} 0${sh}:00`, `${dateStr} ${eh}:00`,
       status, status !== 'pending' ? vid : null, status !== 'pending' ? did : null,
       ['completed','early_completed'].includes(status) ? hours : 0,
       rate, ['completed','early_completed'].includes(status) ? hours * rate : 0,
       pick(purposes), `${dateStr} 08:00:00`]);
  }

  // ============ 点检记录（60条，30天×2司机） ============
  console.log('生成点检记录...');
  for (let d = 0; d < 30; d++) {
    const date = fmtDate(2026, 6, d + 1);
    if (d > 9) continue; // 只做到6月10日（今天）
    for (const did of [6, 7]) {
      const vid = rand(1, 5);
      const sh = 12000 + rand(d * 20, d * 20 + 100);
      const eh = sh + rand(7, 10);
      const abnormal = rand(1, 8) === 1;
      db.run(`INSERT INTO daily_inspections (vehicle_id, driver_id, inspection_date, oil_level, coolant_level, appearance, tire_condition, toolkit_check, overall_status, engine_hours, start_hours, end_hours, fuel_amount, notes, parking_location) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)`,
        [vid, did, date,
         pick(['high','mid','low']), pick(['high','mid','mid']),
         pick(['normal','normal','damaged','dirty']), pick(['normal','normal','normal','worn']),
         abnormal ? 'missing' : 'ok', abnormal ? 'abnormal' : 'normal',
         sh, sh, eh, rand(25, 120),
         abnormal ? '需关注' + pick(['发动机','液压','制动','传动','转向']) : '',
         pick(['1号矿场','2号矿场','修理车间','K28路段','三号排土场'])]);
    }
  }

  // ============ 考勤记录（60条，6月1-10日×3司机×2班次） ============
  console.log('生成考勤...');
  const symbols = ['X','Y','Z','V','G','△','△/X','△/Y'];
  for (let d = 0; d < 10; d++) {
    const date = fmtDate(2026, 6, d + 1);
    for (const did of [6, 7, 6]) { // 张三早晚、李四早
      const ot = rand(1, 6) === 1;
      db.run(`INSERT OR IGNORE INTO driver_attendance (driver_id, attendance_date, attendance_symbol, overtime_hours, overtime_start, overtime_end, overtime_location) VALUES (?,?,?,?,?,?,?)`,
        [did, date, pick(symbols), ot ? rand(2, 4) : 0,
         ot ? '18:00' : '', ot ? `${18 + rand(2,4)}:00` : '',
         ot ? pick(['1号矿场','2号矿场','K28路段','修理车间']) : '']);
    }
  }

  // ============ 配件领用（12条） ============
  console.log('生成配件领用...');
  for (let r = 0; r < 12; r++) {
    const status = r < 8 ? 'completed' : (r < 10 ? 'pending' : 'approved');
    db.run(`INSERT INTO parts_requisitions (user_id, part_id, vehicle_id, quantity, reason, status, created_at) VALUES (?,?,?,?,?,?,?)`,
      [rand(6, 7), rand(1, 10), rand(1, 5), rand(1, 3),
       pick(['定期保养','故障更换','磨损更换','安全检查']),
       status, fmtDate(2026, 6, rand(1, 10)) + ' 08:00:00']);
  }
  // 更新库存（部分配件消耗）
  db.run("UPDATE parts_inventory SET quantity=MAX(quantity-3,2) WHERE id IN (1,2,4,7)");

  // ============ 隐患（12条，各种状态） ============
  console.log('生成隐患...');
  const hazardData = [
    ['一号采矿区','边坡发现裂缝，存在滑坡风险','高','completed',7,'已加固处理','2026-06-05'],
    ['K28路段','路面坑洼严重，车辆通过颠簸','一般','verified',7,'已填补修复','2026-06-07'],
    ['修理车间','乙炔瓶存放不规范，距火源过近','高','rectifying',8,'正在整改中',null],
    ['二号排土场','排水沟堵塞，雨季积水隐患','一般','assigned',7,null,null],
    ['选矿厂','皮带机防护罩缺失','一般','reported',null,null,null],
    ['炸药库','消防器材过期，需更换','紧急','completed',8,'已全部更换','2026-06-03'],
    ['三号采矿区','临边护栏损坏，人员坠落风险','高','rectifying',7,'正在安装新护栏',null],
    ['尾矿库','坝体监测点数据异常波动','紧急','verified',8,'已复核排除隐患','2026-06-09'],
    ['生活区','施工临时用电线路老化','低','completed',7,'已更换新线路','2026-06-08'],
    ['破碎车间','粉尘浓度超标，通风不良','一般','reported',null,null,null],
    ['油库','防静电接地电阻超标','高','assigned',8,null,null],
    ['采矿场','爆破警戒距离不足，有飞石风险','紧急','rectifying',7,'增加警戒线+安排专人值守',null],
  ];
  for (let h = 0; h < hazardData.length; h++) {
    const [loc, desc, sev, status, resp, rectify, vt] = hazardData[h];
    const no = 'HZ-202606' + String(h + 1).padStart(2, '0');
    const d = String(rand(1, 9)).padStart(2, '0');
    db.run(`INSERT INTO hazards (hazard_no, reporter_id, location, description, severity, responsible_id, status, rectify_desc, verified_at, created_at) VALUES (?,?,?,?,?,?,?,?,?,?)`,
      [no, 13, loc, desc, sev,
       ['reported'].includes(status) ? null : resp,
       status, rectify || null,
       vt ? `2026-06-${vt} 16:00:00` : null,
       `2026-06-${d} 08:30:00`]);
  }

  // ============ 考核通报（8条） ============
  console.log('生成考核通报...');
  const assessData = [
    ['通报','张三','车辆点检不到位，连续3天未检查油位','2026-06-02'],
    ['表扬','李四','主动发现并上报K28路段塌方隐患','2026-06-03'],
    ['警告','王五','超速行驶，矿区主干道限速40km/h严重超速','2026-06-04'],
    ['处罚','张三','未按规定佩戴安全帽进入作业区','2026-06-05'],
    ['通报','李四','夜间停车未按规定放置警示标志','2026-06-06'],
    ['表扬','赵师傅','维修质量优异，本月返修率为零','2026-06-07'],
    ['警告','钱调度','派车安排不合理导致车辆闲置3小时','2026-06-08'],
    ['通报','王工','工程机械申请后未按时报备，影响调度','2026-06-09'],
  ];
  for (let a = 0; a < assessData.length; a++) {
    const [type, target, content, date] = assessData[a];
    const no = 'AS-202606' + String(a + 1).padStart(2, '0');
    const targetId = target.includes('张三') ? 6 : target.includes('李四') ? 7 : target.includes('赵师傅') ? 9 : target.includes('钱调度') ? 12 : 8;
    db.run(`INSERT INTO assessments (assess_no, issuer_id, target_id, title, content, assess_type, created_at) VALUES (?,?,?,?,?,?,?)`,
      [no, 5, targetId, `${type}：${target}`, content, type, `${date} 10:00:00`]);
  }

  // ============ 天气预警（增加几条历史及当前活跃） ============
  console.log('生成天气预警...');
  // 已存在8条，再补充模拟数据
  const warnData = [
    ['ZONE-001','rainstorm','yellow','甲马乡暴雨黄色预警','1小时降雨量达30mm，注意防洪',26,'mm/h','active','2026-06-09 18:00:00',null],
    ['ZONE-003','strong_wind','blue','驱龙选矿厂大风蓝色预警','平均风速12m/s，阵风15m/s，注意高空坠物',12.5,'m/s','active','2026-06-09 14:00:00',null],
    ['ZONE-006','snowstorm','orange','知不拉矿暴雪橙色预警','12小时降雪12mm，道路结冰风险高',12,'mm/12h','resolved','2026-06-05 08:00:00','2026-06-06 12:00:00'],
    ['ZONE-004','thunderstorm','yellow','K28路段雷电黄色预警','10分钟内闪电8次，暂停露天作业',8,'strikes/10min','acknowledged','2026-06-08 16:00:00',null],
    ['ZONE-002','low_visibility','blue','甲玛尾矿库大雾蓝色预警','能见度800m，车辆减速慢行',800,'m','active','2026-06-10 06:00:00',null],
    ['ZONE-007','rainstorm','red','三号排土场暴雨红色预警','1小时降雨75mm，立即撤离！',75,'mm/h','active','2026-06-10 07:30:00',null],
  ];
  for (let w = 0; w < warnData.length; w++) {
    const [zone, wtype, level, title, desc, val, unit, status, triggered, resolved] = warnData[w];
    const zoneId = parseInt(zone.split('-')[1]);
    const no = 'WARN-202606' + String(w + 9).padStart(2, '0');
    db.run(`INSERT INTO weather_warnings (warning_no, zone_id, weather_type, level, title, description, measured_value, measured_unit, status, triggered_at, resolved_at) VALUES (?,?,?,?,?,?,?,?,?,?,?)`,
      [no, zoneId, wtype, level, title, desc, val, unit, status, triggered, resolved || null]);
  }

  // ============ 通知（20条） ============
  console.log('生成通知...');
  for (let n = 0; n < 20; n++) {
    const uid = pick([5,6,7,9,10,11,12,13,15]);
    const type = pick(['repair','machinery','hazard','system','weather','assessment']);
    const titles = {
      repair: ['工单已接单','报价已审批','维修完成待验收'],
      machinery: ['派车申请已提交','车辆已指派','用车完成请结算'],
      hazard: ['隐患已上报','隐患整改完成','隐患已验证'],
      system: ['系统维护通知','配件库存不足预警','保养到期提醒'],
      weather: ['暴雨黄色预警','大风蓝色预警','大雾蓝色预警'],
      assessment: ['考核通报已发布','收到新考核','考核结果已出'],
    };
    db.run(`INSERT INTO notifications (user_id, type, title, content, order_id, is_read, created_at) VALUES (?,?,?,?,?,?,?)`,
      [uid, type, pick(titles[type]), pick(titles[type]) + '的详细说明',
       rand(1, 24), rand(0, 1),
       fmtDate(2026, 6, rand(1, 10)) + ' ' + String(rand(8,18)).padStart(2,'0') + ':' + String(rand(0,59)).padStart(2,'0') + ':00']);
  }

  // ============ 单车核算数据（油耗+配件更换+月度台账） ============
  console.log('生成单车核算数据...');
  for (let vid = 1; vid <= 5; vid++) {
    // 油耗记录（每月4-5条，共6个月）
    for (let m = 1; m <= 6; m++) {
      const entries = rand(3, 5);
      for (let e = 0; e < entries; e++) {
        const d = String(rand(1, 28)).padStart(2, '0');
        const fuel = rand(120, 350);
        const h = 12000 + (m - 1) * 200 + e * 50 + rand(0, 30);
        db.run(`INSERT INTO fuel_records (vehicle_id, record_date, fuel_amount, fuel_cost, hour_meter, station, operator_id, remark) VALUES (?,?,?,?,?,?,?,?)`,
          [vid, `2026-${String(m).padStart(2,'0')}-${d}`, fuel, Math.round(fuel * 7.8), h,
           pick(['矿区加油站','外来油罐车']), pick([6,7]),
           e === 0 ? '月初加油' : '日常加油']);
      }
    }
    // 配件更换（每月1-2次）
    const partReplacements = [
      ['轮胎', 'tire', 8500], ['机油滤芯', 'engine', 280], ['刹车片', 'brake', 1200],
      ['液压油管', 'hydraulic', 1800], ['斗齿', 'other', 650], ['空气滤芯', 'engine', 320],
      ['履带板', 'other', 4500], ['变速箱油封', 'transmission', 850],
    ];
    for (let m = 1; m <= 6; m++) {
      for (let p = 0; p < rand(1, 2); p++) {
        const [pname, ptype, cost] = pick(partReplacements);
        const d = String(rand(1, 25)).padStart(2, '0');
        const h = 12000 + (m - 1) * 200 + rand(0, 150);
        db.run(`INSERT INTO part_replacements (vehicle_id, part_name, part_type, replace_date, cost, current_hours, reason, operator_id) VALUES (?,?,?,?,?,?,?,?)`,
          [vid, pname, ptype, `2026-${String(m).padStart(2,'0')}-${d}`, cost, h,
           pick(['定期保养更换','故障更换','磨损超标更换']), pick([6,7])]);
      }
    }
    // 月度台账（每月1条）
    for (let m = 1; m <= 6; m++) {
      const fuelCost = rand(8000, 20000);
      const repairCost = rand(3000, 15000);
      const partsCost = rand(2000, 8000);
      const laborCost = rand(1500, 5000);
      const totalCost = fuelCost + repairCost + partsCost + laborCost;
      const workDays = rand(22, 30);
      const totalHours = workDays * rand(8, 12);
      db.run(`INSERT INTO monthly_ledger (vehicle_id, year_month, fuel_cost, repair_cost, parts_cost, labor_cost, work_days, total_hours, total_cost, revenue, profit, status) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)`,
        [vid, `2026-${String(m).padStart(2,'0')}`, fuelCost, repairCost, partsCost, laborCost,
         workDays, totalHours, totalCost, Math.round(totalCost * 1.3), Math.round(totalCost * 0.3), m === 6 ? 'draft' : 'approved']);
    }
    // KPI评分（每月1条）
    for (let m = 1; m <= 6; m++) {
      const scores = [rand(78,98), rand(75,95), rand(70,92), rand(82,99), rand(65,90), rand(80,100)];
      const total = Math.round(scores.reduce((a,b)=>a+b, 0) / 6);
      db.run(`INSERT INTO kpi_scores (vehicle_id, year_month, fuel_cost_per_unit, repair_rate, utilization_rate, unit_cost, availability_rate, safety_score, total_score, rank) VALUES (?,?,?,?,?,?,?,?,?,?)`,
        [vid, `2026-${String(m).padStart(2,'0')}`, scores[0], scores[1], scores[2], scores[3], scores[4], scores[5], total, rand(1,5)]);
    }
  }

  // ============ 写入 ============
  const data = db.export();
  const backupName = 'data/mine_repair_seed_backup_' + new Date().toISOString().slice(0, 10) + '.db';
  fs.writeFileSync(backupName, Buffer.from(data));
  console.log('备份:', backupName);
  fs.writeFileSync('data/mine_repair.db', Buffer.from(data));
  db.close();

  // ============ 验证 ============
  const SQL2 = await initSqlJs();
  const db2 = new SQL2.Database(fs.readFileSync('data/mine_repair.db'));
  const c = (sql) => {try{return db2.exec(sql)[0].values[0][0]}catch{return 0}};
  console.log('\n=== 灌入完成！数据汇总 ===');
  console.log('  车辆:', c('SELECT COUNT(*) FROM vehicles'), '辆');
  console.log('  部门:', c('SELECT COUNT(*) FROM departments'), '个');
  console.log('  维修工单:', c('SELECT COUNT(*) FROM repair_orders'), '条');
  console.log('  　含报价:', c('SELECT COUNT(*) FROM repair_quotes'), '条');
  console.log('  　含进度:', c('SELECT COUNT(*) FROM repair_progress'), '条');
  console.log('  外部维修:', c('SELECT COUNT(*) FROM external_repair_orders'), '条');
  console.log('  派车申请:', c('SELECT COUNT(*) FROM machinery_applications'), '条');
  console.log('  点检记录:', c('SELECT COUNT(*) FROM daily_inspections'), '条');
  console.log('  考勤记录:', c('SELECT COUNT(*) FROM driver_attendance'), '条');
  console.log('  配件库存:', c('SELECT COUNT(*) FROM parts_inventory'), '种');
  console.log('  配件领用:', c('SELECT COUNT(*) FROM parts_requisitions'), '条');
  console.log('  隐患:', c('SELECT COUNT(*) FROM hazards'), '条');
  console.log('  考核:', c('SELECT COUNT(*) FROM assessments'), '条');
  console.log('  天气预警:', c('SELECT COUNT(*) FROM weather_warnings'), '条');
  console.log('  通知:', c('SELECT COUNT(*) FROM notifications'), '条');
  console.log('  油耗记录:', c('SELECT COUNT(*) FROM fuel_records'), '条');
  console.log('  配件更换:', c('SELECT COUNT(*) FROM part_replacements'), '条');
  console.log('  月度台账:', c('SELECT COUNT(*) FROM monthly_ledger'), '条');
  console.log('  KPI评分:', c('SELECT COUNT(*) FROM kpi_scores'), '条');
  console.log('\n维修工单状态分布:');
  db2.exec('SELECT status,COUNT(*) FROM repair_orders GROUP BY status').forEach(r=>{
    const names = {pending_accept:'待接单',pending_quote:'待报价',pending_approval:'待审批',approved:'已通过',rejected:'已驳回',repairing:'维修中',completed:'待验收',accepted:'已完成'};
    r.values.forEach(v=>console.log('  ',names[v[0]]||v[0],':',v[1]));
  });
  db2.close();
})();
