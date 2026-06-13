import { Router, Request, Response } from 'express';
import { auth } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';

const router = Router();

// 获取通知列表
router.get('/', auth, asyncHandler(async (req: Request, res: Response) => {
  const notifications = getDB().prepare(
    'SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT 50'
  ).all(req.user.id);
  const unread = getDB().prepare(
    'SELECT COUNT(*) as c FROM notifications WHERE user_id = ? AND is_read = 0'
  ).get(req.user.id) as { c: number };
  res.json({ code: 200, data: { list: notifications, unread: unread?.c || 0 } });
}));

// 标记已读
router.put('/:id/read', auth, asyncHandler(async (req: Request, res: Response) => {
  getDB().prepare('UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?').run(req.params.id, req.user.id);
  res.json({ code: 200, msg: '已读' });
}));

// 全部已读
router.put('/read-all', auth, asyncHandler(async (req: Request, res: Response) => {
  getDB().prepare('UPDATE notifications SET is_read = 1 WHERE user_id = ?').run(req.user.id);
  res.json({ code: 200, msg: '全部已读' });
}));

export default router;
