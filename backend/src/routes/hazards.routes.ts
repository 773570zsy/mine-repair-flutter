import { Router, Request, Response } from 'express';
import { auth, requireRole } from '../middleware/auth';
import { validate } from '../middleware/validate';
import { hazardReportSchema, hazardAssignSchema, hazardRectifySchema, hazardRejectSchema, hazardVerifySchema } from '../schemas/hazards.schemas';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';
import dayjs from 'dayjs';

// inline sanitize to avoid import issues
function sanitize(input: string | null | undefined): string { if (input == null) return ''; return String(input).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#x27;'); }

const router = Router();

// 上报隐患（安全员/任何人）
router.post('/report', auth, validate(hazardReportSchema), asyncHandler(async (req: Request, res: Response) => {
  const { location, description, severity, responsible_id, deadline, photos_before } = req.body;
  // 规范化 severity，防止编码问题导致 CHECK 约束失败
  const VALID_SEVERITIES = ['低', '一般', '高', '紧急'];
  const safeSeverity = VALID_SEVERITIES.includes(severity) ? severity : '一般';
  const no = 'YH' + dayjs().format('YYYYMMDD') + String(Date.now()).slice(-4);
  // 指定了整改人 → 直接 assigned；否则 reported 等指派
  const status = responsible_id ? 'assigned' : 'reported';
  getDB().prepare(
    'INSERT INTO hazards (hazard_no, reporter_id, location, description, severity, responsible_id, deadline, photos_before, status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)'
  ).run(no, req.user.id, sanitize(location), sanitize(description), safeSeverity, responsible_id || null, deadline || '', JSON.stringify(photos_before || []), status);

  // 通知整改人
  if (responsible_id) {
    getDB().prepare('INSERT INTO notifications (user_id, type, title, content) VALUES (?, ?, ?, ?)').run(
      responsible_id, 'hazard_assigned', '隐患整改通知', `你被指定整改隐患${no}，期限${deadline || '待定'}，请查看详情并完成整改`);
  }
  res.json({ code: 200, msg: '上报成功', data: { hazard_no: no } });
}));

// 隐患列表
router.get('/list', auth, asyncHandler(async (req: Request, res: Response) => {
  const { status, my } = req.query;
  let sql = `SELECT h.*, u1.name as reporter_name, u2.name as responsible_name
    FROM hazards h JOIN users u1 ON h.reporter_id = u1.id LEFT JOIN users u2 ON h.responsible_id = u2.id WHERE 1=1`;
  const params: (string | number)[] = [];
  if (status) { sql += ' AND h.status = ?'; params.push(String(status)); }
  if (my === '1') { sql += ' AND h.responsible_id = ?'; params.push(req.user.id); }
  sql += ' ORDER BY h.created_at DESC';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 隐患详情
router.get('/detail/:id', auth, asyncHandler(async (req: Request, res: Response) => {
  const h = getDB().prepare(
    `SELECT h.*, u1.name as reporter_name, u2.name as responsible_name, u3.name as verifier_name
     FROM hazards h JOIN users u1 ON h.reporter_id = u1.id
     LEFT JOIN users u2 ON h.responsible_id = u2.id LEFT JOIN users u3 ON h.verified_by = u3.id WHERE h.id = ?`
  ).get(req.params.id);
  if (!h) { res.json({ code: 404, msg: '不存在' }); return; }
  res.json({ code: 200, data: h });
}));

// 安全员指定整改人
router.post('/assign/:id', auth, validate(hazardAssignSchema), asyncHandler(async (req: Request, res: Response) => {
  const { responsible_id, deadline } = req.body;
  getDB().prepare('UPDATE hazards SET responsible_id = ?, deadline = ?, status = ? WHERE id = ?').run(
    responsible_id, deadline || '', 'assigned', req.params.id);
  const h = getDB().prepare('SELECT hazard_no FROM hazards WHERE id = ?').get(req.params.id) as { hazard_no: string } | undefined;
  if (h) {
    getDB().prepare('INSERT INTO notifications (user_id, type, title, content) VALUES (?, ?, ?, ?)').run(
      responsible_id, 'hazard_assigned', '隐患整改通知', `你被指定整改隐患${h.hazard_no}`);
  }
  res.json({ code: 200, msg: '已指派' });
}));

// 整改人提交整改（照片+文字说明）
router.post('/rectify/:id', auth, validate(hazardRectifySchema), asyncHandler(async (req: Request, res: Response) => {
  const { photos_after, rectify_desc } = req.body;
  getDB().prepare("UPDATE hazards SET status = 'completed', photos_after = ?, rectify_desc = ?, reject_reason = NULL, updated_at = datetime('now') WHERE id = ?").run(
    JSON.stringify(photos_after || []), sanitize(rectify_desc), req.params.id);
  // 通知上报人/安全员确认
  const h = getDB().prepare('SELECT hazard_no, reporter_id FROM hazards WHERE id = ?').get(req.params.id) as { hazard_no: string; reporter_id: number } | undefined;
  if (h) {
    getDB().prepare('INSERT INTO notifications (user_id, type, title, content) VALUES (?, ?, ?, ?)').run(
      h.reporter_id, 'hazard_completed', '隐患整改完成待验收', `隐患${h.hazard_no}整改已完成，请验收确认`);
    // 也通知所有安全员
    const safeties = getDB().prepare("SELECT id FROM users WHERE role = 'safety_officer' AND id != ? AND (status = 1 OR status = '' OR status IS NULL)").all(h.reporter_id) as { id: number }[];
    for (const s of safeties) {
      getDB().prepare('INSERT INTO notifications (user_id, type, title, content) VALUES (?, ?, ?, ?)').run(
        s.id, 'hazard_completed', '隐患整改完成待验收', `隐患${h.hazard_no}整改已完成，请验收`);
    }
  }
  res.json({ code: 200, msg: '整改已提交，等待验收' });
}));

// 安全员确认验收
router.post('/verify/:id', auth, validate(hazardVerifySchema), asyncHandler(async (req: Request, res: Response) => {
  getDB().prepare("UPDATE hazards SET status = 'verified', verified_by = ?, verified_at = datetime('now') WHERE id = ?").run(
    req.user.id, req.params.id);
  // 通知整改人
  const h = getDB().prepare('SELECT hazard_no, responsible_id FROM hazards WHERE id = ?').get(req.params.id) as { hazard_no: string; responsible_id: number } | undefined;
  if (h && h.responsible_id) {
    getDB().prepare('INSERT INTO notifications (user_id, type, title, content) VALUES (?, ?, ?, ?)').run(
      h.responsible_id, 'hazard_verified', '整改验收通过', `隐患${h.hazard_no}整改已验收通过`);
  }
  res.json({ code: 200, msg: '已验收通过' });
}));

// 安全员驳回整改
router.post('/reject-rectify/:id', auth, validate(hazardRejectSchema), asyncHandler(async (req: Request, res: Response) => {
  const { reject_reason } = req.body;
  getDB().prepare("UPDATE hazards SET status = 'rectifying', reject_reason = ?, updated_at = datetime('now') WHERE id = ?").run(
    sanitize(reject_reason), req.params.id);
  // 通知整改人
  const h = getDB().prepare('SELECT hazard_no, responsible_id FROM hazards WHERE id = ?').get(req.params.id) as { hazard_no: string; responsible_id: number } | undefined;
  if (h && h.responsible_id) {
    getDB().prepare('INSERT INTO notifications (user_id, type, title, content) VALUES (?, ?, ?, ?)').run(
      h.responsible_id, 'hazard_rejected', '整改被驳回', `隐患${h.hazard_no}整改被驳回：${reject_reason}`);
  }
  res.json({ code: 200, msg: '已驳回' });
}));

// 导出
router.get('/export', auth, requireRole('admin', 'leader'), asyncHandler(async (req: Request, res: Response) => {
  const { date_from, date_to } = req.query;
  let sql = `SELECT h.*, u1.name as reporter_name, u2.name as responsible_name
    FROM hazards h JOIN users u1 ON h.reporter_id = u1.id LEFT JOIN users u2 ON h.responsible_id = u2.id WHERE 1=1`;
  const params: string[] = [];
  if (date_from) { sql += ' AND h.created_at >= ?'; params.push(String(date_from)); }
  if (date_to) { sql += ' AND h.created_at <= ?'; params.push(String(date_to) + ' 23:59:59'); }
  sql += ' ORDER BY h.created_at DESC';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 到期提醒（返回即将到期和已过期的隐患）
router.get('/alerts', auth, asyncHandler(async (_req: Request, res: Response) => {
  const today = dayjs().format('YYYY-MM-DD');
  const urgent = getDB().prepare(
    `SELECT h.*, u1.name as reporter_name, u2.name as responsible_name
     FROM hazards h JOIN users u1 ON h.reporter_id = u1.id LEFT JOIN users u2 ON h.responsible_id = u2.id
     WHERE h.status IN ('assigned', 'rectifying') AND h.deadline != '' AND h.deadline <= date(?, '+2 days')
     ORDER BY h.deadline ASC`
  ).all(today) as Array<Record<string, unknown>>;
  const overdue = urgent.filter(h => String(h.deadline) <= today);
  res.json({ code: 200, data: { urgent, overdue, count: urgent.length, overdueCount: overdue.length } });
}));

export default router;
