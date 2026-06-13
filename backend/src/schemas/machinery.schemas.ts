import { z } from 'zod';

export const machineryApplySchema = z.object({
  applicant_dept: z.string().min(1, '请输入申请部门'),
  applicant_name: z.string().min(1, '请输入申请人'),
  applicant_phone: z.string().min(1, '请输入联系电话'),
  vehicle_type: z.string().min(1, '请选择机械类型'),
  application_type: z.string().optional().default(''),
  scheduled_start: z.string().min(1, '请选择计划开始时间'),
  scheduled_end: z.string().min(1, '请选择计划结束时间'),
  work_location: z.string().min(1, '请输入作业地点'),
  work_altitude: z.string().optional().default(''),
  work_purpose: z.string().min(1, '请输入作业用途'),
  is_hazardous: z.boolean().optional().default(false),
  urgency: z.string().optional().default('normal'),
  briefing_method: z.string().optional().default('现场'),
  briefing_files: z.string().optional().default(''),
});

export const machineryAssignSchema = z.object({
  assigned_vehicle_id: z.number({ required_error: '请选择指派车辆' }).positive(),
  assigned_driver_id: z.number({ required_error: '请选择指派驾驶员' }).positive(),
});

export const machineryEarlyEndSchema = z.object({
  actual_end_time: z.string().optional().default(''),
  settlement_end_time: z.string().optional().default(''),
  remark: z.string().optional().default(''),
});
