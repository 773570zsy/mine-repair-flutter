import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import config from '../config';
import { JwtPayload, UserRole } from '../models';
import { authService } from '../services/auth.service';

// 扩展 Express Request 类型
declare global {
  namespace Express {
    interface Request {
      user: JwtPayload;
    }
  }
}

/** JWT 认证中间件 */
export function auth(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers.authorization;
  const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;

  if (!token) {
    res.status(401).json({ code: 401, msg: '请先登录' });
    return;
  }

  try {
    const decoded = jwt.verify(token, config.jwtSecret) as JwtPayload;
    // 检查会话是否仍有效（同端登录互踢后旧token失效）
    if (decoded.jti && !authService.isSessionValid(decoded.jti)) {
      res.status(401).json({ code: 401, msg: '账号已在其他设备登录，请重新登录' });
      return;
    }
    req.user = decoded;
    next();
  } catch {
    res.status(401).json({ code: 401, msg: '登录已过期，请重新登录' });
  }
}

/** 角色权限中间件 */
export function requireRole(...roles: UserRole[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!roles.includes(req.user.role)) {
      res.status(403).json({ code: 403, msg: '无权操作' });
      return;
    }
    next();
  };
}
