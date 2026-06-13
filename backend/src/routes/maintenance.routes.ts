import { Router, Request, Response } from 'express';
import { auth, requireRole } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';

const router = Router();

// ==================== 保养状态列表 ====================

router.get('/list', auth, requireRole('admin', 'leader', 'driver', 'dispatcher'), asyncHandler(async (_req: Request, res: Response) => {
  // 每辆车取最新晚检工时 + 下次保养工时 + 保养周期 + 最新保养记录
  const rows = getDB().prepare(`
    SELECT v.id as vehicle_id, v.plate_number, v.vehicle_type, v.model,
       v.next_maintenance_hours, v.maintenance_interval_hours,
       COALESCE((SELECT current_km FROM vehicle_archives WHERE plate_number = v.plate_number), 0) as current_km,
       (SELECT di.end_hours FROM daily_inspections di
        WHERE di.vehicle_id = v.id AND di.end_hours > 0
        ORDER BY di.inspection_date DESC LIMIT 1) as current_hours,
       (SELECT mr.maintenance_date FROM maintenance_records mr
        WHERE mr.vehicle_id = v.id ORDER BY mr.maintenance_date DESC LIMIT 1) as last_maintenance_date,
       (SELECT mr.current_hours FROM maintenance_records mr
        WHERE mr.vehicle_id = v.id ORDER BY mr.maintenance_date DESC LIMIT 1) as last_maintenance_hours
    FROM vehicles v
    WHERE v.status != 'scrapped'
    ORDER BY v.next_maintenance_hours > 0 DESC,
       CASE WHEN v.next_maintenance_hours > 0 AND
         COALESCE((SELECT di.end_hours FROM daily_inspections di
           WHERE di.vehicle_id = v.id AND di.end_hours > 0
           ORDER BY di.inspection_date DESC LIMIT 1), 0) >= v.next_maintenance_hours
         THEN 0 ELSE 1 END,
       v.plate_number
  `).all() as Record<string, unknown>[];

  const results = rows.map(r => {
    const current = Number(r.current_hours) || 0;
    const next = Number(r.next_maintenance_hours) || 0;
    const interval = Number(r.maintenance_interval_hours) || 0;
    const remaining = next > 0 ? next - current : 0;
    let status: string;
    if (next <= 0) status = 'none';          // 未设置保养
    else if (remaining <= 0) status = 'overdue';  // 已过期
    else if (remaining <= interval * 0.1) status = 'soon';  // 即将到期（<10%）
    else status = 'normal';

    return { ...r, current_hours: current, next_maintenance_hours: next,
      maintenance_interval_hours: interval, remaining_hours: Math.round(remaining * 100) / 100,
      status };
  });

  res.json({ code: 200, data: results });
}));

// ==================== 记录保养 ====================

router.post('/record', auth, requireRole('admin', 'driver'), asyncHandler(async (req: Request, res: Response) => {
  const { vehicle_id, maintenance_date, current_hours, current_km, maintenance_type, description, cost, parts_info, operator_name, remark } = req.body;
  if (!vehicle_id || !maintenance_date) {
    res.json({ code: 400, msg: '请填写车辆和保养日期' }); return;
  }

  const vehicle = getDB().prepare('SELECT * FROM vehicles WHERE id = ?').get(vehicle_id) as Record<string, unknown>;
  if (!vehicle) { res.json({ code: 404, msg: '车辆不存在' }); return; }

  // 插入保养记录
  getDB().prepare(
    `INSERT INTO maintenance_records (vehicle_id, maintenance_date, current_hours, current_km, maintenance_type, description, cost, parts_info, operator_name, remark)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(vehicle_id, maintenance_date, current_hours || 0, current_km || 0, maintenance_type || 'regular',
    description || '', cost || 0, JSON.stringify(parts_info || []), operator_name || '', remark || '');

  // 自动更新下次保养工时 = 当前工时 + 保养周期
  const interval = Number(vehicle.maintenance_interval_hours) || 500;
  const curHours = Number(current_hours) || 0;
  const nextHours = curHours + interval;
  getDB().prepare('UPDATE vehicles SET next_maintenance_hours = ?, updated_at = datetime(\'now\') WHERE id = ?')
    .run(Math.round(nextHours), vehicle_id);

  res.json({ code: 200, msg: '保养记录已保存，下次保养工时已更新为 ' + nextHours + 'h' });
}));

// ==================== 某车保养历史 ====================

router.get('/records/:vehicleId', auth, requireRole('admin', 'leader', 'driver'), asyncHandler(async (req: Request, res: Response) => {
  const rows = getDB().prepare(
    `SELECT * FROM maintenance_records WHERE vehicle_id = ? ORDER BY maintenance_date DESC`
  ).all(req.params.vehicleId);
  res.json({ code: 200, data: rows });
}));

// ==================== 仪表盘预警统计 ====================

router.get('/alerts', auth, requireRole('admin', 'leader'), asyncHandler(async (_req: Request, res: Response) => {
  // 保养过期
  const overdue = getDB().prepare(`
    SELECT COUNT(*) as c FROM vehicles v
    WHERE v.status = 'normal' AND v.next_maintenance_hours > 0
    AND COALESCE((SELECT di.end_hours FROM daily_inspections di
      WHERE di.vehicle_id = v.id AND di.end_hours > 0
      ORDER BY di.inspection_date DESC LIMIT 1), 0) >= v.next_maintenance_hours
  `).get() as { c: number };

  // 即将到期（剩余<10%周期）
  const soon = getDB().prepare(`
    SELECT COUNT(*) as c FROM vehicles v
    WHERE v.status = 'normal' AND v.next_maintenance_hours > 0
    AND COALESCE((SELECT di.end_hours FROM daily_inspections di
      WHERE di.vehicle_id = v.id AND di.end_hours > 0
      ORDER BY di.inspection_date DESC LIMIT 1), 0) < v.next_maintenance_hours
    AND (v.next_maintenance_hours - COALESCE((SELECT di.end_hours FROM daily_inspections di
      WHERE di.vehicle_id = v.id AND di.end_hours > 0
      ORDER BY di.inspection_date DESC LIMIT 1), 0)) <= v.maintenance_interval_hours * 0.1
  `).get() as { c: number };

  // 隐患整改逾期
  const hazardOverdue = getDB().prepare(`
    SELECT COUNT(*) as c FROM hazards
    WHERE status IN ('reported','assigned','rectifying')
    AND deadline != '' AND date(deadline) < date('now')
  `).get() as { c: number };

  // 待审批报价超24小时
  const approvalStale = getDB().prepare(`
    SELECT COUNT(*) as c FROM (
      SELECT rq.id FROM repair_quotes rq
      JOIN repair_orders ro ON rq.order_id = ro.id
      WHERE rq.approved_at IS NULL AND ro.status = 'pending_approval'
      AND datetime(rq.created_at) < datetime('now', '-1 day')
      UNION ALL
      SELECT eo.id FROM external_repair_orders eo
      WHERE eo.status = 'pending_approval'
      AND datetime(eo.created_at) < datetime('now', '-1 day')
    )
  `).get() as { c: number };

  res.json({
    code: 200,
    data: {
      maintenance_overdue: overdue.c,
      maintenance_soon: soon.c,
      hazard_overdue: hazardOverdue.c,
      approval_stale: approvalStale.c,
    },
  });
}));

export default router;
