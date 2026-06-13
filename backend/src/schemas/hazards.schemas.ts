import { z } from 'zod';

export const hazardReportSchema = z.object({
  location: z.string().optional().default(''),
  description: z.string().min(1, '请填写隐患描述'),
  severity: z.enum(['低', '一般', '高', '紧急'], { errorMap: () => ({ message: '严重程度无效' }) }),
  responsible_id: z.number().optional(),
  deadline: z.string().optional().default(''),
  photos_before: z.array(z.string()).optional().default([]),
});

export const hazardAssignSchema = z.object({
  responsible_id: z.number({ required_error: '请选择责任人' }).positive(),
  deadline: z.string().optional().default(''),
});

export const hazardRectifySchema = z.object({
  photos_after: z.array(z.string()).optional().default([]),
  rectify_desc: z.string().optional().default(''),
});

export const hazardRejectSchema = z.object({
  reject_reason: z.string().min(1, '请填写驳回原因'),
});

export const hazardVerifySchema = z.object({
  verified: z.boolean({ required_error: '请选择验收结果' }),
  remark: z.string().optional().default(''),
});
