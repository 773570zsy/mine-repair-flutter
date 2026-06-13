const express = require('express');
const router = express.Router();
const { auth, requireRole } = require('../middleware/auth');
const { query, queryOne } = require('../utils/db');
const dayjs = require('dayjs');

// 获取今日题目（如已有作答则返回已答记录）
router.get('/today', auth, async (req, res) => {
  const today = dayjs().format('YYYY-MM-DD');
  const existing = await queryOne(
    'SELECT * FROM quiz_results WHERE user_id=? AND quiz_date=?', [req.user.id, today]
  );
  if (existing) {
    return res.json({ code: 200, data: { done: true, result: existing } });
  }
  // 随机选5题
  const questions = await query('SELECT * FROM quiz_questions ORDER BY RANDOM() LIMIT 5');
  res.json({ code: 200, data: { done: false, questions } });
});

// 提交答案
router.post('/submit', auth, async (req, res) => {
  const { answers } = req.body; // [{question_id, user_answer}]
  const today = dayjs().format('YYYY-MM-DD');
  const existing = await queryOne(
    'SELECT * FROM quiz_results WHERE user_id=? AND quiz_date=?', [req.user.id, today]
  );
  if (existing) return res.json({ code: 400, msg: '今日已完成测试' });

  let score = 0;
  const fullAnswers = [];
  for (const a of (answers || [])) {
    const q = await queryOne('SELECT * FROM quiz_questions WHERE id=?', [a.question_id]);
    if (q) {
      const correct = (a.user_answer || '').trim().toUpperCase() === q.answer.trim().toUpperCase();
      if (correct) score++;
      fullAnswers.push({ question_id: q.id, question: q.question, user_answer: a.user_answer, correct_answer: q.answer, correct, explanation: q.explanation });
    }
  }
  await query('INSERT INTO quiz_results (user_id, quiz_date, score, total, answers) VALUES (?,?,?,?,?)',
    [req.user.id, today, score, answers.length, JSON.stringify(fullAnswers)]);
  res.json({ code: 200, msg: `得分：${score}/${answers.length}`, data: { score, total: answers.length, answers: fullAnswers } });
});

// 排行榜（本月）
router.get('/leaderboard', auth, async (req, res) => {
  const month = dayjs().format('YYYY-MM');
  const rows = await query(
    `SELECT u.id as user_id, u.name, SUM(qr.score) as total_score, COUNT(qr.id) as days,
            (SELECT COUNT(*) FROM quiz_likes ql JOIN quiz_results qr2 ON ql.result_id=qr2.id WHERE qr2.user_id=u.id) as likes
     FROM quiz_results qr
     JOIN users u ON qr.user_id=u.id
     WHERE strftime('%Y-%m', qr.quiz_date)=?
     GROUP BY qr.user_id ORDER BY total_score DESC, days DESC`,
    [month]
  );
  // 获取当前用户今日是否已点赞
  const todayResults = await query(
    'SELECT qr.id, qr.user_id FROM quiz_results qr WHERE strftime("%Y-%m", qr.quiz_date)=?', [month]
  );
  const resultIds = todayResults.map(r => r.id);
  let myLikes = [];
  if (resultIds.length) {
    myLikes = await query(
      `SELECT result_id FROM quiz_likes WHERE user_id=? AND result_id IN (${resultIds.join(',')})`,
      [req.user.id]
    );
  }
  const likedSet = new Set(myLikes.map(l => l.result_id));
  res.json({ code: 200, data: { leaderboard: rows, likedSet: [...likedSet] } });
});

// 点赞
router.post('/like/:resultId', auth, async (req, res) => {
  const result = await queryOne('SELECT * FROM quiz_results WHERE id=?', [req.params.resultId]);
  if (!result) return res.json({ code: 404, msg: '记录不存在' });
  try {
    await query('INSERT INTO quiz_likes (result_id, user_id) VALUES (?,?)', [result.id, req.user.id]);
    res.json({ code: 200, msg: '点赞成功' });
  } catch (e) { res.json({ code: 400, msg: '已点过赞' }); }
});

module.exports = router;
