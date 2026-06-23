import { z } from 'zod';

export const loginSchema = z.object({
  phone: z.string().min(1, '请输入手机号').max(20, '手机号过长'),
  password: z.string().min(1, '请输入密码').max(100, '密码过长'),
  device_type: z.enum(['pc', 'mobile']).default('pc'),
});
