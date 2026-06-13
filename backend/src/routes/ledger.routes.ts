import { Router, Request, Response } from 'express';
import { auth, requireRole } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';
import { validate } from '../middleware/validate';
import {
  fuelRecordSchema,
  fuelRecordUpdateSchema,
  fuelImportSchema,
  partReplacementSchema,
  partReplacementUpdateSchema,
  yearMonthSchema,
  thresholdsSaveSchema,
  budgetConfigSaveSchema,
  budgetImportSchema,
} from '../schemas/ledger.schemas';

const router = Router();

// ==================== 燃油消耗记录 ====================

// 查询燃油记录（按车辆+月份筛选）
router.get('/fuel-records', auth, requireRole('driver', 'leader', 'admin'), asyncHandler(async (req: Request, res: Response) => {
  const { vehicle_id, year_month, page = '1', pageSize = '20' } = req.query;
  let sql = `SELECT fr.*, v.plate_number, v.vehicle_type, u.name as operator_name
    FROM fuel_records fr
    JOIN vehicles v ON fr.vehicle_id = v.id
    LEFT JOIN users u ON fr.operator_id = u.id
    WHERE 1=1`;
  const params: (string | number)[] = [];
  if (vehicle_id) { sql += ' AND fr.vehicle_id = ?'; params.push(Number(vehicle_id)); }
  if (year_month) { sql += ' AND strftime(\'%Y-%m\', fr.record_date) = ?'; params.push(String(year_month)); }
  sql += ' ORDER BY fr.record_date DESC';
  const total = (getDB().prepare(`SELECT COUNT(*) as c FROM (${sql})`).all(...params)[0] as { c: number }).c;
  const offset = (Number(page) - 1) * Number(pageSize);
  sql += ` LIMIT ${Number(pageSize)} OFFSET ${offset}`;
  const list = getDB().prepare(sql).all(...params);
  res.json({ code: 200, data: list, total, page: Number(page), pageSize: Number(pageSize) });
}));

// 录入加油记录
router.post('/fuel-records', auth, requireRole('driver', 'admin'), validate(fuelRecordSchema), asyncHandler(async (req: Request, res: Response) => {
  const { vehicle_id, record_date, fuel_amount, fuel_cost, hour_meter, station, operator_id, remark } = req.body;
  const result = getDB().prepare(
    'INSERT INTO fuel_records (vehicle_id, record_date, fuel_amount, fuel_cost, hour_meter, station, operator_id, remark) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
  ).run(vehicle_id, record_date, fuel_amount || 0, fuel_cost || 0, hour_meter || 0, station || '', operator_id || req.user.id, remark || '');
  res.json({ code: 200, msg: '录入成功', data: { id: result.lastInsertRowid } });
}));

// 修改加油记录
router.put('/fuel-records/:id', auth, requireRole('admin'), validate(fuelRecordUpdateSchema), asyncHandler(async (req: Request, res: Response) => {
  const { vehicle_id, record_date, fuel_amount, fuel_cost, hour_meter, station, remark } = req.body;
  const exist = getDB().prepare('SELECT * FROM fuel_records WHERE id = ?').get(req.params.id);
  if (!exist) { res.json({ code: 404, msg: '记录不存在' }); return; }
  getDB().prepare(
    'UPDATE fuel_records SET vehicle_id=?, record_date=?, fuel_amount=?, fuel_cost=?, hour_meter=?, station=?, remark=? WHERE id=?'
  ).run(vehicle_id, record_date, fuel_amount || 0, fuel_cost || 0, hour_meter || 0, station || '', remark || '', req.params.id);
  res.json({ code: 200, msg: '修改成功' });
}));

// 删除加油记录
router.delete('/fuel-records/:id', auth, requireRole('admin'), asyncHandler(async (req: Request, res: Response) => {
  const exist = getDB().prepare('SELECT * FROM fuel_records WHERE id = ?').get(req.params.id);
  if (!exist) { res.json({ code: 404, msg: '记录不存在' }); return; }
  getDB().prepare('DELETE FROM fuel_records WHERE id = ?').run(req.params.id);
  res.json({ code: 200, msg: '已删除' });
}));

// CSV批量导入燃油记录
router.post('/fuel-records/import', auth, requireRole('admin'), validate(fuelImportSchema), asyncHandler(async (req: Request, res: Response) => {
  const { records } = req.body;  // Array<{plate_number, date, liters, cost, hour_meter, station}>
  let success = 0, fail = 0;
  for (const r of records) {
    try {
      const vehicle = getDB().prepare('SELECT id FROM vehicles WHERE plate_number = ?').get(r.plate_number);
      if (!vehicle) { fail++; continue; }
      getDB().prepare(
        'INSERT INTO fuel_records (vehicle_id, record_date, fuel_amount, fuel_cost, hour_meter, station, operator_id) VALUES (?, ?, ?, ?, ?, ?, ?)'
      ).run((vehicle as Record<string, unknown>).id, r.date || r.record_date, r.liters || r.fuel_amount || 0, r.cost || r.fuel_cost || 0, r.hour_meter || 0, r.station || '', req.user.id);
      success++;
    } catch { fail++; }
  }
  res.json({ code: 200, msg: `导入完成：成功${success}条，失败${fail}条` });
}));

// ==================== 配件更换台账 ====================

// 查询配件更换记录
router.get('/part-replacements', auth, asyncHandler(async (req: Request, res: Response) => {
  const { vehicle_id, year_month, part_type, page = '1', pageSize = '20' } = req.query;
  let sql = `SELECT pr.*, v.plate_number, v.vehicle_type, u.name as operator_name
    FROM part_replacements pr
    JOIN vehicles v ON pr.vehicle_id = v.id
    LEFT JOIN users u ON pr.operator_id = u.id
    WHERE 1=1`;
  const params: (string | number)[] = [];
  if (vehicle_id) { sql += ' AND pr.vehicle_id = ?'; params.push(Number(vehicle_id)); }
  if (year_month) { sql += ' AND strftime(\'%Y-%m\', pr.replace_date) = ?'; params.push(String(year_month)); }
  if (part_type) { sql += ' AND pr.part_type = ?'; params.push(String(part_type)); }
  sql += ' ORDER BY pr.replace_date DESC';
  const total = (getDB().prepare(`SELECT COUNT(*) as c FROM (${sql})`).all(...params)[0] as { c: number }).c;
  const offset = (Number(page) - 1) * Number(pageSize);
  sql += ` LIMIT ${Number(pageSize)} OFFSET ${offset}`;
  res.json({ code: 200, data: getDB().prepare(sql).all(...params), total, page: Number(page), pageSize: Number(pageSize) });
}));

// 录入配件更换记录
router.post('/part-replacements', auth, requireRole('driver', 'admin'), validate(partReplacementSchema), asyncHandler(async (req: Request, res: Response) => {
  const { vehicle_id, part_name, part_type, replace_date, cost, current_hours, reason, remark } = req.body;
  const result = getDB().prepare(
    'INSERT INTO part_replacements (vehicle_id, part_name, part_type, replace_date, cost, current_hours, reason, operator_id, remark) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
  ).run(vehicle_id, part_name, part_type || 'other', replace_date, cost || 0, current_hours || 0, reason || '', req.user.id, remark || '');
  res.json({ code: 200, msg: '录入成功', data: { id: result.lastInsertRowid } });
}));

// 修改配件更换记录
router.put('/part-replacements/:id', auth, requireRole('admin'), validate(partReplacementUpdateSchema), asyncHandler(async (req: Request, res: Response) => {
  const { vehicle_id, part_name, part_type, replace_date, cost, current_hours, reason, remark } = req.body;
  const exist = getDB().prepare('SELECT * FROM part_replacements WHERE id = ?').get(req.params.id);
  if (!exist) { res.json({ code: 404, msg: '记录不存在' }); return; }
  getDB().prepare(
    'UPDATE part_replacements SET vehicle_id=?, part_name=?, part_type=?, replace_date=?, cost=?, current_hours=?, reason=?, remark=? WHERE id=?'
  ).run(vehicle_id, part_name, part_type || 'other', replace_date, cost || 0, current_hours || 0, reason || '', remark || '', req.params.id);
  res.json({ code: 200, msg: '修改成功' });
}));

// 删除配件更换记录
router.delete('/part-replacements/:id', auth, requireRole('admin'), asyncHandler(async (req: Request, res: Response) => {
  const exist = getDB().prepare('SELECT * FROM part_replacements WHERE id = ?').get(req.params.id);
  if (!exist) { res.json({ code: 404, msg: '记录不存在' }); return; }
  getDB().prepare('DELETE FROM part_replacements WHERE id = ?').run(req.params.id);
  res.json({ code: 200, msg: '已删除' });
}));

// CSV批量导入配件更换记录
router.post('/part-replacements/import', auth, requireRole('admin'), validate(fuelImportSchema), asyncHandler(async (req: Request, res: Response) => {
  const { records } = req.body;
  let success = 0, fail = 0;
  for (const r of records) {
    try {
      const vehicle = getDB().prepare('SELECT id FROM vehicles WHERE plate_number = ?').get(r.plate_number);
      if (!vehicle) { fail++; continue; }
      getDB().prepare(
        'INSERT INTO part_replacements (vehicle_id, part_name, part_type, replace_date, cost, current_hours, reason, operator_id, remark) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
      ).run((vehicle as Record<string, unknown>).id, r.part_name, r.part_type || 'other', r.replace_date || r.date, r.cost || 0, r.current_hours || 0, r.reason || '', req.user.id, r.remark || '');
      success++;
    } catch { fail++; }
  }
  res.json({ code: 200, msg: `导入完成：成功${success}条，失败${fail}条` });
}));

// ==================== 月度单车核算清单 ====================

// 查询月度清单
router.get('/monthly', auth, requireRole('leader', 'admin'), asyncHandler(async (req: Request, res: Response) => {
  const { year_month, vehicle_id, status } = req.query;
  let sql = `SELECT ml.*, v.plate_number, v.vehicle_type
    FROM monthly_ledger ml
    JOIN vehicles v ON ml.vehicle_id = v.id
    WHERE 1=1`;
  const params: (string | number)[] = [];
  if (year_month) { sql += ' AND ml.year_month = ?'; params.push(String(year_month)); }
  if (vehicle_id) { sql += ' AND ml.vehicle_id = ?'; params.push(Number(vehicle_id)); }
  if (status) { sql += ' AND ml.status = ?'; params.push(String(status)); }
  sql += ' ORDER BY ml.year_month DESC, ml.total_cost DESC';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 可用年月列表（供筛选下拉）
router.get('/monthly/months', auth, requireRole('leader', 'admin'), asyncHandler(async (_req: Request, res: Response) => {
  const months = getDB().prepare(
    "SELECT DISTINCT year_month FROM monthly_ledger ORDER BY year_month DESC"
  ).all() as { year_month: string }[];
  res.json({ code: 200, data: months.map(m => m.year_month) });
}));

// 年度汇总 — 按年份聚合全部月度清单（含草稿/待审批/已审批）
router.get('/annual', auth, requireRole('leader', 'admin'), asyncHandler(async (req: Request, res: Response) => {
  const { year } = req.query;
  if (!year) { res.json({ code: 400, msg: '请指定年份(格式: YYYY)' }); return; }

  const rows = getDB().prepare(
    `SELECT v.id as vehicle_id, v.plate_number, v.vehicle_type,
       COALESCE(SUM(ml.fuel_cost), 0) as fuel_cost,
       COALESCE(SUM(ml.repair_cost), 0) as repair_cost,
       COALESCE(SUM(ml.parts_cost), 0) as parts_cost,
       COALESCE(SUM(ml.total_cost), 0) as total_cost,
       COALESCE(SUM(ml.revenue), 0) as revenue,
       COALESCE(SUM(ml.profit), 0) as profit,
       COALESCE(SUM(ml.work_days), 0) as work_days,
       COALESCE(SUM(ml.total_hours), 0) as total_hours,
       COUNT(ml.id) as month_count,
       SUM(CASE WHEN ml.status = 'approved' THEN 1 ELSE 0 END) as approved_count,
       SUM(CASE WHEN ml.status = 'draft' THEN 1 ELSE 0 END) as draft_count,
       SUM(CASE WHEN ml.status = 'submitted' THEN 1 ELSE 0 END) as submitted_count
    FROM vehicles v
    JOIN monthly_ledger ml ON ml.vehicle_id = v.id AND ml.year_month LIKE ?
    WHERE v.status != 'scrapped'
    GROUP BY v.id
    ORDER BY total_cost DESC`
  ).all(`${year}-%`) as Record<string, unknown>[];

  // 计算年度油耗 = 总燃油费 / 总工时
  const results = rows.map(r => ({
    ...r,
    hourly_fuel_consumption: Number(r.total_hours) > 0
      ? Math.round((Number(r.fuel_cost) / Number(r.total_hours)) * 100) / 100
      : 0,
  }));

  res.json({ code: 200, data: results });
}));

// ==================== 趋势对比 ====================

// 获取车辆月度趋势数据（环比变化 + 连续上涨检测）
router.get('/trend', auth, requireRole('leader', 'admin'), asyncHandler(async (req: Request, res: Response) => {
  const { year, vehicle_id } = req.query;
  if (!year) { res.json({ code: 400, msg: '请指定年份(格式: YYYY)' }); return; }

  let sql = `SELECT ml.*, v.plate_number, v.vehicle_type, v.model
    FROM monthly_ledger ml
    JOIN vehicles v ON ml.vehicle_id = v.id
    WHERE ml.year_month LIKE ? AND v.status != 'scrapped'`;
  const params: (string | number)[] = [`${year}-%`];

  if (vehicle_id) { sql += ' AND ml.vehicle_id = ?'; params.push(Number(vehicle_id)); }

  sql += ' ORDER BY ml.vehicle_id, ml.year_month ASC';

  const rows = getDB().prepare(sql).all(...params) as Record<string, unknown>[];

  // 按车辆分组
  const vehicleMap: Record<number, {
    vehicle_id: number; plate_number: string; vehicle_type: string; model: string;
    months: Record<string, unknown>[];
  }> = {};

  for (const r of rows) {
    const vid = Number(r.vehicle_id);
    if (!vehicleMap[vid]) {
      vehicleMap[vid] = {
        vehicle_id: vid,
        plate_number: String(r.plate_number || ''),
        vehicle_type: String(r.vehicle_type || ''),
        model: String(r.model || ''),
        months: [],
      };
    }
    vehicleMap[vid].months.push(r);
  }

  const results: Record<string, unknown>[] = [];

  for (const entry of Object.values(vehicleMap)) {
    const months = entry.months;
    const data: Record<string, unknown>[] = [];

    let consecRising = 0; // 连续上涨计数器
    let maxConsecRising = 0;
    let sumFuelConsumption = 0;
    let sumRepairCost = 0;
    let consumptionCount = 0;

    for (let i = 0; i < months.length; i++) {
      const m = months[i];
      const prev = i > 0 ? months[i - 1] : null;

      const fuelCost = Number(m.fuel_cost) || 0;
      const repairCost = Number(m.repair_cost) || 0;
      const partsCost = Number(m.parts_cost) || 0;
      const totalCost = Number(m.total_cost) || 0;
      const profit = Number(m.profit) || 0;
      const hfc = Number(m.hourly_fuel_consumption) || 0;

      // 环比变化计算
      const prevFuel = prev ? (Number(prev.fuel_cost) || 0) : null;
      const prevRepair = prev ? (Number(prev.repair_cost) || 0) : null;
      const prevParts = prev ? (Number(prev.parts_cost) || 0) : null;
      const prevTotal = prev ? (Number(prev.total_cost) || 0) : null;
      const prevProfit = prev ? (Number(prev.profit) || 0) : null;

      const fuelChange = prevFuel !== null ? Math.round((fuelCost - prevFuel) * 100) / 100 : null;
      const fuelChangePct = prevFuel !== null && prevFuel !== 0 ? Math.round((fuelChange! / prevFuel) * 1000) / 10 : (prevFuel !== null ? null : null);
      const repairChange = prevRepair !== null ? Math.round((repairCost - prevRepair) * 100) / 100 : null;
      const repairChangePct = prevRepair !== null && prevRepair !== 0 ? Math.round((repairChange! / prevRepair) * 1000) / 10 : (prevRepair !== null ? null : null);
      const partsChange = prevParts !== null ? Math.round((partsCost - prevParts) * 100) / 100 : null;
      const partsChangePct = prevParts !== null && prevParts !== 0 ? Math.round((partsChange! / prevParts) * 1000) / 10 : (prevParts !== null ? null : null);
      const totalChange = prevTotal !== null ? Math.round((totalCost - prevTotal) * 100) / 100 : null;
      const totalChangePct = prevTotal !== null && prevTotal !== 0 ? Math.round((totalChange! / prevTotal) * 1000) / 10 : (prevTotal !== null ? null : null);
      const profitChange = prevProfit !== null ? Math.round((profit - prevProfit) * 100) / 100 : null;
      const profitChangePct = prevProfit !== null && prevProfit !== 0 ? Math.round((profitChange! / prevProfit) * 1000) / 10 : (prevProfit !== null ? null : null);

      // 维修费连续上涨检测
      if (i > 0) {
        const currR = repairCost;
        const prevR = Number(months[i - 1].repair_cost) || 0;
        if (currR > prevR) {
          consecRising++;
        } else {
          consecRising = 0;
        }
      }
      if (consecRising > maxConsecRising) maxConsecRising = consecRising;

      // 累计统计
      sumRepairCost += repairCost;
      if (hfc > 0) { sumFuelConsumption += hfc; consumptionCount++; }

      data.push({
        year_month: m.year_month,
        fuel_cost: fuelCost,
        repair_cost: repairCost,
        parts_cost: partsCost,
        total_cost: totalCost,
        hourly_fuel_consumption: hfc,
        work_days: Number(m.work_days) || 0,
        total_hours: Number(m.total_hours) || 0,
        revenue: Number(m.revenue) || 0,
        profit: profit,
        status: m.status,
        fuel_cost_change: fuelChange,
        fuel_cost_change_pct: fuelChangePct,
        repair_cost_change: repairChange,
        repair_cost_change_pct: repairChangePct,
        parts_cost_change: partsChange,
        parts_cost_change_pct: partsChangePct,
        total_cost_change: totalChange,
        total_cost_change_pct: totalChangePct,
        profit_change: profitChange,
        profit_change_pct: profitChangePct,
        repair_rising_consecutive: consecRising,
      });
    }

    results.push({
      vehicle_id: entry.vehicle_id,
      plate_number: entry.plate_number,
      vehicle_type: entry.vehicle_type,
      model: entry.model,
      alerts: {
        has_rising_alert: maxConsecRising >= 2,
        max_repair_rising_consecutive: maxConsecRising,
        avg_hourly_fuel_consumption: consumptionCount > 0 ? Math.round((sumFuelConsumption / consumptionCount) * 100) / 100 : 0,
        avg_monthly_repair_cost: months.length > 0 ? Math.round((sumRepairCost / months.length) * 100) / 100 : 0,
        total_repair_cost: Math.round(sumRepairCost * 100) / 100,
      },
      data,
    });
  }

  res.json({ code: 200, data: results });
}));

// 自动汇总生成月度清单 — 数据来源全部来自本系统已有模块
router.post('/monthly/generate', auth, requireRole('admin'), validate(yearMonthSchema), asyncHandler(async (req: Request, res: Response) => {
  const { year_month } = req.body;

  // 读取燃油单价配置
  const fuelPriceRow = getDB().prepare("SELECT config_value FROM system_config WHERE config_key = 'fuel_unit_price'").get() as { config_value: string } | undefined;
  const fuelUnitPrice = fuelPriceRow ? Number(fuelPriceRow.config_value) || 8.5 : 8.5;

  const vehicles = getDB().prepare('SELECT * FROM vehicles WHERE status != ?').all('scrapped') as Record<string, unknown>[];
  const results: Record<string, unknown>[] = [];

  for (const v of vehicles) {
    const vid = v.id as number;

    // 1. 燃油费用 — 来源：晚检加油记录(daily_inspections.fuel_amount × 油价)
    const fuelRow = getDB().prepare(
      `SELECT COALESCE(SUM(fuel_amount), 0) as liters FROM daily_inspections
       WHERE vehicle_id = ? AND strftime('%Y-%m', inspection_date) = ?`
    ).get(vid, year_month) as { liters: number };
    const fuelCost = Math.round(fuelRow.liters * fuelUnitPrice * 100) / 100;

    // 2. 维修费用 — 来源：维修模块已验收订单(repair_quotes)，按试车验收通过时间计入
    const repairRow = getDB().prepare(
      `SELECT COALESCE(SUM(rq.quote_amount), 0) as total FROM repair_quotes rq
       JOIN repair_orders ro ON rq.order_id = ro.id
       JOIN repair_progress rp ON rp.order_id = ro.id AND rp.action = 'accepted'
       WHERE ro.vehicle_id = ? AND rq.approved_at IS NOT NULL AND strftime('%Y-%m', rp.created_at) = ?`
    ).get(vid, year_month) as { total: number };
    const repairCost = repairRow.total;

    // 3. 配件费用 — 来源：驾驶员领用记录(parts_requisitions × parts_inventory.unit_price)
    const partsRow = getDB().prepare(
      `SELECT COALESCE(SUM(pr.quantity * pi.unit_price), 0) as total
       FROM parts_requisitions pr JOIN parts_inventory pi ON pr.part_id = pi.id
       WHERE pr.vehicle_id = ? AND pr.status = 'completed' AND strftime('%Y-%m', pr.picked_up_at) = ?`
    ).get(vid, year_month) as { total: number };
    const partsCost = partsRow.total;

    // 4. 出勤天数 — 来源：考勤模块(driver_attendance)，按车辆绑定驾驶员匹配
    const attRow = getDB().prepare(
      `SELECT COUNT(*) as days FROM driver_attendance da
       JOIN driver_vehicle_bindings dvb ON da.driver_id = dvb.driver_id
       WHERE dvb.vehicle_id = ? AND dvb.unbind_date IS NULL AND strftime('%Y-%m', da.attendance_date) = ?`
    ).get(vid, year_month) as { days: number };
    const workDays = attRow.days;

    // 5. 工时合计 — 来源：晚检工时记录(daily_inspections.end_hours - start_hours)
    const hoursRow = getDB().prepare(
      `SELECT COALESCE(SUM(end_hours - start_hours), 0) as hrs FROM daily_inspections
       WHERE vehicle_id = ? AND strftime('%Y-%m', inspection_date) = ?`
    ).get(vid, year_month) as { hrs: number };
    const totalHours = Math.round(Number(hoursRow.hrs) * 100) / 100;

    // 6. 小时耗油量 — 月度总加油量(L) ÷ 月度总工时(h)
    const hourlyFuelConsumption = totalHours > 0 ? Math.round((fuelRow.liters / totalHours) * 100) / 100 : 0;

    // 7. 总成本
    const totalCost = Math.round((fuelCost + repairCost + partsCost) * 100) / 100;

    // 8. 收入 = 月度总工时 × 小时单价
    const hourlyRate = Number(v.hourly_rate) || 0;
    const revenue = Math.round(totalHours * hourlyRate * 100) / 100;

    // 9. 盈亏 = 收入 - 总成本
    const profit = Math.round((revenue - totalCost) * 100) / 100;

    // UPSERT monthly_ledger
    const existing = getDB().prepare('SELECT id FROM monthly_ledger WHERE vehicle_id = ? AND year_month = ?').get(vid, year_month);
    if (existing) {
      getDB().prepare(
        `UPDATE monthly_ledger SET fuel_cost=?, repair_cost=?, parts_cost=?, work_days=?, total_hours=?, hourly_fuel_consumption=?, total_cost=?, revenue=?, profit=?, updated_at=datetime('now')
         WHERE vehicle_id=? AND year_month=?`
      ).run(fuelCost, repairCost, partsCost, workDays, totalHours, hourlyFuelConsumption, totalCost, revenue, profit, vid, year_month);
    } else {
      getDB().prepare(
        `INSERT INTO monthly_ledger (vehicle_id, year_month, fuel_cost, repair_cost, parts_cost, work_days, total_hours, hourly_fuel_consumption, total_cost, revenue, profit, status)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'draft')`
      ).run(vid, year_month, fuelCost, repairCost, partsCost, workDays, totalHours, hourlyFuelConsumption, totalCost, revenue, profit);
    }

    results.push({
      vehicle_id: vid,
      plate_number: v.plate_number,
      vehicle_type: v.vehicle_type,
      year_month,
      fuel_cost: fuelCost,
      fuel_liters: fuelRow.liters,
      repair_cost: repairCost,
      parts_cost: partsCost,
      work_days: workDays,
      total_hours: totalHours,
      hourly_fuel_consumption: hourlyFuelConsumption,
      total_cost: totalCost,
      revenue: revenue,
      profit: profit,
    });
  }

  res.json({ code: 200, msg: `已生成 ${year_month} 的核算清单，共${results.length}辆车`, data: results });
}));

// 提交月度清单
router.put('/monthly/:id/submit', auth, requireRole('admin'), asyncHandler(async (req: Request, res: Response) => {
  const exist = getDB().prepare("SELECT * FROM monthly_ledger WHERE id = ? AND status = 'draft'").get(req.params.id);
  if (!exist) { res.json({ code: 400, msg: '清单不存在或非草稿状态' }); return; }
  getDB().prepare("UPDATE monthly_ledger SET status = 'submitted', submitted_by = ?, updated_at = datetime('now') WHERE id = ?")
    .run(req.user.id, req.params.id);
  res.json({ code: 200, msg: '已提交审核' });
}));

// 审批月度清单
router.put('/monthly/:id/approve', auth, requireRole('leader', 'admin'), asyncHandler(async (req: Request, res: Response) => {
  const exist = getDB().prepare("SELECT * FROM monthly_ledger WHERE id = ? AND status = 'submitted'").get(req.params.id);
  if (!exist) { res.json({ code: 400, msg: '清单不存在或非待审批状态' }); return; }
  getDB().prepare("UPDATE monthly_ledger SET status = 'approved', approved_by = ?, updated_at = datetime('now') WHERE id = ?")
    .run(req.user.id, req.params.id);
  res.json({ code: 200, msg: '审批通过' });
}));

// ==================== KPI考核评分 ====================

// 查询KPI评分
router.get('/kpi', auth, requireRole('leader', 'admin'), asyncHandler(async (req: Request, res: Response) => {
  const { year_month } = req.query;
  let sql = `SELECT ks.*, v.plate_number, v.vehicle_type, v.model,
    ml.fuel_cost, ml.repair_cost, ml.parts_cost, ml.total_cost, ml.work_days, ml.total_hours, ml.mileage, ml.work_volume
    FROM kpi_scores ks
    JOIN vehicles v ON ks.vehicle_id = v.id
    LEFT JOIN monthly_ledger ml ON ks.vehicle_id = ml.vehicle_id AND ks.year_month = ml.year_month
    WHERE 1=1`;
  const params: (string | number)[] = [];
  if (year_month) { sql += ' AND ks.year_month = ?'; params.push(String(year_month)); }
  sql += ' ORDER BY ks.rank ASC';
  const scores = getDB().prepare(sql).all(...params);

  // 附加阈值和奖惩信息
  const thresholds = getDB().prepare('SELECT * FROM kpi_thresholds').all() as Record<string, unknown>[];
  const thresholdMap: Record<string, Record<string, Record<string, unknown>>> = {};
  for (const t of thresholds) {
    const vt = t.vehicle_type as string;
    if (!thresholdMap[vt]) thresholdMap[vt] = {};
    thresholdMap[vt][t.kpi_key as string] = t;
  }

  const enriched = scores.map(s => {
    const vt = s.vehicle_type as string;
    const th = thresholdMap[vt] || {};
    const penalties: Record<string, unknown>[] = [];
    const rewards: Record<string, unknown>[] = [];
    const kpiMap: Record<string, number> = {
      fuel_cost_per_unit: s.fuel_cost_per_unit as number,
      repair_rate: s.repair_rate as number,
      utilization_rate: s.utilization_rate as number,
      unit_cost: s.unit_cost as number,
      availability_rate: s.availability_rate as number,
      safety_score: s.safety_score as number,
    };
    for (const [key, value] of Object.entries(kpiMap)) {
      const t = th[key] as Record<string, unknown> | undefined;
      if (!t) continue;
      // 安全分是越大越好，其他指标是越小越好（对成本类指标）
      if (key === 'safety_score' || key === 'utilization_rate' || key === 'availability_rate') {
        if (value < Number(t.lower_limit) && Number(t.lower_limit) > 0) {
          penalties.push({ kpi: key, value, threshold: Number(t.lower_limit), amount: Number(t.penalty_amount), reason: '低于合格线' });
        } else if (value > Number(t.upper_limit) && Number(t.upper_limit) > 0) {
          rewards.push({ kpi: key, value, threshold: Number(t.upper_limit), amount: Number(t.reward_amount), reason: '超过优秀线' });
        }
      } else {
        if (value > Number(t.upper_limit) && Number(t.upper_limit) > 0) {
          penalties.push({ kpi: key, value, threshold: Number(t.upper_limit), amount: Number(t.penalty_amount), reason: '超出上限' });
        } else if (value < Number(t.lower_limit) && Number(t.lower_limit) > 0) {
          rewards.push({ kpi: key, value, threshold: Number(t.lower_limit), amount: Number(t.reward_amount), reason: '低于优秀线' });
        }
      }
    }
    return { ...s, penalties, rewards, total_penalty: penalties.reduce((a, b) => a + Number(b.amount), 0), total_reward: rewards.reduce((a, b) => a + Number(b.amount), 0) };
  });

  res.json({ code: 200, data: enriched });
}));

// 自动计算KPI — 数据全部来自本系统已有模块
router.post('/kpi/calculate', auth, requireRole('admin'), validate(yearMonthSchema), asyncHandler(async (req: Request, res: Response) => {
  const { year_month } = req.body;

  const ledgers = getDB().prepare("SELECT * FROM monthly_ledger WHERE year_month = ? AND status = 'approved'").all(year_month) as Record<string, unknown>[];
  if (ledgers.length === 0) { res.json({ code: 400, msg: `没有 ${year_month} 已审批的核算清单，请先生成并审批` }); return; }

  // 制度台班数（从config读取，默认26天/月）
  const wdCfg = getDB().prepare("SELECT config_value FROM system_config WHERE config_key = 'monthly_work_days'").get() as { config_value: string } | undefined;
  const MONTHLY_WORK_DAYS = wdCfg ? Number(wdCfg.config_value) || 26 : 26;

  const results: Record<string, unknown>[] = [];

  for (const l of ledgers) {
    const vid = l.vehicle_id as number;
    const vehicle = getDB().prepare('SELECT * FROM vehicles WHERE id = ?').get(vid) as Record<string, unknown>;
    if (!vehicle) continue;

    const fuelCost = Number(l.fuel_cost) || 0;
    const repairCost = Number(l.repair_cost) || 0;
    const totalCost = Number(l.total_cost) || 0;
    const workDays = Number(l.work_days) || 0;
    const totalHours = Number(l.total_hours) || 0;

    // ——— 6项KPI计算 ——— 数据来源标注

    // 1. 台班燃油成本 — 来源：晚检加油(liters) × 油价 / 出勤天数
    const fuelCostPerUnit = workDays > 0 ? Math.round((fuelCost / workDays) * 100) / 100 : 0;

    // 2. 维修费用率(%) — 来源：维修模块报价 / 车辆净值(vehicles.asset_value)
    const assetValue = Number(vehicle.asset_value) || 0;
    const repairRate = assetValue > 0 ? Math.round((repairCost / assetValue) * 10000) / 100 : 0;

    // 3. 车辆利用率(%) — 来源：考勤模块出勤天数 / 制度台班
    const utilizationRate = MONTHLY_WORK_DAYS > 0 ? Math.round((workDays / MONTHLY_WORK_DAYS) * 10000) / 100 : 0;

    // 4. 单位工时成本 — 来源：总成本 / 晚检工时
    const unitCost = totalHours > 0 ? Math.round((totalCost / totalHours) * 100) / 100 : 0;

    // 5. 设备完好率(%) — 来源：维修模块维修天数 vs 制度台班
    const repairDaysRow = getDB().prepare(
      `SELECT COUNT(DISTINCT date(rp.created_at)) as days FROM repair_progress rp
       JOIN repair_orders ro ON rp.order_id = ro.id
       WHERE ro.vehicle_id = ? AND strftime('%Y-%m', rp.created_at) = ? AND rp.action IN ('accepted_order','quote_submitted','progress_update','completed')`
    ).get(vid, year_month) as { days: number };
    const repairDays = repairDaysRow.days;
    const availabilityRate = MONTHLY_WORK_DAYS > 0 ? Math.round(((MONTHLY_WORK_DAYS - repairDays) / MONTHLY_WORK_DAYS) * 10000) / 100 : 100;

    // 6. 安全得分 — 来源：安全模块事故次数扣分
    const incidentCount = (getDB().prepare(
      `SELECT COUNT(*) as c FROM safety_incidents
       WHERE strftime('%Y-%m', incident_time) = ? AND reporter_id IN
         (SELECT driver_id FROM driver_vehicle_bindings WHERE vehicle_id = ? AND unbind_date IS NULL)`
    ).get(year_month, vid) as { c: number }).c;
    const safetyScore = Math.max(0, 100 - incidentCount * 10);

    // ——— 加权总分 ———
    // 成本类指标(越低越好): 归一化为0-100，100=最好
    // 效益类指标(越高越好): 直接使用百分比值
    const fuelScore = fuelCostPerUnit > 0 ? Math.max(0, 100 - fuelCostPerUnit) : 100;
    const repairScore = Math.max(0, 100 - repairRate);
    const unitCostScore = unitCost > 0 ? Math.max(0, 100 - unitCost) : 100;

    const totalScore = Math.round((
      fuelScore * 0.25 +
      repairScore * 0.20 +
      utilizationRate * 0.20 +
      unitCostScore * 0.15 +
      availabilityRate * 0.15 +
      safetyScore * 0.05
    ) * 100) / 100;

    // UPSERT kpi_scores
    const existing = getDB().prepare('SELECT id FROM kpi_scores WHERE vehicle_id = ? AND year_month = ?').get(vid, year_month);
    if (existing) {
      getDB().prepare(
        `UPDATE kpi_scores SET fuel_cost_per_unit=?, repair_rate=?, utilization_rate=?, unit_cost=?, availability_rate=?, safety_score=?, total_score=?, rank=0
         WHERE vehicle_id=? AND year_month=?`
      ).run(fuelCostPerUnit, repairRate, utilizationRate, unitCost, availabilityRate, safetyScore, totalScore, vid, year_month);
    } else {
      getDB().prepare(
        `INSERT INTO kpi_scores (vehicle_id, year_month, fuel_cost_per_unit, repair_rate, utilization_rate, unit_cost, availability_rate, safety_score, total_score)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`
      ).run(vid, year_month, fuelCostPerUnit, repairRate, utilizationRate, unitCost, availabilityRate, safetyScore, totalScore);
    }

    results.push({
      vehicle_id: vid, plate_number: vehicle.plate_number, vehicle_type: vehicle.vehicle_type,
      fuel_cost_per_unit: fuelCostPerUnit, repair_rate: repairRate, utilization_rate: utilizationRate,
      unit_cost: unitCost, availability_rate: availabilityRate, safety_score: safetyScore,
      total_score: totalScore,
      // 附加原始数据用于展示
      fuel_cost: fuelCost, repair_cost: repairCost, total_cost: totalCost,
      work_days: workDays, total_hours: totalHours, asset_value: assetValue,
    });
  }

  // 排名（按总分降序）
  results.sort((a, b) => Number(b.total_score) - Number(a.total_score));
  for (let i = 0; i < results.length; i++) {
    const r = results[i];
    getDB().prepare('UPDATE kpi_scores SET rank = ? WHERE vehicle_id = ? AND year_month = ?')
      .run(i + 1, r.vehicle_id, year_month);
    r.rank = i + 1;
  }

  res.json({ code: 200, msg: `${year_month} KPI计算完成`, data: results });
}));

// ==================== KPI阈值配置 ====================

// 查看阈值配置
router.get('/thresholds', auth, requireRole('admin', 'leader'), asyncHandler(async (_req: Request, res: Response) => {
  const rows = getDB().prepare('SELECT * FROM kpi_thresholds ORDER BY vehicle_type, kpi_key').all();
  // 按车型分组
  const grouped: Record<string, Record<string, unknown>[]> = {};
  for (const r of rows as Record<string, unknown>[]) {
    const vt = r.vehicle_type as string;
    if (!grouped[vt]) grouped[vt] = [];
    grouped[vt].push(r);
  }
  res.json({ code: 200, data: { items: rows, grouped } });
}));

// 保存阈值配置
router.put('/thresholds/save', auth, requireRole('admin'), validate(thresholdsSaveSchema), asyncHandler(async (req: Request, res: Response) => {
  const { thresholds } = req.body;  // Array<{vehicle_type, kpi_key, upper_limit, lower_limit, penalty_amount, reward_amount}>
  for (const t of thresholds) {
    getDB().prepare(
      `INSERT INTO kpi_thresholds (vehicle_type, kpi_key, upper_limit, lower_limit, penalty_amount, reward_amount, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, datetime('now'))
       ON CONFLICT(vehicle_type, kpi_key) DO UPDATE SET upper_limit=?, lower_limit=?, penalty_amount=?, reward_amount=?, updated_at=datetime('now')`
    ).run(t.vehicle_type, t.kpi_key, t.upper_limit, t.lower_limit, t.penalty_amount, t.reward_amount, t.upper_limit, t.lower_limit, t.penalty_amount, t.reward_amount);
  }
  res.json({ code: 200, msg: '阈值保存成功' });
}));

// ==================== 数据汇总（供仪表盘使用） ====================

// 本月台账汇总 — 数据来源：monthly_ledger（与 generate 生成逻辑一致，避免汇总与清单脱节）
router.get('/summary', auth, requireRole('admin', 'leader'), asyncHandler(async (req: Request, res: Response) => {
  const month = (req.query.month as string) || new Date().toISOString().slice(0, 7);

  // 从 monthly_ledger 汇总（包含所有车辆，不管状态），保证仪表盘数字与月度清单一致
  const s = getDB().prepare(
    `SELECT COALESCE(SUM(fuel_cost), 0) as fuelCost,
            COALESCE(SUM(repair_cost), 0) as repairCost,
            COALESCE(SUM(parts_cost), 0) as partsCost,
            COALESCE(SUM(total_cost), 0) as totalCost,
            COALESCE(SUM(revenue), 0) as totalRevenue,
            COALESCE(SUM(profit), 0) as totalProfit,
            COUNT(*) as totalLedgers,
            SUM(CASE WHEN status = 'approved' THEN 1 ELSE 0 END) as approvedLedgers
     FROM monthly_ledger WHERE year_month = ?`
  ).get(month) as Record<string, unknown>;

  const kpiCount = getDB().prepare('SELECT COUNT(*) as c FROM kpi_scores WHERE year_month = ?').get(month) as { c: number };

  res.json({ code: 200, data: {
    month,
    fuelCost: s.fuelCost || 0,
    partsCost: s.partsCost || 0,
    repairCost: s.repairCost || 0,
    totalCost: s.totalCost || 0,
    totalRevenue: s.totalRevenue || 0,
    totalProfit: s.totalProfit || 0,
    approvedLedgers: s.approvedLedgers || 0,
    hasKpi: kpiCount.c > 0,
  }});
}));

// ==================== 维修预算管理 ====================

// 车型预算配置（增幅率）查询
router.get('/budget/config', auth, requireRole('admin', 'leader'), asyncHandler(async (_req: Request, res: Response) => {
  // 确保所有车型有默认配置
  const types = ['履带挖掘机','轮式挖掘机','压路机','装载机','平地机','夹爪机','汽车吊','25吨吊车','50吨吊车','70吨吊车','100吨吊车','200吨吊车','300吨吊车','500吨履带吊','登高车'];
  for (const t of types) {
    const exist = getDB().prepare('SELECT vehicle_type FROM budget_vehicle_config WHERE vehicle_type = ?').get(t);
    if (!exist) {
      getDB().prepare('INSERT INTO budget_vehicle_config (vehicle_type, annual_increase_rate) VALUES (?, 0.05)').run(t);
    }
  }
  const rows = getDB().prepare('SELECT * FROM budget_vehicle_config ORDER BY vehicle_type').all();
  res.json({ code: 200, data: rows });
}));

// 保存车型预算配置
router.put('/budget/config', auth, requireRole('admin'), validate(budgetConfigSaveSchema), asyncHandler(async (req: Request, res: Response) => {
  const { configs } = req.body;
  for (const c of configs) {
    getDB().prepare(
      `INSERT INTO budget_vehicle_config (vehicle_type, annual_increase_rate) VALUES (?, ?)
       ON CONFLICT(vehicle_type) DO UPDATE SET annual_increase_rate = ?, updated_at = datetime('now')`
    ).run(c.vehicle_type, c.annual_increase_rate, c.annual_increase_rate);
  }
  res.json({ code: 200, msg: '配置保存成功' });
}));

// 导入基准预算数据（接受JSON数组）
router.post('/budget/import', auth, requireRole('admin'), validate(budgetImportSchema), asyncHandler(async (req: Request, res: Response) => {
  const { base_year, records } = req.body;
  let success = 0, fail = 0;
  for (const r of records) {
    try {
      const vehicle = getDB().prepare('SELECT id FROM vehicles WHERE plate_number = ?').get(r.plate_number) as Record<string, unknown> | undefined;
      if (!vehicle) { fail++; continue; }
      const vid = vehicle.id as number;
      getDB().prepare(
        `INSERT INTO vehicle_budget_baseline (vehicle_id, base_year, total_annual_cost)
         VALUES (?, ?, ?)
         ON CONFLICT(vehicle_id, base_year) DO UPDATE SET total_annual_cost = ?`
      ).run(vid, base_year, r.total_annual_cost || 0, r.total_annual_cost || 0);
      success++;
    } catch { fail++; }
  }
  res.json({ code: 200, msg: `导入完成：成功${success}条，失败${fail}条` });
}));

// 查询已导入的基准数据
router.get('/budget/baselines', auth, requireRole('admin', 'leader'), asyncHandler(async (req: Request, res: Response) => {
  const { base_year } = req.query;
  let sql = `SELECT bb.*, v.plate_number, v.vehicle_type, v.purchase_date, v.asset_value
    FROM vehicle_budget_baseline bb JOIN vehicle_archives v ON bb.vehicle_id = v.id WHERE 1=1`;
  const params: (string | number)[] = [];
  if (base_year) { sql += ' AND bb.base_year = ?'; params.push(String(base_year)); }
  sql += ' ORDER BY bb.base_year DESC, v.vehicle_type';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 计算月度预算（指定年月，为所有有基准数据的车辆生成预算）
router.post('/budget/calculate/:yearMonth', auth, requireRole('admin', 'leader'), asyncHandler(async (req: Request, res: Response) => {
  const targetYm = req.params.yearMonth as string;
  const targetYear = parseInt(targetYm.split('-')[0]);
  const targetMonth = parseInt(targetYm.split('-')[1]);

  // 取所有车辆的基准数据（取最近一个基准年）
  const baselines = getDB().prepare(
    `SELECT bb.*, v.plate_number, v.vehicle_type, v.purchase_date
     FROM vehicle_budget_baseline bb
     JOIN vehicle_archives v ON bb.vehicle_id = v.id
     WHERE bb.base_year <= ?
     AND bb.id IN (SELECT MAX(id) FROM vehicle_budget_baseline GROUP BY vehicle_id)`
  ).all(targetYear) as Record<string, unknown>[];

  if (baselines.length === 0) {
    res.json({ code: 400, msg: '没有基准数据，请先导入' }); return;
  }

  // 取车型增幅率配置
  const configs = getDB().prepare('SELECT * FROM budget_vehicle_config').all() as Record<string, unknown>[];
  const rateMap: Record<string, number> = {};
  for (const c of configs) { rateMap[c.vehicle_type as string] = Number(c.annual_increase_rate) || 0.05; }

  // 取当月实际花费（维修费+配件费，不含燃油）
  const actuals = getDB().prepare(
    `SELECT vehicle_id, COALESCE(SUM(repair_cost + parts_cost), 0) as actual_total
     FROM monthly_ledger WHERE year_month = ? GROUP BY vehicle_id`
  ).all(targetYm) as Record<string, unknown>[];
  const actualMap: Record<number, number> = {};
  for (const a of actuals) { actualMap[a.vehicle_id as number] = Number(a.actual_total) || 0; }

  const results: Record<string, unknown>[] = [];
  for (const b of baselines) {
    const vid = b.vehicle_id as number;
    const baseYear = parseInt(b.base_year as string);
    const totalAnnual = Number(b.total_annual_cost) || 0;
    const baseMonthly = totalAnnual / 12;
    const vt = b.vehicle_type as string;
    const rate = rateMap[vt] || 0.05;

    // 车龄：从购车年份算
    const purchaseDate = b.purchase_date as string | null;
    const purchaseYear = purchaseDate ? parseInt(purchaseDate.split('-')[0]) : baseYear;
    const vehicleAge = Math.max(0, targetYear - purchaseYear);

    // 预算公式：基准月费 × (1 + 年增幅率)^(今年 - 基准年) × (1 + 增幅率 × 车龄/10)
    const yearsFromBase = Math.max(0, targetYear - baseYear);
    const ageBonus = 1 + rate * (vehicleAge / 10);
    const budgetAmount = Math.round(baseMonthly * Math.pow(1 + rate, yearsFromBase) * ageBonus * 100) / 100;

    const actualAmount = actualMap[vid] || 0;
    const variance = Math.round((actualAmount - budgetAmount) * 100) / 100;

    // UPSERT
    getDB().prepare(
      `INSERT INTO vehicle_monthly_budget (vehicle_id, year_month, budget_amount, actual_amount, variance)
       VALUES (?, ?, ?, ?, ?)
       ON CONFLICT(vehicle_id, year_month) DO UPDATE SET budget_amount=?, actual_amount=?, variance=?`
    ).run(vid, targetYm, budgetAmount, actualAmount, variance, budgetAmount, actualAmount, variance);

    results.push({
      vehicle_id: vid, plate_number: b.plate_number, vehicle_type: vt,
      base_year: b.base_year, total_annual_cost: totalAnnual, base_monthly: Math.round(baseMonthly * 100) / 100,
      purchase_year: purchaseYear, vehicle_age: vehicleAge,
      annual_increase_rate: rate, budget_amount: budgetAmount,
      actual_amount: actualAmount, variance: variance,
      status: variance > 0 ? 'over' : (variance < 0 ? 'under' : 'on_budget'),
    });
  }

  res.json({ code: 200, msg: `已计算 ${targetYm} 预算，共${results.length}辆车`, data: results });
}));

// 查询月度预算列表
router.get('/budget/list/:yearMonth', auth, requireRole('admin', 'leader'), asyncHandler(async (req: Request, res: Response) => {
  const targetYm = req.params.yearMonth;
  let sql = `SELECT vb.*, v.plate_number, v.vehicle_type
    FROM vehicle_monthly_budget vb JOIN vehicle_archives v ON vb.vehicle_id = v.id
    WHERE vb.year_month = ? ORDER BY vb.variance DESC`;
  const rows = getDB().prepare(sql).all(targetYm);
  // 汇总
  let totalBudget = 0, totalActual = 0;
  for (const r of rows as Record<string, unknown>[]) {
    totalBudget += Number(r.budget_amount) || 0;
    totalActual += Number(r.actual_amount) || 0;
  }
  res.json({ code: 200, data: {
    year_month: targetYm, total_budget: Math.round(totalBudget * 100) / 100,
    total_actual: Math.round(totalActual * 100) / 100,
    total_variance: Math.round((totalActual - totalBudget) * 100) / 100,
    items: rows,
  }});
}));

// 预算年度汇总（12个月概览）
router.get('/budget/summary/:year', auth, requireRole('admin', 'leader'), asyncHandler(async (req: Request, res: Response) => {
  const year = req.params.year;
  const rows = getDB().prepare(
    `SELECT year_month, SUM(budget_amount) as total_budget, SUM(actual_amount) as total_actual,
       SUM(variance) as total_variance, COUNT(*) as vehicle_count
     FROM vehicle_monthly_budget WHERE year_month LIKE ?
     GROUP BY year_month ORDER BY year_month`
  ).all(`${year}-%`) as Record<string, unknown>[];
  res.json({ code: 200, data: rows });
}));

// ==================== CSV 导出 ====================

/// 将 YYYY-MM 转为 YYYY年MM月，避免 Excel 将其识别为英文日期
function fmtYearMonth(ym: unknown): string {
  const s = String(ym ?? '');
  const m = s.match(/^(\d{4})-(\d{1,2})$/);
  if (m) return `${m[1]}年${m[2].padStart(2, '0')}月`;
  return s;
}

// 月度清单导出
router.get('/monthly/export', auth, requireRole('leader', 'admin'), asyncHandler(async (req: Request, res: Response) => {
  const { year_month } = req.query;
  let sql = `SELECT ml.*, v.plate_number, v.vehicle_type
    FROM monthly_ledger ml
    JOIN vehicles v ON ml.vehicle_id = v.id
    WHERE 1=1`;
  const params: (string | number)[] = [];
  if (year_month) { sql += ' AND ml.year_month = ?'; params.push(String(year_month)); }
  sql += ' ORDER BY ml.year_month DESC, ml.total_cost DESC';
  const data = getDB().prepare(sql).all(...params) as Record<string, unknown>[];

  let csv = '﻿车牌号,车型,年月,工时(h),工作天数,燃油费,维修费,配件费,总成本,收入,盈亏,小时油耗(L/h),状态\n';
  const statusMap: Record<string, string> = { draft: '草稿', submitted: '待审批', approved: '已审批' };
  data.forEach((r: Record<string, unknown>) => {
    csv += [
      r.plate_number, r.vehicle_type, fmtYearMonth(r.year_month),
      r.total_hours, r.work_days,
      r.fuel_cost, r.repair_cost, r.parts_cost,
      r.total_cost, r.revenue, r.profit,
      r.hourly_fuel_consumption,
      statusMap[String(r.status || '')] || r.status,
    ].map((v: unknown) => '"' + String(v ?? '').replace(/"/g, '""') + '"').join(',') + '\n';
  });

  const filename = '单车核算月度清单_' + (year_month || '全部') + '.csv';
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', "attachment; filename*=UTF-8''" + encodeURIComponent(filename));
  res.send(csv);
}));

// 年度汇总导出
router.get('/annual/export', auth, requireRole('leader', 'admin'), asyncHandler(async (req: Request, res: Response) => {
  const { year } = req.query;
  if (!year) { res.json({ code: 400, msg: '请指定年份' }); return; }

  const rows = getDB().prepare(
    `SELECT v.plate_number, v.vehicle_type,
       COALESCE(SUM(ml.fuel_cost), 0) as fuel_cost,
       COALESCE(SUM(ml.repair_cost), 0) as repair_cost,
       COALESCE(SUM(ml.parts_cost), 0) as parts_cost,
       COALESCE(SUM(ml.total_cost), 0) as total_cost,
       COALESCE(SUM(ml.revenue), 0) as revenue,
       COALESCE(SUM(ml.profit), 0) as profit,
       COALESCE(SUM(ml.work_days), 0) as work_days,
       COALESCE(SUM(ml.total_hours), 0) as total_hours,
       COUNT(ml.id) as month_count,
       SUM(CASE WHEN ml.status = 'approved' THEN 1 ELSE 0 END) as approved_count
    FROM vehicles v
    JOIN monthly_ledger ml ON ml.vehicle_id = v.id AND ml.year_month LIKE ?
    WHERE v.status != 'scrapped'
    GROUP BY v.id
    ORDER BY total_cost DESC`
  ).all(`${year}-%`) as Record<string, unknown>[];

  let csv = '﻿车牌号,车型,年度,总月数,已审批月数,工时(h),工作天数,燃油费,维修费,配件费,总成本,收入,盈亏\n';
  rows.forEach((r: Record<string, unknown>) => {
    csv += [
      r.plate_number, r.vehicle_type, year,
      r.month_count, r.approved_count,
      r.total_hours, r.work_days,
      r.fuel_cost, r.repair_cost, r.parts_cost,
      r.total_cost, r.revenue, r.profit,
    ].map((v: unknown) => '"' + String(v ?? '').replace(/"/g, '""') + '"').join(',') + '\n';
  });

  const filename = '单车核算年度汇总_' + year + '.csv';
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', "attachment; filename*=UTF-8''" + encodeURIComponent(filename));
  res.send(csv);
}));

export default router;
