import { z } from 'zod';

export const assessmentSchema = z.object({
  target_id: z.number({ required_error: '请选择考核对象' }).positive(),
  title: z.string().min(1, '请输入考核标题'),
  content: z.string().optional().default(''),
  assess_type: z.string().optional().default('奖励通报'),
  photos: z.array(z.string()).optional().default([]),
  assess_date: z.string().optional().default(''),
});
