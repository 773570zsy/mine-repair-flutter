// 应用配置
export const config = {
  // JWT密钥 (生产环境应从环境变量读取)
  jwtSecret: process.env.JWT_SECRET || 'mine-repair-jwt-secret-2026',

  // JWT过期时间
  jwtExpiresIn: '30d',

  // 服务端口
  port: parseInt(process.env.PORT || '3000', 10),

  // 文件上传目录
  uploadDir: process.env.UPLOAD_DIR || 'uploads/',

  // 数据库路径
  dbPath: process.env.DB_PATH || 'data/mine_repair.db',

  // 环境
  env: process.env.NODE_ENV || 'development',
};

export default config;
