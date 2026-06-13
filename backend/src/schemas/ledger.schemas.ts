import { z } from 'zod';

// ==================== 燃油记录 ====================

export const fuelRecordSchema = z.object({
  vehicle_id: z.number({ required_error: '请选择车辆' }).positive(),
  record_date: z.string().min(1, '请选择日期'),
  fuel_amount: z.number().min(0).optional().default(0),
  fuel_cost: z.number().min(0).optional().default(0),
  hour_meter: z.number().min(0).optional().default(0),
  station: z.string().optional().default(''),
  operator_id: z.number().optional(),
  remark: z.string().optional().default(''),
});

export const fuelRecordUpdateSchema = z.object({
  vehicle_id: z.number().positive().optional(),
  record_date: z.string().optional(),
  fuel_amount: z.number().min(0).optional().default(0),
  fuel_cost: z.number().min(0).optional().default(0),
  hour_meter: z.number().min(0).optional().default(0),
  station: z.string().optional().default(''),
  remark: z.string().optional().default(''),
});

export const fuelImportSchema = z.object({
  records: z.array(z.record(z.unknown())).min(1, '请提供导入数据'),
});

// ==================== 配件更换 ====================

export const partReplacementSchema = z.object({
  vehicle_id: z.number({ required_error: '请选择车辆' }).positive(),
  part_name: z.string().min(1, '请填写部件名称'),
  part_type: z.string().optional().default('other'),
  replace_date: z.string().min(1, '请填写更换日期'),
  cost: z.number().min(0).optional().default(0),
  current_hours: z.number().min(0).optional().default(0),
  reason: z.string().optional().default(''),
  remark: z.string().optional().default(''),
});

export const partReplacementUpdateSchema = z.object({
  vehicle_id: z.number().positive().optional(),
  part_name: z.string().optional(),
  part_type: z.string().optional().default('other'),
  replace_date: z.string().optional(),
  cost: z.number().min(0).optional().default(0),
  current_hours: z.number().min(0).optional().default(0),
  reason: z.string().optional().default(''),
  remark: z.string().optional().default(''),
});

// ==================== 月度清单 / KPI ====================

export const yearMonthSchema = z.object({
  year_month: z.string().regex(/^\d{4}-\d{2}$/, '年月格式必须为 YYYY-MM'),
});

export const submitMonthlyLedgerSchema = z.object({});
export const approveMonthlyLedgerSchema = z.object({});

// ==================== KPI阈值 ====================

export const thresholdsSaveSchema = z.object({
  thresholds: z.array(z.object({
    vehicle_type: z.string().min(1, '车型不能为空'),
    kpi_key: z.string().min(1, 'KPI指标不能为空'),
    upper_limit: z.number({ required_error: '上限不能为空' }),
    lower_limit: z.number({ required_error: '下限不能为空' }),
    penalty_amount: z.number({ required_error: '罚款金额不能为空' }),
    reward_amount: z.number({ required_error: '奖励金额不能为空' }),
  })).min(1, '阈值列表不能为空'),
});

// ==================== 预算 ====================

export const budgetConfigSaveSchema = z.object({
  configs: z.array(z.object({
    vehicle_type: z.string().min(1),
    annual_increase_rate: z.number().min(0).max(1, '增幅率应在0~1之间'),
  })).min(1),
});

export const budgetImportSchema = z.object({
  base_year: z.string().min(1, '请输入基准年份'),
  records: z.array(z.object({
    plate_number: z.string().min(1),
    total_annual_cost: z.number().min(0),
  }).passthrough()).min(1, '请提供导入数据'),
});
