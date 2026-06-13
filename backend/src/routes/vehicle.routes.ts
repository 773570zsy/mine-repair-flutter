import { Router, Request, Response } from 'express';
import { auth } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';

const router = Router();

// 获取所有车辆（含最新工时+档案数据）
router.get('/', auth, asyncHandler(async (_req: Request, res: Response) => {
  const vehicles = getDB().prepare(
    `SELECT v.*,
      (SELECT di.end_hours FROM daily_inspections di
       WHERE di.vehicle_id = v.id AND di.end_hours > 0
       ORDER BY di.inspection_date DESC, di.created_at DESC LIMIT 1) as latest_end_hours,
      va.current_hours as archive_current_hours,
      va.next_maintenance_hours as archive_next_maintenance,
      va.maintenance_interval as archive_maintenance_interval,
      va.photos as archive_photos,
      va.manufacture_date as archive_manufacture_date,
      va.vin as archive_vin,
      va.insurance_expiry as archive_insurance_expiry,
      va.inspection_date as archive_inspection_date,
      va.has_behavior_monitor as archive_behavior_monitor,
      va.has_360_camera as archive_360_camera,
      va.department as archive_department,
      va.maintenance_interval_km as archive_maintenance_interval_km,
      va.next_maintenance_km as archive_next_maintenance_km,
      va.current_km as archive_current_km
     FROM vehicles v
     LEFT JOIN vehicle_archives va ON v.plate_number = va.plate_number
     WHERE v.status != 'scrapped' ORDER BY v.plate_number`
  ).all();
  res.json({ code: 200, data: vehicles });
}));

// 获取车辆详情
router.get('/:id', auth, asyncHandler(async (req: Request, res: Response) => {
  const vehicle = getDB().prepare('SELECT * FROM vehicles WHERE id = ?').get(req.params.id);
  if (!vehicle) { res.json({ code: 404, msg: '车辆不存在' }); return; }
  res.json({ code: 200, data: vehicle });
}));

// 获取当前司机绑定的车辆
router.get('/driver/:driverId', auth, asyncHandler(async (req: Request, res: Response) => {
  const bindings = getDB().prepare(
    `SELECT dvb.*, v.plate_number, v.vehicle_type, v.next_maintenance_hours, v.maintenance_interval_hours
     FROM driver_vehicle_bindings dvb JOIN vehicles v ON dvb.vehicle_id = v.id
     WHERE dvb.driver_id = ? AND dvb.unbind_date IS NULL`
  ).all(req.params.driverId);
  res.json({ code: 200, data: bindings });
}));

export default router;
