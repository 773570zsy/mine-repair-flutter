import { Router, Request, Response } from 'express';
import { auth, requireRole } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';
import dayjs from 'dayjs';
import { validate } from '../middleware/validate';
import { reportFaultSchema, submitQuoteSchema, updateProgressSchema, completeOrderSchema, approveOrderSchema, trialAcceptSchema } from '../schemas/repair.schemas';
import { notify, sendToUser, sendToRepairShop } from '../services/notification.service';
import { pushToUsers, pushToTag } from '../services/jpush.service';

const router = Router();

// ==================== 驾驶员端 ====================

// 获取可选的修理厂列表（驾驶员报修时选择）
router.get('/shops', auth, asyncHandler(async (_req: Request, res: Response) => {
  const shops = getDB().prepare('SELECT id, name FROM repair_shops WHERE status = 1 ORDER BY id').all();
  res.json({ code: 200, data: shops });
}));

// 发起报修
router.post('/report', auth, requireRole('driver'), validate(reportFaultSchema), asyncHandler(async (req: Request, res: Response) => {
  const { vehicle_id, fault_description, fault_images, repair_shop_id } = req.body;

  // 验证车辆存在
  const vehicle = getDB().prepare('SELECT id, plate_number FROM vehicles WHERE id = ?').get(vehicle_id) as any;
  if (!vehicle) { res.json({ code: 400, msg: '车辆不存在' }); return; }

  const orderNo = 'WX' + dayjs().format('YYYYMMDD') + String(Date.now()).slice(-4);
  const result = getDB().prepare(
    `INSERT INTO repair_orders (order_no, vehicle_id, driver_id, fault_description, fault_images, repair_shop_id, status)
     VALUES (?, ?, ?, ?, ?, ?, 'pending_accept')`
  ).run(orderNo, vehicle_id, req.user.id, fault_description, JSON.stringify(fault_images || []), repair_shop_id || null);
  const orderId = result.lastInsertRowid as number;

  // 通知指定修理厂（或所有修理厂）+ 极光推送
  const insertNotify = getDB().prepare('INSERT INTO notifications (user_id, type, title, content, order_id) VALUES (?, ?, ?, ?, ?)');
  if (repair_shop_id) {
    // 只通知指定修理厂的关联用户
    const shopUsers = getDB().prepare("SELECT id, phone FROM users WHERE role = 'repair_shop' AND repair_shop_id = ? AND status = 1").all(repair_shop_id) as { id: number; phone: string }[];
    const shop = getDB().prepare('SELECT name FROM repair_shops WHERE id = ?').get(repair_shop_id) as any;
    const phones: string[] = [];
    for (const s of shopUsers) {
      insertNotify.run(s.id, 'new_order', '新维修工单', `工单${orderNo}等待${shop?.name || '贵厂'}接单`, orderId);
      if (s.phone) phones.push(s.phone);
    }
    // 极光推送：推送给指定修理厂的所有用户
    if (phones.length > 0) {
      pushToUsers(phones, '新维修工单', `工单${orderNo}：${vehicle.plate_number} ${fault_description}`);
    }
  } else {
    // 未选修理厂：通知所有修理厂
    const shops = getDB().prepare("SELECT id, phone FROM users WHERE role = 'repair_shop' AND status = 1").all() as { id: number; phone: string }[];
    const phones: string[] = [];
    for (const s of shops) {
      insertNotify.run(s.id, 'new_order', '新维修工单', `工单${orderNo}等待接单`, orderId);
      if (s.phone) phones.push(s.phone);
    }
    // 极光推送：标签推送 + 别名推送双保险
    pushToTag('role_repair_shop', '新维修工单', `工单${orderNo}：${vehicle.plate_number} ${fault_description}`);
    if (phones.length > 0) {
      pushToUsers(phones, '新维修工单', `工单${orderNo}：${vehicle.plate_number} ${fault_description}`);
    }
  }

  // 同时通知管理员和领导
  pushToTag('role_admin', '新报修工单', `${vehicle.plate_number} 报修单${orderNo}：${fault_description}`);
  pushToTag('role_leader', '新报修工单', `${vehicle.plate_number} 报修单${orderNo}：${fault_description}`);

  res.json({ code: 200, msg: '报修成功', data: { order_no: orderNo } });
}));

// 我的报修列表
router.get('/my-orders', auth, requireRole('driver'), asyncHandler(async (req: Request, res: Response) => {
  const { status } = req.query;
  let sql = `SELECT ro.*, v.plate_number, v.vehicle_type, rs.name as repair_shop_name
    FROM repair_orders ro JOIN vehicles v ON ro.vehicle_id = v.id
    LEFT JOIN repair_shops rs ON ro.repair_shop_id = rs.id WHERE ro.driver_id = ?`;
  const params: (string | number)[] = [req.user.id];
  if (status) {
    const statuses = String(status).split(',').filter(Boolean);
    if (statuses.length === 1) {
      sql += ' AND ro.status = ?'; params.push(statuses[0]);
    } else {
      sql += ` AND ro.status IN (${statuses.map(() => '?').join(',')})`;
      params.push(...statuses);
    }
  }
  sql += ' ORDER BY ro.created_at DESC';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 试车验收
router.post('/accept/:orderId', auth, requireRole('driver'), validate(trialAcceptSchema), asyncHandler(async (req: Request, res: Response) => {
  const order = getDB().prepare('SELECT * FROM repair_orders WHERE id = ? AND driver_id = ?').get(req.params.orderId, req.user.id) as any;
  if (!order) { res.json({ code: 404, msg: '工单不存在' }); return; }
  if (order.status !== 'completed') { res.json({ code: 400, msg: '当前状态不可验收' }); return; }

  const { content } = req.body;
  const acceptContent = content || '故障已消除，试车目前无问题，可以验收';
  getDB().prepare('UPDATE repair_orders SET status = ? WHERE id = ?').run('accepted', order.id);
  getDB().prepare("INSERT INTO repair_progress (order_id, user_id, action, content) VALUES (?, ?, 'accepted', ?)").run(order.id, req.user.id, acceptContent);
  getDB().prepare("UPDATE vehicles SET status = 'normal' WHERE id = ? AND status = 'repairing'").run(order.vehicle_id);
  res.json({ code: 200, msg: '验收成功' });
}));

// ==================== 修理厂端 ====================

// 待接单列表
router.get('/pending-accept', auth, requireRole('repair_shop'), asyncHandler(async (_req: Request, res: Response) => {
  const orders = getDB().prepare(
    `SELECT ro.*, v.plate_number, v.vehicle_type, u.name as driver_name
     FROM repair_orders ro JOIN vehicles v ON ro.vehicle_id = v.id
     JOIN users u ON ro.driver_id = u.id WHERE ro.status = 'pending_accept' ORDER BY ro.created_at DESC`
  ).all();
  res.json({ code: 200, data: orders });
}));

// 接单
router.post('/accept-order/:orderId', auth, requireRole('repair_shop'), asyncHandler(async (req: Request, res: Response) => {
  const order = getDB().prepare('SELECT * FROM repair_orders WHERE id = ?').get(req.params.orderId) as any;
  if (!order || order.status !== 'pending_accept') { res.json({ code: 400, msg: '该工单不可接单' }); return; }

  getDB().prepare('UPDATE repair_orders SET repair_shop_id = ?, status = ? WHERE id = ?').run(req.user.repair_shop_id, 'pending_quote', order.id);
  getDB().prepare("INSERT INTO repair_progress (order_id, user_id, action, content) VALUES (?, ?, 'accepted_order', '修理厂已接单')").run(order.id, req.user.id);
  sendToUser(order.driver_id, {
    type: 'order_accepted', title: '修理厂已接单',
    content: `工单${order.order_no}已被接单`,
    orderId: order.id,
  });
  res.json({ code: 200, msg: '接单成功' });
}));

// 修理厂工单
router.get('/shop-orders', auth, requireRole('repair_shop'), asyncHandler(async (req: Request, res: Response) => {
  const { status } = req.query;
  let sql = `SELECT ro.*, v.plate_number, v.vehicle_type, u.name as driver_name
    FROM repair_orders ro JOIN vehicles v ON ro.vehicle_id = v.id
    JOIN users u ON ro.driver_id = u.id WHERE ro.repair_shop_id = ?`;
  const params: (string | number)[] = [req.user.repair_shop_id!];
  if (status) { sql += ' AND ro.status = ?'; params.push(String(status)); }
  sql += ' ORDER BY ro.created_at DESC';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 提交报价
router.post('/submit-quote/:orderId', auth, requireRole('repair_shop'), validate(submitQuoteSchema), asyncHandler(async (req: Request, res: Response) => {
  const { quote_amount, parts_cost, labor_cost, hours_cost, parts_list, quote_detail, estimated_days, damage_photos } = req.body;

  const order = getDB().prepare('SELECT * FROM repair_orders WHERE id = ? AND repair_shop_id = ?').get(req.params.orderId, req.user.repair_shop_id) as any;
  if (!order || (order.status !== 'pending_quote' && order.status !== 'rejected')) { res.json({ code: 400, msg: '当前状态不可报价' }); return; }

  const isReQuote = order.status === 'rejected';
  if (isReQuote) {
    // 驳回后重新报价：更新已有报价记录
    getDB().prepare(
      `UPDATE repair_quotes SET quote_amount = ?, parts_cost = ?, labor_cost = ?, hours_cost = ?,
       parts_list = ?, quote_detail = ?, estimated_days = ?, damage_photos = ?,
       approved_at = NULL, leader_id = NULL WHERE order_id = ?`
    ).run(quote_amount, parts_cost || 0, labor_cost || 0, hours_cost || 0,
      JSON.stringify(parts_list || []), quote_detail || '', estimated_days,
      JSON.stringify(damage_photos || []), order.id);
  } else {
    getDB().prepare(
      `INSERT INTO repair_quotes (order_id, repair_shop_id, quote_amount, parts_cost, labor_cost, hours_cost, parts_list, quote_detail, estimated_days, damage_photos)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(order.id, req.user.repair_shop_id, quote_amount, parts_cost || 0, labor_cost || 0, hours_cost || 0, JSON.stringify(parts_list || []), quote_detail || '', estimated_days, JSON.stringify(damage_photos || []));
  }
  getDB().prepare('UPDATE repair_orders SET status = ?, reject_reason = NULL WHERE id = ?').run('pending_approval', order.id);
  getDB().prepare("INSERT INTO repair_progress (order_id, user_id, action, content) VALUES (?, ?, ?, ?)").run(order.id, req.user.id, 'quote_submitted', `${isReQuote ? '重新报价' : '报价'} ¥${quote_amount}，预计${estimated_days}天`);

  // 通知领导 + 管理员 + 报修人（DB写入 + JPush推送）
  notify.quotePending(order.order_no, quote_amount, order.driver_id, order.id);
  res.json({ code: 200, msg: '报价提交成功' });
}));

// 更新进度
router.post('/update-progress/:orderId', auth, requireRole('repair_shop'), validate(updateProgressSchema), asyncHandler(async (req: Request, res: Response) => {
  const { content, note, images } = req.body;
  const progressContent = content || note || '';
  const order = getDB().prepare('SELECT * FROM repair_orders WHERE id = ? AND repair_shop_id = ?').get(req.params.orderId, req.user.repair_shop_id) as any;
  if (!order || !['approved', 'repairing'].includes(order.status)) { res.json({ code: 400, msg: '当前状态不可更新进度' }); return; }

  if (order.status === 'approved') {
    getDB().prepare('UPDATE repair_orders SET status = ? WHERE id = ?').run('repairing', order.id);
    getDB().prepare('UPDATE vehicles SET status = ? WHERE id = ?').run('repairing', order.vehicle_id);
  }
  getDB().prepare("INSERT INTO repair_progress (order_id, user_id, action, content, images) VALUES (?, ?, 'progress_update', ?, ?)").run(order.id, req.user.id, progressContent, JSON.stringify(images || []));
  res.json({ code: 200, msg: '进度更新成功' });
}));

// 完工
router.post('/complete/:orderId', auth, requireRole('repair_shop'), validate(completeOrderSchema), asyncHandler(async (req: Request, res: Response) => {
  const order = getDB().prepare('SELECT * FROM repair_orders WHERE id = ? AND repair_shop_id = ?').get(req.params.orderId, req.user.repair_shop_id) as any;
  if (!order || !['approved', 'repairing'].includes(order.status)) { res.json({ code: 400, msg: '当前状态不可完工' }); return; }

  const { new_photos } = req.body;
  getDB().prepare('UPDATE repair_orders SET status = ? WHERE id = ?').run('completed', order.id);
  getDB().prepare("INSERT INTO repair_progress (order_id, user_id, action, content) VALUES (?, ?, 'completed', '维修已完成，等待验收')").run(order.id, req.user.id);
  // 更新报价记录中的新配件照片
  if (new_photos && new_photos.length > 0) {
    getDB().prepare('UPDATE repair_quotes SET new_photos = ? WHERE order_id = ?').run(JSON.stringify(new_photos), order.id);
  }
  sendToUser(order.driver_id, {
    type: 'repair_completed', title: '车辆维修完成',
    content: `工单${order.order_no}已完工，请验收`,
    orderId: order.id,
  });
  res.json({ code: 200, msg: '完工通知已发送' });
}));

// 修理厂通知驾驶员验收（重新发送通知）
router.post('/notify-accept/:orderId', auth, requireRole('repair_shop'), asyncHandler(async (req: Request, res: Response) => {
  const order = getDB().prepare('SELECT * FROM repair_orders WHERE id = ? AND repair_shop_id = ?').get(req.params.orderId, req.user.repair_shop_id) as any;
  if (!order || order.status !== 'completed') { res.json({ code: 400, msg: '当前状态不可通知验收' }); return; }
  sendToUser(order.driver_id, {
    type: 'repair_completed', title: '车辆维修完成',
    content: `工单${order.order_no}已完工，修理厂提醒您尽快验收`,
    orderId: order.id,
  });
  res.json({ code: 200, msg: '已通知驾驶员验收' });
}));

// ==================== 领导端 ====================

// 待审批
router.get('/pending-approval', auth, requireRole('leader', 'admin'), asyncHandler(async (_req: Request, res: Response) => {
  const orders = getDB().prepare(
    `SELECT ro.*, rq.quote_amount, rq.parts_cost, rq.labor_cost, rq.hours_cost, rq.quote_detail,
            rq.estimated_days, rq.damage_photos, rq.new_photos, rq.parts_list,
            v.plate_number, v.vehicle_type, u.name as driver_name, rs.name as repair_shop_name
     FROM repair_orders ro JOIN vehicles v ON ro.vehicle_id = v.id
     JOIN users u ON ro.driver_id = u.id JOIN repair_shops rs ON ro.repair_shop_id = rs.id
     JOIN repair_quotes rq ON rq.order_id = ro.id WHERE ro.status = 'pending_approval' ORDER BY ro.created_at DESC`
  ).all();
  res.json({ code: 200, data: orders });
}));

// 审批
router.post('/approve/:orderId', auth, requireRole('leader', 'admin'), validate(approveOrderSchema), asyncHandler(async (req: Request, res: Response) => {
  const { approved, reject_reason } = req.body;
  const order = getDB().prepare(
    `SELECT ro.*, rq.id as quote_id FROM repair_orders ro JOIN repair_quotes rq ON rq.order_id = ro.id
     WHERE ro.id = ? AND ro.status = 'pending_approval'`
  ).get(req.params.orderId) as any;
  if (!order) { res.json({ code: 400, msg: '工单不存在或状态异常' }); return; }

  if (approved) {
    getDB().prepare('UPDATE repair_orders SET status = ? WHERE id = ?').run('approved', order.id);
    getDB().prepare('UPDATE vehicles SET status = ? WHERE id = ?').run('repairing', order.vehicle_id);
    getDB().prepare("UPDATE repair_quotes SET leader_id = ?, approved_at = datetime('now') WHERE id = ?").run(req.user.id, order.quote_id);
    getDB().prepare("INSERT INTO repair_progress (order_id, user_id, action, content) VALUES (?, ?, 'approved', '领导审批通过，可开始维修')").run(order.id, req.user.id);
    // 通知修理厂（DB + JPush）
    sendToRepairShop(order.repair_shop_id, {
      type: 'quote_approved', title: '报价已通过',
      content: `工单${order.order_no}报价审批通过`,
      orderId: order.id,
    });
  } else {
    if (!reject_reason) { res.json({ code: 400, msg: '请填写驳回原因' }); return; }
    getDB().prepare('UPDATE repair_orders SET status = ?, reject_reason = ? WHERE id = ?').run('rejected', reject_reason, order.id);
    getDB().prepare("INSERT INTO repair_progress (order_id, user_id, action, content) VALUES (?, ?, 'rejected', ?)").run(order.id, req.user.id, `审批驳回：${reject_reason}`);
    sendToRepairShop(order.repair_shop_id, {
      type: 'quote_rejected', title: '报价被驳回',
      content: `工单${order.order_no}报价被驳回：${reject_reason}`,
      orderId: order.id,
    });
  }
  res.json({ code: 200, msg: approved ? '审批通过' : '已驳回' });
}));

// 标记加急
router.post('/urgent/:orderId', auth, requireRole('leader', 'admin'), asyncHandler(async (req: Request, res: Response) => {
  const order = getDB().prepare('SELECT * FROM repair_orders WHERE id = ?').get(req.params.orderId) as any;
  if (!order) { res.json({ code: 404, msg: '工单不存在' }); return; }
  getDB().prepare('UPDATE repair_orders SET is_urgent = 1 WHERE id = ?').run(order.id);
  getDB().prepare("INSERT INTO repair_progress (order_id, user_id, action, content) VALUES (?, ?, 'urgent', '标记为加急维修')").run(order.id, req.user.id);
  sendToRepairShop(order.repair_shop_id, {
    type: 'order_urgent', title: '加急维修通知',
    content: `工单${order.order_no}已标记为加急维修，请优先处理`,
    orderId: order.id,
  });
  res.json({ code: 200, msg: '已标记为加急' });
}));

// 全部工单
router.get('/all-orders', auth, requireRole('leader', 'admin'), asyncHandler(async (req: Request, res: Response) => {
  const { status, vehicle_id, date_from, date_to, keyword, page = '1', pageSize = '20' } = req.query;
  let sql = `SELECT ro.*, v.plate_number, v.vehicle_type, u.name as driver_name, rs.name as repair_shop_name,
    rq.quote_amount, rq.parts_cost, rq.labor_cost, rq.hours_cost, rq.parts_list,
    rq.quote_detail, rq.estimated_days, rq.approved_at, rq.damage_photos, rq.new_photos
    FROM repair_orders ro JOIN vehicles v ON ro.vehicle_id = v.id
    JOIN users u ON ro.driver_id = u.id LEFT JOIN repair_shops rs ON ro.repair_shop_id = rs.id
    LEFT JOIN repair_quotes rq ON rq.order_id = ro.id WHERE 1=1`;
  const params: (string | number)[] = [];
  if (status) {
    const statuses = String(status).split(',').filter(Boolean);
    if (statuses.length === 1) {
      sql += ' AND ro.status = ?'; params.push(statuses[0]);
    } else {
      sql += ` AND ro.status IN (${statuses.map(() => '?').join(',')})`;
      params.push(...statuses);
    }
  }
  if (vehicle_id) { sql += ' AND ro.vehicle_id = ?'; params.push(Number(vehicle_id)); }
  if (date_from) { sql += ' AND ro.created_at >= ?'; params.push(String(date_from)); }
  if (date_to) { sql += ' AND ro.created_at <= ?'; params.push(String(date_to) + ' 23:59:59'); }
  if (keyword) { sql += ' AND (ro.order_no LIKE ? OR v.plate_number LIKE ? OR u.name LIKE ?)'; params.push(`%${keyword}%`, `%${keyword}%`, `%${keyword}%`); }
  sql += ' ORDER BY ro.created_at DESC LIMIT ? OFFSET ?';
  params.push(Number(pageSize), (Number(page) - 1) * Number(pageSize));
  const orders = getDB().prepare(sql).all(...params);
  res.json({ code: 200, data: { list: orders, page: Number(page), pageSize: Number(pageSize) } });
}));

// 工单详情
router.get('/detail/:orderId', auth, asyncHandler(async (req: Request, res: Response) => {
  const order = getDB().prepare(
    `SELECT ro.*, v.plate_number, v.vehicle_type, v.model,
            u.name as driver_name, u.phone as driver_phone, d.name as dept_name,
            rs.name as repair_shop_name, rq.quote_amount, rq.parts_cost, rq.labor_cost,
            rq.hours_cost, rq.parts_list, rq.quote_detail, rq.estimated_days, rq.approved_at,
            rq.damage_photos, rq.new_photos
     FROM repair_orders ro JOIN vehicles v ON ro.vehicle_id = v.id
     JOIN users u ON ro.driver_id = u.id LEFT JOIN departments d ON u.department_id = d.id
     LEFT JOIN repair_shops rs ON ro.repair_shop_id = rs.id
     LEFT JOIN repair_quotes rq ON rq.order_id = ro.id WHERE ro.id = ?`
  ).get(req.params.orderId) as any;
  if (!order) { res.json({ code: 404, msg: '工单不存在' }); return; }

  const progress = getDB().prepare(
    `SELECT rp.*, us.name as user_name, us.role as user_role
     FROM repair_progress rp JOIN users us ON rp.user_id = us.id
     WHERE rp.order_id = ? ORDER BY rp.created_at ASC`
  ).all(req.params.orderId);

  res.json({ code: 200, data: { order, progress } });
}));

export default router;
