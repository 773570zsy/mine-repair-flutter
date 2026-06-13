const express = require('express');
const router = express.Router();
const { auth } = require('../middleware/auth');
const { query, queryOne } = require('../utils/db');

// 获取我的通知
router.get('/', auth, async (req, res) => {
  const { page = 1, pageSize = 20 } = req.query;
  const list = await query(
    `SELECT * FROM notifications WHERE user_id = ? ORDER BY created_at DESC LIMIT ? OFFSET ?`,
    [req.user.id, Number(pageSize), (Number(page) - 1) * Number(pageSize)]
  );
  const unreadCount = await queryOne(
    'SELECT COUNT(*) as count FROM notifications WHERE user_id = ? AND is_read = 0',
    [req.user.id]
  );
  res.json({ code: 200, data: { list, unreadCount: unreadCount.count } });
});

// 标记已读
router.put('/:id/read', auth, async (req, res) => {
  await query('UPDATE notifications SET is_read = 1 WHERE id = ? AND user_id = ?', [req.params.id, req.user.id]);
  res.json({ code: 200, msg: 'ok' });
});

// 全部已读
router.put('/read-all', auth, async (req, res) => {
  await query('UPDATE notifications SET is_read = 1 WHERE user_id = ? AND is_read = 0', [req.user.id]);
  res.json({ code: 200, msg: 'ok' });
});

module.exports = router;
