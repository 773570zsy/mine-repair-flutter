import { z } from 'zod';

// ==================== 维修流程 ====================

export const reportFaultSchema = z.object({
  vehicle_id: z.number({ required_error: '请选择车辆' }).positive('请选择车辆'),
  fault_description: z.string().min(1, '请填写故障描述'),
  fault_images: z.array(z.string()).optional().default([]),
  repair_shop_id: z.number().optional(),
});

export const acceptOrderSchema = z.object({
  content: z.string().optional().default(''),
});

export const submitQuoteSchema = z.object({
  quote_amount: z.number({ required_error: '请填写报价金额' }).min(0, '报价金额不能为负'),
  parts_cost: z.number().optional().default(0),
  labor_cost: z.number().optional().default(0),
  hours_cost: z.number().optional().default(0),
  parts_list: z.array(z.unknown()).optional().default([]),
  quote_detail: z.string().optional().default(''),
  estimated_days: z.number().nullable().optional(),
  damage_photos: z.array(z.string()).optional().default([]),
  new_photos: z.array(z.string()).optional().default([]),
});

export const updateProgressSchema = z.object({
  content: z.string().optional().default(''),
  note: z.string().optional().default(''),
  images: z.array(z.string()).optional().default([]),
});

export const completeOrderSchema = z.object({
  new_photos: z.array(z.string()).optional().default([]),
});

export const approveOrderSchema = z.object({
  approved: z.boolean({ required_error: '请选择审批结果' }),
  reject_reason: z.string().optional().default(''),
});

export const trialAcceptSchema = z.object({
  content: z.string().optional().default(''),
});
