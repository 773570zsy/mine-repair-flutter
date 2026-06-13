import { z } from 'zod';

export const externalReportSchema = z.object({
  vehicle_name: z.string().min(1, '请输入车辆名称'),
  fault_description: z.string().min(1, '请填写故障描述'),
  fault_images: z.array(z.string()).optional().default([]),
  department_id: z.number().optional(),
  repair_shop_id: z.number().optional(),
});

export const externalAcceptSchema = z.object({
  quote_amount: z.number({ required_error: '请填写报价金额' }).min(0, '报价金额不能为负'),
  parts_cost: z.number().optional().default(0),
  labor_cost: z.number().optional().default(0),
  hours_cost: z.number().optional().default(0),
  parts_list: z.array(z.unknown()).optional().default([]),
  quote_detail: z.string().optional().default(''),
  estimated_days: z.number().optional(),
});

export const externalProgressSchema = z.object({
  content: z.string().optional().default(''),
  images: z.array(z.string()).optional().default([]),
});

export const externalApproveSchema = z.object({
  approved: z.boolean({ required_error: '请选择审批结果' }),
  reject_reason: z.string().optional().default(''),
});

export const externalCompleteSchema = z.object({
  note: z.string().optional().default(''),
});
