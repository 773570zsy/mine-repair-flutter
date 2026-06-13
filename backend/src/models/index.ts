// ==================== 核心模型接口 ====================

export interface User {
  id: number;
  name: string;
  phone: string;
  role: UserRole;
  repair_shop_id: number | null;
  department_id: number | null;
  avatar_url: string;
  status: number;
  password: string;
  created_at: string;
  updated_at: string;
}

export type UserRole = 'driver' | 'repair_shop' | 'leader' | 'admin' | 'safety_officer' | 'dispatcher' | 'applicant' | 'external_repair';

export interface JwtPayload {
  id: number;
  name: string;
  role: UserRole;
  repair_shop_id: number | null;
  department_id: number | null;
}

export interface Vehicle {
  id: number;
  plate_number: string;
  vehicle_type: string;
  model: string;
  buy_date: string;
  current_driver_id: number | null;
  status: 'normal' | 'repairing' | 'scrapped';
  next_maintenance_hours: number;
  maintenance_interval_hours: number;
  initial_engine_hours: number;
  purchase_date: string;
  asset_value: number;
  hourly_rate: number;
  remark: string;
  created_at: string;
  updated_at: string;
}

export interface RepairOrder {
  id: number;
  order_no: string;
  vehicle_id: number;
  driver_id: number;
  repair_shop_id: number | null;
  fault_description: string;
  fault_images: string; // JSON array
  status: RepairStatus;
  reject_reason: string;
  is_urgent: number;
  created_at: string;
  updated_at: string;
}

export type RepairStatus =
  | 'pending_accept' | 'pending_quote' | 'pending_approval'
  | 'approved' | 'rejected' | 'repairing' | 'completed' | 'accepted' | 'cancelled';

export interface RepairQuote {
  id: number;
  order_id: number;
  repair_shop_id: number;
  quote_amount: number;
  parts_cost: number;
  labor_cost: number;
  hours_cost: number;
  parts_list: string;
  quote_detail: string;
  estimated_days: number | null;
  damage_photos: string;
  new_photos: string;
  leader_id: number | null;
  approved_at: string | null;
  created_at: string;
}

export interface RepairProgress {
  id: number;
  order_id: number;
  user_id: number;
  action: string;
  content: string;
  images: string;
  created_at: string;
}

export interface DailyInspection {
  id: number;
  vehicle_id: number;
  driver_id: number;
  inspection_date: string;
  oil_level: string;
  coolant_level: string;
  appearance: string;
  tire_condition: string;
  toolkit_check: string;
  overall_status: string;
  abnormal_desc: string;
  notes: string;
  engine_hours: number;
  start_hours: number;
  end_hours: number;
  fuel_amount: number;
  attendance_symbol: string;
  parking_location: string;
  start_km: number;
  current_km: number;
  photos: string;
  videos: string;
  created_at: string;
  updated_at: string;
}

export interface Hazard {
  id: number;
  hazard_no: string;
  reporter_id: number;
  location: string;
  description: string;
  severity: '低' | '一般' | '高' | '紧急';
  responsible_id: number | null;
  deadline: string;
  status: 'reported' | 'assigned' | 'rectifying' | 'completed' | 'verified';
  photos_before: string;
  photos_after: string;
  verified_by: number | null;
  verified_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface Department {
  id: number;
  name: string;
  contact_person: string;
  contact_phone: string;
  dept_key: string;
  status: number;
  created_at: string;
}

export interface ExternalRepairOrder {
  id: number;
  order_no: string;
  department_id: number;
  user_id: number;
  repair_shop_id: number | null;
  vehicle_name: string;
  fault_description: string;
  fault_images: string;
  status: string;
  quote_amount: number;
  parts_cost: number;
  labor_cost: number;
  hours_cost: number;
  parts_list: string;
  quote_detail: string;
  estimated_days: number | null;
  reject_reason: string;
  is_urgent: number;
  leader_id: number | null;
  approved_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface Notification {
  id: number;
  user_id: number;
  type: string;
  title: string;
  content: string;
  order_id: number | null;
  is_read: number;
  created_at: string;
}

export interface ApiResponse<T = unknown> {
  code: number;
  msg?: string;
  data?: T;
  total?: number;
  page?: number;
  pageSize?: number;
}

// ==================== 单车核算模块接口 ====================

export interface FuelRecord {
  id: number;
  vehicle_id: number;
  record_date: string;
  fuel_amount: number;
  fuel_cost: number;
  hour_meter: number;
  station: string;
  operator_id: number | null;
  remark: string;
  created_at: string;
}

export interface PartReplacement {
  id: number;
  vehicle_id: number;
  part_name: string;
  part_type: 'tire' | 'engine' | 'hydraulic' | 'transmission' | 'brake' | 'other';
  replace_date: string;
  cost: number;
  current_hours: number;
  reason: string;
  operator_id: number | null;
  remark: string;
  created_at: string;
}

export interface MonthlyLedger {
  id: number;
  vehicle_id: number;
  year_month: string;
  fuel_cost: number;
  repair_cost: number;
  parts_cost: number;
  labor_cost: number;
  work_days: number;
  total_hours: number;
  mileage: number;
  work_volume: number;
  total_cost: number;
  hourly_fuel_consumption: number;
  status: 'draft' | 'submitted' | 'approved';
  submitted_by: number | null;
  approved_by: number | null;
  created_at: string;
  updated_at: string;
}

export interface KpiScore {
  id: number;
  vehicle_id: number;
  year_month: string;
  fuel_cost_per_unit: number;
  repair_rate: number;
  utilization_rate: number;
  unit_cost: number;
  availability_rate: number;
  safety_score: number;
  total_score: number;
  rank: number;
  created_at: string;
}

export interface KpiThreshold {
  id: number;
  vehicle_type: string;
  kpi_key: string;
  upper_limit: number;
  lower_limit: number;
  penalty_amount: number;
  reward_amount: number;
  updated_at: string;
}

// ==================== 在编车辆档案 ====================

export interface VehicleArchive {
  id: number;
  plate_number: string;
  department: string;
  vehicle_type: string;
  model: string;
  manufacture_date: string;
  vin: string;
  insurance_expiry: string;
  inspection_date: string;
  maintenance_interval: number;
  next_maintenance_hours: number;
  current_hours: number;
  maintenance_interval_km: number;
  next_maintenance_km: number;
  current_km: number;
  purchase_date: string;
  has_behavior_monitor: number;
  has_360_camera: number;
  photos: string;
  created_at: string;
  updated_at: string;
}

// ==================== 工程机械申请与指派 ====================

export interface MachineryApplication {
  id: number;
  application_no: string;
  applicant_id: number;
  applicant_dept: string;
  applicant_name: string;
  applicant_phone: string;
  vehicle_type: string;
  application_type: 'short_term' | 'long_term';
  scheduled_start: string;
  scheduled_end: string;
  work_location: string;
  work_altitude: string;
  work_purpose: string;
  is_hazardous: number;
  urgency: 'normal' | 'urgent' | 'emergency';
  briefing_method: string;
  briefing_files: string;
  status: 'pending' | 'assigned' | 'in_progress' | 'completed' | 'early_completed' | 'cancelled';
  assigned_vehicle_id: number | null;
  assigned_driver_id: number | null;
  dispatcher_id: number | null;
  actual_end_time: string;
  settlement_end_time: string;
  working_hours: number;
  hourly_rate: number;
  total_cost: number;
  created_at: string;
  updated_at: string;
  // 关联查询扩展字段
  applicant_user_name?: string;
  dept_name?: string;
  assigned_plate?: string;
  assigned_vehicle_type?: string;
  assigned_vehicle_model?: string;
  driver_name?: string;
  driver_phone?: string;
  dispatcher_name?: string;
}

// ==================== 天气预警模块 ====================

export type WeatherType = 'rainstorm' | 'thunderstorm' | 'strong_wind' | 'snowstorm' | 'sandstorm' | 'low_visibility';

export type WarningLevel = 'blue' | 'yellow' | 'orange' | 'red';

export type WarningStatus = 'active' | 'acknowledged' | 'resolved' | 'cancelled';

export type WeatherDataSource = 'api' | 'sensor' | 'manual';

export interface WeatherZone {
  id: number;
  zone_name: string;
  zone_code: string;
  altitude: string;
  description: string;
  status: number;
  created_at: string;
}

export interface WeatherData {
  id: number;
  zone_id: number;
  source: WeatherDataSource;
  data_type: string;
  value: number;
  unit: string;
  recorded_at: string;
  raw_data: string;
  created_at: string;
}

export interface WeatherThreshold {
  id: number;
  zone_id: number | null;
  weather_type: WeatherType;
  level: WarningLevel;
  threshold_value: number;
  threshold_unit: string;
  duration_minutes: number;
  enabled: number;
  created_at: string;
  updated_at: string;
  // 关联字段
  zone_name?: string;
}

export interface WeatherWarning {
  id: number;
  warning_no: string;
  zone_id: number;
  weather_type: WeatherType;
  level: WarningLevel;
  title: string;
  description: string;
  measured_value: number | null;
  measured_unit: string;
  status: WarningStatus;
  triggered_at: string;
  resolved_at: string | null;
  resolved_by: number | null;
  auto_actions: string;
  created_at: string;
  // 关联字段
  zone_name?: string;
  zone_code?: string;
  resolver_name?: string;
  actions?: WeatherWarningAction[];
}

export interface WeatherWarningAction {
  id: number;
  warning_id: number;
  action_type: string;
  action_detail: string;
  executed_by: number | null;
  executed_at: string;
  result: string;
}
