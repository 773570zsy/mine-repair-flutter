const express = require('express');
const router = express.Router();
const { auth, requireRole } = require('../middleware/auth');
const { query, queryOne } = require('../utils/db');
const dayjs = require('dayjs');

// 流程: 外部门报修 → 修理厂接单报价 → 外部审批员审批 → 维修 → 完工 → 验收

router.get('/departments', auth, async (_, res) => {
  res.json({ code: 200, data: await query('SELECT * FROM departments WHERE status=1 ORDER BY name') });
});
router.get('/repair-shops', auth, async (_, res) => {
  res.json({ code: 200, data: await query('SELECT * FROM repair_shops WHERE status=1') });
});

// 外部门发起报修
router.post('/report', auth, requireRole('external'), async (req, res) => {
  const { repair_shop_id, vehicle_name, fault_description } = req.body;
  if (!req.user.department_id) return res.json({ code: 400, msg: '未绑定部门' });
  if (!repair_shop_id || !fault_description) return res.json({ code: 400, msg: '请选择修理厂并填写故障描述' });
  const orderNo = 'EW' + dayjs().format('YYYYMMDD') + String(Date.now()).slice(-4);
  await query(`INSERT INTO external_repair_orders (order_no,department_id,user_id,repair_shop_id,vehicle_name,fault_description,status) VALUES (?,?,?,?,?,?,'pending_accept')`,
    [orderNo, req.user.department_id, req.user.id, repair_shop_id, vehicle_name||'', fault_description]);
  res.json({ code: 200, msg: '报修已提交', data: { order_no: orderNo } });
});

// 外部门-我的报修
router.get('/my-orders', auth, requireRole('external'), async (req, res) => {
  const { status } = req.query;
  let sql = `SELECT eo.*, d.name as dept_name, rs.name as shop_name FROM external_repair_orders eo
    JOIN departments d ON eo.department_id=d.id LEFT JOIN repair_shops rs ON eo.repair_shop_id=rs.id WHERE eo.department_id=?`;
  const params = [req.user.department_id];
  if (status) { sql += ' AND eo.status=?'; params.push(status); }
  sql += ' ORDER BY eo.created_at DESC';
  res.json({ code: 200, data: await query(sql, params) });
});

// 工单详情
router.get('/detail/:id', auth, async (req, res) => {
  const order = await queryOne(`SELECT eo.*, d.name as dept_name, rs.name as shop_name, u.name as reporter
    FROM external_repair_orders eo JOIN departments d ON eo.department_id=d.id
    LEFT JOIN repair_shops rs ON eo.repair_shop_id=rs.id JOIN users u ON eo.user_id=u.id WHERE eo.id=?`, [req.params.id]);
  if (!order) return res.json({ code: 404, msg: '工单不存在' });
  const progress = await query(`SELECT erp.*, u.name as uname FROM external_repair_progress erp
    JOIN users u ON erp.user_id=u.id WHERE erp.order_id=? ORDER BY erp.created_at ASC`, [req.params.id]);
  res.json({ code: 200, data: { order, progress } });
});

// ==================== 修理厂 ====================
router.get('/shop-pending', auth, requireRole('repair_shop'), async (_, res) => {
  res.json({ code: 200, data: await query(`SELECT eo.*, d.name as dept_name FROM external_repair_orders eo
    JOIN departments d ON eo.department_id=d.id WHERE eo.status='pending_accept' ORDER BY eo.created_at DESC`) });
});

router.get('/shop-orders', auth, requireRole('repair_shop'), async (req, res) => {
  res.json({ code: 200, data: await query(`SELECT eo.*, d.name as dept_name FROM external_repair_orders eo
    JOIN departments d ON eo.department_id=d.id WHERE eo.repair_shop_id=? ORDER BY eo.created_at DESC`, [req.user.repair_shop_id]) });
});

// 接单+报价
router.post('/shop-accept/:id', auth, requireRole('repair_shop'), async (req, res) => {
  const { quote_amount, parts_cost, labor_cost, hours_cost, parts_list, quote_detail, estimated_days } = req.body;
  if (!quote_amount) return res.json({ code: 400, msg: '请填写报价金额' });
  const order = await queryOne('SELECT * FROM external_repair_orders WHERE id=? AND status=?', [req.params.id, 'pending_accept']);
  if (!order) return res.json({ code: 400, msg: '工单状态异常' });
  await query(`UPDATE external_repair_orders SET repair_shop_id=?, quote_amount=?, parts_cost=?, labor_cost=?,
    hours_cost=?, parts_list=?, quote_detail=?, estimated_days=?, status='pending_approval', updated_at=datetime('now') WHERE id=?`,
    [req.user.repair_shop_id, quote_amount||0, parts_cost||0, labor_cost||0, hours_cost||0, JSON.stringify(parts_list||[]), quote_detail||'', estimated_days, order.id]);
  await query("INSERT INTO external_repair_progress (order_id, user_id, action, content) VALUES (?,?,?,?)",
    [order.id, req.user.id, 'accepted_and_quoted', `接单并报价 ¥${quote_amount}`]);
  // 通知外部审批员
  const approvers = await query("SELECT id FROM users WHERE role='external_approver' AND status=1");
  for (const ap of approvers) {
    await query('INSERT INTO notifications (user_id, type, title, content) VALUES (?,?,?,?)',
      [ap.id, 'ext_quote_pending', '外部报修待审批', `工单${order.order_no}已报价¥${quote_amount}`]);
  }
  res.json({ code: 200, msg: '已接单并报价' });
});

// 进度/完工/验收
router.post('/shop-progress/:id', auth, requireRole('repair_shop'), async (req, res) => {
  const { content } = req.body;
  await query("UPDATE external_repair_orders SET status='repairing' WHERE id=? AND status='approved'", [req.params.id]);
  await query("INSERT INTO external_repair_progress (order_id, user_id, action, content) VALUES (?,?,?,?)",
    [req.params.id, req.user.id, 'progress', content||'']);
  res.json({ code: 200, msg: '进度已更新' });
});

router.post('/shop-complete/:id', auth, requireRole('repair_shop'), async (req, res) => {
  await query("UPDATE external_repair_orders SET status='completed', updated_at=datetime('now') WHERE id=?", [req.params.id]);
  await query("INSERT INTO external_repair_progress (order_id, user_id, action, content) VALUES (?,?,?,?)",
    [req.params.id, req.user.id, 'completed', '维修完成，等待验收']);
  res.json({ code: 200, msg: '已完工' });
});

router.post('/accept/:id', auth, requireRole('external'), async (req, res) => {
  const order = await queryOne('SELECT * FROM external_repair_orders WHERE id=? AND department_id=?',
    [req.params.id, req.user.department_id]);
  if (!order || order.status !== 'completed') return res.json({ code: 400, msg: '状态异常' });
  await query("UPDATE external_repair_orders SET status='accepted', updated_at=datetime('now') WHERE id=?", [order.id]);
  await query("INSERT INTO external_repair_progress (order_id, user_id, action, content) VALUES (?,?,?,?)",
    [order.id, req.user.id, 'accepted', '部门验收通过']);
  res.json({ code: 200, msg: '验收成功' });
});

// ==================== 外部审批员审批 ====================

router.get('/pending-approval', auth, requireRole('external_approver'), async (_, res) => {
  const orders = await query(`SELECT eo.*, d.name as dept_name, rs.name as shop_name, u.name as reporter
    FROM external_repair_orders eo JOIN departments d ON eo.department_id=d.id
    LEFT JOIN repair_shops rs ON eo.repair_shop_id=rs.id JOIN users u ON eo.user_id=u.id
    WHERE eo.status='pending_approval' ORDER BY eo.created_at DESC`);
  res.json({ code: 200, data: orders });
});

// 外部审批员审批通过/驳回
router.post('/approve/:id', auth, requireRole('external_approver'), async (req, res) => {
  const { approved, reject_reason } = req.body;
  const order = await queryOne('SELECT * FROM external_repair_orders WHERE id=? AND status=?',
    [req.params.id, 'pending_approval']);
  if (!order) return res.json({ code: 400, msg: '工单状态异常' });
  if (approved) {
    await query("UPDATE external_repair_orders SET status='approved', approved_at=datetime('now') WHERE id=?", [order.id]);
    await query("INSERT INTO external_repair_progress (order_id, user_id, action, content) VALUES (?,?,?,?)",
      [order.id, req.user.id, 'approved', '外部审批通过']);
    // 通知修理厂
    const shopUsers = await query("SELECT id FROM users WHERE role='repair_shop' AND repair_shop_id=?", [order.repair_shop_id]);
    for (const u of shopUsers) {
      await query('INSERT INTO notifications (user_id, type, title, content) VALUES (?,?,?,?)',
        [u.id, 'ext_approved', '外部报修审批通过', `工单${order.order_no}已通过审批`]);
    }
  } else {
    if (!reject_reason) return res.json({ code: 400, msg: '请填写驳回原因' });
    await query('UPDATE external_repair_orders SET status=?, reject_reason=? WHERE id=?', ['rejected', reject_reason, order.id]);
    await query("INSERT INTO external_repair_progress (order_id, user_id, action, content) VALUES (?,?,?,?)",
      [order.id, req.user.id, 'rejected', `驳回：${reject_reason}`]);
  }
  res.json({ code: 200, msg: approved ? '已通过' : '已驳回' });
});

// 导出
router.get('/export-orders', auth, async (req, res) => {
  const { date_from, date_to } = req.query;
  let sql = `SELECT eo.*, d.name as dept_name, rs.name as shop_name FROM external_repair_orders eo
    JOIN departments d ON eo.department_id=d.id LEFT JOIN repair_shops rs ON eo.repair_shop_id=rs.id WHERE 1=1`;
  const params = [];
  if (req.user.role === 'external') { sql += ' AND eo.department_id=?'; params.push(req.user.department_id); }
  if (date_from) { sql += ' AND eo.created_at>=?'; params.push(date_from); }
  if (date_to) { sql += ' AND eo.created_at<=?'; params.push(date_to+' 23:59:59'); }
  sql += ' ORDER BY eo.created_at DESC';
  res.json({ code: 200, data: await query(sql, params) });
});

// 管理员-部门管理
router.post('/departments/add', auth, requireRole('admin'), async (req, res) => {
  const { name } = req.body;
  if (!name) return res.json({ code: 400, msg: '请填写部门名称' });
  const deptKey = 'JL' + Date.now().toString(36).toUpperCase().slice(-6);
  await query('INSERT INTO departments (name, dept_key) VALUES (?,?)', [name, deptKey]);
  res.json({ code: 200, msg: '添加成功', data: { dept_key: deptKey } });
});

router.post('/departments/create-account', auth, requireRole('admin'), async (req, res) => {
  const { department_id, phone, name } = req.body;
  if (!department_id || !phone) return res.json({ code: 400, msg: '请填写手机号' });
  const exist = await queryOne('SELECT id FROM users WHERE department_id=? AND role=?', [department_id, 'external']);
  if (exist) return res.json({ code: 400, msg: '该部门已有账号' });
  const dept = await queryOne('SELECT * FROM departments WHERE id=?', [department_id]);
  await query('INSERT INTO users (name, phone, role, department_id) VALUES (?,?,?,?)',
    [name||dept?.name||'', phone, 'external', department_id]);
  res.json({ code: 200, msg: '账号已创建，默认密码123456' });
});

module.exports = router;
