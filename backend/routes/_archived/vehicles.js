const express = require('express');
const router = express.Router();
const { auth, requireRole } = require('../middleware/auth');
const { query, queryOne } = require('../utils/db');

// 获取所有车辆列表（含最新晚检end_hours用于保养预警）
router.get('/', auth, async (req, res) => {
  let sql = `
    SELECT v.*, u.name as driver_name, u.phone as driver_phone,
      (SELECT di.end_hours FROM daily_inspections di WHERE di.vehicle_id=v.id AND di.end_hours>0 ORDER BY di.inspection_date DESC, di.created_at DESC LIMIT 1) as latest_end_hours
    FROM vehicles v
    LEFT JOIN users u ON v.current_driver_id = u.id
    WHERE 1=1
  `;
  const params = [];
  sql += ' ORDER BY v.plate_number';
  res.json({ code: 200, data: await query(sql, params) });
});

// 保养完成重置
router.post('/:id/maintenance-done', auth, requireRole('admin'), async (req, res) => {
  const vehicle = await queryOne('SELECT * FROM vehicles WHERE id=?', [req.params.id]);
  if (!vehicle) return res.json({ code: 404, msg: '车辆不存在' });
  const latest = await queryOne(
    'SELECT end_hours FROM daily_inspections WHERE vehicle_id=? AND end_hours>0 ORDER BY inspection_date DESC LIMIT 1',
    [vehicle.id]
  );
  const current = latest ? latest.end_hours : (vehicle.initial_engine_hours || 0);
  const next = current + (vehicle.maintenance_interval_hours || 500);
  await query('UPDATE vehicles SET next_maintenance_hours=? WHERE id=?', [next, vehicle.id]);
  res.json({ code: 200, msg: `保养已确认，下次保养：${next}h` });
});

// 车辆详情
router.get('/:id', auth, async (req, res) => {
  const vehicle = await queryOne(
    `SELECT v.*, u.name as driver_name
     FROM vehicles v LEFT JOIN users u ON v.current_driver_id = u.id
     WHERE v.id = ?`, [req.params.id]
  );
  if (!vehicle) return res.json({ code: 404, msg: '车辆不存在' });

  // 维修历史
  const repairHistory = await query(
    `SELECT ro.*, rs.name as repair_shop_name
     FROM repair_orders ro
     LEFT JOIN repair_shops rs ON ro.repair_shop_id = rs.id
     WHERE ro.vehicle_id = ? AND ro.status IN ('completed','accepted')
     ORDER BY ro.updated_at DESC LIMIT 10`,
    [vehicle.id]
  );

  // 点检记录
  const inspections = await query(
    `SELECT di.*, u.name as driver_name
     FROM daily_inspections di
     JOIN users u ON di.driver_id = u.id
     WHERE di.vehicle_id = ?
     ORDER BY di.inspection_date DESC LIMIT 30`,
    [vehicle.id]
  );

  // 绑定历史
  const bindings = await query(
    `SELECT dvb.*, u.name as driver_name
     FROM driver_vehicle_bindings dvb
     JOIN users u ON dvb.driver_id = u.id
     WHERE dvb.vehicle_id = ?
     ORDER BY dvb.bind_date DESC`,
    [vehicle.id]
  );

  res.json({ code: 200, data: { vehicle, repairHistory, inspections, bindings } });
});

module.exports = router;
