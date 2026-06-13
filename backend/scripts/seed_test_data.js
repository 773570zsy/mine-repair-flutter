const initSqlJs = require('sql.js');
const fs = require('fs');

(async () => {
  const SQL = await initSqlJs();
  const buf = fs.readFileSync('data/mine_repair.db');
  const db = new SQL.Database(buf);
  const now = new Date().toISOString().slice(0, 19).replace('T', ' ');
  // 清空之前的测试数据
  db.run('DELETE FROM repair_quotes');
  db.run('DELETE FROM repair_progress');
  db.run('DELETE FROM repair_orders');
  db.run('DELETE FROM external_repair_progress');
  db.run('DELETE FROM external_repair_orders');
  db.run('DELETE FROM machinery_applications');
  db.run('DELETE FROM daily_inspections');
  db.run('DELETE FROM driver_attendance');
  db.run('DELETE FROM parts_requisitions');
  db.run('DELETE FROM parts_inventory');
  db.run("DELETE FROM sqlite_sequence WHERE name IN ('repair_orders','repair_quotes','external_repair_orders','machinery_applications','daily_inspections','driver_attendance','parts_requisitions','parts_inventory')");

  // === 维修工单（15条）===
  const faults = [
    ['发动机异响，机油压力不足', 'accepted', 1],
    ['液压油管爆裂，系统压力骤降', 'repairing', 1],
    ['变速箱挂挡困难，异响严重', 'pending_approval', 2],
    ['制动系统失灵，刹车片磨损超标', 'completed', 1],
    ['转向油缸漏油，方向盘沉重', 'repairing', 2],
    ['冷却系统高温，水箱漏水', 'accepted', 1],
    ['履带松脱，行走跑偏', 'pending_approval', 2],
    ['铲斗焊缝开裂，结构变形', 'completed', 1],
    ['电气系统故障，仪表盘不亮', 'repairing', 2],
    ['空调压缩机异响，制冷失效', 'accepted', 1],
    ['排气管断裂，噪音超标', 'completed', 2],
    ['燃油泵供油不足，动力下降', 'repairing', 1],
    ['支重轮轴承损坏，行走抖动', 'pending_approval', 2],
    ['回转支承异响，回转无力', 'accepted', 1],
    ['驾驶室密封条老化，进灰严重', 'completed', 2],
  ];
  for (let i = 0; i < faults.length; i++) {
    const no = 'WO-0608' + String(i + 1).padStart(3, '0');
    db.run('INSERT OR REPLACE INTO repair_orders (order_no, vehicle_id, driver_id, repair_shop_id, fault_description, status, created_at) VALUES (?,?,?,?,?,?,?)',
      [no, (i % 4) + 1, 3 + (i % 3), (i % 2) + 1, faults[i][0], faults[i][1], now]);
    if (['accepted', 'completed'].includes(faults[i][1])) {
      db.run('INSERT OR REPLACE INTO repair_quotes (order_id, repair_shop_id, quote_amount, parts_cost, labor_cost, hours_cost, parts_list, quote_detail, estimated_days, approved_at) VALUES (?,?,?,?,?,?,?,?,?,?)',
        [i + 1, (i % 2) + 1, 3000 + Math.random() * 15000, 1000 + Math.random() * 5000, 800 + Math.random() * 4000, 400 + Math.random() * 2000,
          '[{"name":"' + (i % 3 ? '轴承座' : '油封套件') + '","qty":' + (1 + Math.ceil(Math.random() * 3)) + ',"price":' + Math.floor(200 + Math.random() * 1500) + '}]',
          '更换' + (i % 2 ? '发动机' : '传动') + '部件', (i % 3) + 2, now]);
    }
  }

  // === 外修工单（3条）===
  const extFaults = [['球磨机', '轴承磨损'], ['浮选机', '叶轮损坏'], ['破碎机', '筛网破裂']];
  for (let e = 0; e < 3; e++) {
    db.run('INSERT OR REPLACE INTO external_repair_orders (order_no, department_id, user_id, repair_shop_id, vehicle_name, fault_description, status, quote_amount, parts_cost, labor_cost, hours_cost, approved_at, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)',
      ['EWO-0608' + (e + 1), (e % 3) + 1, 3 + e, (e % 2) + 1, extFaults[e][0], extFaults[e][1], 'accepted', 5000 + e * 3000, 2000 + e * 1000, 1500 + e * 800, 800 + e * 400, now, now]);
  }

  // === 派车（12条）===
  const applicants = ['张三', '李四', '王五'];
  const depts = ['第一选矿厂重机班', '第二选矿厂重机班', '甲玛乡尾矿库重机班', '巨龙铜业采矿场'];
  const vtypes = ['挖掘机', '装载机', '推土机', '矿用卡车'];
  const locations = ['一号采矿区', '二号采矿区', '一号排土场', 'K28路段', '驱龙第一选矿厂', '知不拉铜多金属矿'];
  const purposes = ['矿石装车', '废石清运', '道路平整', '材料运输', '设备吊装', '边坡修整'];
  for (let m = 0; m < 12; m++) {
    const startH = 7 + Math.floor(Math.random() * 3);
    const endH = startH + 8 + Math.floor(Math.random() * 4);
    const hours = endH - startH;
    const rate = 250 + Math.floor(Math.random() * 200);
    const st = m < 9 ? 'completed' : 'assigned';
    db.run('INSERT INTO machinery_applications (application_no, applicant_id, applicant_name, applicant_dept, vehicle_type, work_location, scheduled_start, scheduled_end, status, assigned_vehicle_id, assigned_driver_id, working_hours, hourly_rate, total_cost, work_purpose, created_at) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
      ['MA-0608' + (m + 1), 3 + (m % 3), applicants[m % 3], depts[m % 4], vtypes[m % 4], locations[m % 6],
        '2026-06-0' + (3 + Math.floor(m / 4)) + ' 0' + startH + ':00', '2026-06-0' + (3 + Math.floor(m / 4)) + ' ' + endH + ':00',
        st, (m % 4) + 1, 3 + (m % 3), st === 'completed' ? hours : 0, rate, st === 'completed' ? hours * rate : 0, purposes[m % 6], now]);
  }

  // === 点检工时（20条）===
  const dates = ['2026-06-03', '2026-06-04', '2026-06-05', '2026-06-06', '2026-06-07', '2026-06-08'];
  for (let d = 0; d < 20; d++) {
    const sh = 3000 + Math.floor(Math.random() * 8000);
    const eh = sh + 8 + Math.floor(Math.random() * 4);
    db.run('INSERT INTO daily_inspections (vehicle_id, driver_id, inspection_date, oil_level, coolant_level, appearance, tire_condition, overall_status, start_hours, end_hours, fuel_amount, notes) VALUES (?,?,?,?,?,?,?,?,?,?,?,?)',
      [(d % 4) + 1, 3 + (d % 3), dates[d % 6], ['normal', 'normal', 'low'][d % 3], ['normal', 'normal', 'normal'][d % 3],
        ['normal', 'normal', 'damaged'][d % 3], ['normal', 'worn', 'normal'][d % 3], ['normal', 'normal', 'abnormal'][d % 3],
        sh, eh, 30 + Math.floor(Math.random() * 150), d % 5 === 0 ? '异常记录' : (d % 3 === 0 ? '正常' : '')]);
  }

  // === 考勤（15条）===
  for (let a = 0; a < 15; a++) {
    const otStart = a % 4 === 0 ? '18:00' : '';
    const otEnd = a % 4 === 0 ? '2' + (1 + Math.floor(Math.random() * 3)) + ':00' : '';
    const otHours = a % 4 === 0 ? 3 + Math.floor(Math.random() * 3) : 0;
    db.run('INSERT OR REPLACE INTO driver_attendance (driver_id, attendance_date, attendance_symbol, overtime_start, overtime_end, overtime_hours, overtime_location) VALUES (?,?,?,?,?,?,?)',
      [3 + (a % 3), dates[a % 6], ['√', '√', '△'][a % 3], otStart, otEnd, otHours, otHours > 0 ? locations[a % 6] : '']);
  }

  // === 配件（8条库存+6条领用）===
  const partList = [
    ['机油滤芯', 'OIL-001', 25, '个', 250],
    ['液压密封圈', 'SEAL-003', 8, '套', 800],
    ['柴油滤清器', 'FUEL-002', 15, '个', 180],
    ['空气滤芯', 'AIR-004', 20, '个', 120],
    ['刹车片', 'BRAKE-005', 6, '套', 650],
    ['履带板', 'TRACK-006', 4, '块', 3200],
    ['液压油', 'OIL-H-007', 12, '桶', 450],
    ['轴承座', 'BRG-008', 3, '个', 1800],
  ];
  for (let p = 0; p < partList.length; p++) {
    db.run('INSERT OR IGNORE INTO parts_inventory (part_name, part_code, quantity, unit, unit_price) VALUES (?,?,?,?,?)', partList[p]);
  }
  for (let r = 0; r < 6; r++) {
    db.run('INSERT INTO parts_requisitions (user_id, part_id, vehicle_id, quantity, reason, status, created_at) VALUES (?,?,?,?,?,?,?)',
      [3 + (r % 3), (r % 8) + 1, (r % 4) + 1, 1 + Math.floor(Math.random() * 3), ['定期保养', '故障更换', '磨损更换'][r % 3], r < 4 ? 'completed' : 'pending', now]);
  }

  const data = db.export();
  fs.writeFileSync('data/mine_repair.db', Buffer.from(data));
  db.close();

  // Verify
  const SQL2 = await initSqlJs();
  const db2 = new SQL2.Database(fs.readFileSync('data/mine_repair.db'));
  console.log('=== Test Data Summary ===');
  console.log('  维修工单:', db2.exec('SELECT COUNT(*) FROM repair_orders')[0].values[0][0], '(含', db2.exec('SELECT COUNT(*) FROM repair_quotes')[0].values[0][0], '条报价)');
  console.log('  外修工单:', db2.exec('SELECT COUNT(*) FROM external_repair_orders')[0].values[0][0]);
  console.log('  派车记录:', db2.exec('SELECT COUNT(*) FROM machinery_applications WHERE assigned_vehicle_id IS NOT NULL')[0].values[0][0]);
  console.log('  点检记录:', db2.exec('SELECT COUNT(*) FROM daily_inspections')[0].values[0][0]);
  console.log('  考勤记录:', db2.exec('SELECT COUNT(*) FROM driver_attendance')[0].values[0][0]);
  console.log('  配件库存:', db2.exec('SELECT COUNT(*) FROM parts_inventory')[0].values[0][0], '种');
  console.log('  配件领用:', db2.exec('SELECT COUNT(*) FROM parts_requisitions')[0].values[0][0]);
  db2.close();
})();
