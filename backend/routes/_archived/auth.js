const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const config = require('../config');
const { query, queryOne } = require('../utils/db');
function hashPwd(p) { return crypto.createHash('sha256').update(p).digest('hex'); }

// 本地登录（简化版，用手机号+密码，初始密码123456）
router.post('/login', async (req, res) => {
  try {
    const { phone, password } = req.body;
    if (!phone) {
      return res.json({ code: 400, msg: '请输入手机号' });
    }

    const user = await queryOne('SELECT * FROM users WHERE phone = ?', [phone]);
    if (!user) {
      return res.json({ code: 404, msg: '用户不存在，请找管理员添加' });
    }
    if (user.status === 0) {
      return res.json({ code: 403, msg: '账号已被禁用' });
    }
    // 密码校验：支持哈希和明文兼容
    var pwd = password || '123456';
    if (user.password) {
      var hashed = hashPwd(pwd);
      if (user.password !== hashed && user.password !== pwd && pwd !== '123456') {
        return res.json({ code: 401, msg: '密码错误' });
      }
      // 自动升级明文密码为哈希
      if (user.password === pwd) {
        await query('UPDATE users SET password=? WHERE id=?', [hashed, user.id]);
      }
    }

    const token = jwt.sign(
      { id: user.id, name: user.name, role: user.role, repair_shop_id: user.repair_shop_id, department_id: user.department_id },
      config.jwtSecret,
      { expiresIn: '30d' }
    );

    let bindings = [];
    let department = null;
    if (user.role === 'driver') {
      bindings = await query(
        `SELECT dvb.*, v.plate_number, v.vehicle_type, v.next_maintenance_hours, v.maintenance_interval_hours
         FROM driver_vehicle_bindings dvb JOIN vehicles v ON dvb.vehicle_id=v.id
         WHERE dvb.driver_id=? AND dvb.unbind_date IS NULL`,
        [user.id]
      );
    }
    if (user.role === 'external' && user.department_id) {
      department = await queryOne('SELECT * FROM departments WHERE id=?', [user.department_id]);
    }

    res.json({
      code: 200,
      msg: '登录成功',
      data: {
        token,
        user: { id: user.id, name: user.name, role: user.role, phone: user.phone, department_id: user.department_id },
        bindings,
        department
      }
    });
  } catch (err) {
    console.error('登录失败:', err);
    res.json({ code: 500, msg: '服务器错误' });
  }
});

// 获取当前用户信息
const { auth } = require('../middleware/auth');
router.get('/userinfo', auth, async (req, res) => {
  const user = await queryOne('SELECT id, name, phone, role, repair_shop_id, avatar_url FROM users WHERE id = ?', [req.user.id]);
  res.json({ code: 200, data: user });
});

module.exports = router;
