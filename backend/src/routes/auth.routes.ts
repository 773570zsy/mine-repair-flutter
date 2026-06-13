import { Router, Request, Response } from 'express';
import { auth } from '../middleware/auth';
import { asyncHandler } from '../middleware/error-handler';
import { authService } from '../services/auth.service';
import { validate } from '../middleware/validate';
import { loginSchema } from '../schemas/auth.schemas';

const router = Router();

// 登录
router.post('/login', validate(loginSchema), asyncHandler(async (req: Request, res: Response) => {
  const { phone, password } = req.body;

  const data = authService.login(phone, password);
  const bindings = authService.getBindings(data.user.id, data.user.role);
  const department = authService.getDepartment(data.user.department_id);

  res.json({
    code: 200,
    msg: '登录成功',
    data: { ...data, bindings, department },
  });
}));

// 获取当前用户信息
router.get('/userinfo', auth, asyncHandler(async (req: Request, res: Response) => {
  const { userRepo } = require('../repositories/user.repository');
  const user = userRepo.findById(req.user.id);
  res.json({ code: 200, data: user });
}));

export default router;
