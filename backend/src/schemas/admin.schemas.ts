import { z } from 'zod';

export const vehicleImportSchema = z.object({
  vehicles: z.array(z.record(z.unknown())).min(1, '请提供导入数据'),
});

export const vehicleBindSchema = z.object({
  driver_id: z.number({ required_error: '请选择驾驶员' }).positive(),
  vehicle_id: z.number({ required_error: '请选择车辆' }).positive(),
});

export const vehicleUpdateSchema = z.object({
  plate_number: z.string().optional(),
  vehicle_type: z.string().optional(),
  model: z.string().optional().default(''),
  department: z.string().optional().default(''),
  hourly_rate: z.number().optional(),
});

export const vehicleUnbindSchema = z.object({
  binding_id: z.number({ required_error: '缺少绑定ID' }).positive(),
});

export const userAddSchema = z.object({
  name: z.string().min(1, '请输入姓名'),
  phone: z.string().min(1, '请输入手机号'),
  role: z.string().min(1, '请选择角色'),
  repair_shop_id: z.number().nullable().optional(),
  department_id: z.number().nullable().optional(),
});

export const userImportSchema = z.object({
  users: z.array(z.record(z.unknown())).min(1, '请提供导入数据'),
});

export const shopAddSchema = z.object({
  name: z.string().min(1, '请输入修理厂名称'),
  contact_person: z.string().optional().default(''),
  contact_phone: z.string().optional().default(''),
  remark: z.string().optional().default(''),
});

export const configSaveSchema = z.object({
  config: z.record(z.unknown()),
});

export const changePasswordSchema = z.object({
  old_pwd: z.string().min(1, '请输入旧密码'),
  new_pwd: z.string().min(1, '请输入新密码').max(100),
});

export const restoreBackupSchema = z.object({
  filename: z.string().min(1, '请指定备份文件'),
});

export const exportOrdersSchema = z.object({
  date_from: z.string().optional().default(''),
  date_to: z.string().optional().default(''),
  repair_shop_id: z.number().nullable().optional(),
  department_id: z.number().nullable().optional(),
  status: z.string().optional().default(''),
});

export const exportCostSchema = z.object({
  date_from: z.string().optional().default(''),
  date_to: z.string().optional().default(''),
});
