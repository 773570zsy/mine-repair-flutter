import jwt from 'jsonwebtoken';
import config from '../config';
import { userRepo } from '../repositories/user.repository';
import { hashPassword, verifyPassword, isLegacyHash } from '../utils/hash';
import { AppError } from '../middleware/error-handler';
import { JwtPayload } from '../models';
import { getDB } from '../db';
import crypto from 'crypto';

export class AuthService {
  /** 用户登录 */
  login(phone: string, rawPassword: string) {
    const user = userRepo.findByPhone(phone);
    if (!user) throw new AppError(404, '用户不存在，请找管理员添加');
    if (user.status === 0) throw new AppError(403, '账号已被禁用');

    const pwd = rawPassword;

    if (user.password) {
      if (isLegacyHash(user.password)) {
        // 旧版SHA256兼容
        const legacyHash = crypto.createHash('sha256').update(pwd).digest('hex');
        if (user.password !== legacyHash && user.password !== pwd) {
          throw new AppError(401, '密码错误');
        }
        // 自动升级为bcrypt
        if (user.password === legacyHash || user.password === pwd) {
          userRepo.updatePassword(user.id, hashPassword(pwd));
        }
      } else {
        // bcrypt验证
        if (!verifyPassword(pwd, user.password)) {
          throw new AppError(401, '密码错误');
        }
      }
    }

    const payload: JwtPayload = {
      id: user.id,
      name: user.name,
      role: user.role,
      repair_shop_id: user.repair_shop_id,
      department_id: user.department_id,
    };

    const token = jwt.sign(payload, config.jwtSecret, { expiresIn: config.jwtExpiresIn } as jwt.SignOptions);

    return {
      token,
      user: {
        id: user.id,
        name: user.name,
        role: user.role,
        phone: user.phone,
        department_id: user.department_id,
      },
    };
  }

  /** 获取用户绑定信息 */
  getBindings(userId: number, role: string) {
    if (role === 'driver') {
      return getDB().prepare(
        `SELECT dvb.*, v.plate_number, v.vehicle_type, v.next_maintenance_hours, v.maintenance_interval_hours
         FROM driver_vehicle_bindings dvb JOIN vehicles v ON dvb.vehicle_id = v.id
         WHERE dvb.driver_id = ? AND dvb.unbind_date IS NULL`
      ).all(userId);
    }
    return [];
  }

  /** 获取部门信息 */
  getDepartment(departmentId: number | null) {
    if (!departmentId) return null;
    return getDB().prepare('SELECT * FROM departments WHERE id = ?').get(departmentId);
  }

  /** 修改密码 */
  changePassword(userId: number, oldPwd: string, newPwd: string) {
    if (!newPwd || newPwd.length < 4) throw new AppError(400, '新密码至少4位');

    const user = userRepo.findByIdWithPassword(userId);
    if (!user) throw new AppError(404, '用户不存在');

    if (user.password) {
      if (isLegacyHash(user.password)) {
        const oldHash = crypto.createHash('sha256').update(oldPwd || '').digest('hex');
        if (user.password !== oldHash && user.password !== oldPwd) {
          throw new AppError(400, '原密码错误');
        }
      } else {
        if (!verifyPassword(oldPwd || '', user.password)) {
          throw new AppError(400, '原密码错误');
        }
      }
    }

    userRepo.updatePassword(userId, hashPassword(newPwd));
  }
}

export const authService = new AuthService();
