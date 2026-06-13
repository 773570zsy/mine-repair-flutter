const express = require('express');
const router = express.Router();
const { auth, requireRole } = require('../middleware/auth');
const { query, queryOne } = require('../utils/db');
const dayjs = require('dayjs');

// 上报隐患（安全员/任何人）
router.post('/report', auth, async (req, res) => {
  const { location, description, severity, responsible_id, deadline, photos_before } = req.body;
  if (!description) return res.json({ code: 400, msg: '请填写隐患描述' });
  const no = 'YH' + dayjs().format('YYYYMMDD') + String(Date.now()).slice(-4);
  await query(
    'INSERT INTO hazards (hazard_no,reporter_id,location,description,severity,responsible_id,deadline,photos_before,status) VALUES (?,?,?,?,?,?,?,?,"reported")',
    [no, req.user.id, location||'', description, severity||'一般', responsible_id||null, deadline||'', JSON.stringify(photos_before||[])]);
  // 通知整改人
  if (responsible_id) {
    await query('INSERT INTO notifications (user_id,type,title,content) VALUES (?,?,?,?)',
      [responsible_id, 'hazard_assigned', '隐患整改通知', `你被指定整改隐患${no}，期限${deadline||'待定'}`]);
  }
  res.json({ code: 200, msg: '上报成功', data: { hazard_no: no } });
});

// 隐患列表
router.get('/list', auth, async (req, res) => {
  const { status, my } = req.query;
  let sql = `SELECT h.*, u1.name as reporter_name, u2.name as responsible_name
    FROM hazards h JOIN users u1 ON h.reporter_id=u1.id LEFT JOIN users u2 ON h.responsible_id=u2.id WHERE 1=1`;
  const params = [];
  if (status) { sql += ' AND h.status=?'; params.push(status); }
  if (my === '1') { sql += ' AND h.responsible_id=?'; params.push(req.user.id); }
  sql += ' ORDER BY h.created_at DESC';
  res.json({ code: 200, data: await query(sql, params) });
});

// 隐患详情
router.get('/detail/:id', auth, async (req, res) => {
  const h = await queryOne(
    `SELECT h.*, u1.name as reporter_name, u2.name as responsible_name, u3.name as verifier_name
     FROM hazards h JOIN users u1 ON h.reporter_id=u1.id
     LEFT JOIN users u2 ON h.responsible_id=u2.id LEFT JOIN users u3 ON h.verified_by=u3.id WHERE h.id=?`, [req.params.id]);
  if (!h) return res.json({ code: 404, msg: '不存在' });
  res.json({ code: 200, data: h });
});

// 安全员指定整改人
router.post('/assign/:id', auth, async (req, res) => {
  const { responsible_id, deadline } = req.body;
  if (!responsible_id) return res.json({ code: 400, msg: '请选择整改人' });
  await query('UPDATE hazards SET responsible_id=?, deadline=?, status=? WHERE id=?',
    [responsible_id, deadline||'', 'assigned', req.params.id]);
  const h = await queryOne('SELECT hazard_no FROM hazards WHERE id=?', [req.params.id]);
  await query('INSERT INTO notifications (user_id,type,title,content) VALUES (?,?,?,?)',
    [responsible_id, 'hazard_assigned', '隐患整改通知', `你被指定整改隐患${h.hazard_no}`]);
  res.json({ code: 200, msg: '已指派' });
});

// 整改人上传完成照片
router.post('/rectify/:id', auth, async (req, res) => {
  const { photos_after } = req.body;
  await query("UPDATE hazards SET status=?, photos_after=?, updated_at=datetime('now') WHERE id=?",
    ['completed', JSON.stringify(photos_after||[]), req.params.id]);
  // 通知上报人确认
  const h = await queryOne('SELECT hazard_no, reporter_id FROM hazards WHERE id=?', [req.params.id]);
  if (h) {
    await query('INSERT INTO notifications (user_id,type,title,content) VALUES (?,?,?,?)',
      [h.reporter_id, 'hazard_completed', '隐患整改完成', `隐患${h.hazard_no}已整改，请确认`]);
  }
  res.json({ code: 200, msg: '整改完成，等待确认' });
});

// 安全员确认闭环
router.post('/verify/:id', auth, async (req, res) => {
  await query("UPDATE hazards SET status=?, verified_by=?, verified_at=datetime('now') WHERE id=?",
    ['verified', req.user.id, req.params.id]);
  res.json({ code: 200, msg: '已确认闭环' });
});

// 导出
router.get('/export', auth, requireRole('admin', 'leader'), async (req, res) => {
  const { date_from, date_to } = req.query;
  let sql = `SELECT h.*, u1.name as reporter_name, u2.name as responsible_name
    FROM hazards h JOIN users u1 ON h.reporter_id=u1.id LEFT JOIN users u2 ON h.responsible_id=u2.id WHERE 1=1`;
  const params = [];
  if (date_from) { sql += ' AND h.created_at>=?'; params.push(date_from); }
  if (date_to) { sql += ' AND h.created_at<=?'; params.push(date_to+' 23:59:59'); }
  sql += ' ORDER BY h.created_at DESC';
  res.json({ code: 200, data: await query(sql, params) });
});

// 到期提醒（返回即将到期和已过期的隐患）
router.get('/alerts', auth, async (req, res) => {
  const today = dayjs().format('YYYY-MM-DD');
  const urgent = await query(
    `SELECT h.*, u1.name as reporter_name, u2.name as responsible_name
     FROM hazards h JOIN users u1 ON h.reporter_id=u1.id LEFT JOIN users u2 ON h.responsible_id=u2.id
     WHERE h.status IN ('assigned','rectifying') AND h.deadline!='' AND h.deadline <= date(?, '+2 days')
     ORDER BY h.deadline ASC`, [today]);
  const overdue = urgent.filter(h => h.deadline <= today);
  res.json({ code: 200, data: { urgent, overdue, count: urgent.length, overdueCount: overdue.length } });
});

module.exports = router;
