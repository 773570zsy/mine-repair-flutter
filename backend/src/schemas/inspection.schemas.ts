import { z } from 'zod';

export const morningCheckSchema = z.object({
  vehicle_id: z.number({ required_error: '请选择车辆' }).positive(),
  driver_id: z.number().optional(),
  oil_level: z.string().optional().default(''),
  coolant_level: z.string().optional().default(''),
  appearance: z.string().optional().default(''),
  tire_condition: z.string().optional().default(''),
  toolkit_check: z.string().optional().default(''),
  overall_status: z.string().optional().default('normal'),
  abnormal_desc: z.string().optional().default(''),
  notes: z.string().optional().default(''),
  engine_hours: z.number().optional().default(0),
  photos: z.array(z.string()).optional().default([]),
  current_km: z.number().optional().default(0),
});

export const eveningCheckSchema = z.object({
  vehicle_id: z.number({ required_error: '请选择车辆' }).positive(),
  driver_id: z.number().optional(),
  start_hours: z.number().optional().default(0),
  end_hours: z.number().optional().default(0),
  fuel_amount: z.number().optional().default(0),
  attendance_symbol: z.string().optional().default(''),
  parking_location: z.string().optional().default(''),
  start_km: z.number().optional().default(0),
  end_km: z.number().optional().default(0),
  photos: z.array(z.string()).optional().default([]),
  videos: z.array(z.string()).optional().default([]),
  notes: z.string().optional().default(''),
  current_km: z.number().optional().default(0),
});

export const attendanceSubmitSchema = z.object({
  month: z.string().optional().default(''),
  driver_id: z.number().optional(),
  department_id: z.number().optional(),
  attendance_date: z.string().optional(),
  attendance_symbol: z.string().optional().default(''),
  overtime_hours: z.number().optional().default(0),
  overtime_start: z.string().optional().default(''),
  overtime_end: z.string().optional().default(''),
  overtime_location: z.string().optional().default(''),
  vehicle_type: z.string().optional().default(''),
  plate_number: z.string().optional().default(''),
});

export const partsAddSchema = z.object({
  part_name: z.string().min(1, '请输入配件名称'),
  part_code: z.string().optional().default(''),
  quantity: z.number().min(0).optional().default(0),
  unit: z.string().optional().default('个'),
  unit_price: z.number().min(0).optional().default(0),
  remark: z.string().optional().default(''),
});

export const partsThresholdSchema = z.object({
  part_id: z.number({ required_error: '缺少配件ID' }),
  threshold: z.number({ required_error: '请输入阈值' }).min(0),
});

export const partsImportSchema = z.object({
  parts: z.array(z.record(z.unknown())).min(1, '请提供导入数据'),
});

export const partsRequisitionSchema = z.object({
  part_id: z.number({ required_error: '请选择配件' }).positive(),
  vehicle_id: z.number().optional(),
  quantity: z.number({ required_error: '请输入数量' }).min(1, '数量至少为1'),
  reason: z.string().optional().default(''),
});

export const exportAttendanceSchema = z.object({
  month: z.string().min(1, '请选择月份'),
  driver_id: z.number().optional(),
  department_id: z.number().optional(),
});
