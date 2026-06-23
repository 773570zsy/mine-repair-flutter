import { Router, Request, Response } from 'express';
import { auth, requireRole } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';
import dayjs from 'dayjs';
import { validate } from '../middleware/validate';
import {
  externalReportSchema,
  externalAcceptSchema,
  externalProgressSchema,
  externalApproveSchema,
} from '../schemas/external-repair.schemas';
import { pushToUsers, pushToTag } from '../services/jpush.service';
import { sendToUser, sendToRepairShop } from '../services/notification.service';

const router = Router();

// ==================== 共用 ====================

// 修理厂列表
router.get('/shops', auth, asyncHandler(async (_req: Request, res: Response) => {
  const shops = getDB().prepare('SELECT id, name FROM repair_shops WHERE status = 1 ORDER BY id').all();
  res.json({ code: 200, data: shops });
}));

// 部门列表
router.get('/departments', auth, asyncHandler(async (_req: Request, res: Response) => {
  const depts = getDB().prepare('SELECT id, name FROM departments WHERE status = 1 ORDER BY id').all();
  res.json({ code: 200, data: depts });
}));

// ==================== 报修人端 ====================

// 发起外部报修
router.post('/report', auth, requireRole('applicant', 'driver', 'external_repair'), validate(externalReportSchema), asyncHandler(async (req: Request, res: Response) => {
  const { vehicle_name, fault_description, fault_images, department_id, repair_shop_id } = req.body;

  // 优先使用请求体中的 department_id，其次用当前用户所属部门
  const deptId = department_id || req.user.department_id || 0;

  const orderNo = 'WX' + dayjs().format('YYYYMMDD') + String(Date.now()).slice(-4);
  const result = getDB().prepare(
    `INSERT INTO external_repair_orders (order_no, department_id, user_id, vehicle_name, fault_description, fault_images, status, repair_shop_id)
     VALUES (?, ?, ?, ?, ?, ?, 'pending_accept', ?)`
  ).run(orderNo, deptId, req.user.id, vehicle_name, fault_description, JSON.stringify(fault_images || []), repair_shop_id || null);
  const orderId = result.lastInsertRowid as number;

  // 通知：指定修理厂则只通知该厂用户，否则通知所有修理厂 + 极光推送
  const content = `外部报修单${orderNo}：${vehicle_name} ${fault_description}`;
  if (repair_shop_id) {
    const shopUsers = getDB().prepare("SELECT id, phone FROM users WHERE role = 'repair_shop' AND repair_shop_id = ? AND status = 1").all(repair_shop_id) as Array<{ id: number; phone: string }>;
    const phones: string[] = [];
    for (const su of shopUsers) {
      try {
        getDB().prepare(
          `INSERT INTO notifications (user_id, type, title, content, order_id)
           VALUES (?, 'new_order', '新外部报修单', ?, ?)`
        ).run(su.id, content, orderId);
        if (su.phone) phones.push(su.phone);
      } catch { /* 通知非关键 */ }
    }
    if (phones.length > 0) {
      pushToUsers(phones, '新外部报修单', content);
    }
  } else {
    const shopUsers = getDB().prepare("SELECT id, phone FROM users WHERE role = 'repair_shop' AND status = 1").all() as Array<{ id: number; phone: string }>;
    const phones: string[] = [];
    for (const su of shopUsers) {
      try {
        getDB().prepare(
          `INSERT INTO notifications (user_id, type, title, content, order_id)
           VALUES (?, 'new_order', '新外部报修单', ?, ?)`
        ).run(su.id, content, orderId);
        if (su.phone) phones.push(su.phone);
      } catch { /* 通知非关键 */ }
    }
    // 标签推送 + 别名推送双保险
    pushToTag('role_repair_shop', '新外部报修单', content);
    if (phones.length > 0) {
      pushToUsers(phones, '新外部报修单', content);
    }
  }

  // 通知管理员和领导
  const admins = getDB().prepare("SELECT id, phone FROM users WHERE role IN ('admin','leader') AND status = 1").all() as Array<{ id: number; phone: string }>;
  for (const a of admins) {
    try {
      getDB().prepare(
        `INSERT INTO notifications (user_id, type, title, content)
         VALUES (?, 'new_order', '新外部报修单', ?)`
      ).run(a.id, content);
    } catch { /* 通知非关键 */ }
  }
  pushToTag('role_admin', '新外部报修单', content);
  pushToTag('role_leader', '新外部报修单', content);

  res.json({ code: 200, msg: '报修成功', data: { order_no: orderNo } });
}));

// 本人的外修请求列表
router.get('/my-requests', auth, requireRole('applicant', 'driver', 'external_repair'), asyncHandler(async (req: Request, res: Response) => {
  const { status } = req.query;
  let sql = `SELECT eo.*, rs.name as repair_shop_name, d.name as dept_name
    FROM external_repair_orders eo
    LEFT JOIN repair_shops rs ON eo.repair_shop_id = rs.id
    LEFT JOIN departments d ON eo.department_id = d.id
    WHERE eo.user_id = ?`;
  const params: (string | number)[] = [req.user.id];
  if (status) { sql += ' AND eo.status = ?'; params.push(String(status)); }
  sql += ' ORDER BY eo.created_at DESC';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 确认验收
router.post('/accept-completion/:orderId', auth, requireRole('applicant', 'driver', 'external_repair'), asyncHandler(async (req: Request, res: Response) => {
  const order = getDB().prepare('SELECT * FROM external_repair_orders WHERE id = ?').get(req.params.orderId) as Record<string, unknown> | undefined;
  if (!order) { res.json({ code: 404, msg: '工单不存在' }); return; }
  if (order.user_id !== req.user.id) { res.json({ code: 403, msg: '无权操作' }); return; }
  if (order.status !== 'completed') { res.json({ code: 400, msg: '当前状态不可验收' }); return; }

  getDB().prepare("UPDATE external_repair_orders SET status = 'accepted', updated_at = datetime('now') WHERE id = ?").run(req.params.orderId);
  getDB().prepare(
    "INSERT INTO external_repair_progress (order_id, user_id, action, content) VALUES (?, ?, 'accepted', '报修人确认验收')"
  ).run(req.params.orderId, req.user.id);

  res.json({ code: 200, msg: '已验收' });
}));

// ==================== 修理厂端 ====================

// 待接单列表
router.get('/pending-accept', auth, requireRole('repair_shop'), asyncHandler(async (_req: Request, res: Response) => {
  const orders = getDB().prepare(
    `SELECT eo.*, d.name as dept_name, u.name as user_name
     FROM external_repair_orders eo
     JOIN departments d ON eo.department_id = d.id
     JOIN users u ON eo.user_id = u.id
     WHERE eo.status = 'pending_accept'
     ORDER BY eo.created_at DESC`
  ).all();
  res.json({ code: 200, data: orders });
}));

// 接单+报价（一步完成）
router.post('/accept-order/:orderId', auth, requireRole('repair_shop'), validate(externalAcceptSchema), asyncHandler(async (req: Request, res: Response) => {
  const order = getDB().prepare('SELECT * FROM external_repair_orders WHERE id = ?').get(req.params.orderId) as Record<string, unknown> | undefined;
  if (!order) { res.json({ code: 404, msg: '工单不存在' }); return; }
  if (order.status !== 'pending_accept') { res.json({ code: 400, msg: '当前状态不可接单' }); return; }

  const { quote_amount, parts_cost, labor_cost, hours_cost, parts_list, quote_detail, estimated_days } = req.body;

  getDB().prepare(
    `UPDATE external_repair_orders SET
      repair_shop_id = ?, status = 'pending_approval',
      quote_amount = ?, parts_cost = ?, labor_cost = ?, hours_cost = ?,
      parts_list = ?, quote_detail = ?, estimated_days = ?,
      updated_at = datetime('now')
     WHERE id = ?`
  ).run(
    req.user.repair_shop_id,
    quote_amount, parts_cost || 0, labor_cost || 0, hours_cost || 0,
    JSON.stringify(parts_list || []), quote_detail || '', estimated_days || null,
    req.params.orderId
  );

  getDB().prepare(
    "INSERT INTO external_repair_progress (order_id, user_id, action, content) VALUES (?, ?, 'accepted_order', '修理厂接单并提交报价')"
  ).run(req.params.orderId, req.user.id);

  // 通知报修人审批报价（DB + JPush）
  sendToUser(order.user_id as number, {
    type: 'quote_pending', title: '外部报修报价待审批',
    content: `外部报修单${order.order_no}已有报价¥${quote_amount}，请审批`,
  });

  res.json({ code: 200, msg: '接单成功，已提交报修人审批' });
}));

// 修理厂的外修工单
router.get('/shop-orders', auth, requireRole('repair_shop'), asyncHandler(async (req: Request, res: Response) => {
  const { status } = req.query;
  let sql = `SELECT eo.*, d.name as dept_name, u.name as user_name
    FROM external_repair_orders eo
    JOIN departments d ON eo.department_id = d.id
    JOIN users u ON eo.user_id = u.id
    WHERE eo.repair_shop_id = ?`;
  const params: (string | number)[] = [req.user.repair_shop_id ?? 0];
  if (status) {
    if (status === 'active') {
      sql += " AND eo.status IN ('pending_approval','approved','repairing')";
    } else {
      sql += ' AND eo.status = ?';
      params.push(String(status));
    }
  }
  sql += ' ORDER BY eo.created_at DESC';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 更新进度
router.post('/update-progress/:orderId', auth, requireRole('repair_shop'), validate(externalProgressSchema), asyncHandler(async (req: Request, res: Response) => {
  const order = getDB().prepare('SELECT * FROM external_repair_orders WHERE id = ?').get(req.params.orderId) as Record<string, unknown> | undefined;
  if (!order) { res.json({ code: 404, msg: '工单不存在' }); return; }
  if (order.repair_shop_id !== req.user.repair_shop_id) { res.json({ code: 403, msg: '无权操作' }); return; }
  if (order.status !== 'approved' && order.status !== 'repairing') { res.json({ code: 400, msg: '当前状态不可更新进度' }); return; }

  const { content, images } = req.body;
  // 首次更新进度时自动转入 repairing
  if (order.status === 'approved') {
    getDB().prepare("UPDATE external_repair_orders SET status = 'repairing', updated_at = datetime('now') WHERE id = ?").run(req.params.orderId);
  }

  getDB().prepare(
    "INSERT INTO external_repair_progress (order_id, user_id, action, content, images) VALUES (?, ?, 'progress_update', ?, ?)"
  ).run(req.params.orderId, req.user.id, content || '', JSON.stringify(images || []));

  res.json({ code: 200, msg: '进度已更新' });
}));

// 完工
router.post('/complete/:orderId', auth, requireRole('repair_shop'), asyncHandler(async (req: Request, res: Response) => {
  const order = getDB().prepare('SELECT * FROM external_repair_orders WHERE id = ?').get(req.params.orderId) as Record<string, unknown> | undefined;
  if (!order) { res.json({ code: 404, msg: '工单不存在' }); return; }
  if (order.repair_shop_id !== req.user.repair_shop_id) { res.json({ code: 403, msg: '无权操作' }); return; }
  if (order.status !== 'approved' && order.status !== 'repairing') { res.json({ code: 400, msg: '当前状态不可完工' }); return; }

  getDB().prepare("UPDATE external_repair_orders SET status = 'completed', updated_at = datetime('now') WHERE id = ?").run(req.params.orderId);
  getDB().prepare(
    "INSERT INTO external_repair_progress (order_id, user_id, action, content) VALUES (?, ?, 'completed', '维修已完成，等待验收')"
  ).run(req.params.orderId, req.user.id);

  // 通知报修人验收（DB + JPush）
  sendToUser(order.user_id as number, {
    type: 'repair_completed', title: '车辆维修完成',
    content: `外部报修单${order.order_no}已完工，请验收`,
  });

  res.json({ code: 200, msg: '已完工，待报修人验收' });
}));

// ==================== 领导/管理员端 ====================

// 待审批列表（报修人只看自己的，领导/管理员看全部）
router.get('/pending-approval', auth, asyncHandler(async (req: Request, res: Response) => {
  let sql = `SELECT eo.*, rs.name as repair_shop_name, d.name as dept_name, u.name as user_name
     FROM external_repair_orders eo
     LEFT JOIN repair_shops rs ON eo.repair_shop_id = rs.id
     JOIN departments d ON eo.department_id = d.id
     JOIN users u ON eo.user_id = u.id
     WHERE eo.status = 'pending_approval'`;
  const params: (string | number)[] = [];
  // 报修人只看自己的
  if (req.user.role === 'applicant' || req.user.role === 'driver' || req.user.role === 'external_repair') {
    sql += ' AND eo.user_id = ?';
    params.push(req.user.id);
  } else if (req.user.role !== 'admin' && req.user.role !== 'leader') {
    res.json({ code: 403, msg: '无权访问' }); return;
  }
  sql += ' ORDER BY eo.created_at DESC';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 审批（报修人或领导/管理员均可）
router.post('/approve/:orderId', auth, validate(externalApproveSchema), asyncHandler(async (req: Request, res: Response) => {
  const order = getDB().prepare('SELECT * FROM external_repair_orders WHERE id = ?').get(req.params.orderId) as Record<string, unknown> | undefined;
  if (!order) { res.json({ code: 404, msg: '工单不存在' }); return; }
  // 只有报修人本人或领导/管理员可以审批
  if (order.user_id !== req.user.id && req.user.role !== 'admin' && req.user.role !== 'leader') {
    res.json({ code: 403, msg: '无权审批' }); return;
  }
  if (order.status !== 'pending_approval') { res.json({ code: 400, msg: '当前状态不可审批' }); return; }

  const { approved, reject_reason } = req.body;

  if (approved) {
    getDB().prepare(
      "UPDATE external_repair_orders SET status = 'approved', leader_id = ?, approved_at = datetime('now'), updated_at = datetime('now') WHERE id = ?"
    ).run(req.user.id, req.params.orderId);
    getDB().prepare(
      "INSERT INTO external_repair_progress (order_id, user_id, action, content) VALUES (?, ?, 'approved', '审批通过')"
    ).run(req.params.orderId, req.user.id);

    // 通知修理厂（DB + JPush）
    sendToRepairShop(order.repair_shop_id as number, {
      type: 'quote_approved', title: '外修报价已通过',
      content: `外部报修单${order.order_no}报价已审批通过，请开始维修`,
    });
    res.json({ code: 200, msg: '审批通过' });
  } else {
    getDB().prepare(
      "UPDATE external_repair_orders SET status = 'rejected', reject_reason = ?, updated_at = datetime('now') WHERE id = ?"
    ).run(reject_reason, req.params.orderId);
    getDB().prepare(
      "INSERT INTO external_repair_progress (order_id, user_id, action, content) VALUES (?, ?, 'rejected', ?)"
    ).run(req.params.orderId, req.user.id, '审批驳回：' + reject_reason);

    // 通知修理厂（DB + JPush）
    sendToRepairShop(order.repair_shop_id as number, {
      type: 'quote_rejected', title: '外修报价被驳回',
      content: `外部报修单${order.order_no}报价被驳回：${reject_reason}`,
    });
    res.json({ code: 200, msg: '已驳回' });
  }
}));

// 标记加急
router.post('/urgent/:orderId', auth, requireRole('leader', 'admin'), asyncHandler(async (req: Request, res: Response) => {
  const order = getDB().prepare('SELECT * FROM external_repair_orders WHERE id = ?').get(req.params.orderId) as Record<string, unknown> | undefined;
  if (!order) { res.json({ code: 404, msg: '工单不存在' }); return; }
  if (order.status === 'accepted' || order.status === 'cancelled') { res.json({ code: 400, msg: '当前状态不可加急' }); return; }

  getDB().prepare("UPDATE external_repair_orders SET is_urgent = 1, updated_at = datetime('now') WHERE id = ?").run(req.params.orderId);
  getDB().prepare(
    "INSERT INTO external_repair_progress (order_id, user_id, action, content) VALUES (?, ?, 'urgent', '标记为加急')"
  ).run(req.params.orderId, req.user.id);

  // 通知修理厂（DB + JPush）
  if (order.repair_shop_id) {
    sendToRepairShop(order.repair_shop_id as number, {
      type: 'urgent', title: '加急维修通知',
      content: `外部报修单${order.order_no}已标记为加急维修，请优先处理`,
    });
  }

  res.json({ code: 200, msg: '已标记加急' });
}));

// 全部外修工单（分页+筛选）
router.get('/all-orders', auth, requireRole('leader', 'admin'), asyncHandler(async (req: Request, res: Response) => {
  const { status, department_id, repair_shop_id, date_from, date_to, keyword, page, pageSize } = req.query;
  let where = 'WHERE 1=1';
  const params: (string | number)[] = [];

  if (status) { where += ' AND eo.status = ?'; params.push(String(status)); }
  if (department_id) { where += ' AND eo.department_id = ?'; params.push(Number(department_id)); }
  if (repair_shop_id) { where += ' AND eo.repair_shop_id = ?'; params.push(Number(repair_shop_id)); }
  if (date_from) { where += ' AND eo.created_at >= ?'; params.push(String(date_from)); }
  if (date_to) { where += ' AND eo.created_at <= ?'; params.push(String(date_to) + ' 23:59:59'); }
  if (keyword) {
    where += ' AND (eo.order_no LIKE ? OR eo.vehicle_name LIKE ? OR u.name LIKE ?)';
    const kw = '%' + keyword + '%';
    params.push(kw, kw, kw);
  }

  const p = parseInt(String(page)) || 1;
  const ps = Math.min(parseInt(String(pageSize)) || 20, 100);
  const offset = (p - 1) * ps;

  const countRow = getDB().prepare(
    `SELECT COUNT(*) as total FROM external_repair_orders eo
     LEFT JOIN repair_shops rs ON eo.repair_shop_id = rs.id
     LEFT JOIN departments d ON eo.department_id = d.id
     LEFT JOIN users u ON eo.user_id = u.id
     ${where}`
  ).get(...params) as { total: number };

  const list = getDB().prepare(
    `SELECT eo.*, rs.name as repair_shop_name, d.name as dept_name, u.name as user_name
     FROM external_repair_orders eo
     LEFT JOIN repair_shops rs ON eo.repair_shop_id = rs.id
     LEFT JOIN departments d ON eo.department_id = d.id
     LEFT JOIN users u ON eo.user_id = u.id
     ${where}
     ORDER BY eo.created_at DESC LIMIT ${ps} OFFSET ${offset}`
  ).all(...params);

  res.json({ code: 200, data: { list, total: countRow.total, page: p, pageSize: ps } });
}));

// 订单详情
router.get('/detail/:orderId', auth, asyncHandler(async (req: Request, res: Response) => {
  const order = getDB().prepare(
    `SELECT eo.*, rs.name as repair_shop_name, d.name as dept_name, u.name as user_name
     FROM external_repair_orders eo
     LEFT JOIN repair_shops rs ON eo.repair_shop_id = rs.id
     LEFT JOIN departments d ON eo.department_id = d.id
     LEFT JOIN users u ON eo.user_id = u.id
     WHERE eo.id = ?`
  ).get(req.params.orderId);
  if (!order) { res.json({ code: 404, msg: '工单不存在' }); return; }

  const progress = getDB().prepare(
    `SELECT ep.*, u.name as user_name
     FROM external_repair_progress ep
     LEFT JOIN users u ON ep.user_id = u.id
     WHERE ep.order_id = ?
     ORDER BY ep.created_at ASC`
  ).all(req.params.orderId);

  res.json({ code: 200, data: { order, progress } });
}));

export default router;
