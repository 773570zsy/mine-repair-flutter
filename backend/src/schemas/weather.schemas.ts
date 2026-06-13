import { z } from 'zod';

export const weatherZoneCreateSchema = z.object({
  zone_name: z.string().min(1, '请输入区域名称'),
  zone_code: z.string().min(1, '请输入区域编码'),
  latitude: z.number().optional().default(0),
  longitude: z.number().optional().default(0),
  altitude: z.string().optional().default(''),
  description: z.string().optional().default(''),
});

export const weatherZoneUpdateSchema = z.object({
  zone_name: z.string().optional(),
  zone_code: z.string().optional(),
  latitude: z.number().optional(),
  longitude: z.number().optional(),
  altitude: z.string().optional(),
  description: z.string().optional(),
  status: z.string().optional(),
});

export const weatherThresholdCreateSchema = z.object({
  zone_id: z.number().nullable().optional(),
  weather_type: z.string().min(1, '请选择天气类型'),
  level: z.string().min(1, '请选择预警等级'),
  threshold_value: z.number({ required_error: '请输入阈值' }),
  threshold_unit: z.string().optional().default(''),
  duration_minutes: z.number().optional().default(30),
  enabled: z.boolean().optional().default(true),
});

export const weatherThresholdUpdateSchema = z.object({
  zone_id: z.number().nullable().optional(),
  weather_type: z.string().optional(),
  level: z.string().optional(),
  threshold_value: z.number().optional(),
  threshold_unit: z.string().optional(),
  duration_minutes: z.number().optional(),
  enabled: z.boolean().optional(),
});

export const weatherDataIngestSchema = z.object({
  items: z.array(z.record(z.unknown())).min(1, '请提供数据'),
});

export const weatherWarningResolveSchema = z.object({
  reason: z.string().optional().default(''),
});

export const weatherSmsSchema = z.object({
  phones: z.array(z.string()).min(1, '请提供手机号'),
  content: z.string().min(1, '请输入短信内容'),
});
