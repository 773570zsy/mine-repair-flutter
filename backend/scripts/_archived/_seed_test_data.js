const fs = require('fs');
const path = require('path');
const dbPath = path.join(__dirname, 'data', 'mine_repair.db');
const sqlJsModule = require('sql.js');

async function main() {
  const SQL = await sqlJsModule.default();
  const buffer = fs.readFileSync(dbPath);
  const db = new SQL.Database(buffer);
  
  // Fix vehicle asset values
  db.run("UPDATE vehicles SET asset_value = 1800000 WHERE id = 1");
  db.run("UPDATE vehicles SET asset_value = 850000 WHERE id = 2");
  db.run("UPDATE vehicles SET asset_value = 2200000 WHERE id = 3");
  db.run("UPDATE vehicles SET asset_value = 1200000 WHERE id = 4");
  
  // Clear existing test records for June 2026
  db.run("DELETE FROM daily_inspections WHERE inspection_date LIKE '2026-06-%' AND vehicle_id IN (1,2,3,4)");
  db.run("DELETE FROM driver_attendance WHERE attendance_date LIKE '2026-06-%'");
  
  // Insert test daily_inspections (晚检数据)
  // 矿A-001 挖掘机: 20天, 每天150L油, 8h→18h
  for (let d = 1; d <= 20; d++) {
    const date = `2026-06-${String(d).padStart(2,'0')}`;
    db.run(`INSERT INTO daily_inspections 
      (vehicle_id, driver_id, inspection_date, oil_level, coolant_level, appearance, tire_condition, toolkit_check, overall_status, start_hours, end_hours, fuel_amount, parking_location)
      VALUES (1, 1, '${date}', 'normal', 'normal', 'normal', 'normal', 'ok', 'normal', 8, 18, 150, '矿区停车场')`);
  }
  // 矿A-002 装载机: 15天, 100L/天, 8h→17h
  for (let d = 1; d <= 15; d++) {
    const date = `2026-06-${String(d).padStart(2,'0')}`;
    db.run(`INSERT INTO daily_inspections 
      (vehicle_id, driver_id, inspection_date, oil_level, coolant_level, appearance, tire_condition, toolkit_check, overall_status, start_hours, end_hours, fuel_amount, parking_location)
      VALUES (2, 2, '${date}', 'normal', 'normal', 'normal', 'normal', 'ok', 'normal', 8, 17, 100, '矿区停车场')`);
  }
  // 矿B-003 矿卡: 22天, 250L/天, 8h→19h
  for (let d = 1; d <= 22; d++) {
    const date = `2026-06-${String(d).padStart(2,'0')}`;
    db.run(`INSERT INTO daily_inspections 
      (vehicle_id, driver_id, inspection_date, oil_level, coolant_level, appearance, tire_condition, toolkit_check, overall_status, start_hours, end_hours, fuel_amount, parking_location)
      VALUES (3, 3, '${date}', 'normal', 'normal', 'normal', 'normal', 'ok', 'normal', 8, 19, 250, '矿区停车场')`);
  }
  // 矿B-004 推土机: 18天, 130L/天, 8h→17.5h
  for (let d = 1; d <= 18; d++) {
    const date = `2026-06-${String(d).padStart(2,'0')}`;
    db.run(`INSERT INTO daily_inspections 
      (vehicle_id, driver_id, inspection_date, oil_level, coolant_level, appearance, tire_condition, toolkit_check, overall_status, start_hours, end_hours, fuel_amount, parking_location)
      VALUES (4, 4, '${date}', 'normal', 'normal', 'normal', 'normal', 'ok', 'normal', 8, 17.5, 130, '矿区停车场')`);
  }
  
  // Insert attendance records (考勤)
  // Driver 1 (张思远): 20天 → 对应车辆1和2
  for (let d = 1; d <= 20; d++) {
    const date = `2026-06-${String(d).padStart(2,'0')}`;
    db.run(`INSERT OR REPLACE INTO driver_attendance (driver_id, attendance_date, attendance_symbol) VALUES (1, '${date}', '出勤')`);
  }
  // Driver 2 (张三): 15天 → 对应车辆3
  for (let d = 1; d <= 15; d++) {
    const date = `2026-06-${String(d).padStart(2,'0')}`;
    db.run(`INSERT OR REPLACE INTO driver_attendance (driver_id, attendance_date, attendance_symbol) VALUES (2, '${date}', '出勤')`);
  }
  // Driver 3 (李四): 22天 → 对应车辆4
  for (let d = 1; d <= 22; d++) {
    const date = `2026-06-${String(d).padStart(2,'0')}`;
    db.run(`INSERT OR REPLACE INTO driver_attendance (driver_id, attendance_date, attendance_symbol) VALUES (3, '${date}', '出勤')`);
  }
  
  // Verify
  const inspCount = db.exec("SELECT COUNT(*) as c FROM daily_inspections WHERE inspection_date LIKE '2026-06-%'");
  const attCount = db.exec("SELECT COUNT(*) as c FROM driver_attendance WHERE attendance_date LIKE '2026-06-%'");
  const assetCheck = db.exec("SELECT id, plate_number, asset_value FROM vehicles");
  
  console.log(`Inspections 2026-06: ${inspCount[0]?.values[0]?.[0] || 0} records`);
  console.log(`Attendance 2026-06: ${attCount[0]?.values[0]?.[0] || 0} records`);
  if (assetCheck[0]) {
    assetCheck[0].values.forEach(r => console.log(`  Vehicle ${r[0]}: ${r[1]} asset=¥${r[2]}`));
  }
  
  // Save
  const data = db.export();
  fs.writeFileSync(dbPath, Buffer.from(data));
  console.log('Database saved');
  db.close();
}

main().catch(e => console.error(e));
