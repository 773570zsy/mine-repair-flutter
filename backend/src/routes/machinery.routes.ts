import { Router, Request, Response } from 'express';
import { auth, requireRole } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';
import { sendExcel, ColumnDef } from '../utils/excel';
import dayjs from 'dayjs';
import { validate } from '../middleware/validate';
import { machineryApplySchema, machineryAssignSchema } from '../schemas/machinery.schemas';
import { sendToUser } from '../services/notification.service';

const router = Router();

// ==================== 申请方：提交申请 ====================

router.post('/apply', auth, validate(machineryApplySchema), asyncHandler(async (req: Request, res: Response) => {
  const {
    applicant_dept, applicant_name, applicant_phone,
    vehicle_type, application_type, scheduled_start, scheduled_end,
    work_location, work_altitude, work_purpose,
    is_hazardous, urgency,
    briefing_method, briefing_files, fee_provider
  } = req.body;

  const no = 'PC' + dayjs().format('YYYYMMDD') + String(Date.now()).slice(-4);

  getDB().prepare(
    `INSERT INTO machinery_applications
     (application_no, applicant_id, applicant_dept, applicant_name, applicant_phone,
      vehicle_type, application_type, scheduled_start, scheduled_end, work_location, work_altitude, work_purpose,
      is_hazardous, urgency, briefing_method, briefing_files, fee_provider)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).run(no, req.user.id,
    applicant_dept, applicant_name, applicant_phone,
    vehicle_type || '',
    application_type || 'short_term',
    scheduled_start, scheduled_end,
    work_location, work_altitude || '', work_purpose,
    is_hazardous ? 1 : 0, urgency || 'normal',
    briefing_method || '', briefing_files || '[]',
    fee_provider || '');

  res.json({ code: 200, msg: '申请已提交', data: { application_no: no } });
}));

// ==================== 申请方：我的申请列表 ====================

router.get('/my-applications', auth, asyncHandler(async (req: Request, res: Response) => {
  autoCompleteOverdueApplications();
  const sql = `SELECT ma.*,
      v.plate_number as assigned_plate,
      v.vehicle_type as assigned_vehicle_type,
      v.model as assigned_vehicle_model,
      du.name as driver_name, du.phone as driver_phone,
      dis.name as dispatcher_name
    FROM machinery_applications ma
    LEFT JOIN vehicles v ON ma.assigned_vehicle_id = v.id
    LEFT JOIN users du ON ma.assigned_driver_id = du.id
    LEFT JOIN users dis ON ma.dispatcher_id = dis.id
    WHERE ma.applicant_id = ?
    ORDER BY ma.created_at DESC`;
  const data = getDB().prepare(sql).all(req.user.id);
  res.json({ code: 200, data });
}));

// ==================== 申请方：当前进行中的申请（提前结束入口） ====================

router.get('/active', auth, asyncHandler(async (req: Request, res: Response) => {
  const sql = `SELECT ma.*,
      v.plate_number as assigned_plate,
      v.vehicle_type as assigned_vehicle_type,
      v.model as assigned_vehicle_model,
      du.name as driver_name, du.phone as driver_phone
    FROM machinery_applications ma
    LEFT JOIN vehicles v ON ma.assigned_vehicle_id = v.id
    LEFT JOIN users du ON ma.assigned_driver_id = du.id
    WHERE ma.applicant_id = ? AND ma.status IN ('assigned','in_progress')
    ORDER BY ma.created_at DESC`;
  const data = getDB().prepare(sql).all(req.user.id);
  res.json({ code: 200, data });
}));

// ==================== 申请方：提前结束用车 ====================

router.post('/early-end/:id', auth, asyncHandler(async (req: Request, res: Response) => {
  const app = getDB().prepare('SELECT * FROM machinery_applications WHERE id = ?').get(req.params.id) as Record<string, unknown> | undefined;
  if (!app) { res.json({ code: 404, msg: '申请不存在' }); return; }
  if (Number(app.applicant_id) !== req.user.id && !['admin', 'dispatcher'].includes(req.user.role)) {
    res.json({ code: 403, msg: '无权操作' }); return;
  }
  if (!['assigned', 'in_progress'].includes(String(app.status))) {
    res.json({ code: 400, msg: '只能结束进行中的用车' }); return;
  }

  const now = dayjs();
  const actualEnd = now.format('HH:mm');

  // 解析计划开始/结束为完整日期时间（格式：YYYY-MM-DD HH:mm 或 HH:mm）
  const scheduledEnd = String(app.scheduled_end || '18:00');
  const scheduledStart = String(app.scheduled_start || '08:00');
  const todayForParse = now.format('YYYY-MM-DD');
  const schedStartDt = dayjs(scheduledStart.length > 5 ? scheduledStart : `${todayForParse} ${scheduledStart}`);
  const schedEndDt = dayjs(scheduledEnd.length > 5 ? scheduledEnd : `${todayForParse} ${scheduledEnd}`);

  let workingHours = 0;
  let totalCost = 0;
  let settlementEnd = actualEnd;
  let isEarly = false;
  let newStatus: string;

  // 如果结束时间在计划开始时间之前 → 未实际使用，工时=0
  if (now.isBefore(schedStartDt)) {
    newStatus = 'early_completed';
    isEarly = true;
    settlementEnd = actualEnd;  // 实际结束时间就是现在
  } else {
    // effectiveEnd = min(now, schedEndDt)，不超出计划结束时间
    const effectiveEnd = now.isBefore(schedEndDt) ? now : schedEndDt;
    isEarly = now.isBefore(schedEndDt);

    // +30分钟返程路途，但不能超出计划结束时间
    const rawSettlementEnd = effectiveEnd.add(30, 'minute');
    const cappedSettlementEnd = rawSettlementEnd.isBefore(schedEndDt) ? rawSettlementEnd : schedEndDt;

    const workMins = cappedSettlementEnd.diff(schedStartDt, 'minute');
    workingHours = Math.round(Math.max(0, workMins) / 60 * 100) / 100;
    totalCost = Math.round(workingHours * (Number(app.hourly_rate) || 0) * 100) / 100;

    settlementEnd = cappedSettlementEnd.format('HH:mm');
    newStatus = isEarly ? 'early_completed' : 'completed';
  }

  getDB().prepare(`UPDATE machinery_applications
    SET status = ?,
        actual_end_time = ?,
        settlement_end_time = ?,
        working_hours = ?,
        total_cost = ?,
        updated_at = datetime('now')
    WHERE id = ?`).run(newStatus, actualEnd, settlementEnd, workingHours, totalCost, req.params.id);

  const msgs: Record<string, string> = {
    early_completed: workingHours === 0 ? '用车已提前结束（未实际使用，不产生费用）' : '用车已提前结束',
    completed: '用车已结束（按申请时段结算）',
  };
  const msg = msgs[newStatus] || '操作成功';
  res.json({ code: 200, msg, data: { working_hours: workingHours, total_cost: totalCost, is_early: isEarly } });
}));

// ==================== 自动结束已过期的用车（在查询列表时调用） ====================
function autoCompleteOverdueApplications() {
  const now = dayjs();

  const active = getDB().prepare(
    "SELECT * FROM machinery_applications WHERE status IN ('assigned','in_progress')"
  ).all() as Array<Record<string, unknown>>;

  for (const app of active) {
    const schedEnd = String(app.scheduled_end || '18:00');
    // 解析完整日期时间（格式：YYYY-MM-DD HH:mm 或 HH:mm）
    const schedEndDt = dayjs(schedEnd.length > 5 ? schedEnd : `${now.format('YYYY-MM-DD')} ${schedEnd}`);
    // 计划结束 + 30分钟返程 < 当前时间 → 自动结束
    if (schedEndDt.add(30, 'minute').isBefore(now)) {
      const scheduledStart = String(app.scheduled_start || '08:00');
      const todayForAuto = now.format('YYYY-MM-DD');
      const schedStartDt = dayjs(scheduledStart.length > 5 ? scheduledStart : `${todayForAuto} ${scheduledStart}`);
      // 计划时长(分钟) + 30分钟返程路途
      const plannedMins = schedEndDt.diff(schedStartDt, 'minute');
      const workMins = plannedMins + 30;
      const workingHours = Math.round(Math.max(0, workMins) / 60 * 100) / 100;
      const totalCost = Math.round(workingHours * (Number(app.hourly_rate) || 0) * 100) / 100;
      const settlementEndDt = schedEndDt.add(30, 'minute');
      const settlementEnd = settlementEndDt.format('HH:mm');

      getDB().prepare(`UPDATE machinery_applications
        SET status = 'completed',
            actual_end_time = ?, settlement_end_time = ?,
            working_hours = ?, total_cost = ?,
            updated_at = datetime('now')
        WHERE id = ?`).run(schedEndDt.format('HH:mm'), settlementEnd, workingHours, totalCost, app.id);

      const appId = Number(app.id);
      const vehicleInfo = `${app.vehicle_type || '未知车型'}`;

      // 通知驾驶员（DB + JPush）
      if (app.assigned_driver_id) {
        sendToUser(app.assigned_driver_id as number, {
          type: 'machinery_completed', title: '用车任务完成',
          content: `${vehicleInfo} 用车任务已自动结束，用时${workingHours}小时，费用¥${totalCost}`,
          orderId: appId,
        });
      }

      // 通知申请人（DB + JPush）
      if (app.applicant_id) {
        sendToUser(app.applicant_id as number, {
          type: 'machinery_completed', title: '用车申请已完成',
          content: `您的${vehicleInfo}用车申请已自动结束，费用¥${totalCost}`,
          orderId: appId,
        });
      }
    }
  }
}

// ==================== 自动清除过期未指派申请（每天10:00后首次查询触发） ====================
let lastPendingCleanupDate: string | null = null;

function autoCleanupExpiredPending() {
  const now = dayjs();
  // 只在10:00之后触发，且今天还没清理过
  if (now.hour() < 10) return;
  const today = now.format('YYYY-MM-DD');
  if (lastPendingCleanupDate === today) return;

  // 将昨天及以前的所有pending申请标记为cancelled
  const result = getDB().prepare(
    `UPDATE machinery_applications
     SET status = 'cancelled', updated_at = datetime('now')
     WHERE status = 'pending' AND date(created_at) < date(?)`
  ).run(today);
  lastPendingCleanupDate = today;

  if ((result.changes as number) > 0) {
    console.log(`[auto-cleanup] 已自动取消 ${result.changes} 条过期未指派申请 (${today})`);
  }
}

// ==================== 申请方：取消申请 ====================

router.post('/cancel/:id', auth, asyncHandler(async (req: Request, res: Response) => {
  const app = getDB().prepare('SELECT * FROM machinery_applications WHERE id = ?').get(req.params.id) as Record<string, unknown> | undefined;
  if (!app) { res.json({ code: 404, msg: '申请不存在' }); return; }
  if (Number(app.applicant_id) !== req.user.id && !['admin', 'dispatcher'].includes(req.user.role)) {
    res.json({ code: 403, msg: '无权操作' }); return;
  }
  if (String(app.status) !== 'pending') {
    res.json({ code: 400, msg: '只能取消待指派的申请' }); return;
  }
  getDB().prepare("UPDATE machinery_applications SET status = 'cancelled', updated_at = datetime('now') WHERE id = ?").run(req.params.id);
  res.json({ code: 200, msg: '申请已取消' });
}));

// ==================== 调度员：待指派列表 ====================

// ==================== 调度员：生成今日已指派文本（企业微信） ====================

router.get('/generate-daily-report', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (_req: Request, res: Response) => {
  const now = dayjs();
  const today = now.format('YYYY-MM-DD');
  const monthDay = `${now.month() + 1}月${now.date()}日`;

  // 查今日已指派/进行中的申请
  const apps = getDB().prepare(
    `SELECT ma.*,
        v.plate_number, v.vehicle_type, v.model,
        du.name as driver_name
     FROM machinery_applications ma
     JOIN vehicles v ON ma.assigned_vehicle_id = v.id
     JOIN users du ON ma.assigned_driver_id = du.id
     WHERE ma.status IN ('assigned','in_progress')
       AND date(ma.created_at) <= date(?)
       AND (ma.assigned_vehicle_id IS NOT NULL)
     ORDER BY v.plate_number ASC`
  ).all(today + ' 23:59:59') as Array<Record<string, unknown>>;

  let text = `${monthDay}重机一班机械工作安排：\n`;
  text += `安全目标：轻伤以上事故为0，环保事故为0，职业病为0。\n`;
  text += `    具体步骤：1.穿戴好防护用品（工作服  安全帽  劳保鞋  口罩）；\n`;
  text += `    2.行车前做好"一分钟安全全确认"；\n`;
  text += `    3.行车中严格按照交通指示牌行车（听从现场交通管理人员指挥），不超速；\n`;
  text += `    4.到达现场做好"人机分离"4步法，方能作业；\n`;
  text += `    5.下班时车辆停放安全处，拉好手刹，拔掉车钥匙，垫好垫木，关掉总电源，关好车窗。\n`;
  text += `  生产安排：\n`;

  if (apps.length === 0) {
    text += `  （今日暂无已指派车辆）\n`;
  } else {
    for (const a of apps) {
      const plate = (a.plate_number || '').toString();
      const driver = (a.driver_name || '').toString();
      const dept = (a.applicant_dept || '').toString();
      const name = (a.applicant_name || '').toString();
      const phone = (a.applicant_phone || '').toString();
      const purpose = (a.work_purpose || '').toString();

      // 有具体联系人 → 显示部门+姓名+电话；否则显示作业用途
      let contact = '';
      if (name && phone) {
        contact = `${dept}${name}${phone}`;
      } else if (name) {
        contact = `${dept}${name}`;
      } else {
        contact = purpose || '临时安排';
      }
      text += `  ${plate}${driver}联系${contact}\n`;
    }
  }

  res.json({ code: 200, data: { text, count: apps.length } });
}));

router.get('/pending-list', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (req: Request, res: Response) => {
  autoCleanupExpiredPending();
  const data = getDB().prepare(
    `SELECT ma.*, u.name as applicant_user_name
     FROM machinery_applications ma
     JOIN users u ON ma.applicant_id = u.id
     WHERE ma.status = 'pending'
     ORDER BY
       CASE ma.urgency WHEN 'emergency' THEN 0 WHEN 'urgent' THEN 1 ELSE 2 END,
       ma.created_at ASC`
  ).all();

  // 资源统计：剩余可派车辆 & 剩余驾驶员
  const totalVehicles = (getDB().prepare(
    "SELECT COUNT(*) as cnt FROM vehicles WHERE status = 'normal'"
  ).get() as { cnt: number }).cnt;

  const busyVehicleIds = getDB().prepare(
    "SELECT DISTINCT assigned_vehicle_id FROM machinery_applications WHERE status IN ('assigned','in_progress') AND assigned_vehicle_id IS NOT NULL"
  ).all() as Array<{ assigned_vehicle_id: number }>;

  const totalDrivers = (getDB().prepare(
    "SELECT COUNT(*) as cnt FROM users WHERE role = 'driver' AND status = 1"
  ).get() as { cnt: number }).cnt;

  const busyDriverIds = getDB().prepare(
    "SELECT DISTINCT assigned_driver_id FROM machinery_applications WHERE status IN ('assigned','in_progress') AND assigned_driver_id IS NOT NULL"
  ).all() as Array<{ assigned_driver_id: number }>;

  const stats = {
    totalVehicles,
    availableVehicles: totalVehicles - busyVehicleIds.length,
    totalDrivers,
    availableDrivers: totalDrivers - busyDriverIds.length,
  };

  res.json({ code: 200, data: { list: data, stats } });
}));

// ==================== 调度员：全部申请列表 ====================

router.get('/list-all', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (req: Request, res: Response) => {
  autoCleanupExpiredPending();
  const { status, urgency, keyword } = req.query;
  let sql = `SELECT ma.*,
      u.name as applicant_user_name,
      v.plate_number as assigned_plate,
      du.name as driver_name,
      dis.name as dispatcher_name
    FROM machinery_applications ma
    JOIN users u ON ma.applicant_id = u.id
    LEFT JOIN vehicles v ON ma.assigned_vehicle_id = v.id
    LEFT JOIN users du ON ma.assigned_driver_id = du.id
    LEFT JOIN users dis ON ma.dispatcher_id = dis.id
    WHERE 1=1`;
  const params: (string | number)[] = [];

  if (status) { sql += ' AND ma.status = ?'; params.push(String(status)); }
  if (urgency) { sql += ' AND ma.urgency = ?'; params.push(String(urgency)); }
  if (keyword) {
    sql += ' AND (ma.application_no LIKE ? OR ma.applicant_name LIKE ? OR ma.applicant_dept LIKE ? OR ma.work_location LIKE ?)';
    const kw = `%${keyword}%`;
    params.push(kw, kw, kw, kw);
  }
  sql += ' ORDER BY ma.created_at DESC';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// ==================== 调度员：撤销指派 ====================

router.post('/revoke/:id', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (req: Request, res: Response) => {
  const app = getDB().prepare('SELECT * FROM machinery_applications WHERE id = ?').get(req.params.id) as Record<string, unknown> | undefined;
  if (!app) { res.json({ code: 404, msg: '申请不存在' }); return; }
  if (!['assigned', 'in_progress'].includes(String(app.status))) {
    res.json({ code: 400, msg: '只能撤销已指派的申请' }); return;
  }
  getDB().prepare(`UPDATE machinery_applications
    SET status = 'pending',
        assigned_vehicle_id = NULL,
        assigned_driver_id = NULL,
        dispatcher_id = NULL,
        hourly_rate = NULL,
        updated_at = datetime('now')
    WHERE id = ?`).run(req.params.id);

  // 通知申请人（DB + JPush）
  sendToUser(app.applicant_id as number, {
    type: 'machinery_revoked', title: '指派已撤销',
    content: '您的用车申请指派已被撤销，订单回到待指派状态，请等待调度员重新分派。',
    orderId: Number(req.params.id),
  });

  // 通知驾驶员（DB + JPush）
  if (app.assigned_driver_id) {
    sendToUser(app.assigned_driver_id as number, {
      type: 'machinery_revoked', title: '任务取消',
      content: '您被指派的任务已被撤销，请关注新的派车通知。',
      orderId: Number(req.params.id),
    });
  }

  res.json({ code: 200, msg: '指派已撤销，订单回到待指派列表' });
}));

// ==================== 调度看板（今日全貌） ====================

router.get('/kanban', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (_req: Request, res: Response) => {
  // 自动完成过期任务
  autoCompleteOverdueApplications();

  const today = dayjs().format('YYYY-MM-DD');

  // 1. 活跃任务（已指派/进行中）
  const activeTasks = getDB().prepare(
    `SELECT ma.*, v.plate_number, v.vehicle_type as assigned_vehicle_type, v.model as assigned_vehicle_model,
            d.name as driver_name, d.phone as driver_phone
     FROM machinery_applications ma
     LEFT JOIN vehicles v ON ma.assigned_vehicle_id = v.id
     LEFT JOIN users d ON ma.assigned_driver_id = d.id
     WHERE ma.status IN ('assigned','in_progress')
     ORDER BY ma.scheduled_start ASC`
  ).all() as Record<string, unknown>[];

  const busyVehicleIds = new Set<number>();
  const busyDriverIds = new Set<number>();
  for (const t of activeTasks) {
    if (t.assigned_vehicle_id) busyVehicleIds.add(Number(t.assigned_vehicle_id));
    if (t.assigned_driver_id) busyDriverIds.add(Number(t.assigned_driver_id));
  }

  // 2. 车辆列表
  const allVehicles = getDB().prepare(
    `SELECT id, plate_number, vehicle_type, model, status, current_driver_id
     FROM vehicles WHERE status != 'scrapped' ORDER BY vehicle_type, plate_number`
  ).all() as Record<string, unknown>[];

  const vehicles = allVehicles.map(v => {
    const vid = Number(v.id);
    const isBusy = busyVehicleIds.has(vid);
    const isRepairing = v.status === 'repairing';
    const task = isBusy ? activeTasks.find(t => Number(t.assigned_vehicle_id) === vid) : null;
    return {
      id: vid,
      plate_number: v.plate_number,
      vehicle_type: v.vehicle_type,
      model: v.model,
      status: v.status,
      current_status: isRepairing ? 'repairing' : (isBusy ? 'busy' : 'available'),
      current_task: task ? {
        application_id: task.id,
        application_no: task.application_no,
        applicant_name: task.applicant_name,
        applicant_dept: task.applicant_dept,
        work_location: task.work_location,
        work_purpose: task.work_purpose,
        scheduled_start: task.scheduled_start,
        scheduled_end: task.scheduled_end,
        driver_name: task.driver_name,
        driver_phone: task.driver_phone,
      } : null,
    };
  });

  // 3. 驾驶员列表（含考勤）
  const allDrivers = getDB().prepare(
    `SELECT u.id, u.name, u.phone, u.status,
            da.attendance_symbol
     FROM users u
     LEFT JOIN driver_attendance da ON da.driver_id = u.id AND da.attendance_date = ?
     WHERE u.role = 'driver' AND u.status = 1
     ORDER BY u.name`
  ).all(today) as Record<string, unknown>[];

  const leaveSymbols = new Set(['请假', '休', '病假', '事假', '年休', '旷工']);

  const drivers = allDrivers.map(d => {
    const did = Number(d.id);
    const isBusy = busyDriverIds.has(did);
    const symbol = String(d.attendance_symbol || '');
    let currentStatus: string;
    if (isBusy) {
      currentStatus = 'busy';
    } else if (leaveSymbols.has(symbol)) {
      currentStatus = 'on_leave';
    } else {
      currentStatus = 'available';  // 不再和考勤挂钩，未签到也算空闲
    }

    const task = isBusy ? activeTasks.find(t => Number(t.assigned_driver_id) === did) : null;
    return {
      id: did,
      name: d.name,
      phone: d.phone,
      status: 'active',
      current_status: currentStatus,
      attendance_symbol: symbol || null,
      current_task: task ? {
        application_id: task.id,
        application_no: task.application_no,
        applicant_name: task.applicant_name,
        applicant_dept: task.applicant_dept,
        work_location: task.work_location,
        work_purpose: task.work_purpose,
        scheduled_start: task.scheduled_start,
        scheduled_end: task.scheduled_end,
        driver_name: task.driver_name,
        driver_phone: task.driver_phone,
        plate_number: task.plate_number,
      } : null,
    };
  });

  // 4. 待指派申请
  const pendingApps = getDB().prepare(
    `SELECT ma.*, v.plate_number as assigned_plate, v.vehicle_type as assigned_vehicle_type,
            v.model as assigned_vehicle_model, d.name as driver_name
     FROM machinery_applications ma
     LEFT JOIN vehicles v ON ma.assigned_vehicle_id = v.id
     LEFT JOIN users d ON ma.assigned_driver_id = d.id
     WHERE ma.status = 'pending'
     ORDER BY CASE ma.urgency WHEN 'emergency' THEN 0 WHEN 'urgent' THEN 1 ELSE 2 END,
              ma.created_at ASC`
  ).all() as Record<string, unknown>[];

  // 5. 汇总
  const summary = {
    totalVehicles: vehicles.length,
    availableVehicles: vehicles.filter(v => v.current_status === 'available').length,
    busyVehicles: vehicles.filter(v => v.current_status === 'busy').length,
    repairingVehicles: vehicles.filter(v => v.current_status === 'repairing').length,
    totalDrivers: drivers.length,
    availableDrivers: drivers.filter(d => d.current_status === 'available').length,
    busyDrivers: drivers.filter(d => d.current_status === 'busy').length,
    onLeaveDrivers: drivers.filter(d => d.current_status === 'on_leave').length,
    absentDrivers: 0,
    pendingCount: pendingApps.length,
  };

  res.json({
    code: 200,
    data: { date: today, summary, vehicles, drivers, pendingApplications: pendingApps },
  });
}));

// ==================== 调度员：当前繁忙资源（用于指派页标记不可选） ====================

router.get('/busy-resources', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (_req: Request, res: Response) => {
  // 所有已指派/进行中的申请
  const active = getDB().prepare(
    `SELECT ma.id, ma.application_no, ma.applicant_name, ma.applicant_dept,
            ma.scheduled_start, ma.scheduled_end,
            ma.assigned_vehicle_id, ma.assigned_driver_id,
            v.plate_number, v.vehicle_type, v.model,
            du.name as driver_name, du.phone as driver_phone
     FROM machinery_applications ma
     JOIN vehicles v ON ma.assigned_vehicle_id = v.id
     JOIN users du ON ma.assigned_driver_id = du.id
     WHERE ma.status IN ('assigned','in_progress')`
  ).all() as Array<Record<string, unknown>>;

  const busyVehicles: Array<Record<string, unknown>> = [];
  const busyDrivers: Array<Record<string, unknown>> = [];
  const seenV = new Set<number>();
  const seenD = new Set<number>();

  for (const a of active) {
    const vid = Number(a.assigned_vehicle_id);
    const did = Number(a.assigned_driver_id);
    if (!seenV.has(vid)) {
      seenV.add(vid);
      busyVehicles.push({ vehicle_id: vid, plate_number: a.plate_number, vehicle_type: a.vehicle_type, model: a.model, application_no: a.application_no, applicant_name: a.applicant_name, applicant_dept: a.applicant_dept, driver_name: a.driver_name });
    }
    if (!seenD.has(did)) {
      seenD.add(did);
      busyDrivers.push({ driver_id: did, driver_name: a.driver_name, driver_phone: a.driver_phone, application_no: a.application_no, plate_number: a.plate_number, vehicle_type: a.vehicle_type, applicant_name: a.applicant_name, applicant_dept: a.applicant_dept, scheduled_start: a.scheduled_start, scheduled_end: a.scheduled_end });
    }
  }
  res.json({ code: 200, data: { busyVehicles, busyDrivers } });
}));

// ==================== 调度员：指派车辆和驾驶员 ====================

router.post('/assign/:id', auth, validate(machineryAssignSchema), requireRole('admin', 'dispatcher'), asyncHandler(async (req: Request, res: Response) => {
  const { assigned_vehicle_id, assigned_driver_id } = req.body;

  const app = getDB().prepare('SELECT * FROM machinery_applications WHERE id = ? AND status = ?')
    .get(req.params.id, 'pending') as Record<string, unknown> | undefined;
  if (!app) { res.json({ code: 404, msg: '申请不存在或已处理' }); return; }

  // 获取车辆信息（含小时单价快照）
  const vehicle = getDB().prepare('SELECT * FROM vehicles WHERE id = ?').get(assigned_vehicle_id) as Record<string, unknown> | undefined;
  if (!vehicle) { res.json({ code: 404, msg: '车辆不存在' }); return; }

  // 获取驾驶员信息
  const driver = getDB().prepare("SELECT * FROM users WHERE id = ? AND role = 'driver'").get(assigned_driver_id) as Record<string, unknown> | undefined;
  if (!driver) { res.json({ code: 404, msg: '驾驶员不存在' }); return; }

  // 天气红色预警检查：任何区域有红色预警则暂停派车
  try {
    const redWarnings = getDB().prepare(
      "SELECT * FROM weather_warnings WHERE level = 'red' AND status IN ('active','acknowledged') ORDER BY triggered_at DESC"
    ).all() as Array<Record<string, unknown>>;
    if (redWarnings.length > 0) {
      const zoneNames = [...new Set(redWarnings.map(w => {
        const z = getDB().prepare('SELECT zone_name FROM weather_zones WHERE id = ?').get(w.zone_id) as { zone_name: string } | undefined;
        return z?.zone_name || '未知区域';
      }))].join('、');
      res.json({ code: 400, msg: `⛔ 天气红色预警生效中，暂停所有派车！预警区域: ${zoneNames}。请等待预警解除后再操作。` }); return;
    }
  } catch { /* 天气检查非关键，失败不影响派车 */ }

  const hourlyRate = Number(vehicle.hourly_rate) || 0;

  getDB().prepare(`UPDATE machinery_applications
    SET status = 'assigned',
        assigned_vehicle_id = ?,
        assigned_driver_id = ?,
        dispatcher_id = ?,
        hourly_rate = ?,
        updated_at = datetime('now')
    WHERE id = ?`).run(assigned_vehicle_id, assigned_driver_id, req.user.id, hourlyRate, req.params.id);

  // 通知驾驶员（DB + JPush）
  sendToUser(assigned_driver_id as number, {
    type: 'machinery_dispatch', title: '派车通知',
    content: `${vehicle.plate_number} 派往 ${app.applicant_dept} — ${app.work_location}`,
    orderId: Number(req.params.id),
  });

  // 通知申请方（DB + JPush）
  sendToUser(app.applicant_id as number, {
    type: 'machinery_assigned', title: '派车成功',
    content: `驾驶员 ${driver.name}（${driver.phone}）已被派往您的作业`,
    orderId: Number(req.params.id),
  });

  res.json({ code: 200, msg: '派车成功',
    data: {
      vehicle: `${vehicle.plate_number}（${vehicle.vehicle_type} ${vehicle.model}）`,
      driver: `${driver.name} ${driver.phone}`
    }
  });
}));

// ==================== 驾驶员：收到的派车任务 ====================

router.get('/driver-tasks', auth, requireRole('driver'), asyncHandler(async (req: Request, res: Response) => {
  autoCompleteOverdueApplications();
  const data = getDB().prepare(
    `SELECT ma.*,
        v.plate_number as assigned_plate,
        v.vehicle_type as assigned_vehicle_type,
        v.model as assigned_vehicle_model,
        dis.name as dispatcher_name
     FROM machinery_applications ma
     LEFT JOIN vehicles v ON ma.assigned_vehicle_id = v.id
     LEFT JOIN users dis ON ma.dispatcher_id = dis.id
     WHERE ma.assigned_driver_id = ? AND ma.status IN ('assigned','in_progress')
     ORDER BY ma.created_at DESC`
  ).all(req.user.id);
  res.json({ code: 200, data });
}));

// ==================== 驾驶员：历史任务 ====================

router.get('/driver-history', auth, requireRole('driver'), asyncHandler(async (req: Request, res: Response) => {
  const data = getDB().prepare(
    `SELECT ma.*,
        v.plate_number as assigned_plate,
        v.vehicle_type as assigned_vehicle_type,
        v.model as assigned_vehicle_model
     FROM machinery_applications ma
     LEFT JOIN vehicles v ON ma.assigned_vehicle_id = v.id
     WHERE ma.assigned_driver_id = ? AND ma.status IN ('completed','early_completed')
     ORDER BY ma.updated_at DESC`
  ).all(req.user.id);
  res.json({ code: 200, data });
}));

// ==================== 通用：申请详情 ====================

router.get('/detail/:id', auth, asyncHandler(async (req: Request, res: Response) => {
  const app = getDB().prepare(
    `SELECT ma.*,
        u.name as applicant_user_name,
        v.plate_number as assigned_plate,
        v.vehicle_type as assigned_vehicle_type,
        v.model as assigned_vehicle_model,
        du.name as driver_name, du.phone as driver_phone,
        dis.name as dispatcher_name
     FROM machinery_applications ma
     JOIN users u ON ma.applicant_id = u.id
     LEFT JOIN vehicles v ON ma.assigned_vehicle_id = v.id
     LEFT JOIN users du ON ma.assigned_driver_id = du.id
     LEFT JOIN users dis ON ma.dispatcher_id = dis.id
     WHERE ma.id = ?`
  ).get(req.params.id);
  if (!app) { res.json({ code: 404, msg: '申请不存在' }); return; }
  res.json({ code: 200, data: app });
}));

// ==================== 申请方：费用统计 ====================

router.get('/my-cost-stats', auth, asyncHandler(async (req: Request, res: Response) => {
  // 本月统计
  const thisMonth = dayjs().format('YYYY-MM');
  const monthStats = getDB().prepare(
    `SELECT COUNT(*) as total_count,
        SUM(CASE WHEN status IN ('completed','early_completed') THEN 1 ELSE 0 END) as completed_count,
        SUM(CASE WHEN status = 'assigned' THEN 1 ELSE 0 END) as active_count,
        COALESCE(SUM(total_cost), 0) as total_cost,
        COALESCE(SUM(working_hours), 0) as total_hours
     FROM machinery_applications
     WHERE applicant_id = ? AND created_at LIKE ?`
  ).get(req.user.id, thisMonth + '%') as Record<string, unknown>;

  // 全部汇总
  const allStats = getDB().prepare(
    `SELECT COALESCE(SUM(total_cost), 0) as all_total_cost,
        COUNT(*) as all_count
     FROM machinery_applications
     WHERE applicant_id = ? AND status IN ('completed','early_completed','assigned','in_progress')`
  ).get(req.user.id) as Record<string, unknown>;

  // 最近费用明细
  const recentItems = getDB().prepare(
    `SELECT application_no, applicant_dept, scheduled_start, scheduled_end,
        working_hours, hourly_rate, total_cost, status, application_type,
        created_at
     FROM machinery_applications
     WHERE applicant_id = ? AND total_cost > 0
     ORDER BY updated_at DESC LIMIT 20`
  ).all(req.user.id);

  res.json({ code: 200, data: {
    thisMonth: {
      totalCount: monthStats.total_count || 0,
      completedCount: monthStats.completed_count || 0,
      activeCount: monthStats.active_count || 0,
      totalCost: monthStats.total_cost || 0,
      totalHours: monthStats.total_hours || 0,
    },
    allTime: {
      totalCost: allStats.all_total_cost || 0,
      totalCount: allStats.all_count || 0,
    },
    recentItems,
  }});
}));

// ==================== 调度员：已派车订单列表（含日期筛选） ====================

router.get('/dispatched-list', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (req: Request, res: Response) => {
  autoCompleteOverdueApplications();
  const { date_from, date_to, period } = req.query;

  let sql = `SELECT ma.*,
      v.plate_number as assigned_plate,
      v.vehicle_type as assigned_vehicle_type,
      v.model as assigned_vehicle_model,
      du.name as driver_name
    FROM machinery_applications ma
    LEFT JOIN vehicles v ON ma.assigned_vehicle_id = v.id
    LEFT JOIN users du ON ma.assigned_driver_id = du.id
    WHERE ma.status IN ('assigned','in_progress','completed','early_completed')
      AND ma.assigned_vehicle_id IS NOT NULL`;
  const params: string[] = [];

  // 快捷筛选：今日/本月/本年
  const now = dayjs();
  if (period === 'today') {
    const today = now.format('YYYY-MM-DD');
    sql += ' AND ma.created_at >= ? AND ma.created_at <= ?';
    params.push(today + ' 00:00:00', today + ' 23:59:59');
  } else if (period === 'month') {
    sql += ' AND ma.created_at >= ? AND ma.created_at <= ?';
    params.push(now.format('YYYY-MM') + '-01 00:00:00', now.format('YYYY-MM-DD') + ' 23:59:59');
  } else if (period === 'year') {
    sql += ' AND ma.created_at >= ? AND ma.created_at <= ?';
    params.push(now.format('YYYY') + '-01-01 00:00:00', now.format('YYYY-MM-DD') + ' 23:59:59');
  } else {
    // 自定义日期范围
    if (date_from) { sql += ' AND ma.created_at >= ?'; params.push(String(date_from) + ' 00:00:00'); }
    if (date_to) { sql += ' AND ma.created_at <= ?'; params.push(String(date_to) + ' 23:59:59'); }
  }

  sql += ' ORDER BY ma.created_at DESC';
  const data = getDB().prepare(sql).all(...params);

  // 汇总统计
  const stats = { totalCount: data.length, totalRevenue: 0, totalHours: 0 };
  data.forEach((r: Record<string, unknown>) => {
    stats.totalRevenue += Number(r.total_cost) || 0;
    stats.totalHours += Number(r.working_hours) || 0;
  });
  stats.totalRevenue = Math.round(stats.totalRevenue * 100) / 100;
  stats.totalHours = Math.round(stats.totalHours * 100) / 100;

  res.json({ code: 200, data: { list: data, stats } });
}));

// ==================== 导出已派车收益数据CSV ====================

router.get('/export', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (req: Request, res: Response) => {
  const { date_from, date_to, period } = req.query;
  let sql = `SELECT ma.*,
      v.plate_number as assigned_plate,
      v.vehicle_type as assigned_vehicle_type,
      v.model as assigned_vehicle_model,
      du.name as driver_name
    FROM machinery_applications ma
    LEFT JOIN vehicles v ON ma.assigned_vehicle_id = v.id
    LEFT JOIN users du ON ma.assigned_driver_id = du.id
    WHERE ma.status IN ('assigned','in_progress','completed','early_completed')
      AND ma.assigned_vehicle_id IS NOT NULL`;
  const params: string[] = [];

  const now = dayjs();
  if (period === 'today') {
    const today = now.format('YYYY-MM-DD');
    sql += ' AND ma.created_at >= ? AND ma.created_at <= ?';
    params.push(today + ' 00:00:00', today + ' 23:59:59');
  } else if (period === 'month') {
    sql += ' AND ma.created_at >= ? AND ma.created_at <= ?';
    params.push(now.format('YYYY-MM') + '-01 00:00:00', now.format('YYYY-MM-DD') + ' 23:59:59');
  } else if (period === 'year') {
    sql += ' AND ma.created_at >= ? AND ma.created_at <= ?';
    params.push(now.format('YYYY') + '-01-01 00:00:00', now.format('YYYY-MM-DD') + ' 23:59:59');
  } else {
    if (date_from) { sql += ' AND ma.created_at >= ?'; params.push(String(date_from) + ' 00:00:00'); }
    if (date_to) { sql += ' AND ma.created_at <= ?'; params.push(String(date_to) + ' 23:59:59'); }
  }

  sql += ' ORDER BY ma.created_at DESC';
  const data = getDB().prepare(sql).all(...params);

  // 构建CSV - 简化列
  let csv = '﻿申请日期,申请部门,申请人,车辆,作业地点,作业时间,产生费用(元)\n';
  data.forEach((r: Record<string, unknown>) => {
    const vehicle = (r.assigned_plate || '') + ' ' + (r.assigned_vehicle_type || '') + ' ' + (r.assigned_vehicle_model || '');
    const workTime = (r.scheduled_start || '') + ' ~ ' + (r.scheduled_end || '');
    csv += [
      String(r.created_at || '').slice(0, 10),
      r.applicant_dept,
      r.applicant_name,
      vehicle.trim(),
      r.work_location,
      workTime,
      r.total_cost
    ].map(function(v: unknown) { return '"' + String(v).replace(/"/g, '""') + '"'; }).join(',') + '\n';
  });

  const filename = '已派车收益明细_' + dayjs().format('YYYYMMDD') + '.csv';
  res.setHeader('Content-Type', 'text/csv; charset=utf-8');
  res.setHeader('Content-Disposition', "attachment; filename*=UTF-8''" + encodeURIComponent(filename));
  res.send(csv);
}));

// ==================== 辅助函数 ====================

function parseTimeToMinutes(time: string): number {
  // 兼容两种格式: "HH:mm" 或 "YYYY-MM-DD HH:mm"
  var t = String(time);
  if (t.includes(' ')) t = t.split(' ')[1];  // 取日期后面的时间部分
  const parts = t.split(':');
  return (parseInt(parts[0]) || 0) * 60 + (parseInt(parts[1]) || 0);
}

function statusLabel(s: string): string {
  const map: Record<string, string> = {
    pending: '待指派', assigned: '用车中', in_progress: '用车中',
    completed: '已完成', early_completed: '提前结束', cancelled: '已取消'
  };
  return map[s] || s;
}

// ==================== 导出派车收益 Excel ====================
router.post('/export-xlsx', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (req: Request, res: Response) => {
  const { date_from, date_to, period } = req.body;
  let sql = `SELECT ma.*, v.plate_number as assigned_plate, v.vehicle_type as assigned_vehicle_type, v.model as assigned_vehicle_model, du.name as driver_name FROM machinery_applications ma LEFT JOIN vehicles v ON ma.assigned_vehicle_id=v.id LEFT JOIN users du ON ma.assigned_driver_id=du.id WHERE ma.status IN ('assigned','in_progress','completed','early_completed') AND ma.assigned_vehicle_id IS NOT NULL`;
  const params: string[] = [];
  const now = dayjs();
  if (period === 'today') { sql += ' AND ma.created_at >= ? AND ma.created_at <= ?'; params.push(now.format('YYYY-MM-DD')+' 00:00:00', now.format('YYYY-MM-DD')+' 23:59:59'); }
  else if (period === 'month') { sql += ' AND ma.created_at >= ? AND ma.created_at <= ?'; params.push(now.format('YYYY-MM')+'-01 00:00:00', now.format('YYYY-MM-DD')+' 23:59:59'); }
  else if (period === 'year') { sql += ' AND ma.created_at >= ? AND ma.created_at <= ?'; params.push(now.format('YYYY')+'-01-01 00:00:00', now.format('YYYY-MM-DD')+' 23:59:59'); }
  else { if (date_from) { sql += ' AND ma.created_at >= ?'; params.push(String(date_from)+' 00:00:00'); } if (date_to) { sql += ' AND ma.created_at <= ?'; params.push(String(date_to)+' 23:59:59'); } }
  sql += ' ORDER BY ma.created_at DESC';
  const data = getDB().prepare(sql).all(...params) as Record<string,unknown>[];

  const columns: ColumnDef[] = [
    { header:'申请日期',width:12,style:'date' },{ header:'申请部门',width:16 },{ header:'费供',width:8 },{ header:'申请人',width:12 },
    { header:'车辆',width:20 },{ header:'驾驶员',width:12 },{ header:'作业地点',width:18 },
    { header:'作业时间',width:30 },{ header:'作业时长(h)',width:12 },{ header:'费用(元)',width:14,style:'currency' },
    { header:'状态',width:10 },
  ];
  const rows = data.map(r => {
    const vehicle = (r.assigned_plate||'')+' '+(r.assigned_vehicle_type||'')+' '+(r.assigned_vehicle_model||'');
    const workTime = (r.scheduled_start||'')+' ~ '+(r.scheduled_end||'');
    const workHours = r.working_hours ? Number(r.working_hours).toFixed(1) : '-';
    const fp = r.fee_provider;
    const feeLabel = fp === 'party_a' ? '甲方' : fp === 'party_b' ? '乙方' : '-';
    return {
      '申请日期': String(r.created_at||'').slice(0,10), '申请部门': r.applicant_dept||'总调度室',
      '费供': feeLabel,
      '申请人': r.applicant_name||'-', '车辆': vehicle.trim(), '驾驶员': r.driver_name||'-',
      '作业地点': r.work_location||'-', '作业时间': workTime,
      '作业时长(h)': workHours, '费用(元)': Number(r.total_cost)||0,
      '状态': statusLabel(String(r.status||'')),
    };
  });
  await sendExcel(res, '派车收益明细.xlsx', '派车收益', columns, rows);
}));

// ==================== 申请分析（车型分布 + 趋势 + 车辆排名） ====================
router.get('/application-analysis', auth, requireRole('admin', 'dispatcher'), asyncHandler(async (req: Request, res: Response) => {
  const period = String(req.query.period || 'month');
  let fmt: string;
  if (period === 'year') fmt = '%Y';
  else if (period === 'day') fmt = '%Y-%m-%d';
  else fmt = '%Y-%m';

  // 车型申请分布
  const byType = getDB().prepare(
    `SELECT vehicle_type, COUNT(*) as cnt
     FROM machinery_applications WHERE vehicle_type != ''
     GROUP BY vehicle_type ORDER BY cnt DESC`
  ).all() as Record<string,unknown>[];
  const totalCount = (byType as any[]).reduce((s: number, r: any) => s + Number(r.cnt), 0);
  const byTypeResult = (byType as any[]).map((r: any) => ({
    vehicle_type: r.vehicle_type,
    count: Number(r.cnt),
    percentage: totalCount > 0 ? Math.round(Number(r.cnt) / totalCount * 1000) / 10 : 0,
  }));

  // 趋势
  const trendRows = getDB().prepare(
    `SELECT strftime('${fmt}', created_at) as label, vehicle_type, COUNT(*) as cnt
     FROM machinery_applications WHERE vehicle_type != ''
     GROUP BY label, vehicle_type ORDER BY label`
  ).all() as Record<string,unknown>[];
  const trendMap = new Map<string, { count: number; types: Record<string, number> }>();
  for (const r of (trendRows as any[])) {
    const label = String(r.label);
    if (!trendMap.has(label)) trendMap.set(label, { count: 0, types: {} });
    const entry = trendMap.get(label)!;
    entry.count += Number(r.cnt);
    entry.types[String(r.vehicle_type)] = Number(r.cnt);
  }
  const trend = Array.from(trendMap.entries()).map(([label, v]) => ({
    label, count: v.count, types: v.types,
  }));

  // 车辆被派次数排名（已指派/用车中/已完成/提前结束的工单）
  const vehicleRank = getDB().prepare(
    `SELECT v.plate_number, v.vehicle_type, COUNT(*) as cnt
     FROM machinery_applications ma
     JOIN vehicles v ON ma.assigned_vehicle_id = v.id
     WHERE ma.assigned_vehicle_id IS NOT NULL
     GROUP BY ma.assigned_vehicle_id
     ORDER BY cnt DESC`
  ).all() as Record<string,unknown>[];
  const vehicleRanking = (vehicleRank as any[]).map((r: any) => ({
    plate_number: r.plate_number,
    vehicle_type: r.vehicle_type,
    count: Number(r.cnt),
  }));

  res.json({ code: 200, data: { period, totalCount, byType: byTypeResult, trend, vehicleRanking } });
}));

export default router;
