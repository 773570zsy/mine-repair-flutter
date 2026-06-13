const express = require('express');
const router = express.Router();
const { auth, requireRole } = require('../middleware/auth');
const { query, queryOne } = require('../utils/db');
const dayjs = require('dayjs');

// 上报安全事件（任何人可用）
router.post('/report', auth, async (req, res) => {
  const { location, incident_time, description, severity } = req.body;
  if (!description) return res.json({ code: 400, msg: '请填写事件描述' });
  const no = 'SG' + dayjs().format('YYYYMMDD') + String(Date.now()).slice(-4);
  await query('INSERT INTO safety_incidents (incident_no,reporter_id,location,incident_time,description,severity) VALUES (?,?,?,?,?,?)',
    [no, req.user.id, location||'', incident_time||'', description, severity||'一般']);
  res.json({ code: 200, msg: '上报成功', data: { incident_no: no } });
});

// 事件列表
router.get('/list', auth, async (req, res) => {
  const { status } = req.query;
  let sql = `SELECT si.*, u.name as reporter_name FROM safety_incidents si JOIN users u ON si.reporter_id=u.id WHERE 1=1`;
  const params = [];
  if (status) { sql += ' AND si.status=?'; params.push(status); }
  sql += ' ORDER BY si.created_at DESC';
  res.json({ code: 200, data: await query(sql, params) });
});

// 事件详情
router.get('/detail/:id', auth, async (req, res) => {
  const inc = await queryOne(
    `SELECT si.*, u.name as reporter_name FROM safety_incidents si JOIN users u ON si.reporter_id=u.id WHERE si.id=?`, [req.params.id]
  );
  if (!inc) return res.json({ code: 404, msg: '不存在' });
  const investigation = await queryOne(
    `SELECT ii.*, u.name as investigator_name FROM incident_investigations ii LEFT JOIN users u ON ii.investigator_id=u.id WHERE ii.incident_id=?`, [inc.id]
  );
  const actions = await query(
    `SELECT ia.*, u.name as responsible_name FROM incident_actions ia LEFT JOIN users u ON ia.responsible_id=u.id WHERE ia.incident_id=? ORDER BY ia.created_at`, [inc.id]
  );
  res.json({ code: 200, data: { incident: inc, investigation, actions } });
});

// 指派调查（管理员/领导）
router.post('/assign/:id', auth, requireRole('admin', 'leader'), async (req, res) => {
  const { investigator_id } = req.body;
  await query('UPDATE safety_incidents SET status=? WHERE id=?', ['investigating', req.params.id]);
  await query('INSERT INTO incident_investigations (incident_id,investigator_id) VALUES (?,?)', [req.params.id, investigator_id]);
  res.json({ code: 200, msg: '已指派调查' });
});

// 提交调查报告
router.post('/investigate/:id', auth, async (req, res) => {
  const { root_cause, findings } = req.body;
  if (!root_cause) return res.json({ code: 400, msg: '请填写根本原因' });
  await query('UPDATE incident_investigations SET root_cause=?, findings=? WHERE incident_id=?',
    [root_cause, findings||'', req.params.id]);
  await query('UPDATE safety_incidents SET status=? WHERE id=?', ['rectifying', req.params.id]);
  res.json({ code: 200, msg: '调查报告已提交' });
});

// 添加整改措施
router.post('/action/:id', auth, requireRole('admin', 'leader'), async (req, res) => {
  const { action_desc, responsible_id, due_date } = req.body;
  if (!action_desc) return res.json({ code: 400, msg: '请填写整改内容' });
  await query('INSERT INTO incident_actions (incident_id,action_desc,responsible_id,due_date) VALUES (?,?,?,?)',
    [req.params.id, action_desc, responsible_id||null, due_date||'']);
  res.json({ code: 200, msg: '整改措施已添加' });
});

// 完成整改
router.post('/action-complete/:actionId', auth, async (req, res) => {
  await query('UPDATE incident_actions SET status=?, completed_at=datetime(\"now\") WHERE id=?', ['completed', req.params.actionId]);
  // 检查所有整改是否完成
  const act = await queryOne('SELECT incident_id FROM incident_actions WHERE id=?', [req.params.actionId]);
  if (act) {
    const pending = await queryOne('SELECT COUNT(*) as c FROM incident_actions WHERE incident_id=? AND status=?', [act.incident_id, 'pending']);
    if (pending.c === 0) {
      await query('UPDATE safety_incidents SET status=? WHERE id=?', ['closed', act.incident_id]);
    }
  }
  res.json({ code: 200, msg: '整改完成' });
});

// 导出
router.get('/export', auth, requireRole('admin', 'leader'), async (req, res) => {
  const { date_from, date_to } = req.query;
  let sql = `SELECT si.*, u.name as reporter_name FROM safety_incidents si JOIN users u ON si.reporter_id=u.id WHERE 1=1`;
  const params = [];
  if (date_from) { sql += ' AND si.created_at>=?'; params.push(date_from); }
  if (date_to) { sql += ' AND si.created_at<=?'; params.push(date_to+' 23:59:59'); }
  sql += ' ORDER BY si.created_at DESC';
  res.json({ code: 200, data: await query(sql, params) });
});

module.exports = router;
