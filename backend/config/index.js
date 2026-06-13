module.exports = {
  // JWT密钥
  jwtSecret: 'mine-repair-jwt-secret-2026',

  // 微信小程序配置（本地调试时可留空）
  wx: {
    appId: process.env.WX_APPID || '',
    appSecret: process.env.WX_SECRET || ''
  },

  // 文件上传目录
  uploadDir: 'uploads/',

  // 服务端口
  port: 3000
};
