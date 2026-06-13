import { Router, Request, Response } from 'express';
import { auth, requireRole } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';
import { sendExcel, ColumnDef } from '../utils/excel';
import { z } from 'zod';
import { validate } from '../middleware/validate';

const archiveCreateSchema = z.object({
  plate_number: z.string().min(1, '请输入车牌号'),
}).passthrough();

const archiveUpdateSchema = z.object({
  plate_number: z.string().optional(),
}).passthrough();

const router = Router();

// ==================== 筛选用 ====================
router.get('/departments', auth, asyncHandler(async (_req: Request, res: Response) => {
  const rows = getDB().prepare(
    'SELECT DISTINCT department FROM vehicle_archives WHERE department IS NOT NULL AND department != \'\' ORDER BY department'
  ).all() as Record<string,unknown>[];
  res.json({ code: 200, data: rows.map(r => r.department) });
}));

router.get('/vehicle-types', auth, asyncHandler(async (_req: Request, res: Response) => {
  const rows = getDB().prepare(
    'SELECT DISTINCT vehicle_type FROM vehicle_archives WHERE vehicle_type IS NOT NULL AND vehicle_type != \'\' ORDER BY vehicle_type'
  ).all() as Record<string,unknown>[];
  res.json({ code: 200, data: rows.map(r => r.vehicle_type) });
}));

// ==================== 列表 ====================
router.get('/list', auth, asyncHandler(async (req: Request, res: Response) => {
  // 申请人不可查看
  if (req.user.role === 'applicant') {
    res.json({ code: 403, msg: '无权限' }); return;
  }
  const { department, vehicle_type } = req.query;
  let sql = `SELECT va.*,
      v.status as vehicle_status, v.current_driver_id,
      u.name as driver_name
     FROM vehicle_archives va
     LEFT JOIN vehicles v ON va.plate_number = v.plate_number
     LEFT JOIN users u ON v.current_driver_id = u.id
     WHERE 1=1`;
  const params: (string | number)[] = [];
  if (department && String(department).length > 0) {
    sql += ' AND va.department = ?'; params.push(String(department));
  }
  if (vehicle_type && String(vehicle_type).length > 0) {
    sql += ' AND va.vehicle_type = ?'; params.push(String(vehicle_type));
  }
  sql += ' ORDER BY va.plate_number';
  const list = getDB().prepare(sql).all(...params);
  res.json({ code: 200, data: list });
}));

// ==================== 详情 ====================
router.get('/:plate_number', auth, asyncHandler(async (req: Request, res: Response) => {
  if (req.user.role === 'applicant') {
    res.json({ code: 403, msg: '无权限' }); return;
  }
  const archive = getDB().prepare(
    `SELECT va.*, v.status as vehicle_status, v.current_driver_id, v.asset_value,
      u.name as driver_name
     FROM vehicle_archives va
     LEFT JOIN vehicles v ON va.plate_number = v.plate_number
     LEFT JOIN users u ON v.current_driver_id = u.id
     WHERE va.plate_number = ?`
  ).get(req.params.plate_number);
  if (!archive) { res.json({ code: 404, msg: '车辆档案不存在' }); return; }
  res.json({ code: 200, data: archive });
}));

// ==================== 新建 ====================
router.post('/', auth, requireRole('admin', 'dispatcher'), validate(archiveCreateSchema), asyncHandler(async (req: Request, res: Response) => {
  const {
    plate_number, department, vehicle_type, model, manufacture_date, vin,
    insurance_expiry, inspection_date, maintenance_interval,
    next_maintenance_hours, maintenance_interval_km, next_maintenance_km, current_km,
    purchase_date, asset_value, hourly_rate,
    has_behavior_monitor, has_360_camera, photos
  } = req.body;

  const exist = getDB().prepare('SELECT id FROM vehicle_archives WHERE plate_number = ?').get(plate_number.trim());
  if (exist) { res.json({ code: 400, msg: '该编号已存在' }); return; }

  const dept = department || '总调度室';

  getDB().prepare(
    `INSERT INTO vehicle_archives
     (plate_number, department, vehicle_type, model, manufacture_date, vin,
      insurance_expiry, inspection_date, maintenance_interval,
      next_maintenance_hours, maintenance_interval_km, next_maintenance_km, current_km,
      purchase_date, hourly_rate,
      has_behavior_monitor, has_360_camera, photos)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(
    plate_number.trim(), dept, vehicle_type || '', model || '', manufacture_date || '',
    vin || '', insurance_expiry || '', inspection_date || '',
    maintenance_interval || 500, next_maintenance_hours || 0,
    maintenance_interval_km || 0, next_maintenance_km || 0, current_km || 0,
    purchase_date || '', hourly_rate || 0,
    has_behavior_monitor ? 1 : 0, has_360_camera ? 1 : 0,
    photos ? JSON.stringify(photos) : '[]'
  );

  // 同步到 vehicles 表
  const vehExist = getDB().prepare('SELECT id FROM vehicles WHERE plate_number = ?').get(plate_number.trim());
  if (!vehExist) {
    getDB().prepare(
      `INSERT INTO vehicles (plate_number, vehicle_type, model, next_maintenance_hours, maintenance_interval_hours, asset_value, hourly_rate)
       VALUES (?, ?, ?, ?, ?, ?, ?)`
    ).run(plate_number.trim(), vehicle_type || '', model || '',
      next_maintenance_hours || 0, maintenance_interval || 500, asset_value || 0, hourly_rate || 0);
  }

  res.json({ code: 200, msg: '车辆档案已创建' });
}));

// ==================== 更新 ====================
router.put('/:plate_number', auth, requireRole('admin', 'dispatcher'), validate(archiveUpdateSchema), asyncHandler(async (req: Request, res: Response) => {
  const archive = getDB().prepare('SELECT * FROM vehicle_archives WHERE plate_number = ?').get(req.params.plate_number);
  if (!archive) { res.json({ code: 404, msg: '车辆档案不存在' }); return; }

  const {
    department, vehicle_type, model, manufacture_date, vin,
    insurance_expiry, inspection_date, maintenance_interval,
    next_maintenance_hours, maintenance_interval_km, next_maintenance_km, current_km,
    purchase_date, asset_value, hourly_rate,
    has_behavior_monitor, has_360_camera, photos
  } = req.body;

  const a = archive as Record<string, unknown>;

  const oldPlate = req.params.plate_number;
  const newPlate = (req.body.plate_number || oldPlate).trim();

  getDB().prepare(
    `UPDATE vehicle_archives SET
      plate_number = ?,
      department = ?, vehicle_type = ?, model = ?, manufacture_date = ?, vin = ?,
      insurance_expiry = ?, inspection_date = ?,
      maintenance_interval = ?, next_maintenance_hours = ?,
      maintenance_interval_km = ?, next_maintenance_km = ?, current_km = ?,
      purchase_date = ?, hourly_rate = ?,
      has_behavior_monitor = ?, has_360_camera = ?,
      photos = ?, updated_at = datetime('now')
     WHERE plate_number = ?`
  ).run(
    newPlate,
    department ?? a.department ?? '总调度室',
    vehicle_type ?? a.vehicle_type ?? '',
    model ?? a.model ?? '',
    manufacture_date ?? a.manufacture_date ?? '',
    vin ?? a.vin ?? '',
    insurance_expiry ?? a.insurance_expiry ?? '',
    inspection_date ?? a.inspection_date ?? '',
    maintenance_interval ?? a.maintenance_interval ?? 500,
    next_maintenance_hours ?? a.next_maintenance_hours ?? 0,
    maintenance_interval_km ?? a.maintenance_interval_km ?? 0,
    next_maintenance_km ?? a.next_maintenance_km ?? 0,
    current_km ?? a.current_km ?? 0,
    purchase_date ?? a.purchase_date ?? '',
    hourly_rate ?? a.hourly_rate ?? 0,
    has_behavior_monitor !== undefined ? (has_behavior_monitor ? 1 : 0) : (a.has_behavior_monitor ?? 0),
    has_360_camera !== undefined ? (has_360_camera ? 1 : 0) : (a.has_360_camera ?? 0),
    photos !== undefined ? JSON.stringify(photos) : (a.photos ?? '[]'),
    oldPlate
  );

  // 同步基础字段到 vehicles 表（含 plate_number）
  getDB().prepare(
    `UPDATE vehicles SET plate_number = ?, vehicle_type = ?, model = ?, next_maintenance_hours = ?, maintenance_interval_hours = ?, asset_value = ?, hourly_rate = ?
     WHERE plate_number = ?`
  ).run(
    newPlate,
    vehicle_type ?? a.vehicle_type ?? '',
    model ?? a.model ?? '',
    next_maintenance_hours ?? a.next_maintenance_hours ?? 0,
    maintenance_interval ?? a.maintenance_interval ?? 500,
    asset_value ?? a.asset_value ?? 0,
    hourly_rate ?? a.hourly_rate ?? 0,
    oldPlate
  );

  res.json({ code: 200, msg: '车辆档案已更新' });
}));

// ==================== 删除 ====================
router.delete('/:plate_number', auth, requireRole('admin'), asyncHandler(async (req: Request, res: Response) => {
  const archive = getDB().prepare('SELECT * FROM vehicle_archives WHERE plate_number = ?').get(req.params.plate_number);
  if (!archive) { res.json({ code: 404, msg: '车辆档案不存在' }); return; }

  // 检查是否有维修记录
  const veh = getDB().prepare('SELECT id FROM vehicles WHERE plate_number = ?').get(req.params.plate_number) as Record<string, unknown> | undefined;
  if (veh) {
    const cnt = getDB().prepare('SELECT COUNT(*) as c FROM repair_orders WHERE vehicle_id = ?').get(veh.id) as { c: number };
    if (cnt.c > 0) { res.json({ code: 400, msg: `该车辆有${cnt.c}条维修记录，不可删除` }); return; }
  }

  getDB().prepare('DELETE FROM vehicle_archives WHERE plate_number = ?').run(req.params.plate_number);
  // 同时删除 vehicles 表对应记录
  if (veh) {
    getDB().prepare('DELETE FROM driver_vehicle_bindings WHERE vehicle_id = ?').run(veh.id);
    getDB().prepare('DELETE FROM vehicles WHERE id = ?').run(veh.id);
  }
  res.json({ code: 200, msg: '已删除' });
}));

// ==================== 保养完成 ====================
router.post('/:plate_number/maintenance-done', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (req: Request, res: Response) => {
  const archive = getDB().prepare('SELECT * FROM vehicle_archives WHERE plate_number = ?').get(req.params.plate_number);
  if (!archive) { res.json({ code: 404, msg: '车辆档案不存在' }); return; }

  const a = archive as Record<string, unknown>;
  const interval = Number(a.maintenance_interval) || 500;
  const next = (Number(a.next_maintenance_hours) || 0) + interval;

  getDB().prepare(
    'UPDATE vehicle_archives SET next_maintenance_hours = ?, updated_at = datetime(\'now\') WHERE plate_number = ?'
  ).run(next, req.params.plate_number);

  // 同步到 vehicles 表
  getDB().prepare(
    'UPDATE vehicles SET next_maintenance_hours = ? WHERE plate_number = ?'
  ).run(next, req.params.plate_number);

  res.json({ code: 200, msg: '保养已完成，下次保养工时：' + next + 'h', data: { next_maintenance_hours: next } });
}));

// ==================== 保养完成（公里） ====================
router.post('/:plate_number/maintenance-done-km', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (req: Request, res: Response) => {
  const archive = getDB().prepare('SELECT * FROM vehicle_archives WHERE plate_number = ?').get(req.params.plate_number);
  if (!archive) { res.json({ code: 404, msg: '车辆档案不存在' }); return; }

  const a = archive as Record<string, unknown>;
  const interval = Number(a.maintenance_interval_km) || 10000;
  const next = (Number(a.next_maintenance_km) || 0) + interval;

  getDB().prepare(
    "UPDATE vehicle_archives SET next_maintenance_km = ?, updated_at = datetime('now') WHERE plate_number = ?"
  ).run(next, req.params.plate_number);

  res.json({ code: 200, msg: '保养已完成，下次保养公里：' + next + 'km', data: { next_maintenance_km: next } });
}));

// ==================== 导出档案 Excel ====================
router.post('/export-xlsx', auth, asyncHandler(async (req: Request, res: Response) => {
  if (req.user.role === 'applicant') {
    res.json({ code: 403, msg: '无权限' }); return;
  }
  const { department, vehicle_type } = req.body;
  let sql = `SELECT va.*, v.status as vehicle_status, u.name as driver_name
     FROM vehicle_archives va
     LEFT JOIN vehicles v ON va.plate_number = v.plate_number
     LEFT JOIN users u ON v.current_driver_id = u.id
     WHERE 1=1`;
  const params: (string | number)[] = [];
  if (department && String(department).length > 0) {
    sql += ' AND va.department = ?'; params.push(String(department));
  }
  if (vehicle_type && String(vehicle_type).length > 0) {
    sql += ' AND va.vehicle_type = ?'; params.push(String(vehicle_type));
  }
  sql += ' ORDER BY va.plate_number';
  const data = getDB().prepare(sql).all(...params) as Record<string,unknown>[];

  const columns: ColumnDef[] = [
    { header:'内部编号',width:16 },{ header:'归属部门',width:14 },{ header:'车型',width:14 },
    { header:'型号',width:12 },{ header:'当前工时(h)',width:12 },{ header:'当前公里(km)',width:12 },
    { header:'保养间隔h',width:10 },{ header:'下次保养h',width:12 },
    { header:'保养间隔km',width:10 },{ header:'下次保养km',width:12 },
    { header:'驾驶员',width:10 },{ header:'状态',width:10 },
    { header:'生产日期',width:12,style:'date' },{ header:'购入日期',width:12,style:'date' },
    { header:'保险到期',width:12,style:'date' },{ header:'年检时间',width:12,style:'date' },
    { header:'VIN',width:20 },{ header:'行为监控',width:8 },{ header:'360全景',width:8 },
  ];
  const stMap: Record<string,string> = { normal:'正常', repairing:'维修中', scrapped:'已报废' };
  const rows = data.map(d => ({
    '内部编号':d.plate_number,'归属部门':d.department||'','车型':d.vehicle_type||'',
    '型号':d.model||'','当前工时(h)':Number(d.current_hours)||0,'当前公里(km)':Number(d.current_km)||0,
    '保养间隔h':Number(d.maintenance_interval)||0,'下次保养h':Number(d.next_maintenance_hours)||0,
    '保养间隔km':Number(d.maintenance_interval_km)||0,'下次保养km':Number(d.next_maintenance_km)||0,
    '驾驶员':d.driver_name||'','状态':stMap[String(d.vehicle_status)]||d.vehicle_status||'',
    '生产日期':d.manufacture_date||'','购入日期':d.purchase_date||'',
    '保险到期':d.insurance_expiry||'','年检时间':d.inspection_date||'',
    'VIN':d.vin||'','行为监控':d.has_behavior_monitor?'是':'否','360全景':d.has_360_camera?'是':'否',
  }));
  await sendExcel(res, '车辆档案明细.xlsx', '车辆档案', columns, rows);
}));

export default router;
