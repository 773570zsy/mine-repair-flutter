import { Router, Request, Response } from 'express';
import { auth } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { getDB } from '../db';
import dayjs from 'dayjs';

const router = Router();

// 一次性迁移：quiz_likes 从 (result_id, user_id) 改为 (target_user_id, liker_user_id, month)
let _quizLikesMigrated = false;
function migrateQuizLikes(): void {
  if (_quizLikesMigrated) return;
  const db = getDB();
  try {
    const info = db.prepare('PRAGMA table_info(quiz_likes)').all() as Array<{ name: string }>;
    const cols = info.map(r => r.name);
    if (cols.includes('result_id')) {
      // 旧结构 → 重建
      db.exec(`
        CREATE TABLE IF NOT EXISTS quiz_likes_v2 (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          target_user_id INTEGER NOT NULL,
          liker_user_id INTEGER NOT NULL,
          month TEXT NOT NULL,
          created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
          UNIQUE(target_user_id, liker_user_id, month)
        );
        INSERT OR IGNORE INTO quiz_likes_v2 (id, target_user_id, liker_user_id, month, created_at)
          SELECT ql.id, qr.user_id, ql.user_id, strftime('%Y-%m', qr.quiz_date), ql.created_at
          FROM quiz_likes ql JOIN quiz_results qr ON ql.result_id = qr.id;
        DROP TABLE quiz_likes;
        ALTER TABLE quiz_likes_v2 RENAME TO quiz_likes;
      `);
      console.log('[quiz] quiz_likes migrated to (target_user_id, liker_user_id, month)');
    }
  } catch (_) { /* 表不存在或已迁移 */ }
  _quizLikesMigrated = true;
}

// 获取今日题目
router.get('/today', auth, asyncHandler(async (req: Request, res: Response) => {
  const today = dayjs().format('YYYY-MM-DD');
  const existing = getDB().prepare('SELECT * FROM quiz_results WHERE user_id = ? AND quiz_date = ?').get(req.user.id, today);

  if (existing) {
    res.json({ code: 200, data: { done: true, result: existing } });
    return;
  }

  const questions = getDB().prepare('SELECT * FROM quiz_questions ORDER BY RANDOM() LIMIT 5').all();
  res.json({ code: 200, data: { done: false, questions } });
}));

// 提交答案
router.post('/submit', auth, asyncHandler(async (req: Request, res: Response) => {
  const { answers } = req.body;
  const today = dayjs().format('YYYY-MM-DD');

  const existing = getDB().prepare('SELECT * FROM quiz_results WHERE user_id = ? AND quiz_date = ?').get(req.user.id, today);
  if (existing) { res.json({ code: 400, msg: '今日已完成测试' }); return; }

  let score = 0;
  const fullAnswers: Record<string, unknown>[] = [];

  for (const a of (answers || [])) {
    const q = getDB().prepare('SELECT * FROM quiz_questions WHERE id = ?').get(a.question_id) as any;
    if (q) {
      const correct = (a.user_answer || '').trim().toUpperCase() === q.answer.trim().toUpperCase();
      if (correct) score++;
      fullAnswers.push({ question_id: q.id, question: q.question, user_answer: a.user_answer, correct_answer: q.answer, correct, explanation: q.explanation });
    }
  }

  getDB().prepare('INSERT INTO quiz_results (user_id, quiz_date, score, total, answers) VALUES (?, ?, ?, ?, ?)').run(
    req.user.id, today, score, answers.length, JSON.stringify(fullAnswers)
  );
  res.json({ code: 200, msg: `得分：${score}/${answers.length}`, data: { score, total: answers.length, answers: fullAnswers } });
}));

// 排行榜（含点赞数 + 当前用户是否已点赞）
router.get('/leaderboard', auth, asyncHandler(async (req: Request, res: Response) => {
  migrateQuizLikes();
  const month = dayjs().format('YYYY-MM');
  const db = getDB();

  // 先确保 quiz_likes 是 v2 结构
  let likesJoin: string;
  try {
    db.prepare('SELECT target_user_id FROM quiz_likes LIMIT 1').all();
    likesJoin = `LEFT JOIN (SELECT target_user_id, COUNT(*) as likes FROM quiz_likes WHERE month = '${month}' GROUP BY target_user_id) ql ON ql.target_user_id = u.id`;
  } catch {
    likesJoin = `LEFT JOIN (SELECT result_id, COUNT(*) as likes FROM quiz_likes GROUP BY result_id) ql2 ON 1=0`; // fallback
  }

  const rows = db.prepare(
    `SELECT u.id as user_id, u.name, SUM(qr.score) as total_score, COUNT(qr.id) as days,
            COALESCE(ql.likes, 0) as likes
     FROM quiz_results qr JOIN users u ON qr.user_id = u.id
     ${likesJoin}
     WHERE strftime('%Y-%m', qr.quiz_date) = ?
     GROUP BY qr.user_id ORDER BY total_score DESC, days DESC`
  ).all(month) as Array<Record<string, unknown>>;

  // 查当前用户给谁点过赞
  const myLikes = new Set<number>();
  try {
    const liked = db.prepare('SELECT target_user_id FROM quiz_likes WHERE liker_user_id = ? AND month = ?').all(req.user.id, month) as Array<{ target_user_id: number }>;
    liked.forEach(l => myLikes.add(l.target_user_id));
  } catch { /* ignore */ }

  const leaderboard = rows.map(r => ({
    ...r,
    liked_by_me: myLikes.has(r.user_id as number)
  }));

  res.json({ code: 200, data: { leaderboard } });
}));

// 点赞/取消点赞
router.post('/like', auth, asyncHandler(async (req: Request, res: Response) => {
  migrateQuizLikes();
  const { target_user_id, month } = req.body;
  if (!target_user_id || !month) { res.json({ code: 400, msg: '缺少参数' }); return; }
  if (Number(target_user_id) === req.user.id) { res.json({ code: 400, msg: '不能给自己点赞' }); return; }

  const db = getDB();
  const existing = db.prepare(
    'SELECT id FROM quiz_likes WHERE target_user_id = ? AND liker_user_id = ? AND month = ?'
  ).get(target_user_id, req.user.id, month);

  if (existing) {
    // 取消点赞
    db.prepare('DELETE FROM quiz_likes WHERE id = ?').run((existing as { id: number }).id);
    res.json({ code: 200, msg: '已取消点赞', data: { liked: false } });
  } else {
    db.prepare('INSERT INTO quiz_likes (target_user_id, liker_user_id, month) VALUES (?, ?, ?)').run(target_user_id, req.user.id, month);
    res.json({ code: 200, msg: '点赞成功', data: { liked: true } });
  }
}));

export default router;
