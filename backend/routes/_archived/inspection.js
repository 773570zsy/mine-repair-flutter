const express = require('express');
const router = express.Router();
const { auth, requireRole } = require('../middleware/auth');
const { query, queryOne } = require('../utils/db');
const dayjs = require('dayjs');

// 驾驶员-获取所有车辆
router.get('/my-vehicles', auth, requireRole('driver'), async (req, res) => {
  res.json({ code: 200, data: await query("SELECT * FROM vehicles WHERE status!='scrapped' ORDER BY plate_number") });
});

// 获取所有驾驶员列表（用于选择）
router.get('/driver-list', auth, async (req, res) => {
  const drivers = await query("SELECT id, name, phone FROM users WHERE role='driver' AND status=1 ORDER BY name");
  res.json({ code: 200, data: drivers });
});

// 早检提交（车辆检查项）
router.post('/morning-check', auth, async (req, res) => {
  const { vehicle_id, driver_id, oil_level, coolant_level, appearance, tire_condition,
          toolkit_check, overall_status, abnormal_desc, notes, engine_hours, photos } = req.body;
  const vid = vehicle_id || req.body.vehicle_id;
  const did = driver_id || req.user.id;
  if (!vid) return res.json({ code: 400, msg: '请选择车辆' });

  const today = dayjs().format('YYYY-MM-DD');
  // 检查今日是否已有记录
  const existing = await queryOne(
    'SELECT id FROM daily_inspections WHERE vehicle_id=? AND driver_id=? AND inspection_date=?',
    [vid, did, today]
  );
  if (existing) return res.json({ code: 400, msg: '该车辆今日已有早检记录' });

  await query(
    `INSERT INTO daily_inspections
     (vehicle_id, driver_id, inspection_date, oil_level, coolant_level, appearance,
      tire_condition, toolkit_check, overall_status, abnormal_desc, notes, engine_hours, photos)
     VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)`,
    [vid, did, today, oil_level||null, coolant_level||null,
     appearance||null, tire_condition||null, toolkit_check||null,
     overall_status||'normal', abnormal_desc||'', notes||'', engine_hours||0, JSON.stringify(photos||[])]
  );
  res.json({ code: 200, msg: '早检提交成功' });
});

// 晚检提交（工时/加油/考勤/停车地点）
router.post('/evening-check', auth, async (req, res) => {
  const { vehicle_id, driver_id, start_hours, end_hours, fuel_amount,
          attendance_symbol, parking_location, photos } = req.body;
  const vid = vehicle_id || req.body.vehicle_id;
  const did = driver_id || req.user.id;
  if (!vid) return res.json({ code: 400, msg: '请选择车辆' });
  if (end_hours && start_hours && parseFloat(end_hours) <= parseFloat(start_hours)) {
    return res.json({ code: 400, msg: '下班工时必须大于上班工时' });
  }
  if (fuel_amount && parseFloat(fuel_amount) < 0) {
    return res.json({ code: 400, msg: '加油量不能为负数' });
  }

  const today = dayjs().format('YYYY-MM-DD');
  // 查找今日早检记录
  const record = await queryOne(
    'SELECT id FROM daily_inspections WHERE vehicle_id=? AND driver_id=? AND inspection_date=?',
    [vid, did, today]
  );
  if (!record) return res.json({ code: 400, msg: '请先完成早检' });

  await query(
    `UPDATE daily_inspections SET start_hours=?, end_hours=?, fuel_amount=?,
     attendance_symbol=?, parking_location=?, photos=?, updated_at=datetime('now')
     WHERE id=?`,
    [start_hours||0, end_hours||0, fuel_amount||0,
     attendance_symbol||'', parking_location||'', JSON.stringify(photos||[]), record.id]
  );

  // 自动推进保养周期：如果当前工时超过下次保养时间，自动+周期
  const veh = await queryOne('SELECT * FROM vehicles WHERE id=?', [vid]);
  if (veh && end_hours > 0 && veh.maintenance_interval_hours > 0) {
    let next = veh.next_maintenance_hours || (veh.initial_engine_hours || 0) + veh.maintenance_interval_hours;
    while (end_hours >= next) { next += veh.maintenance_interval_hours; }
    if (next !== veh.next_maintenance_hours) {
      await query('UPDATE vehicles SET next_maintenance_hours=? WHERE id=?', [next, vid]);
    }
  }

  res.json({ code: 200, msg: '晚检提交成功' });
});

// 驾驶员-查看自己的点检记录
router.get('/my-records', auth, async (req, res) => {
  const { month } = req.query;
  let sql = `SELECT di.*, v.plate_number, v.vehicle_type
    FROM daily_inspections di JOIN vehicles v ON di.vehicle_id=v.id
    WHERE di.driver_id=?`;
  const params = [req.user.id];
  if (month) { sql += ' AND substr(di.inspection_date,1,7)=?'; params.push(month); }
  sql += ' ORDER BY di.inspection_date DESC';
  res.json({ code: 200, data: await query(sql, params) });
});

// 查看所有车辆点检记录
router.get('/all-records', auth, async (req, res) => {
  const { date, vehicle_id, driver_id, page=1, pageSize=20 } = req.query;
  let sql = `SELECT di.*, v.plate_number, v.vehicle_type, u.name as driver_name
    FROM daily_inspections di JOIN vehicles v ON di.vehicle_id=v.id JOIN users u ON di.driver_id=u.id WHERE 1=1`;
  const params = [];
  if (date) { sql += ' AND di.inspection_date=?'; params.push(date); }
  if (vehicle_id) { sql += ' AND di.vehicle_id=?'; params.push(vehicle_id); }
  if (driver_id) { sql += ' AND di.driver_id=?'; params.push(driver_id); }
  sql += ' ORDER BY di.inspection_date DESC, di.created_at DESC LIMIT ? OFFSET ?';
  params.push(Number(pageSize), (Number(page)-1)*Number(pageSize));
  res.json({ code: 200, data: await query(sql, params) });
});

// 今日概况
router.get('/today-summary', auth, requireRole('leader', 'admin'), async (req, res) => {
  const today = dayjs().format('YYYY-MM-DD');
  const [{ t: totalVehicles }] = await query(
    "SELECT COUNT(*) as t FROM vehicles v WHERE v.status='normal' AND v.current_driver_id IS NOT NULL");
  const [{ t: inspectedCount }] = await query(
    'SELECT COUNT(DISTINCT vehicle_id) as t FROM daily_inspections WHERE inspection_date=?', [today]);
  const uninspected = await query(
    `SELECT v.id, v.plate_number, v.vehicle_type, u.name as driver_name
     FROM vehicles v JOIN users u ON v.current_driver_id=u.id
     WHERE v.status='normal' AND v.id NOT IN (SELECT vehicle_id FROM daily_inspections WHERE inspection_date=?)
     ORDER BY v.plate_number`, [today]);
  res.json({ code: 200, data: { date: today, totalVehicles, inspectedCount, uninspectedCount: uninspected.length, uninspected } });
});

// 工时统计
router.get('/work-hours-report', auth, requireRole('leader', 'admin'), async (req, res) => {
  const { month } = req.query;
  if (!month) return res.json({ code: 400, msg: '请选择月份' });
  const rows = await query(
    `SELECT di.driver_id, u.name as driver_name, di.inspection_date,
            v.plate_number, di.start_hours, di.end_hours,
            (di.end_hours - di.start_hours) as work_hours,
            di.fuel_amount, di.attendance_symbol, di.parking_location
     FROM daily_inspections di JOIN users u ON di.driver_id=u.id JOIN vehicles v ON di.vehicle_id=v.id
     WHERE substr(di.inspection_date,1,7)=? ORDER BY di.driver_id, di.inspection_date`, [month]);
  const summary = {};
  rows.forEach(r => {
    const k = r.driver_id;
    if (!summary[k]) summary[k] = { driver_name: r.driver_name, total_hours:0, total_fuel:0, days:0, records:[] };
    summary[k].total_hours += r.work_hours||0;
    summary[k].total_fuel += r.fuel_amount||0;
    summary[k].days++;
    summary[k].records.push(r);
  });
  res.json({ code: 200, data: { detail: rows, summary: Object.values(summary) } });
});

// ==================== 配件管理 ====================

router.get('/parts-list', auth, async (req, res) => {
  res.json({ code: 200, data: await query('SELECT * FROM parts_inventory ORDER BY part_name') });
});

router.post('/parts/add', auth, requireRole('admin'), async (req, res) => {
  const { part_name, part_code, quantity, unit, remark } = req.body;
  if (!part_name) return res.json({ code: 400, msg: '请填写名称' });
  await query('INSERT INTO parts_inventory (part_name,part_code,quantity,unit,remark) VALUES (?,?,?,?,?)',
    [part_name, part_code||'', quantity||0, unit||'个', remark||'']);
  res.json({ code: 200, msg: '添加成功' });
});

router.post('/parts/import', auth, requireRole('admin'), async (req, res) => {
  const { parts } = req.body;
  if (!parts||!parts.length) return res.json({ code: 400, msg: '请提供数据' });
  let sc = 0;
  for (const p of parts) {
    try { await query('INSERT INTO parts_inventory (part_name,part_code,quantity,unit) VALUES (?,?,?,?)',[p.part_name,p.part_code||'',p.quantity||0,p.unit||'个']); sc++; } catch(e){}
  }
  res.json({ code: 200, msg: `导入完成：${sc}条` });
});

router.post('/parts/requisition', auth, requireRole('driver'), async (req, res) => {
  const { part_id, vehicle_id, quantity, reason } = req.body;
  if (!part_id||!quantity) return res.json({ code: 400, msg: '请选择配件和数量' });
  const part = await queryOne('SELECT * FROM parts_inventory WHERE id=?',[part_id]);
  if (!part) return res.json({ code: 404, msg: '配件不存在' });
  if (part.quantity < quantity) return res.json({ code: 400, msg: `库存不足(当前:${part.quantity})` });
  await query('INSERT INTO parts_requisitions (user_id,part_id,vehicle_id,quantity,reason) VALUES (?,?,?,?,?)',[req.user.id,part_id,vehicle_id||null,quantity,reason||'']);
  res.json({ code: 200, msg: '申请已提交' });
});

router.post('/parts/confirm/:reqId', auth, requireRole('admin'), async (req, res) => {
  const reqItem = await queryOne('SELECT * FROM parts_requisitions WHERE id=?',[req.params.reqId]);
  if (!reqItem||reqItem.status!=='pending') return res.json({ code: 400, msg: '状态异常' });
  await query("UPDATE parts_inventory SET quantity=quantity-?, updated_at=datetime('now') WHERE id=?",[reqItem.quantity,reqItem.part_id]);
  await query("UPDATE parts_requisitions SET status='completed', approved_by=?, picked_up_at=datetime('now'), updated_at=datetime('now') WHERE id=?",[req.user.id,reqItem.id]);
  res.json({ code: 200, msg: '已确认出库' });
});

router.post('/parts/reject/:reqId', auth, requireRole('admin'), async (req, res) => {
  await query("UPDATE parts_requisitions SET status='rejected',approved_by=? WHERE id=?",[req.user.id,req.params.reqId]);
  res.json({ code: 200, msg: '已驳回' });
});

router.get('/parts/requisitions', auth, async (req, res) => {
  const { date_from, date_to, user_id } = req.query;
  let sql = `SELECT pr.*, pi.part_name, pi.part_code, u.name as user_name, v.plate_number
    FROM parts_requisitions pr
    JOIN parts_inventory pi ON pr.part_id=pi.id
    JOIN users u ON pr.user_id=u.id
    LEFT JOIN vehicles v ON pr.vehicle_id=v.id WHERE 1=1`;
  const params = [];
  if (date_from) { sql += ' AND pr.created_at>=?'; params.push(date_from); }
  if (date_to) { sql += ' AND pr.created_at<=?'; params.push(date_to+' 23:59:59'); }
  if (user_id) { sql += ' AND pr.user_id=?'; params.push(+user_id); }
  sql += ' ORDER BY pr.created_at DESC';
  res.json({ code: 200, data: await query(sql, params) });
});

// ==================== 考勤加班 ====================

// 查询当日考勤
router.get('/attendance/today', auth, async (req, res) => {
  const today = dayjs().format('YYYY-MM-DD');
  const rec = await queryOne('SELECT * FROM driver_attendance WHERE driver_id=? AND attendance_date=?',
    [req.user.id, today]);
  res.json({ code: 200, data: rec || null });
});

// 提交考勤
router.post('/attendance/submit', auth, async (req, res) => {
  const { attendance_symbol, overtime_hours, overtime_start, overtime_end, overtime_location } = req.body;
  const today = dayjs().format('YYYY-MM-DD');
  // 检查今日是否已提交
  const existing = await queryOne('SELECT * FROM driver_attendance WHERE driver_id=? AND attendance_date=?',
    [req.user.id, today]);
  if (existing && existing.attendance_symbol) {
    return res.json({ code: 400, msg: '今日考勤已提交，不可重复提交' });
  }
  // 如果有时间段，自动计算小时数
  let calcHours = overtime_hours || 0;
  if (overtime_start && overtime_end) {
    const [sh, sm] = overtime_start.split(':').map(Number);
    const [eh, em] = overtime_end.split(':').map(Number);
    calcHours = (eh + em/60) - (sh + sm/60);
    if (calcHours < 0) calcHours += 24;
    calcHours = Math.round(calcHours * 10) / 10;
  }
  if (existing) {
    await query(
      `UPDATE driver_attendance SET attendance_symbol=?, overtime_hours=?, overtime_start=?, overtime_end=?, overtime_location=? WHERE id=?`,
      [attendance_symbol||'', calcHours, overtime_start||'', overtime_end||'', overtime_location||'', existing.id]
    );
  } else {
    await query(
      `INSERT INTO driver_attendance (driver_id, attendance_date, attendance_symbol, overtime_hours, overtime_start, overtime_end, overtime_location)
       VALUES (?,?,?,?,?,?,?)`,
      [req.user.id, today, attendance_symbol||'', calcHours, overtime_start||'', overtime_end||'', overtime_location||'']
    );
  }
  res.json({ code: 200, msg: '提交成功', data: { overtime_hours: calcHours } });
});

// 考勤统计导出（管理员用）
router.get('/attendance/report', auth, requireRole('admin', 'leader'), async (req, res) => {
  const { month, driver_id } = req.query;
  if (!month) return res.json({ code: 400, msg: '请选择月份' });
  let sql = `SELECT da.*, u.name as driver_name FROM driver_attendance da JOIN users u ON da.driver_id=u.id
    WHERE substr(da.attendance_date,1,7)=?`;
  const params = [month];
  if (driver_id) { sql += ' AND da.driver_id=?'; params.push(+driver_id); }
  sql += ' ORDER BY da.driver_id, da.attendance_date';
  res.json({ code: 200, data: await query(sql, params) });
});

module.exports = router;
