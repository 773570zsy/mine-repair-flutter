import { Router, Request, Response } from 'express';
import { auth, requireRole } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { morningCheckSchema, eveningCheckSchema, partsAddSchema, partsThresholdSchema, partsImportSchema, partsRequisitionSchema, attendanceSubmitSchema, exportAttendanceSchema } from '../schemas/inspection.schemas';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';
import { sendExcel, ColumnDef } from '../utils/excel';
import dayjs from 'dayjs';

const router = Router();

// ==================== 点检 ====================

// 驾驶员-获取所有车辆
router.get('/my-vehicles', auth, requireRole('driver'), asyncHandler(async (_req: Request, res: Response) => {
  const vehicles = getDB().prepare("SELECT * FROM vehicles WHERE status != 'scrapped' ORDER BY plate_number").all();
  res.json({ code: 200, data: vehicles });
}));

// 获取所有驾驶员列表（用于选择）
router.get('/driver-list', auth, asyncHandler(async (_req: Request, res: Response) => {
  const drivers = getDB().prepare("SELECT id, name, phone FROM users WHERE role = 'driver' AND (status = 1 OR status = '' OR status IS NULL) ORDER BY name").all();
  res.json({ code: 200, data: drivers });
}));

// 获取所有人员列表（用于隐患指派等）
router.get('/all-users', auth, asyncHandler(async (_req: Request, res: Response) => {
  const users = getDB().prepare("SELECT id, name, phone, role FROM users WHERE status = 1 OR status = '' OR status IS NULL ORDER BY name").all();
  res.json({ code: 200, data: users });
}));

// 早检提交（车辆检查项）
router.post('/morning-check', auth, validate(morningCheckSchema), asyncHandler(async (req: Request, res: Response) => {
  const { vehicle_id, driver_id, oil_level, coolant_level, appearance, tire_condition,
    toolkit_check, overall_status, abnormal_desc, notes, engine_hours, photos } = req.body;
  const vid = vehicle_id;
  const did = driver_id || req.user.id;

  const today = dayjs().format('YYYY-MM-DD');
  const existing = getDB().prepare(
    'SELECT id FROM daily_inspections WHERE vehicle_id = ? AND driver_id = ? AND inspection_date = ?'
  ).get(vid, did, today);
  if (existing) { res.json({ code: 400, msg: '该车辆今日已有早检记录' }); return; }

  getDB().prepare(
    `INSERT INTO daily_inspections
     (vehicle_id, driver_id, inspection_date, oil_level, coolant_level, appearance,
      tire_condition, toolkit_check, overall_status, abnormal_desc, notes, engine_hours, photos)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(vid, did, today, oil_level || null, coolant_level || null,
    appearance || null, tire_condition || null, toolkit_check || null,
    overall_status || 'normal', abnormal_desc || '', notes || '', engine_hours || 0, JSON.stringify(photos || []));
  res.json({ code: 200, msg: '早检提交成功' });
}));

// 晚检提交（工时/加油/考勤/停车地点）
router.post('/evening-check', auth, validate(eveningCheckSchema), asyncHandler(async (req: Request, res: Response) => {
  const { vehicle_id, driver_id, start_hours, end_hours, fuel_amount,
    attendance_symbol, parking_location, start_km, end_km, photos } = req.body;
  const vid = vehicle_id;
  const did = driver_id || req.user.id;
  if (end_hours && start_hours && parseFloat(end_hours) <= parseFloat(start_hours)) {
    res.json({ code: 400, msg: '下班工时必须大于上班工时' }); return;
  }
  if (fuel_amount && parseFloat(fuel_amount) < 0) {
    res.json({ code: 400, msg: '加油量不能为负数' }); return;
  }

  const today = dayjs().format('YYYY-MM-DD');
  const record = getDB().prepare(
    'SELECT id FROM daily_inspections WHERE vehicle_id = ? AND driver_id = ? AND inspection_date = ?'
  ).get(vid, did, today) as { id: number } | undefined;

  if (record) {
    // 已有记录（含早检）→ 更新
    getDB().prepare(
      `UPDATE daily_inspections SET start_hours = ?, end_hours = ?, fuel_amount = ?,
       attendance_symbol = ?, parking_location = ?, start_km = ?, current_km = ?, photos = ?, updated_at = datetime('now')
       WHERE id = ?`
    ).run(start_hours || 0, end_hours || 0, fuel_amount || 0,
      attendance_symbol || '', parking_location || '', start_km || 0, end_km || 0, JSON.stringify(photos || []), record.id);
  } else {
    // 无早检 → 直接插入晚检记录
    getDB().prepare(
      `INSERT INTO daily_inspections
       (vehicle_id, driver_id, inspection_date, start_hours, end_hours, fuel_amount,
        attendance_symbol, parking_location, start_km, current_km, photos, overall_status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(vid, did, today, start_hours || 0, end_hours || 0, fuel_amount || 0,
      attendance_symbol || '', parking_location || '', start_km || 0, end_km || 0, JSON.stringify(photos || []), 'normal');
  }

  // 更新在编车辆档案的当前工时，并检查保养周期（西藏恒骏不参与）
  if (end_hours && Number(end_hours) > 0) {
    const endHrs = Number(end_hours);
    const veh = getDB().prepare('SELECT plate_number FROM vehicles WHERE id = ?').get(vid) as Record<string, unknown> | undefined;
    if (veh) {
      const plate = String(veh.plate_number);
      const archive = getDB().prepare('SELECT * FROM vehicle_archives WHERE plate_number = ?').get(plate) as Record<string, unknown> | undefined;
      if (archive) {
        // 西藏恒骏车辆不参与工时更新和保养检查
        const dept = String(archive.department || '总调度室');
        if (dept !== '西藏恒骏') {
          // 更新当前工时
          getDB().prepare('UPDATE vehicle_archives SET current_hours = ?, updated_at = datetime(\'now\') WHERE plate_number = ?')
            .run(endHrs, plate);

          // 检查保养：如果当前工时超出下次保养工时，自动推进
          const interval = Number(archive.maintenance_interval) || 500;
          let next = Number(archive.next_maintenance_hours) || 0;
          if (next <= 0) { next = endHrs + interval; }
          while (endHrs >= next) { next += interval; }
          if (next !== Number(archive.next_maintenance_hours)) {
            getDB().prepare('UPDATE vehicle_archives SET next_maintenance_hours = ? WHERE plate_number = ?').run(next, plate);
            // 同步 vehicles 表
            getDB().prepare('UPDATE vehicles SET next_maintenance_hours = ? WHERE plate_number = ?').run(next, plate);
          }
          // 同步 vehicles 表
          getDB().prepare('UPDATE vehicles SET next_maintenance_hours = ? WHERE plate_number = ?').run(next, plate);
        }

        // 更新当前公里数（取下班公里数），并检查公里保养周期
        if (end_km && Number(end_km) > 0) {
          const curKm = Number(end_km);
          getDB().prepare("UPDATE vehicle_archives SET current_km = ?, updated_at = datetime('now') WHERE plate_number = ?")
            .run(curKm, plate);

          const kmInterval = Number(archive.maintenance_interval_km) || 0;
          if (kmInterval > 0) {
            let nextKm = Number(archive.next_maintenance_km) || 0;
            if (nextKm <= 0) { nextKm = curKm + kmInterval; }
            while (curKm >= nextKm) { nextKm += kmInterval; }
            if (nextKm !== Number(archive.next_maintenance_km)) {
              getDB().prepare('UPDATE vehicle_archives SET next_maintenance_km = ? WHERE plate_number = ?').run(nextKm, plate);
            }
          }
        }
      } else {
        // 兼容旧逻辑：无档案时直接基于 vehicles 表计算
        const v = getDB().prepare('SELECT * FROM vehicles WHERE id = ?').get(vid) as Record<string, unknown> | undefined;
        if (v && Number(v.maintenance_interval_hours) > 0) {
          const interval = Number(v.maintenance_interval_hours);
          let next = Number(v.next_maintenance_hours) || (Number(v.initial_engine_hours) || 0) + interval;
          while (endHrs >= next) { next += interval; }
          if (next !== Number(v.next_maintenance_hours)) {
            getDB().prepare('UPDATE vehicles SET next_maintenance_hours = ? WHERE id = ?').run(next, vid);
          }
        }
      }
    }
  }

  res.json({ code: 200, msg: '晚检提交成功' });
}));

// 驾驶员-查看自己的点检记录
router.get('/my-records', auth, asyncHandler(async (req: Request, res: Response) => {
  const { month } = req.query;
  let sql = `SELECT di.*, v.plate_number, v.vehicle_type
    FROM daily_inspections di JOIN vehicles v ON di.vehicle_id = v.id
    WHERE di.driver_id = ?`;
  const params: (string | number)[] = [req.user.id];
  if (month) { sql += ' AND substr(di.inspection_date, 1, 7) = ?'; params.push(String(month)); }
  sql += ' ORDER BY di.inspection_date DESC';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 查看所有车辆点检记录
router.get('/all-records', auth, asyncHandler(async (req: Request, res: Response) => {
  const { date, vehicle_id, driver_id, page = '1', pageSize = '20' } = req.query;
  let sql = `SELECT di.*, v.plate_number, v.vehicle_type, u.name as driver_name
    FROM daily_inspections di JOIN vehicles v ON di.vehicle_id = v.id JOIN users u ON di.driver_id = u.id WHERE 1=1`;
  const params: (string | number)[] = [];
  if (date) { sql += ' AND di.inspection_date = ?'; params.push(String(date)); }
  if (vehicle_id) { sql += ' AND di.vehicle_id = ?'; params.push(Number(vehicle_id)); }
  if (driver_id) { sql += ' AND di.driver_id = ?'; params.push(Number(driver_id)); }
  sql += ' ORDER BY di.inspection_date DESC, di.created_at DESC LIMIT ? OFFSET ?';
  params.push(Number(pageSize), (Number(page) - 1) * Number(pageSize));
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 今日概况
router.get('/today-summary', auth, requireRole('leader', 'admin'), asyncHandler(async (_req: Request, res: Response) => {
  const today = dayjs().format('YYYY-MM-DD');
  const totalVehicles = getDB().prepare(
    "SELECT COUNT(*) as t FROM vehicles WHERE status = 'normal' AND current_driver_id IS NOT NULL"
  ).get() as { t: number };
  const inspectedCount = getDB().prepare(
    'SELECT COUNT(DISTINCT vehicle_id) as t FROM daily_inspections WHERE inspection_date = ?'
  ).get(today) as { t: number };
  const uninspected = getDB().prepare(
    `SELECT v.id, v.plate_number, v.vehicle_type, u.name as driver_name
     FROM vehicles v JOIN users u ON v.current_driver_id = u.id
     WHERE v.status = 'normal' AND v.id NOT IN (SELECT vehicle_id FROM daily_inspections WHERE inspection_date = ?)
     ORDER BY v.plate_number`
  ).all(today);
  res.json({ code: 200, data: { date: today, totalVehicles: totalVehicles.t, inspectedCount: inspectedCount.t, uninspectedCount: (uninspected as unknown[]).length, uninspected } });
}));

// 工时统计
router.get('/work-hours-report', auth, requireRole('leader', 'admin'), asyncHandler(async (req: Request, res: Response) => {
  const { month, driver_id, department_id } = req.query;
  if (!month) { res.json({ code: 400, msg: '请选择月份' }); return; }
  let sql = `SELECT di.driver_id, u.name as driver_name, di.inspection_date,
            v.plate_number, v.vehicle_type,
            di.start_hours, di.end_hours,
            ROUND(di.end_hours - di.start_hours, 1) as work_hours,
            di.start_km, di.current_km as end_km,
            ROUND(MAX(di.current_km - di.start_km, 0), 1) as driven_km,
            di.fuel_amount, di.attendance_symbol, di.parking_location
     FROM daily_inspections di JOIN users u ON di.driver_id = u.id JOIN vehicles v ON di.vehicle_id = v.id
     WHERE substr(di.inspection_date, 1, 7) = ?`;
  const params: (string | number)[] = [String(month)];
  if (driver_id) { sql += ' AND di.driver_id = ?'; params.push(Number(driver_id)); }
  if (department_id) { sql += ' AND u.department_id = ?'; params.push(Number(department_id)); }
  sql += ' ORDER BY di.driver_id, di.inspection_date';
  const rows = getDB().prepare(sql).all(...params) as Array<Record<string, unknown>>;

  const summary: Record<string, { driver_name: string; total_hours: number; total_fuel: number; total_km: number; days: number; records: unknown[] }> = {};
  for (const r of rows) {
    const k = String(r.driver_id);
    if (!summary[k]) summary[k] = { driver_name: r.driver_name as string, total_hours: 0, total_fuel: 0, total_km: 0, days: 0, records: [] };
    summary[k].total_hours += Number(r.work_hours) || 0;
    summary[k].total_fuel += Number(r.fuel_amount) || 0;
    summary[k].total_km += Number(r.driven_km) || 0;
    summary[k].days++;
    summary[k].records.push(r);
  }
  res.json({ code: 200, data: { detail: rows, summary: Object.values(summary) } });
}));

// ==================== 配件管理 ====================

router.get('/parts-list', auth, asyncHandler(async (_req: Request, res: Response) => {
  res.json({ code: 200, data: getDB().prepare('SELECT * FROM parts_inventory ORDER BY part_name').all() });
}));

router.post('/parts/add', auth, requireRole('admin'), validate(partsAddSchema), asyncHandler(async (req: Request, res: Response) => {
  const { part_name, part_code, quantity, unit, unit_price, remark } = req.body;
  const addQty = Number(quantity) || 0;
  const price = Number(unit_price) || 0;
  // 先去重：按编码或名称查找已有配件，找到则累加库存并更新单价
  let existing: Record<string, unknown> | undefined;
  if (part_code) {
    existing = getDB().prepare('SELECT * FROM parts_inventory WHERE part_code = ?').get(part_code) as Record<string, unknown> | undefined;
  }
  if (!existing) {
    existing = getDB().prepare('SELECT * FROM parts_inventory WHERE part_name = ?').get(part_name) as Record<string, unknown> | undefined;
  }
  if (existing) {
    const newQty = Number(existing.quantity) + addQty;
    getDB().prepare("UPDATE parts_inventory SET quantity = ?, unit_price = ?, remark = ?, updated_at = datetime('now') WHERE id = ?")
      .run(newQty, price || Number(existing.unit_price) || 0, remark || (existing.remark || ''), existing.id);
    res.json({ code: 200, msg: `配件已存在，库存累加: ${existing.quantity} → ${newQty}` });
  } else {
    getDB().prepare('INSERT INTO parts_inventory (part_name, part_code, quantity, unit, unit_price, remark) VALUES (?, ?, ?, ?, ?, ?)').run(
      part_name, part_code || '', addQty, unit || '个', price, remark || '');
    res.json({ code: 200, msg: '添加成功' });
  }
}));

// 配件模糊搜索（支持名称/编码）
router.get('/parts/search', auth, asyncHandler(async (req: Request, res: Response) => {
  const { q = '' } = req.query;
  if (!q || !String(q).trim()) { res.json({ code: 200, data: [] }); return; }
  const kw = `%${String(q).trim()}%`;
  const rows = getDB().prepare(
    'SELECT * FROM parts_inventory WHERE part_name LIKE ? OR part_code LIKE ? ORDER BY part_name LIMIT 30'
  ).all(kw, kw);
  res.json({ code: 200, data: rows });
}));

// 删除配件
router.delete('/parts/:id', auth, requireRole('admin'), asyncHandler(async (req: Request, res: Response) => {
  const part = getDB().prepare('SELECT * FROM parts_inventory WHERE id = ?').get(req.params.id);
  if (!part) { res.json({ code: 404, msg: '配件不存在' }); return; }
  // 检查是否有领用记录引用
  const refCount = (getDB().prepare('SELECT COUNT(*) as c FROM parts_requisitions WHERE part_id = ?').get(req.params.id) as { c: number }).c;
  if (refCount > 0) {
    res.json({ code: 400, msg: `该配件有${refCount}条领用记录，无法删除。可将其库存清零代替删除` });
    return;
  }
  getDB().prepare('DELETE FROM parts_inventory WHERE id = ?').run(req.params.id);
  res.json({ code: 200, msg: '已删除' });
}));

// 设置配件库存阈值
router.put('/parts/threshold', auth, requireRole('admin'), validate(partsThresholdSchema), asyncHandler(async (req: Request, res: Response) => {
  const { part_id, threshold } = req.body;
  const val = Math.max(1, Number(threshold));
  getDB().prepare("UPDATE parts_inventory SET threshold = ?, updated_at = datetime('now') WHERE id = ?").run(val, part_id);
  res.json({ code: 200, msg: '阈值已更新' });
}));

router.post('/parts/import', auth, requireRole('admin'), validate(partsImportSchema), asyncHandler(async (req: Request, res: Response) => {
  const { parts } = req.body;
  let added = 0, merged = 0;
  for (const p of parts) {
    try {
      let existing: Record<string, unknown> | undefined;
      if (p.part_code) {
        existing = getDB().prepare('SELECT * FROM parts_inventory WHERE part_code = ?').get(p.part_code) as Record<string, unknown> | undefined;
      }
      if (!existing) {
        existing = getDB().prepare('SELECT * FROM parts_inventory WHERE part_name = ?').get(p.part_name) as Record<string, unknown> | undefined;
      }
      if (existing) {
        getDB().prepare("UPDATE parts_inventory SET quantity = quantity + ?, updated_at = datetime('now') WHERE id = ?")
          .run(p.quantity || 0, existing.id);
        merged++;
      } else {
        getDB().prepare('INSERT INTO parts_inventory (part_name, part_code, quantity, unit) VALUES (?, ?, ?, ?)').run(
          p.part_name, p.part_code || '', p.quantity || 0, p.unit || '个');
        added++;
      }
    } catch { /* 跳过失败 */ }
  }
  res.json({ code: 200, msg: `导入完成：新增${added}条，累加${merged}条` });
}));

router.post('/parts/requisition', auth, requireRole('driver'), validate(partsRequisitionSchema), asyncHandler(async (req: Request, res: Response) => {
  const { part_id, vehicle_id, quantity, reason } = req.body;
  const part = getDB().prepare('SELECT * FROM parts_inventory WHERE id = ?').get(part_id) as Record<string, unknown> | undefined;
  if (!part) { res.json({ code: 404, msg: '配件不存在' }); return; }
  if (Number(part.quantity) < Number(quantity)) { res.json({ code: 400, msg: `库存不足(当前:${part.quantity})` }); return; }
  getDB().prepare('INSERT INTO parts_requisitions (user_id, part_id, vehicle_id, quantity, reason) VALUES (?, ?, ?, ?, ?)').run(
    req.user.id, part_id, vehicle_id || null, quantity, reason || '');
  res.json({ code: 200, msg: '申请已提交' });
}));

router.post('/parts/confirm/:reqId', auth, requireRole('admin'), asyncHandler(async (req: Request, res: Response) => {
  const reqItem = getDB().prepare('SELECT * FROM parts_requisitions WHERE id = ?').get(req.params.reqId) as Record<string, unknown> | undefined;
  if (!reqItem || reqItem.status !== 'pending') { res.json({ code: 400, msg: '状态异常' }); return; }
  getDB().prepare("UPDATE parts_inventory SET quantity = quantity - ?, updated_at = datetime('now') WHERE id = ?").run(reqItem.quantity, reqItem.part_id);
  getDB().prepare("UPDATE parts_requisitions SET status = 'completed', approved_by = ?, picked_up_at = datetime('now'), updated_at = datetime('now') WHERE id = ?").run(req.user.id, reqItem.id);
  res.json({ code: 200, msg: '已确认出库' });
}));

router.post('/parts/reject/:reqId', auth, requireRole('admin'), asyncHandler(async (req: Request, res: Response) => {
  getDB().prepare("UPDATE parts_requisitions SET status = 'rejected', approved_by = ? WHERE id = ?").run(req.user.id, req.params.reqId);
  res.json({ code: 200, msg: '已驳回' });
}));

router.get('/parts/requisitions', auth, asyncHandler(async (req: Request, res: Response) => {
  const { date_from, date_to, user_id } = req.query;
  let sql = `SELECT pr.*, pi.part_name, pi.part_code, u.name as user_name, v.plate_number
    FROM parts_requisitions pr
    JOIN parts_inventory pi ON pr.part_id = pi.id
    JOIN users u ON pr.user_id = u.id
    LEFT JOIN vehicles v ON pr.vehicle_id = v.id WHERE 1=1`;
  const params: (string | number)[] = [];
  if (date_from) { sql += ' AND pr.created_at >= ?'; params.push(String(date_from)); }
  if (date_to) { sql += ' AND pr.created_at <= ?'; params.push(String(date_to) + ' 23:59:59'); }
  if (user_id) { sql += ' AND pr.user_id = ?'; params.push(Number(user_id)); }
  sql += ' ORDER BY pr.created_at DESC';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// ==================== 考勤加班 ====================

// 查询当日考勤
router.get('/attendance/today', auth, asyncHandler(async (req: Request, res: Response) => {
  const today = dayjs().format('YYYY-MM-DD');
  const rec = getDB().prepare('SELECT * FROM driver_attendance WHERE driver_id = ? AND attendance_date = ?').get(req.user.id, today);
  res.json({ code: 200, data: rec || null });
}));

// 提交考勤
router.post('/attendance/submit', auth, validate(attendanceSubmitSchema), asyncHandler(async (req: Request, res: Response) => {
  const { attendance_symbol, overtime_hours, overtime_start, overtime_end, overtime_location, vehicle_type, plate_number } = req.body;
  const today = dayjs().format('YYYY-MM-DD');
  const existing = getDB().prepare('SELECT * FROM driver_attendance WHERE driver_id = ? AND attendance_date = ?').get(req.user.id, today) as Record<string, unknown> | undefined;
  if (existing && existing.attendance_symbol) {
    res.json({ code: 400, msg: '今日考勤已提交，不可重复提交' }); return;
  }
  let calcHours = Number(overtime_hours) || 0;
  if (overtime_start && overtime_end) {
    const [sh, sm] = String(overtime_start).split(':').map(Number);
    const [eh, em] = String(overtime_end).split(':').map(Number);
    calcHours = (eh + em / 60) - (sh + sm / 60);
    if (calcHours < 0) calcHours += 24;
    calcHours = Math.round(calcHours * 10) / 10;
  }
  if (existing) {
    getDB().prepare(
      `UPDATE driver_attendance SET attendance_symbol = ?, overtime_hours = ?, overtime_start = ?, overtime_end = ?, overtime_location = ?, vehicle_type = ?, plate_number = ? WHERE id = ?`
    ).run(attendance_symbol || '', calcHours, overtime_start || '', overtime_end || '', overtime_location || '', vehicle_type || '', plate_number || '', existing.id);
  } else {
    getDB().prepare(
      `INSERT INTO driver_attendance (driver_id, attendance_date, attendance_symbol, overtime_hours, overtime_start, overtime_end, overtime_location, vehicle_type, plate_number)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(req.user.id, today, attendance_symbol || '', calcHours, overtime_start || '', overtime_end || '', overtime_location || '', vehicle_type || '', plate_number || '');
  }
  res.json({ code: 200, msg: '提交成功', data: { overtime_hours: calcHours } });
}));

// 考勤统计（管理员/领导看全部，驾驶员只看自己）
router.get('/attendance/report', auth, requireRole('admin', 'leader', 'driver'), asyncHandler(async (req: Request, res: Response) => {
  const { month, driver_id, department_id } = req.query;
  if (!month) { res.json({ code: 400, msg: '请选择月份' }); return; }
  let sql = `SELECT da.*, u.name as driver_name FROM driver_attendance da JOIN users u ON da.driver_id = u.id
    WHERE substr(da.attendance_date, 1, 7) = ?`;
  const params: (string | number)[] = [String(month)];
  // 驾驶员只能查看自己的记录
  const effectiveDriverId = req.user.role === 'driver' ? req.user.id : (driver_id ? Number(driver_id) : undefined);
  if (effectiveDriverId) { sql += ' AND da.driver_id = ?'; params.push(effectiveDriverId); }
  if (department_id) { sql += ' AND u.department_id = ?'; params.push(Number(department_id)); }
  sql += ' ORDER BY da.driver_id, da.attendance_date';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// ==================== 导出 Excel (.xlsx) ====================

// 导出考勤表（日历横排：姓名 | 1 | 2 | ... | 31）
router.post('/export-attendance-xlsx', auth, requireRole('admin', 'leader'), validate(exportAttendanceSchema), asyncHandler(async (req: Request, res: Response) => {
  const { month, driver_id, department_id } = req.body;

  // 查询考勤数据
  let sql = `SELECT da.attendance_date, da.attendance_symbol, da.driver_id, u.name as driver_name
    FROM driver_attendance da JOIN users u ON da.driver_id=u.id
    WHERE substr(da.attendance_date,1,7)=?`;
  const params: (string|number)[] = [String(month)];
  if (driver_id) { sql += ' AND da.driver_id=?'; params.push(Number(driver_id)); }
  if (department_id) { sql += ' AND u.department_id=?'; params.push(Number(department_id)); }
  sql += ' ORDER BY u.name, da.attendance_date';
  const data = getDB().prepare(sql).all(...params) as Record<string,unknown>[];

  // 算出该月天数
  const [y, m] = month.split('-').map(Number);
  const daysInMonth = new Date(y, m, 0).getDate();

  // 按员工分组
  const empMap = new Map<number, { name: string; days: Record<number, string> }>();
  for (const d of data) {
    const eid = Number(d.driver_id);
    const day = parseInt(String(d.attendance_date).slice(-2), 10);
    if (!empMap.has(eid)) empMap.set(eid, { name: String(d.driver_name), days: {} });
    empMap.get(eid)!.days[day] = String(d.attendance_symbol || '');
  }

  // 构建列：姓名 + 1~31
  const columns: ColumnDef[] = [{ header: '姓名', width: 14 }];
  for (let d = 1; d <= daysInMonth; d++) {
    columns.push({ header: String(d), width: 5 });
  }

  // 构建行
  const rows: Record<string, unknown>[] = [];
  for (const [, emp] of empMap) {
    const row: Record<string, unknown> = { '姓名': emp.name };
    for (let d = 1; d <= daysInMonth; d++) {
      row[String(d)] = emp.days[d] || '';
    }
    rows.push(row);
  }

  const filename = (data.length > 0 ? '考勤表' : '考勤表') + '_' + month + '.xlsx';
  await sendExcel(res, filename, month + '考勤表', columns, rows);
}));

// 导出加班表（按姓名分组排序，同一个人排在一起）
router.post('/export-overtime-xlsx', auth, requireRole('admin', 'leader'), validate(exportAttendanceSchema), asyncHandler(async (req: Request, res: Response) => {
  const { month, driver_id, department_id } = req.body;

  let sql = `SELECT u.name as driver_name, da.attendance_date, da.overtime_start, da.overtime_end,
      da.overtime_hours, da.overtime_location, da.plate_number, da.vehicle_type
    FROM driver_attendance da JOIN users u ON da.driver_id=u.id
    WHERE substr(da.attendance_date,1,7)=? AND da.overtime_hours > 0`;
  const params: (string|number)[] = [String(month)];
  if (driver_id) { sql += ' AND da.driver_id=?'; params.push(Number(driver_id)); }
  if (department_id) { sql += ' AND u.department_id=?'; params.push(Number(department_id)); }
  sql += ' ORDER BY u.name';
  const data = getDB().prepare(sql).all(...params) as Record<string,unknown>[];

  const columns: ColumnDef[] = [
    { header:'姓名',width:12 },{ header:'日期',width:14,style:'date' },
    { header:'加班开始',width:14 },{ header:'加班结束',width:14 },
    { header:'加班小时',width:10 },{ header:'加班地点',width:16 },
    { header:'车辆编号',width:12 },{ header:'车型',width:14 },
  ];
  const rows = data.map(d => ({
    '姓名':d.driver_name,'日期':d.attendance_date,
    '加班开始':d.overtime_start||'','加班结束':d.overtime_end||'',
    '加班小时':Number(d.overtime_hours)||0,'加班地点':d.overtime_location||'',
    '车辆编号':d.plate_number||'','车型':d.vehicle_type||'',
  }));
  await sendExcel(res, '加班记录_'+month+'.xlsx', '加班记录', columns, rows);
}));

// 导出工时统计 Excel
router.post('/export-workhours-xlsx', auth, requireRole('admin', 'leader'), validate(exportAttendanceSchema), asyncHandler(async (req: Request, res: Response) => {
  const { month, driver_id, department_id } = req.body;
  let detailSql = `SELECT di.inspection_date, ROUND(di.end_hours - di.start_hours, 1) as work_hours,
            di.start_hours, di.end_hours, di.start_km, di.current_km as end_km,
            ROUND(MAX(di.current_km - di.start_km, 0), 1) as driven_km,
            di.fuel_amount, di.notes,
            u.name as driver_name, v.plate_number, v.vehicle_type
     FROM daily_inspections di JOIN users u ON di.driver_id=u.id JOIN vehicles v ON di.vehicle_id=v.id
     WHERE strftime('%Y-%m', di.inspection_date)=?`;
  const detailParams: (string|number)[] = [month];
  if (driver_id) { detailSql += ' AND di.driver_id=?'; detailParams.push(Number(driver_id)); }
  if (department_id) { detailSql += ' AND u.department_id=?'; detailParams.push(Number(department_id)); }
  detailSql += ' ORDER BY di.driver_id, di.inspection_date';
  const detail = getDB().prepare(detailSql).all(...detailParams) as Record<string,unknown>[];

  let summarySql = `SELECT u.name as driver_name, COUNT(DISTINCT di.inspection_date) as days,
            SUM(di.end_hours - di.start_hours) as total_hours, SUM(di.fuel_amount) as total_fuel,
            SUM(MAX(di.current_km - di.start_km, 0)) as total_km
     FROM daily_inspections di JOIN users u ON di.driver_id=u.id
     WHERE strftime('%Y-%m', di.inspection_date)=?`;
  const summaryParams: (string|number)[] = [month];
  if (driver_id) { summarySql += ' AND di.driver_id=?'; summaryParams.push(Number(driver_id)); }
  if (department_id) { summarySql += ' AND u.department_id=?'; summaryParams.push(Number(department_id)); }
  summarySql += ' GROUP BY di.driver_id';
  const summary = getDB().prepare(summarySql).all(...summaryParams) as Record<string,unknown>[];

  const columns: ColumnDef[] = [
    { header:'姓名',width:12 },{ header:'日期',width:12,style:'date' },{ header:'车辆',width:16 },{ header:'车型',width:12 },
    { header:'上班工时',width:10 },{ header:'下班工时',width:10 },{ header:'工时(h)',width:10 },
    { header:'上班公里',width:10 },{ header:'下班公里',width:10 },{ header:'行驶(km)',width:10 },
    { header:'加油(L)',width:10 },{ header:'备注',width:20 },
  ];
  const rows = detail.map(d => ({
    '姓名':d.driver_name,'日期':d.inspection_date,'车辆':d.plate_number||'-','车型':d.vehicle_type||'',
    '上班工时':Number(d.start_hours)||0,'下班工时':Number(d.end_hours)||0,'工时(h)':Number(d.work_hours)||0,
    '上班公里':Number(d.start_km)||0,'下班公里':Number(d.end_km)||0,'行驶(km)':Number(d.driven_km)||0,
    '加油(L)':Number(d.fuel_amount)||0,'备注':d.notes||'',
  }));
  // 插入汇总行
  (rows as any[]).unshift({ '姓名':'【汇总】', '日期':'', '车辆':'', '车型':'', '上班工时':'', '下班工时':'', '工时(h)':'', '上班公里':'', '下班公里':'', '行驶(km)':'', '加油(L)':'', '备注':'' });
  summary.forEach(s => { (rows as any[]).unshift({ '姓名':s.driver_name,'日期':s.days+'天','车辆':'','车型':'','上班工时':'','下班工时':'','工时(h)':Number(s.total_hours)||0,'上班公里':'','下班公里':'','行驶(km)':Number(s.total_km)||0,'加油(L)':Number(s.total_fuel)||0,'备注':'' }); });
  (rows as any[]).unshift({ '姓名':'【按人汇总】', '日期':'天数', '车辆':'', '车型':'', '上班工时':'', '下班工时':'', '工时(h)':'总工时', '上班公里':'', '下班公里':'', '行驶(km)':'总公里', '加油(L)':'总加油', '备注':'' });
  await sendExcel(res, '员工工时统计.xlsx', '工时', columns, rows);
}));

// 导出配件领用 Excel
router.post('/export-parts-xlsx', auth, requireRole('admin'), asyncHandler(async (req: Request, res: Response) => {
  const reqs = getDB().prepare(
    `SELECT pr.*, u.name as user_name, pi.part_name, pi.part_code, v.plate_number
     FROM parts_requisitions pr JOIN users u ON pr.user_id=u.id
     JOIN parts_inventory pi ON pr.part_id=pi.id LEFT JOIN vehicles v ON pr.vehicle_id=v.id
     ORDER BY pr.created_at DESC LIMIT 500`
  ).all() as Record<string,unknown>[];
  const sm: Record<string,string> = { pending:'待确认', completed:'已出库', rejected:'已驳回' };
  const columns: ColumnDef[] = [
    { header:'申请人',width:12 },{ header:'配件名称',width:16 },{ header:'编码',width:12 },
    { header:'车辆',width:14 },{ header:'数量',width:8 },{ header:'状态',width:10 },
    { header:'时间',width:16,style:'datetime' },
  ];
  const rows = reqs.map(x => ({
    '申请人':x.user_name,'配件名称':x.part_name,'编码':x.part_code||'-',
    '车辆':x.plate_number||'-','数量':Number(x.quantity)||0,
    '状态':sm[String(x.status)]||x.status,'时间':String(x.created_at||'').slice(0,16),
  }));
  await sendExcel(res, '配件领用记录.xlsx', '领用记录', columns, rows);
}));

export default router;
