const jwt = require('jsonwebtoken');
const config = require('../config');

// JWT认证中间件
function auth(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    return res.status(401).json({ code: 401, msg: '请先登录' });
  }
  try {
    const decoded = jwt.verify(token, config.jwtSecret);
    req.user = decoded;
    next();
  } catch (e) {
    return res.status(401).json({ code: 401, msg: '登录已过期，请重新登录' });
  }
}

// 角色权限中间件
function requireRole(...roles) {
  return (req, res, next) => {
    if (!roles.includes(req.user.role)) {
      return res.status(403).json({ code: 403, msg: '无权操作' });
    }
    next();
  };
}

module.exports = { auth, requireRole };
