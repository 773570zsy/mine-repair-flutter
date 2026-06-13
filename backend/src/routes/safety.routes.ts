import { Router, Request, Response } from 'express';
import { auth, requireRole } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';
import dayjs from 'dayjs';
import { validate } from '../middleware/validate';
import { assessmentSchema } from '../schemas/safety.schemas';

function sanitize(input: string | null | undefined): string { if (input == null) return ''; return String(input).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#x27;'); }

const router = Router();

// ==================== 考核通报 ====================

// 下发考核通报（安全员/管理员）
router.post('/assessment', auth, requireRole('safety_officer', 'admin'), validate(assessmentSchema), asyncHandler(async (req: Request, res: Response) => {
  try {
    const { target_id, title, content, assess_type, photos, assess_date } = req.body;

    // 验证目标用户存在
    const target = getDB().prepare('SELECT id, name FROM users WHERE id = ? AND (status = 1 OR status = 0 OR status IS NULL OR status = \'\')').get(target_id) as any;
    if (!target) { res.json({ code: 400, msg: '被考核人不存在或已禁用' }); return; }

    const dateStr = assess_date || dayjs().format('YYYYMMDD');
    const no = 'KP' + dateStr + String(Date.now()).slice(-4);
    getDB().prepare(
      'INSERT INTO assessments (assess_no, issuer_id, target_id, title, content, assess_type, photos, assess_date) VALUES (?, ?, ?, ?, ?, ?, ?, ?)'
    ).run(no, req.user.id, target_id, sanitize(title), sanitize(content || ''), assess_type || '通报', JSON.stringify(photos || []), dateStr);
    // 通知被考核人
    getDB().prepare('INSERT INTO notifications (user_id, type, title, content) VALUES (?, ?, ?, ?)').run(
      target_id, 'assessment_new', '考核通报：' + sanitize(title), `你收到一条${assess_type || '通报'}：${sanitize(title)}。编号${no}`);
    // 通知所有管理员
    const admins = getDB().prepare("SELECT id FROM users WHERE role IN ('admin','leader','safety_officer') AND id != ? AND (status = 1 OR status = 0 OR status IS NULL OR status = '')").all(req.user.id) as { id: number }[];
    for (const a of admins) {
      getDB().prepare('INSERT INTO notifications (user_id, type, title, content) VALUES (?, ?, ?, ?)').run(
        a.id, 'assessment_new', '考核通报：' + sanitize(title), `${req.user.name || '安全员'}对${sanitize(title)}下发了${assess_type || '通报'}。编号${no}`);
    }
    res.json({ code: 200, msg: '通报已下发', data: { assess_no: no } });
  } catch (err: any) {
    console.error('[Safety] Assessment error:', err?.message || err);
    res.status(500).json({ code: 500, msg: '服务器内部错误: ' + (err?.message || '未知错误') });
  }
}));

// 考核列表
router.get('/assessments', auth, asyncHandler(async (req: Request, res: Response) => {
  let sql = `SELECT a.*, u1.name as issuer_name, u2.name as target_name
    FROM assessments a JOIN users u1 ON a.issuer_id = u1.id JOIN users u2 ON a.target_id = u2.id WHERE 1=1`;
  const params: (string | number)[] = [];
  if (req.query.my === '1') { sql += ' AND a.target_id = ?'; params.push(req.user.id); }
  sql += ' ORDER BY a.created_at DESC LIMIT 100';
  res.json({ code: 200, data: getDB().prepare(sql).all(...params) });
}));

// 考核详情
router.get('/assessment/:id', auth, asyncHandler(async (req: Request, res: Response) => {
  const a = getDB().prepare(
    `SELECT a.*, u1.name as issuer_name, u2.name as target_name
     FROM assessments a JOIN users u1 ON a.issuer_id = u1.id JOIN users u2 ON a.target_id = u2.id WHERE a.id = ?`
  ).get(req.params.id);
  if (!a) { res.json({ code: 404, msg: '不存在' }); return; }
  res.json({ code: 200, data: a });
}));

export default router;
