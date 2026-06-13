import { getDB } from '../db';

/** 创建测试管理员（密码: test123） */
export function seedTestAdmin(): { id: number; phone: string } {
  const db = getDB();
  // 插入管理员角色
  db.prepare(`INSERT OR REPLACE INTO departments (id, name) VALUES (1, '测试部门')`).run();
  db.prepare(`INSERT OR REPLACE INTO users (id, name, phone, password, role, department_id)
    VALUES (1, '测试管理员', '13800000000', '123456', 'admin', 1)`).run();
  return { id: 1, phone: '13800000000' };
}

/** 创建测试车辆 */
export function seedTestVehicle(): { id: number; plate: string } {
  const db = getDB();
  db.prepare(`INSERT OR REPLACE INTO vehicles (id, plate_number, vehicle_type, status, hourly_rate, asset_value)
    VALUES (1, 'TEST01', '装载机', 'normal', 200, 500000)`).run();
  return { id: 1, plate: 'TEST01' };
}

/** 创建测试驾驶员 */
export function seedTestDriver(): { id: number } {
  const db = getDB();
  db.prepare(`INSERT OR REPLACE INTO users (id, name, phone, password, role, department_id)
    VALUES (2, '测试驾驶员', '13800000001', '123456', 'driver', 1)`).run();
  return { id: 2 };
}

/** 创建测试点检数据（含加油量和工时） */
export function seedTestInspection(vehicleId: number, driverId: number, date: string, fuelLiters: number, hours: number): void {
  const db = getDB();
  db.prepare(`INSERT INTO daily_inspections (vehicle_id, driver_id, inspection_date, start_hours, end_hours, fuel_amount)
    VALUES (?, ?, ?, 0, ?, ?)`).run(vehicleId, driverId, date, hours, fuelLiters);
}

/** 绑定驾驶员到车辆 */
export function bindDriverToVehicle(driverId: number, vehicleId: number): void {
  const db = getDB();
  db.prepare(`INSERT INTO driver_vehicle_bindings (driver_id, vehicle_id, bind_date) VALUES (?, ?, date('now'))`).run(driverId, vehicleId);
}

/** 录入考勤 */
export function seedAttendance(driverId: number, date: string): void {
  const db = getDB();
  db.prepare(`INSERT INTO driver_attendance (driver_id, attendance_date, attendance_symbol)
    VALUES (?, ?, '出勤')`).run(driverId, date);
}

/** 创建测试修理厂 */
export function seedTestRepairShop(): { id: number; name: string } {
  const db = getDB();
  db.prepare(`INSERT OR REPLACE INTO repair_shops (id, name, contact_person, contact_phone, status)
    VALUES (1, '测试修理厂', '李师傅', '13900001111', 1)`).run();
  return { id: 1, name: '测试修理厂' };
}

/** 创建测试修理厂用户 */
export function seedTestRepairShopUser(shopId: number): { id: number; phone: string } {
  const db = getDB();
  db.prepare(`INSERT OR REPLACE INTO users (id, name, phone, password, role, repair_shop_id, department_id)
    VALUES (3, '测试修理工', '13800000002', '123456', 'repair_shop', ?, 1)`).run(shopId);
  return { id: 3, phone: '13800000002' };
}

/** 创建测试领导 */
export function seedTestLeader(): { id: number; phone: string } {
  const db = getDB();
  db.prepare(`INSERT OR REPLACE INTO users (id, name, phone, password, role, department_id)
    VALUES (4, '测试领导', '13800000003', '123456', 'leader', 1)`).run();
  return { id: 4, phone: '13800000003' };
}
