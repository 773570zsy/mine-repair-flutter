const express = require('express');
const router = express.Router();
const { auth, requireRole } = require('../middleware/auth');
const { query, queryOne } = require('../utils/db');
const { sendNotification } = require('../utils/notify');
const dayjs = require('dayjs');

// ==================== 驾驶员端 ====================

// 发起报修
router.post('/report', auth, requireRole('driver'), async (req, res) => {
  try {
    const { vehicle_id, fault_description, fault_images } = req.body;
    if (!vehicle_id || !fault_description) {
      return res.json({ code: 400, msg: '请填写车辆和故障描述' });
    }

    const orderNo = 'JL' + dayjs().format('YYYYMMDD') + String(Date.now()).slice(-4);

    await query(
      `INSERT INTO repair_orders (order_no, vehicle_id, driver_id, fault_description, fault_images, status)
       VALUES (?, ?, ?, ?, ?, 'pending_accept')`,
      [orderNo, vehicle_id, req.user.id, fault_description, JSON.stringify(fault_images || [])]
    );

    // 通知所有修理厂
    await sendNotification('repair_shop', 'new_order', '新维修工单', `工单${orderNo}等待接单`, null);

    res.json({ code: 200, msg: '报修成功', data: { order_no: orderNo } });
  } catch (err) {
    console.error(err);
    res.json({ code: 500, msg: '报修失败' });
  }
});

// 驾驶员-查看我的报修列表
router.get('/my-orders', auth, requireRole('driver'), async (req, res) => {
  const { status } = req.query;
  let sql = `
    SELECT ro.*, v.plate_number, v.vehicle_type, rs.name as repair_shop_name
    FROM repair_orders ro
    JOIN vehicles v ON ro.vehicle_id = v.id
    LEFT JOIN repair_shops rs ON ro.repair_shop_id = rs.id
    WHERE ro.driver_id = ?
  `;
  const params = [req.user.id];
  if (status) { sql += ' AND ro.status = ?'; params.push(status); }
  sql += ' ORDER BY ro.created_at DESC';

  const orders = await query(sql, params);
  res.json({ code: 200, data: orders });
});

// 驾驶员-验收车辆
router.post('/accept/:orderId', auth, requireRole('driver'), async (req, res) => {
  const order = await queryOne('SELECT * FROM repair_orders WHERE id = ? AND driver_id = ?',
    [req.params.orderId, req.user.id]);
  if (!order) return res.json({ code: 404, msg: '工单不存在' });
  if (order.status !== 'completed') return res.json({ code: 400, msg: '当前状态不可验收' });

  await query('UPDATE repair_orders SET status = ? WHERE id = ?', ['accepted', order.id]);
  await query(
    `INSERT INTO repair_progress (order_id, user_id, action, content) VALUES (?, ?, 'accepted', '驾驶员验收通过')`,
    [order.id, req.user.id]
  );

  // 验收后恢复车辆正常状态
  await query("UPDATE vehicles SET status='normal' WHERE id=? AND status='repairing'", [order.vehicle_id]);

  res.json({ code: 200, msg: '验收成功' });
});

// ==================== 修理厂端 ====================

// 待接单列表
router.get('/pending-accept', auth, requireRole('repair_shop'), async (req, res) => {
  const orders = await query(
    `SELECT ro.*, v.plate_number, v.vehicle_type, u.name as driver_name
     FROM repair_orders ro
     JOIN vehicles v ON ro.vehicle_id = v.id
     JOIN users u ON ro.driver_id = u.id
     WHERE ro.status = 'pending_accept'
     ORDER BY ro.created_at DESC`
  );
  res.json({ code: 200, data: orders });
});

// 接单
router.post('/accept-order/:orderId', auth, requireRole('repair_shop'), async (req, res) => {
  const order = await queryOne('SELECT * FROM repair_orders WHERE id = ?', [req.params.orderId]);
  if (!order || order.status !== 'pending_accept') {
    return res.json({ code: 400, msg: '该工单不可接单' });
  }

  await query(
    'UPDATE repair_orders SET repair_shop_id = ?, status = ? WHERE id = ?',
    [req.user.repair_shop_id, 'pending_quote', order.id]
  );
  await query(
    `INSERT INTO repair_progress (order_id, user_id, action, content)
     VALUES (?, ?, 'accepted_order', '修理厂已接单')`,
    [order.id, req.user.id]
  );
  await sendNotification('driver', 'order_accepted', '修理厂已接单', `工单${order.order_no}已被接单`, order.id);

  res.json({ code: 200, msg: '接单成功' });
});

// 修理厂-查看我的工单
router.get('/shop-orders', auth, requireRole('repair_shop'), async (req, res) => {
  const { status } = req.query;
  let sql = `
    SELECT ro.*, v.plate_number, v.vehicle_type, u.name as driver_name
    FROM repair_orders ro
    JOIN vehicles v ON ro.vehicle_id = v.id
    JOIN users u ON ro.driver_id = u.id
    WHERE ro.repair_shop_id = ?
  `;
  const params = [req.user.repair_shop_id];
  if (status) { sql += ' AND ro.status = ?'; params.push(status); }
  sql += ' ORDER BY ro.created_at DESC';

  const orders = await query(sql, params);
  res.json({ code: 200, data: orders });
});

// 提交报价
router.post('/submit-quote/:orderId', auth, requireRole('repair_shop'), async (req, res) => {
  const { quote_amount, parts_cost, labor_cost, hours_cost, parts_list, quote_detail, estimated_days, damage_photos, new_photos } = req.body;
  if (!quote_amount) return res.json({ code: 400, msg: '请填写报价金额' });

  const order = await queryOne('SELECT * FROM repair_orders WHERE id = ? AND repair_shop_id = ?',
    [req.params.orderId, req.user.repair_shop_id]);
  if (!order || order.status !== 'pending_quote') {
    return res.json({ code: 400, msg: '当前状态不可报价' });
  }

  await query(
    `INSERT INTO repair_quotes (order_id, repair_shop_id, quote_amount, parts_cost, labor_cost, hours_cost, parts_list, quote_detail, estimated_days, damage_photos, new_photos)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [order.id, req.user.repair_shop_id, quote_amount, parts_cost || 0, labor_cost || 0, hours_cost || 0, JSON.stringify(parts_list || []), quote_detail || '', estimated_days, JSON.stringify(damage_photos||[]), JSON.stringify(new_photos||[])]
  );
  await query('UPDATE repair_orders SET status = ? WHERE id = ?', ['pending_approval', order.id]);
  await query(
    `INSERT INTO repair_progress (order_id, user_id, action, content)
     VALUES (?, ?, 'quote_submitted', ?)`,
    [order.id, req.user.id, `报价 ¥${quote_amount}，预计${estimated_days}天`]
  );
  await sendNotification('leader', 'quote_pending', '待审批报价', `工单${order.order_no}报价¥${quote_amount}，请审批`, order.id);

  res.json({ code: 200, msg: '报价提交成功' });
});

// 更新维修进度
router.post('/update-progress/:orderId', auth, requireRole('repair_shop'), async (req, res) => {
  const { content, images } = req.body;
  const order = await queryOne('SELECT * FROM repair_orders WHERE id = ? AND repair_shop_id = ?',
    [req.params.orderId, req.user.repair_shop_id]);
  if (!order || !['approved', 'repairing'].includes(order.status)) {
    return res.json({ code: 400, msg: '当前状态不可更新进度' });
  }

  // 首次更新进度时改为维修中
  if (order.status === 'approved') {
    await query('UPDATE repair_orders SET status = ? WHERE id = ?', ['repairing', order.id]);
    await query('UPDATE vehicles SET status = ? WHERE id = ?', ['repairing', order.vehicle_id]);
  }

  await query(
    `INSERT INTO repair_progress (order_id, user_id, action, content, images)
     VALUES (?, ?, 'progress_update', ?, ?)`,
    [order.id, req.user.id, content, JSON.stringify(images || [])]
  );

  res.json({ code: 200, msg: '进度更新成功' });
});

// 完工
router.post('/complete/:orderId', auth, requireRole('repair_shop'), async (req, res) => {
  const order = await queryOne('SELECT * FROM repair_orders WHERE id = ? AND repair_shop_id = ?',
    [req.params.orderId, req.user.repair_shop_id]);
  if (!order || !['approved', 'repairing'].includes(order.status)) {
    return res.json({ code: 400, msg: '当前状态不可完工' });
  }

  await query('UPDATE repair_orders SET status = ? WHERE id = ?', ['completed', order.id]);
  await query(
    `INSERT INTO repair_progress (order_id, user_id, action, content)
     VALUES (?, ?, 'completed', '维修已完成，等待验收')`,
    [order.id, req.user.id]
  );
  await sendNotification('driver', 'repair_completed', '车辆维修完成', `工单${order.order_no}已完工，请验收`, order.id);

  res.json({ code: 200, msg: '完工通知已发送' });
});

// ==================== 领导端 ====================

// 待审批报价列表
router.get('/pending-approval', auth, requireRole('leader', 'admin'), async (req, res) => {
  const orders = await query(
    `SELECT ro.*, rq.quote_amount, rq.parts_cost, rq.labor_cost, rq.quote_detail, rq.estimated_days,
            v.plate_number, v.vehicle_type, u.name as driver_name, rs.name as repair_shop_name
     FROM repair_orders ro
     JOIN vehicles v ON ro.vehicle_id = v.id
     JOIN users u ON ro.driver_id = u.id
     JOIN repair_shops rs ON ro.repair_shop_id = rs.id
     JOIN repair_quotes rq ON rq.order_id = ro.id
     WHERE ro.status = 'pending_approval'
     ORDER BY ro.created_at DESC`
  );
  res.json({ code: 200, data: orders });
});

// 审批报价
router.post('/approve/:orderId', auth, requireRole('leader', 'admin'), async (req, res) => {
  const { approved, reject_reason } = req.body; // approved: true=通过, false=驳回

  const order = await queryOne(
    `SELECT ro.*, rq.id as quote_id FROM repair_orders ro
     JOIN repair_quotes rq ON rq.order_id = ro.id
     WHERE ro.id = ? AND ro.status = 'pending_approval'`,
    [req.params.orderId]
  );
  if (!order) return res.json({ code: 400, msg: '工单不存在或状态异常' });

  if (approved) {
    await query('UPDATE repair_orders SET status = ? WHERE id = ?', ['approved', order.id]);
    await query("UPDATE repair_quotes SET leader_id = ?, approved_at = datetime('now') WHERE id = ?",
      [req.user.id, order.quote_id]);
    await query(
      `INSERT INTO repair_progress (order_id, user_id, action, content)
       VALUES (?, ?, 'approved', '领导审批通过，可开始维修')`,
      [order.id, req.user.id]
    );
    await sendNotification('repair_shop', 'quote_approved', '报价已通过', `工单${order.order_no}报价审批通过`, order.id);
  } else {
    if (!reject_reason) return res.json({ code: 400, msg: '请填写驳回原因' });
    await query('UPDATE repair_orders SET status = ?, reject_reason = ? WHERE id = ?',
      ['rejected', reject_reason, order.id]);
    await query(
      `INSERT INTO repair_progress (order_id, user_id, action, content)
       VALUES (?, ?, 'rejected', ?)`,
      [order.id, req.user.id, `审批驳回：${reject_reason}`]
    );
    await sendNotification('repair_shop', 'quote_rejected', '报价被驳回', `工单${order.order_no}报价被驳回`, order.id);
  }

  res.json({ code: 200, msg: approved ? '审批通过' : '已驳回' });
});

// 标记加急
router.post('/urgent/:orderId', auth, requireRole('leader', 'admin'), async (req, res) => {
  const order = await queryOne('SELECT * FROM repair_orders WHERE id=?', [req.params.orderId]);
  if (!order) return res.json({ code: 404, msg: '工单不存在' });
  await query('UPDATE repair_orders SET is_urgent=1 WHERE id=?', [order.id]);
  await query(
    "INSERT INTO repair_progress (order_id, user_id, action, content) VALUES (?,?,'urgent','标记为加急维修')",
    [order.id, req.user.id]
  );
  await sendNotification('repair_shop', 'order_urgent', '加急维修通知', `工单${order.order_no}已标记为加急维修，请优先处理`, order.id);
  res.json({ code: 200, msg: '已标记为加急' });
});

// 所有维修记录（领导/管理员可查看全部）
router.get('/all-orders', auth, requireRole('leader', 'admin'), async (req, res) => {
  const { status, vehicle_id, date_from, date_to, keyword, page = 1, pageSize = 20 } = req.query;

  let sql = `
    SELECT ro.*, v.plate_number, v.vehicle_type, u.name as driver_name, rs.name as repair_shop_name,
           rq.quote_amount, rq.approved_at
    FROM repair_orders ro
    JOIN vehicles v ON ro.vehicle_id = v.id
    JOIN users u ON ro.driver_id = u.id
    LEFT JOIN repair_shops rs ON ro.repair_shop_id = rs.id
    LEFT JOIN repair_quotes rq ON rq.order_id = ro.id
    WHERE 1=1
  `;
  const params = [];

  if (status) { sql += ' AND ro.status = ?'; params.push(status); }
  if (vehicle_id) { sql += ' AND ro.vehicle_id = ?'; params.push(vehicle_id); }
  if (date_from) { sql += ' AND ro.created_at >= ?'; params.push(date_from); }
  if (date_to) { sql += ' AND ro.created_at <= ?'; params.push(date_to + ' 23:59:59'); }
  if (keyword) {
    sql += ' AND (ro.order_no LIKE ? OR v.plate_number LIKE ? OR u.name LIKE ?)';
    params.push(`%${keyword}%`, `%${keyword}%`, `%${keyword}%`);
  }

  sql += ' ORDER BY ro.created_at DESC LIMIT ? OFFSET ?';
  params.push(Number(pageSize), (Number(page) - 1) * Number(pageSize));

  const orders = await query(sql, params);

  // 总数
  let countSql = 'SELECT COUNT(*) as total FROM repair_orders ro JOIN vehicles v ON ro.vehicle_id=v.id JOIN users u ON ro.driver_id=u.id WHERE 1=1';
  const countParams = [];
  if (status) { countSql += ' AND ro.status=?'; countParams.push(status); }
  if (vehicle_id) { countSql += ' AND ro.vehicle_id=?'; countParams.push(vehicle_id); }
  if (date_from) { countSql += ' AND ro.created_at>=?'; countParams.push(date_from); }
  if (date_to) { countSql += ' AND ro.created_at<=?'; countParams.push(date_to+' 23:59:59'); }
  if (keyword) { countSql += ' AND (ro.order_no LIKE ? OR v.plate_number LIKE ? OR u.name LIKE ?)'; countParams.push(`%${keyword}%`, `%${keyword}%`, `%${keyword}%`); }
  const countResult = await queryOne(countSql, countParams);
  const total = countResult ? (countResult.total || 0) : orders.length;

  res.json({ code: 200, data: { list: orders, total, page: Number(page), pageSize: Number(pageSize) } });
});

// 工单详情（进度记录）
router.get('/detail/:orderId', auth, async (req, res) => {
  const order = await queryOne(
    `SELECT ro.*, v.plate_number, v.vehicle_type, v.model,
            u.name as driver_name, u.phone as driver_phone,
            d.name as dept_name,
            rs.name as repair_shop_name,
            rq.quote_amount, rq.parts_cost, rq.labor_cost, rq.hours_cost, rq.parts_list, rq.quote_detail, rq.estimated_days, rq.approved_at
     FROM repair_orders ro
     JOIN vehicles v ON ro.vehicle_id = v.id
     JOIN users u ON ro.driver_id = u.id
     LEFT JOIN departments d ON u.department_id = d.id
     LEFT JOIN repair_shops rs ON ro.repair_shop_id = rs.id
     LEFT JOIN repair_quotes rq ON rq.order_id = ro.id
     WHERE ro.id = ?`, [req.params.orderId]
  );
  if (!order) return res.json({ code: 404, msg: '工单不存在' });

  const progress = await query(
    `SELECT rp.*, us.name as user_name, us.role as user_role
     FROM repair_progress rp
     JOIN users us ON rp.user_id = us.id
     WHERE rp.order_id = ?
     ORDER BY rp.created_at ASC`,
    [req.params.orderId]
  );

  res.json({ code: 200, data: { order, progress } });
});

module.exports = router;
