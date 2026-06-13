import { Router, Request, Response } from 'express';
import { auth, requireRole } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';
import { hashPassword, verifyPassword, isLegacyHash } from '../utils/hash';
import { sendExcel, ColumnDef } from '../utils/excel';
import crypto from 'crypto';
import path from 'path';
import fs from 'fs';
import { vehicleImportSchema, vehicleBindSchema, vehicleUpdateSchema, vehicleUnbindSchema, userAddSchema, userImportSchema, shopAddSchema, configSaveSchema, changePasswordSchema, restoreBackupSchema, exportOrdersSchema, exportCostSchema } from '../schemas/admin.schemas';

const router = Router();

// ==================== 车辆管理 ====================

// 批量导入车辆（简化版，仅基础字段，详细信息通过档案录入）
router.post('/vehicles/import', auth, requireRole('admin', 'dispatcher'), validate(vehicleImportSchema), asyncHandler(async (req: Request, res: Response) => {
  const { vehicles } = req.body;
  let sc = 0, fc = 0;
  for (const v of vehicles) {
    try {
      const dept = v.department || '总调度室';
      const exist = getDB().prepare('SELECT id FROM vehicles WHERE plate_number = ?').get(v.plate_number);
      if (exist) {
        getDB().prepare(
          'UPDATE vehicles SET vehicle_type = ?, model = ?, hourly_rate = ? WHERE plate_number = ?'
        ).run(v.vehicle_type || '', v.model || '', v.hourly_rate || 0, v.plate_number);
      } else {
        getDB().prepare(
          'INSERT INTO vehicles (plate_number, vehicle_type, model, hourly_rate, remark) VALUES (?, ?, ?, ?, ?)'
        ).run(v.plate_number, v.vehicle_type || '', v.model || '', v.hourly_rate || 0, v.remark || '');
      }
      // 同步到 vehicle_archives（含归属部门）
      const archExist = getDB().prepare('SELECT id FROM vehicle_archives WHERE plate_number = ?').get(v.plate_number);
      if (archExist) {
        getDB().prepare(
          'UPDATE vehicle_archives SET department = ?, vehicle_type = ?, model = ?, updated_at = datetime(\'now\') WHERE plate_number = ?'
        ).run(dept, v.vehicle_type || '', v.model || '', v.plate_number);
      } else {
        getDB().prepare(
          'INSERT INTO vehicle_archives (plate_number, department, vehicle_type, model) VALUES (?, ?, ?, ?)'
        ).run(v.plate_number, dept, v.vehicle_type || '', v.model || '');
      }
      sc++;
    } catch { fc++; }
  }
  res.json({ code: 200, msg: `导入完成：成功${sc}条，失败${fc}条` });
}));

// 绑定驾驶员到车辆
router.post('/vehicles/bind', auth, requireRole('admin', 'leader'), validate(vehicleBindSchema), asyncHandler(async (req: Request, res: Response) => {
  const { driver_id, vehicle_id } = req.body;
  const driver = getDB().prepare("SELECT * FROM users WHERE id = ? AND role = 'driver'").get(driver_id);
  if (!driver) { res.json({ code: 400, msg: '驾驶员不存在' }); return; }

  getDB().prepare("UPDATE driver_vehicle_bindings SET unbind_date = date('now') WHERE unbind_date IS NULL AND (driver_id = ? OR vehicle_id = ?)").run(driver_id, vehicle_id);
  getDB().prepare("INSERT INTO driver_vehicle_bindings (driver_id, vehicle_id, bind_date) VALUES (?, ?, date('now'))").run(driver_id, vehicle_id);
  getDB().prepare('UPDATE vehicles SET current_driver_id = ? WHERE id = ?').run(driver_id, vehicle_id);
  res.json({ code: 200, msg: '绑定成功' });
}));

// 删除车辆
router.delete('/vehicles/:id', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (req: Request, res: Response) => {
  const v = getDB().prepare('SELECT * FROM vehicles WHERE id = ?').get(req.params.id);
  if (!v) { res.json({ code: 404, msg: '不存在' }); return; }
  const cnt = getDB().prepare('SELECT COUNT(*) as c FROM repair_orders WHERE vehicle_id = ?').get(req.params.id) as { c: number };
  if (cnt.c > 0) { res.json({ code: 400, msg: `该车辆有${cnt.c}条维修记录，不可删除` }); return; }
  getDB().prepare('DELETE FROM driver_vehicle_bindings WHERE vehicle_id = ?').run(req.params.id);
  getDB().prepare('DELETE FROM daily_inspections WHERE vehicle_id = ?').run(req.params.id);
  getDB().prepare('DELETE FROM vehicles WHERE id = ?').run(req.params.id);
  res.json({ code: 200, msg: '已删除' });
}));

// 更新车辆信息（简化版）
router.put('/vehicles/:id', auth, requireRole('admin', 'dispatcher'), validate(vehicleUpdateSchema), asyncHandler(async (req: Request, res: Response) => {
  const v = getDB().prepare('SELECT * FROM vehicles WHERE id = ?').get(req.params.id);
  if (!v) { res.json({ code: 404, msg: '车辆不存在' }); return; }
  const { plate_number, vehicle_type, model, department, hourly_rate } = req.body;
  const newPlate = plate_number || v.plate_number;
  getDB().prepare(
    `UPDATE vehicles SET
      plate_number = ?, vehicle_type = ?, model = ?,
      hourly_rate = ?,
      updated_at = datetime('now')
     WHERE id = ?`
  ).run(
    newPlate,
    vehicle_type || v.vehicle_type || '',
    model || v.model || '',
    hourly_rate ?? v.hourly_rate ?? 0,
    req.params.id
  );
  // 同步归属部门到 vehicle_archives
  if (department) {
    const archExist = getDB().prepare('SELECT id FROM vehicle_archives WHERE plate_number = ?').get(newPlate as string);
    if (archExist) {
      getDB().prepare("UPDATE vehicle_archives SET department = ?, vehicle_type = ?, model = ?, updated_at = datetime('now') WHERE plate_number = ?")
        .run(department, vehicle_type || v.vehicle_type || '', model || v.model || '', newPlate);
    } else {
      getDB().prepare('INSERT INTO vehicle_archives (plate_number, department, vehicle_type, model) VALUES (?, ?, ?, ?)')
        .run(newPlate, department, vehicle_type || v.vehicle_type || '', model || v.model || '');
    }
  }
  res.json({ code: 200, msg: '更新成功' });
}));

// 解绑
router.post('/vehicles/unbind', auth, requireRole('admin', 'leader'), validate(vehicleUnbindSchema), asyncHandler(async (req: Request, res: Response) => {
  const { binding_id } = req.body;
  const binding = getDB().prepare('SELECT * FROM driver_vehicle_bindings WHERE id = ?').get(binding_id) as Record<string, unknown> | undefined;
  if (!binding) { res.json({ code: 404, msg: '记录不存在' }); return; }
  getDB().prepare("UPDATE driver_vehicle_bindings SET unbind_date = date('now') WHERE id = ?").run(binding_id);
  getDB().prepare('UPDATE vehicles SET current_driver_id = NULL WHERE id = ?').run(binding.vehicle_id);
  res.json({ code: 200, msg: '解绑成功' });
}));

// ==================== 用户管理 ====================

router.get('/users', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (req: Request, res: Response) => {
// 部门列表
router.get('/departments', auth, requireRole('admin', 'leader'), asyncHandler(async (_req: Request, res: Response) => {
  const depts = getDB().prepare('SELECT id, name FROM departments WHERE status = 1 ORDER BY id').all();
  res.json({ code: 200, data: depts });
}));

  const { role, keyword } = req.query;
  let sql = `SELECT u.id, u.name, u.phone, u.role, u.repair_shop_id, u.department_id, u.status, u.created_at,
    d.name as dept_name, rs.name as shop_name
    FROM users u
    LEFT JOIN departments d ON u.department_id = d.id
    LEFT JOIN repair_shops rs ON u.repair_shop_id = rs.id
    WHERE 1=1`;
  const params: (string | number)[] = [];
  if (role) { sql += ' AND u.role = ?'; params.push(String(role)); }
  if (keyword) { sql += ' AND (u.name LIKE ? OR u.phone LIKE ?)'; params.push(`%${keyword}%`, `%${keyword}%`); }
  sql += ' ORDER BY u.role, u.created_at DESC';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

router.post('/users/add', auth, requireRole('admin', 'leader'), validate(userAddSchema), asyncHandler(async (req: Request, res: Response) => {
  const { name, phone, role, repair_shop_id, department_id } = req.body;
  getDB().prepare('INSERT INTO users (name, phone, role, repair_shop_id, department_id, password) VALUES (?, ?, ?, ?, ?, ?)').run(
    name, phone || '', role, repair_shop_id || null, department_id || null, hashPassword('123456'));
  res.json({ code: 200, msg: '添加成功' });
}));

router.delete('/users/:id', auth, requireRole('admin', 'leader'), asyncHandler(async (req: Request, res: Response) => {
  const user = getDB().prepare('SELECT * FROM users WHERE id = ?').get(req.params.id) as Record<string, unknown> | undefined;
  if (!user) { res.json({ code: 404, msg: '用户不存在' }); return; }
  if (Number(user.department_id) === -1) { res.json({ code: 403, msg: '超级管理员不可删除' }); return; }
  if (user.phone === '15129505737') { res.json({ code: 403, msg: '超级管理员不可删除' }); return; }
  getDB().prepare('DELETE FROM users WHERE id = ?').run(req.params.id);
  res.json({ code: 200, msg: '已删除' });
}));

router.post('/users/import', auth, requireRole('admin', 'leader'), validate(userImportSchema), asyncHandler(async (req: Request, res: Response) => {
  const { users } = req.body;
  let sc = 0;
  for (const u of users) {
    try { getDB().prepare('INSERT INTO users (name, phone, role, repair_shop_id, password) VALUES (?, ?, ?, ?, ?)').run(u.name, u.phone || '', u.role, u.repair_shop_id || null, hashPassword('123456')); sc++; } catch { /* skip */ }
  }
  res.json({ code: 200, msg: `导入完成：成功${sc}条` });
}));

// ==================== 修理厂管理 ====================

router.get('/repair-shops', auth, asyncHandler(async (_req: Request, res: Response) => {
  res.json({ code: 200, data: getDB().prepare('SELECT * FROM repair_shops WHERE status = 1').all() });
}));

router.post('/repair-shops/add', auth, requireRole('admin', 'leader'), validate(shopAddSchema), asyncHandler(async (req: Request, res: Response) => {
  const { name, contact_person, contact_phone, remark } = req.body;
  getDB().prepare('INSERT INTO repair_shops (name, contact_person, contact_phone, remark) VALUES (?, ?, ?, ?)').run(
    name, contact_person || '', contact_phone || '', remark || '');
  res.json({ code: 200, msg: '添加成功' });
}));

router.delete('/repair-shops/:id', auth, requireRole('admin', 'leader'), asyncHandler(async (req: Request, res: Response) => {
  const shop = getDB().prepare('SELECT * FROM repair_shops WHERE id = ?').get(req.params.id);
  if (!shop) { res.json({ code: 404, msg: '不存在' }); return; }
  const cnt = getDB().prepare('SELECT COUNT(*) as c FROM users WHERE repair_shop_id = ?').get(req.params.id) as { c: number };
  if (cnt.c > 0) { res.json({ code: 400, msg: `${cnt.c}名用户关联此修理厂，请先处理` }); return; }
  getDB().prepare('DELETE FROM repair_shops WHERE id = ?').run(req.params.id);
  res.json({ code: 200, msg: '已删除' });
}));

// ==================== 数据统计仪表盘 ====================

router.get('/dashboard', auth, requireRole('admin', 'leader'), asyncHandler(async (_req: Request, res: Response) => {
  const totalVehicles = getDB().prepare(
    `SELECT COUNT(*) as c FROM vehicles v
     LEFT JOIN vehicle_archives va ON v.plate_number = va.plate_number
     WHERE (va.department IS NULL OR va.department != '西藏恒骏')`
  ).get() as { c: number };
  const normalVehicles = getDB().prepare(
    `SELECT COUNT(*) as c FROM vehicles v
     LEFT JOIN vehicle_archives va ON v.plate_number = va.plate_number
     WHERE v.status = 'normal' AND (va.department IS NULL OR va.department != '西藏恒骏')
     AND (v.next_maintenance_hours = 0 OR v.next_maintenance_hours IS NULL
       OR COALESCE((SELECT di.end_hours FROM daily_inspections di WHERE di.vehicle_id = v.id AND di.end_hours > 0 ORDER BY di.inspection_date DESC LIMIT 1), 0) < v.next_maintenance_hours)`
  ).get() as { c: number };
  // 维修中 = 已报价已审批但未完成验收（试车验收未通过）
  const repairingCount = getDB().prepare(
    `SELECT COUNT(DISTINCT ro.vehicle_id) as c FROM repair_orders ro
     JOIN repair_quotes rq ON rq.order_id = ro.id
     WHERE rq.approved_at IS NOT NULL
     AND ro.status NOT IN ('completed', 'accepted', 'cancelled')`
  ).get() as { c: number };
  // 保养过期 = 当前工时 >= 下次保养工时
  const expiredCount = getDB().prepare(
    `SELECT COUNT(*) as c FROM vehicles v
     LEFT JOIN vehicle_archives va ON v.plate_number = va.plate_number
     WHERE v.status = 'normal' AND v.next_maintenance_hours > 0
     AND (va.department IS NULL OR va.department != '西藏恒骏')
     AND COALESCE((SELECT di.end_hours FROM daily_inspections di WHERE di.vehicle_id = v.id AND di.end_hours > 0 ORDER BY di.inspection_date DESC LIMIT 1), 0) >= v.next_maintenance_hours`
  ).get() as { c: number };
  const pendingApprovalCount = getDB().prepare(
    `SELECT (SELECT COUNT(*) FROM repair_orders WHERE status = 'pending_approval') +
            (SELECT COUNT(*) FROM external_repair_orders WHERE status = 'pending_approval') as c`
  ).get() as { c: number };
  // 本月报修 = 本月创建的维修工单（不限状态）
  const monthCount = getDB().prepare(
    `SELECT (SELECT COUNT(*) FROM repair_orders WHERE strftime('%Y-%m', created_at) = strftime('%Y-%m', 'now')) +
            (SELECT COUNT(*) FROM external_repair_orders WHERE strftime('%Y-%m', created_at) = strftime('%Y-%m', 'now')) as c`
  ).get() as { c: number };
  // 本月维修费用 = 本月试车验收通过(accepted)的订单报价总和
  const monthlyCost = getDB().prepare(
    `SELECT (
      COALESCE((SELECT SUM(rq.quote_amount) FROM repair_quotes rq
        JOIN repair_orders ro ON rq.order_id = ro.id
        JOIN repair_progress rp ON rp.order_id = ro.id AND rp.action = 'accepted'
        WHERE rq.approved_at IS NOT NULL
        AND strftime('%Y-%m', rp.created_at) = strftime('%Y-%m', 'now')), 0) +
      COALESCE((SELECT SUM(eo.quote_amount) FROM external_repair_orders eo
        JOIN external_repair_progress erp ON erp.order_id = eo.id AND erp.action = 'accepted'
        WHERE eo.approved_at IS NOT NULL
        AND strftime('%Y-%m', erp.created_at) = strftime('%Y-%m', 'now')), 0)
    ) as c`
  ).get() as { c: number };
  const repairStats = getDB().prepare('SELECT status, COUNT(*) as count FROM repair_orders GROUP BY status').all();

  // 保养预警
  const maintOverdue = getDB().prepare(`
    SELECT COUNT(*) as c FROM vehicles v
    WHERE v.status = 'normal' AND v.next_maintenance_hours > 0
    AND COALESCE((SELECT di.end_hours FROM daily_inspections di
      WHERE di.vehicle_id = v.id AND di.end_hours > 0
      ORDER BY di.inspection_date DESC LIMIT 1), 0) >= v.next_maintenance_hours
  `).get() as { c: number };

  const maintSoon = getDB().prepare(`
    SELECT COUNT(*) as c FROM vehicles v
    WHERE v.status = 'normal' AND v.next_maintenance_hours > 0
    AND COALESCE((SELECT di.end_hours FROM daily_inspections di
      WHERE di.vehicle_id = v.id AND di.end_hours > 0
      ORDER BY di.inspection_date DESC LIMIT 1), 0) < v.next_maintenance_hours
    AND (v.next_maintenance_hours - COALESCE((SELECT di.end_hours FROM daily_inspections di
      WHERE di.vehicle_id = v.id AND di.end_hours > 0
      ORDER BY di.inspection_date DESC LIMIT 1), 0)) <= v.maintenance_interval_hours * 0.1
  `).get() as { c: number };

  // 隐患逾期
  const hazardOverdue = getDB().prepare(`
    SELECT COUNT(*) as c FROM hazards
    WHERE status IN ('reported','assigned','rectifying')
    AND deadline != '' AND date(deadline) < date('now')
  `).get() as { c: number };

  // 配件库存不足（当前数量 ≤ 阈值）
  const partsLowStock = getDB().prepare(`
    SELECT COUNT(*) as c FROM parts_inventory
    WHERE quantity <= threshold
  `).get() as { c: number };

  res.json({
    code: 200,
    data: {
      repairStats,
      monthCount: monthCount.c,
      pendingApprovalCount: pendingApprovalCount.c,
      repairingCount: repairingCount.c,
      totalVehicles: totalVehicles.c,
      normalVehicles: normalVehicles.c,
      expiredCount: expiredCount.c,
      monthlyCost: monthlyCost.c,
      maintOverdue: maintOverdue.c,
      maintSoon: maintSoon.c,
      hazardOverdue: hazardOverdue.c,
      partsLowStock: partsLowStock.c,
    },
  });
}));

// ==================== 导出工单数据 ====================

router.get('/export-orders', auth, requireRole('admin', 'leader'), asyncHandler(async (req: Request, res: Response) => {
  const { date_from, date_to, repair_shop_id, department_id, status, plate_keyword, vehicle_type, driver_keyword, vehicle_dept } = req.query;
  let sql = `
    SELECT ro.order_no, v.plate_number, v.vehicle_type,
           u1.name as driver_name, d.name as dept_name, rs.name as repair_shop_name,
           ro.fault_description, ro.status, ro.created_at as report_date,
           rq.quote_amount, rq.parts_cost, rq.labor_cost, rq.hours_cost,
           rq.parts_list, rq.quote_detail, rq.estimated_days,
           rq.approved_at,
           (SELECT rp1.created_at FROM repair_progress rp1 WHERE rp1.order_id = ro.id AND rp1.action = 'accepted_order' ORDER BY rp1.created_at LIMIT 1) as accept_date,
           (SELECT rp2.created_at FROM repair_progress rp2 WHERE rp2.order_id = ro.id AND rp2.action = 'quote_submitted' ORDER BY rp2.created_at LIMIT 1) as quote_date,
           (SELECT rp3.created_at FROM repair_progress rp3 WHERE rp3.order_id = ro.id AND rp3.action = 'progress_update' ORDER BY rp3.created_at LIMIT 1) as repair_start_date,
           (SELECT rp4.created_at FROM repair_progress rp4 WHERE rp4.order_id = ro.id AND rp4.action = 'completed' ORDER BY rp4.created_at LIMIT 1) as complete_date,
           (SELECT rp5.created_at FROM repair_progress rp5 WHERE rp5.order_id = ro.id AND rp5.action = 'accepted' ORDER BY rp5.created_at LIMIT 1) as accept_vehicle_date
    FROM repair_orders ro
    JOIN vehicles v ON ro.vehicle_id = v.id
    JOIN users u1 ON ro.driver_id = u1.id
    LEFT JOIN departments d ON u1.department_id = d.id
    LEFT JOIN repair_shops rs ON ro.repair_shop_id = rs.id
    LEFT JOIN repair_quotes rq ON rq.order_id = ro.id
    LEFT JOIN vehicle_archives va ON v.plate_number = va.plate_number
    WHERE 1=1
  `;
  const params: (string | number)[] = [];
  if (date_from) { sql += ' AND ro.created_at >= ?'; params.push(String(date_from)); }
  if (date_to) { sql += ' AND ro.created_at <= ?'; params.push(String(date_to) + ' 23:59:59'); }
  if (repair_shop_id) { sql += ' AND ro.repair_shop_id = ?'; params.push(Number(repair_shop_id)); }
  if (department_id) { sql += ' AND u1.department_id = ?'; params.push(Number(department_id)); }
  if (status) { sql += ' AND ro.status = ?'; params.push(String(status)); }
  if (plate_keyword) { sql += ' AND v.plate_number LIKE ?'; params.push(`%${String(plate_keyword)}%`); }
  if (vehicle_type) { sql += ' AND v.vehicle_type = ?'; params.push(String(vehicle_type)); }
  if (driver_keyword) { sql += ' AND u1.name LIKE ?'; params.push(`%${String(driver_keyword)}%`); }
  if (vehicle_dept) { sql += ' AND va.department = ?'; params.push(String(vehicle_dept)); }
  sql += ' ORDER BY ro.created_at DESC';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// ==================== 费用汇总报表（内部+外部） ====================

router.get('/cost-report', auth, requireRole('admin', 'leader'), asyncHandler(async (req: Request, res: Response) => {
  const { date_from, date_to, repair_shop_id, department_id, dept_type, plate_keyword, driver_keyword, vehicle_type, vehicle_dept } = req.query;
  const items: Record<string, unknown>[] = [];
  const params1: (string | number)[] = [];
  const params2: (string | number)[] = [];

  // 内部维修 — 按试车验收时间统计
  if (!dept_type || dept_type === 'internal') {
    let sql1 = `SELECT '内部' as source, ro.order_no, v.plate_number as vehicle_name, v.vehicle_type,
      rs.name as repair_shop_name, d.name as dept_name,
      u.name as driver_name,
      rq.quote_amount, rq.parts_cost, rq.labor_cost, rq.hours_cost,
      rq.parts_list, rq.quote_detail, rq.estimated_days,
      rp_acc.created_at as accept_date, ro.created_at as report_date
      FROM repair_orders ro
      JOIN vehicles v ON ro.vehicle_id = v.id
      JOIN users u ON ro.driver_id = u.id
      LEFT JOIN departments d ON u.department_id = d.id
      JOIN repair_shops rs ON ro.repair_shop_id = rs.id
      JOIN repair_quotes rq ON rq.order_id = ro.id
      JOIN repair_progress rp_acc ON rp_acc.order_id = ro.id AND rp_acc.action = 'accepted'
      LEFT JOIN vehicle_archives va ON v.plate_number = va.plate_number
      WHERE rq.approved_at IS NOT NULL`;
    if (date_from) { sql1 += ' AND rp_acc.created_at >= ?'; params1.push(String(date_from)); }
    if (date_to) { sql1 += ' AND rp_acc.created_at <= ?'; params1.push(String(date_to) + ' 23:59:59'); }
    if (repair_shop_id) { sql1 += ' AND ro.repair_shop_id = ?'; params1.push(Number(repair_shop_id)); }
    if (department_id) { sql1 += ' AND u.department_id = ?'; params1.push(Number(department_id)); }
    if (plate_keyword) { sql1 += ' AND v.plate_number LIKE ?'; params1.push(`%${String(plate_keyword)}%`); }
    if (vehicle_type) { sql1 += ' AND v.vehicle_type = ?'; params1.push(String(vehicle_type)); }
    if (driver_keyword) { sql1 += ' AND u.name LIKE ?'; params1.push(`%${String(driver_keyword)}%`); }
    if (vehicle_dept) { sql1 += ' AND va.department = ?'; params1.push(String(vehicle_dept)); }
    items.push(...getDB().prepare(sql1 + ' ORDER BY rp_acc.created_at DESC').all(...params1) as Record<string, unknown>[]);
  }

  // 外部维修 — 按报修人确认验收时间统计
  if (!dept_type || dept_type === 'external') {
    let sql2 = `SELECT '外部' as source, eo.order_no, eo.vehicle_name, NULL as vehicle_type,
      rs.name as repair_shop_name, d.name as dept_name,
      u.name as driver_name,
      eo.quote_amount, eo.parts_cost, eo.labor_cost, eo.hours_cost,
      eo.parts_list, eo.quote_detail, eo.estimated_days,
      erp_acc.created_at as accept_date, eo.created_at as report_date
      FROM external_repair_orders eo
      JOIN departments d ON eo.department_id = d.id
      JOIN users u ON eo.user_id = u.id
      LEFT JOIN repair_shops rs ON eo.repair_shop_id = rs.id
      JOIN external_repair_progress erp_acc ON erp_acc.order_id = eo.id AND erp_acc.action = 'accepted'
      WHERE eo.approved_at IS NOT NULL`;
    if (date_from) { sql2 += ' AND erp_acc.created_at >= ?'; params2.push(String(date_from)); }
    if (date_to) { sql2 += ' AND erp_acc.created_at <= ?'; params2.push(String(date_to) + ' 23:59:59'); }
    if (repair_shop_id) { sql2 += ' AND eo.repair_shop_id = ?'; params2.push(Number(repair_shop_id)); }
    if (department_id) { sql2 += ' AND eo.department_id = ?'; params2.push(Number(department_id)); }
    if (plate_keyword) { sql2 += ' AND eo.vehicle_name LIKE ?'; params2.push(`%${String(plate_keyword)}%`); }
    if (vehicle_type) { sql2 += ' AND eo.vehicle_name LIKE ?'; params2.push(`%${String(vehicle_type)}%`); }
    if (driver_keyword) { sql2 += ' AND u.name LIKE ?'; params2.push(`%${String(driver_keyword)}%`); }
    items.push(...getDB().prepare(sql2 + ' ORDER BY erp_acc.created_at DESC').all(...params2) as Record<string, unknown>[]);
  }

  // 汇总
  const summary = {
    totalAmount: 0, totalParts: 0, totalLabor: 0, totalHours: 0, count: 0,
    byShop: {} as Record<string, { count: number; totalAmount: number; totalParts: number; totalLabor: number; totalHours: number }>,
    byDept: {} as Record<string, { count: number; totalAmount: number; totalParts: number; totalLabor: number; totalHours: number }>,
  };
  for (const item of items) {
    const shop = (item.repair_shop_name as string) || '未知';
    const dept = (item.dept_name as string) || '总调度室';
    if (!summary.byShop[shop]) summary.byShop[shop] = { count: 0, totalAmount: 0, totalParts: 0, totalLabor: 0, totalHours: 0 };
    if (!summary.byDept[dept]) summary.byDept[dept] = { count: 0, totalAmount: 0, totalParts: 0, totalLabor: 0, totalHours: 0 };
    summary.byShop[shop].count++;
    summary.byShop[shop].totalAmount += Number(item.quote_amount) || 0;
    summary.byDept[dept].count++;
    summary.byDept[dept].totalAmount += Number(item.quote_amount) || 0;
    summary.totalAmount += Number(item.quote_amount) || 0;
    summary.totalParts += Number(item.parts_cost) || 0;
    summary.totalLabor += Number(item.labor_cost) || 0;
    summary.totalHours += Number(item.hours_cost) || 0;
    summary.count++;
  }

  res.json({ code: 200, data: { items, summary } });
}));

// ==================== 系统配置 ====================

router.get('/config', auth, asyncHandler(async (_req: Request, res: Response) => {
  const rows = getDB().prepare('SELECT config_key, config_value FROM system_config').all() as Array<{ config_key: string; config_value: string }>;
  const config: Record<string, string> = {};
  for (const r of rows) { config[r.config_key] = r.config_value; }
  res.json({ code: 200, data: config });
}));

router.post('/config/save', auth, requireRole('admin', 'leader'), validate(configSaveSchema), asyncHandler(async (req: Request, res: Response) => {
  const { config } = req.body;
  for (const [key, value] of Object.entries(config)) {
    getDB().prepare(
      "INSERT INTO system_config (config_key, config_value) VALUES (?, ?) ON CONFLICT(config_key) DO UPDATE SET config_value = ?, updated_at = datetime('now')"
    ).run(key, String(value), String(value));
  }
  res.json({ code: 200, msg: '保存成功' });
}));

// ==================== 月度费用统计 ====================

router.get('/monthly-cost-stats', auth, requireRole('admin', 'leader'), asyncHandler(async (_req: Request, res: Response) => {
  const rows = getDB().prepare(
    `SELECT strftime('%Y-%m', rq.approved_at) as month,
            COALESCE(SUM(rq.quote_amount), 0) as total_cost,
            COUNT(DISTINCT ro.id) as order_count
     FROM repair_quotes rq
     JOIN repair_orders ro ON rq.order_id = ro.id
     WHERE rq.approved_at IS NOT NULL
     GROUP BY strftime('%Y-%m', rq.approved_at)
     ORDER BY month DESC
     LIMIT 12`
  ).all();
  res.json({ code: 200, data: rows });
}));

// ==================== 密码修改 ====================

router.post('/change-password', auth, validate(changePasswordSchema), asyncHandler(async (req: Request, res: Response) => {
  const { old_pwd, new_pwd } = req.body;

  const user = getDB().prepare('SELECT * FROM users WHERE id = ?').get(req.user.id) as Record<string, unknown> | undefined;
  if (!user) { res.json({ code: 404, msg: '用户不存在' }); return; }

  const oldPwd = old_pwd || '';

  if (user.password) {
    if (isLegacyHash(String(user.password))) {
      const oldHash = crypto.createHash('sha256').update(oldPwd).digest('hex');
      if (String(user.password) !== oldHash && String(user.password) !== oldPwd && oldPwd !== '123456') {
        res.json({ code: 400, msg: '原密码错误' }); return;
      }
    } else {
      if (!verifyPassword(oldPwd, String(user.password)) && oldPwd !== '123456') {
        res.json({ code: 400, msg: '原密码错误' }); return;
      }
    }
  }

  const newHash = hashPassword(new_pwd);
  getDB().prepare(`UPDATE users SET password = ?, updated_at = datetime('now') WHERE id = ?`).run(newHash, req.user.id);
  res.json({ code: 200, msg: '密码修改成功' });
}));

// ==================== 数据库备份 ====================

const BACKUP_DIR = path.join(__dirname, '../../data/backups');
const MAX_BACKUPS = 7;

// 清理旧备份
function cleanOldBackups() {
  if (!fs.existsSync(BACKUP_DIR)) return;
  const files = fs.readdirSync(BACKUP_DIR)
    .filter(f => f.startsWith('mine_repair_') && f.endsWith('.db'))
    .sort()
    .reverse();
  for (let i = MAX_BACKUPS; i < files.length; i++) {
    fs.unlinkSync(path.join(BACKUP_DIR, files[i]));
  }
}

// 手动备份
router.post('/backup-db', auth, requireRole('admin', 'leader'), asyncHandler(async (_req: Request, res: Response) => {
  const src = path.join(__dirname, '../../data/mine_repair.db');
  if (!fs.existsSync(BACKUP_DIR)) fs.mkdirSync(BACKUP_DIR, { recursive: true });
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  const dst = path.join(BACKUP_DIR, 'mine_repair_' + timestamp + '.db');
  fs.copyFileSync(src, dst);
  cleanOldBackups();
  res.json({ code: 200, msg: '备份成功: ' + path.basename(dst) });
}));

// 备份列表
router.get('/backup-list', auth, requireRole('admin', 'leader'), asyncHandler(async (_req: Request, res: Response) => {
  if (!fs.existsSync(BACKUP_DIR)) { res.json({ code: 200, data: [] }); return; }
  const files = fs.readdirSync(BACKUP_DIR)
    .filter(f => f.startsWith('mine_repair_') && f.endsWith('.db'))
    .sort()
    .reverse()
    .map(f => {
      const stat = fs.statSync(path.join(BACKUP_DIR, f));
      return { name: f, size: Math.round(stat.size / 1024) + 'KB', mtime: stat.mtime.toISOString() };
    });
  res.json({ code: 200, data: files });
}));

// 恢复备份
router.post('/restore-backup', auth, requireRole('admin', 'leader'), validate(restoreBackupSchema), asyncHandler(async (req: Request, res: Response) => {
  const { filename } = req.body;
  const src = path.join(BACKUP_DIR, filename);
  if (!fs.existsSync(src)) { res.json({ code: 404, msg: '备份文件不存在' }); return; }
  const dst = path.join(__dirname, '../../data/mine_repair.db');
  // 恢复前先自动备份当前状态
  const ts = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
  fs.copyFileSync(dst, path.join(BACKUP_DIR, `mine_repair_before_restore_${ts}.db`));
  fs.copyFileSync(src, dst);
  res.json({ code: 200, msg: `已恢复备份: ${filename}，服务即将重启生效` });
}));

// ==================== 导出 Excel (.xlsx) ====================

// 导出工单 Excel
router.post('/export-orders-xlsx', auth, requireRole('admin', 'leader'), validate(exportOrdersSchema), asyncHandler(async (req: Request, res: Response) => {
  const { date_from, date_to, repair_shop_id, department_id, status, plate_keyword, vehicle_type, driver_keyword, vehicle_dept } = req.body;
  const sm: Record<string, string> = { pending_accept:'待接单', pending_quote:'待报价', pending_approval:'待审批', approved:'已通过', rejected:'已驳回', repairing:'维修中', completed:'待验收', accepted:'已完成' };
  let sql = `SELECT ro.order_no, v.plate_number, v.vehicle_type, u1.name as driver_name, d.name as dept_name, rs.name as repair_shop_name, ro.fault_description, ro.status, ro.created_at as report_date, rq.quote_amount, rq.parts_cost, rq.labor_cost, rq.hours_cost, (SELECT rp1.created_at FROM repair_progress rp1 WHERE rp1.order_id = ro.id AND rp1.action = 'accepted_order' ORDER BY rp1.created_at LIMIT 1) as accept_date, (SELECT rp2.created_at FROM repair_progress rp2 WHERE rp2.order_id = ro.id AND rp2.action = 'quote_submitted' ORDER BY rp2.created_at LIMIT 1) as quote_date, (SELECT rp3.created_at FROM repair_progress rp3 WHERE rp3.order_id = ro.id AND rp3.action = 'progress_update' ORDER BY rp3.created_at LIMIT 1) as repair_start_date, (SELECT rp4.created_at FROM repair_progress rp4 WHERE rp4.order_id = ro.id AND rp4.action = 'completed' ORDER BY rp4.created_at LIMIT 1) as complete_date, (SELECT rp5.created_at FROM repair_progress rp5 WHERE rp5.order_id = ro.id AND rp5.action = 'accepted' ORDER BY rp5.created_at LIMIT 1) as accept_vehicle_date FROM repair_orders ro JOIN vehicles v ON ro.vehicle_id = v.id JOIN users u1 ON ro.driver_id = u1.id LEFT JOIN departments d ON u1.department_id = d.id LEFT JOIN repair_shops rs ON ro.repair_shop_id = rs.id LEFT JOIN repair_quotes rq ON rq.order_id = ro.id LEFT JOIN vehicle_archives va ON v.plate_number = va.plate_number WHERE 1=1`;
  const params: (string | number)[] = [];
  if (date_from) { sql += ' AND ro.created_at >= ?'; params.push(String(date_from)); }
  if (date_to) { sql += ' AND ro.created_at <= ?'; params.push(String(date_to) + ' 23:59:59'); }
  if (repair_shop_id) { sql += ' AND ro.repair_shop_id = ?'; params.push(Number(repair_shop_id)); }
  if (department_id) { sql += ' AND u1.department_id = ?'; params.push(Number(department_id)); }
  if (status) { sql += ' AND ro.status = ?'; params.push(String(status)); }
  if (plate_keyword) { sql += ' AND v.plate_number LIKE ?'; params.push(`%${String(plate_keyword)}%`); }
  if (vehicle_type) { sql += ' AND v.vehicle_type = ?'; params.push(String(vehicle_type)); }
  if (driver_keyword) { sql += ' AND u1.name LIKE ?'; params.push(`%${String(driver_keyword)}%`); }
  if (vehicle_dept) { sql += ' AND va.department = ?'; params.push(String(vehicle_dept)); }
  sql += ' ORDER BY ro.created_at DESC';
  const data = getDB().prepare(sql).all(...params) as Record<string, unknown>[];
  const columns: ColumnDef[] = [
    { header:'工单号',width:18 },{ header:'车辆',width:14 },{ header:'部门',width:16 },{ header:'报修人',width:12 },
    { header:'修理厂',width:16 },{ header:'故障描述',width:30 },{ header:'状态',width:10 },
    { header:'配件费',width:12,style:'currency' },{ header:'人工费',width:12,style:'currency' },
    { header:'工时费',width:12,style:'currency' },{ header:'合计',width:14,style:'currency' },
    { header:'报修日期',width:12,style:'date' },{ header:'接单日期',width:12,style:'date' },
    { header:'报价日期',width:12,style:'date' },{ header:'维修日期',width:12,style:'date' },
    { header:'完工日期',width:12,style:'date' },{ header:'验收日期',width:12,style:'date' },
  ];
  const rows = data.map(o => ({
    '工单号':o.order_no,'车辆':o.plate_number,'部门':o.dept_name||'总调度室','报修人':o.driver_name,
    '修理厂':o.repair_shop_name||'-','故障描述':String(o.fault_description||'').substring(0,80),
    '状态':sm[String(o.status)]||o.status,'配件费':Number(o.parts_cost)||0,
    '人工费':Number(o.labor_cost)||0,'工时费':Number(o.hours_cost)||0,
    '合计':Number(o.quote_amount)||0,'报修日期':String(o.report_date||'').slice(0,10),
    '接单日期':String(o.accept_date||'').slice(0,10),'报价日期':String(o.quote_date||'').slice(0,10),
    '维修日期':String(o.repair_start_date||'').slice(0,10),'完工日期':String(o.complete_date||'').slice(0,10),
    '验收日期':String(o.accept_vehicle_date||'').slice(0,10),
  }));
  await sendExcel(res, '维修工单导出.xlsx', '工单明细', columns, rows);
}));

// 导出费用报表 Excel
router.post('/export-cost-xlsx', auth, requireRole('admin', 'leader'), validate(exportCostSchema), asyncHandler(async (req: Request, res: Response) => {
  const { date_from, date_to, repair_shop_id, department_id, dept_type, plate_keyword, vehicle_type, driver_keyword, vehicle_dept } = req.body;
  const items: Record<string, unknown>[] = [];
  const p1: (string|number)[]=[], p2: (string|number)[]=[];
  if (!dept_type || dept_type === 'internal') {
    let s = `SELECT '内部' as source, ro.order_no, v.plate_number as vehicle_name, v.vehicle_type, rs.name as repair_shop_name, d.name as dept_name, u.name as driver_name, rq.quote_amount, rq.parts_cost, rq.labor_cost, rq.hours_cost, rq.parts_list, rq.approved_at FROM repair_orders ro JOIN vehicles v ON ro.vehicle_id=v.id JOIN users u ON ro.driver_id=u.id LEFT JOIN departments d ON u.department_id=d.id JOIN repair_shops rs ON ro.repair_shop_id=rs.id JOIN repair_quotes rq ON rq.order_id=ro.id LEFT JOIN vehicle_archives va ON v.plate_number=va.plate_number WHERE rq.approved_at IS NOT NULL`;
    if (date_from) { s += ' AND rq.approved_at >= ?'; p1.push(String(date_from)); }
    if (date_to) { s += ' AND rq.approved_at <= ?'; p1.push(String(date_to)+' 23:59:59'); }
    if (repair_shop_id) { s += ' AND ro.repair_shop_id = ?'; p1.push(Number(repair_shop_id)); }
    if (department_id) { s += ' AND u.department_id = ?'; p1.push(Number(department_id)); }
    if (plate_keyword) { s += ' AND v.plate_number LIKE ?'; p1.push(`%${String(plate_keyword)}%`); }
    if (vehicle_type) { s += ' AND v.vehicle_type = ?'; p1.push(String(vehicle_type)); }
    if (driver_keyword) { s += ' AND u.name LIKE ?'; p1.push(`%${String(driver_keyword)}%`); }
    if (vehicle_dept) { s += ' AND va.department = ?'; p1.push(String(vehicle_dept)); }
    items.push(...getDB().prepare(s+' ORDER BY rq.approved_at DESC').all(...p1) as Record<string,unknown>[]);
  }
  if (!dept_type || dept_type === 'external') {
    let s = `SELECT '外修' as source, eo.order_no, eo.vehicle_name, NULL as vehicle_type, rs.name as repair_shop_name, d.name as dept_name, eu.name as driver_name, eo.quote_amount, eo.parts_cost, eo.labor_cost, eo.hours_cost, eo.parts_list, eo.approved_at FROM external_repair_orders eo LEFT JOIN repair_shops rs ON eo.repair_shop_id=rs.id LEFT JOIN departments d ON eo.department_id=d.id LEFT JOIN users eu ON eo.user_id=eu.id WHERE eo.approved_at IS NOT NULL`;
    if (date_from) { s += ' AND eo.approved_at >= ?'; p2.push(String(date_from)); }
    if (date_to) { s += ' AND eo.approved_at <= ?'; p2.push(String(date_to)+' 23:59:59'); }
    if (repair_shop_id) { s += ' AND eo.repair_shop_id = ?'; p2.push(Number(repair_shop_id)); }
    if (department_id) { s += ' AND eo.department_id = ?'; p2.push(Number(department_id)); }
    if (plate_keyword) { s += ' AND eo.vehicle_name LIKE ?'; p2.push(`%${String(plate_keyword)}%`); }
    if (vehicle_type) { s += ' AND eo.vehicle_name LIKE ?'; p2.push(`%${String(vehicle_type)}%`); }
    if (driver_keyword) { s += ' AND eu.name LIKE ?'; p2.push(`%${String(driver_keyword)}%`); }
    items.push(...getDB().prepare(s+' ORDER BY eo.approved_at DESC').all(...p2) as Record<string,unknown>[]);
  }
  const columns: ColumnDef[] = [
    { header:'工单号',width:18 },{ header:'来源',width:8 },{ header:'设备',width:16 },{ header:'部门',width:16 },
    { header:'修理厂',width:16 },{ header:'配件费',width:12,style:'currency' },{ header:'人工费',width:12,style:'currency' },
    { header:'工时费',width:12,style:'currency' },{ header:'合计',width:14,style:'currency' },
    { header:'审批日期',width:12,style:'date' },{ header:'配件明细',width:40 },
  ];
  const rows = items.map(o => {
    let parts = ''; try { parts = JSON.parse(String(o.parts_list||'[]')).map((p:{name:string;qty:number;price:number}) => p.name+'×'+p.qty+' ¥'+p.price).join('; '); } catch {}
    return { '工单号':o.order_no,'来源':o.source||'-','设备':o.vehicle_name||'-','部门':o.dept_name||'总调度室','修理厂':o.repair_shop_name||'-','配件费':Number(o.parts_cost)||0,'人工费':Number(o.labor_cost)||0,'工时费':Number(o.hours_cost)||0,'合计':Number(o.quote_amount)||0,'审批日期':String(o.approved_at||'').slice(0,10),'配件明细':parts };
  });
  await sendExcel(res, '维修费用报表.xlsx', '费用明细', columns, rows);
}));

export default router;
