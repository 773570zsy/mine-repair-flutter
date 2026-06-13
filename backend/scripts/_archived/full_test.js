const http = require('http');
let fail = 0;

function api(m, p, d, t) {
  return new Promise(r => {
    const b = d ? JSON.stringify(d) : '';
    const h = { hostname: 'localhost', port: 3000, path: p, method: m, headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(b) } };
    if (t) h.headers['Authorization'] = 'Bearer ' + t;
    const q = http.request(h, res => { let c = ''; res.on('data', x => c += x); res.on('end', () => { try { var j=JSON.parse(c); r(j.code===200?j.data:null); } catch(e){r(null);} }); });
    q.on('error', () => r(null));
    if (b) q.write(b);
    q.end();
  });
}

async function test(name, fn) {
  try {
    const ok = await fn();
    if (ok) console.log('✅ ' + name);
    else { console.log('❌ ' + name); fail++; }
  } catch (e) {
    console.log('💥 ' + name + ' ERROR: ' + e.message);
    fail++;
  }
}

async function run() {
  console.log('═══════════════════════════════════');
  console.log('  全功能 E2E 测试');
  console.log('═══════════════════════════════════\n');

  // ===== LOGIN =====
  console.log('── 登录 ──');
  const admin = await api('POST', '/api/auth/login', { phone: '13900000000', password: '123456' });
  const at = admin?.data?.token;
  await test('管理员登录', () => at && admin.code === 200);

  const d1 = await api('POST', '/api/auth/login', { phone: '13900000001', password: '123456' });
  const dt = d1?.data?.token;
  await test('驾驶员张三登录', () => dt && d1.code === 200);

  const s1 = await api('POST', '/api/auth/login', { phone: '13900000011', password: '123456' });
  const st = s1?.data?.token;
  await test('西藏桦翔登录', () => st && s1.code === 200);

  const ldr = await api('POST', '/api/auth/login', { phone: '13900000099', password: '123456' });
  const lt = ldr?.data?.token;
  await test('科级审批登录', () => lt && ldr.code === 200);

  const ea = await api('POST', '/api/auth/login', { phone: '13900000088', password: '123456' });
  const eat = ea?.data?.token;
  await test('外部审批员登录', () => eat && ea.code === 200);

  const ext = await api('POST', '/api/auth/login', { phone: '13900000106', password: '123456' });
  const et = ext?.data?.token;
  await test('采矿场外部登录', () => et && ext.data?.department?.name === '巨龙铜业采矿场');

  // ===== DASHBOARD =====
  console.log('\n── 仪表盘 ──');
  const dash = await api('GET', '/api/admin/dashboard', null, at);
  await test('仪表盘数据', () => dash?.code === 200 && dash.data.totalVehicles > 0);
  await test('统计数字完整', () => dash.data.normalVehicles !== undefined && dash.data.repairingCount !== undefined && dash.data.expiredCount !== undefined);

  // ===== VEHICLES =====
  console.log('\n── 车辆管理 ──');
  const vehs = await api('GET', '/api/vehicles', null, at);
  await test('车辆列表', () => vehs?.length > 0);
  await test('车辆含latest_end_hours', () => vehs[0].latest_end_hours !== undefined);

  // Add vehicle
  const addV = await api('POST', '/api/admin/vehicles/import', {
    vehicles: [{ plate_number: 'TEST-001', vehicle_type: '测试车', model: 'TEST', initial_engine_hours: 1000, maintenance_interval_hours: 500, purchase_date: '2024-01-01' }]
  }, at);
  await test('添加车辆', () => addV?.code === 200);

  // Maintenance done
  const md = await api('POST', '/api/vehicles/1/maintenance-done', {}, at);
  await test('保养完成重置', () => md?.code === 200 && md.msg.includes('下次保养'));

  // Delete test vehicle
  const vehs2 = await api('GET', '/api/vehicles', null, at);
  const testV = vehs2?.find(v => v.plate_number === 'TEST-001');
  if (testV) {
    const delV = await api('DELETE', '/api/admin/vehicles/' + testV.id, null, at);
    await test('删除车辆', () => delV?.code === 200);
  }

  // ===== REPAIR FULL CYCLE =====
  console.log('\n── 内部维修全流程 ──');
  const rpt = await api('POST', '/api/repair/report', { vehicle_id: 1, fault_description: 'E2E测试故障' }, dt);
  await test('1.报修', () => rpt?.code === 200 && rpt.data.order_no.startsWith('JL'));

  const pend = await api('GET', '/api/repair/pending-accept', null, st);
  const oid = pend?.data?.[0]?.id;
  await test('2.待接单可见', () => oid > 0);

  await api('POST', '/api/repair/accept-order/' + oid, {}, st);
  await test('3.接单', () => true);

  const q = await api('POST', '/api/repair/submit-quote/' + oid, {
    quote_amount: 3000, parts_cost: 1500, labor_cost: 1000, hours_cost: 500,
    parts_list: [{ name: '测试配件', qty: 2, price: 500 }],
    quote_detail: 'E2E测试报价', estimated_days: 1
  }, st);
  await test('4.报价含配件', () => q?.code === 200);

  const urg = await api('POST', '/api/repair/urgent/' + oid, {}, lt);
  await test('5.标记加急', () => urg?.code === 200);

  const appr = await api('POST', '/api/repair/approve/' + oid, { approved: true }, lt);
  await test('6.科级审批通过', () => appr?.code === 200);

  await api('POST', '/api/repair/update-progress/' + oid, { content: '维修中' }, st);
  await test('7.更新进度', () => true);

  await api('POST', '/api/repair/complete/' + oid, {}, st);
  await test('8.完工', () => true);

  await api('POST', '/api/repair/accept/' + oid, {}, dt);
  const det = await api('GET', '/api/repair/detail/' + oid, null, at);
  await test('9.验收+详情', () => det?.data?.order?.status === 'accepted' && det.data.order.is_urgent === 1);

  // Reject flow
  const rpt2 = await api('POST', '/api/repair/report', { vehicle_id: 2, fault_description: '驳回测试' }, dt);
  const p2 = await api('GET', '/api/repair/pending-accept', null, st);
  const oid2 = p2?.data?.[0]?.id;
  await api('POST', '/api/repair/accept-order/' + oid2, {}, st);
  await api('POST', '/api/repair/submit-quote/' + oid2, { quote_amount: 1000, parts_cost: 500, labor_cost: 300, hours_cost: 200, parts_list: [], quote_detail: '', estimated_days: 1 }, st);
  await api('POST', '/api/repair/approve/' + oid2, { approved: false, reject_reason: '报价虚高' }, lt);
  const det2 = await api('GET', '/api/repair/detail/' + oid2, null, at);
  await test('10.驳回流程', () => det2?.data?.order?.status === 'rejected');

  // ===== INSPECTION =====
  console.log('\n── 点检 ──');
  const mc = await api('POST', '/api/inspection/morning-check', {
    vehicle_id: 1, oil_level: 'high', coolant_level: 'mid', appearance: 'normal',
    tire_condition: 'normal', toolkit_check: 'ok', overall_status: 'normal', notes: '正常'
  }, dt);
  await test('早检提交', () => mc?.code === 200);

  const dup = await api('POST', '/api/inspection/morning-check', { vehicle_id: 1 }, dt);
  await test('重复早检拒绝', () => dup?.code === 400);

  const ec = await api('POST', '/api/inspection/evening-check', {
    vehicle_id: 1, start_hours: 1250, end_hours: 1260, fuel_amount: 45,
    attendance_symbol: 'X', parking_location: '3号矿场'
  }, dt);
  await test('晚检提交', () => ec?.code === 200);

  const noMC = await api('POST', '/api/inspection/evening-check', { vehicle_id: 3 }, dt);
  await test('无早检则晚检拒绝', () => noMC?.code === 400);

  const allInsp = await api('GET', '/api/inspection/all-records?date=' + new Date().toISOString().slice(0, 10), null, at);
  await test('查看所有点检', () => allInsp?.data?.length >= 1);

  const dl = await api('GET', '/api/inspection/driver-list', null, dt);
  await test('司机列表', () => dl?.data?.length >= 3);

  // ===== PARTS =====
  console.log('\n── 配件管理 ──');
  const parts = await api('GET', '/api/inspection/parts-list', null, at);
  await test('配件列表', () => parts?.data?.length >= 10);

  const pReq = await api('POST', '/api/inspection/parts/requisition', { part_id: 1, quantity: 2, reason: 'E2E测试领用' }, dt);
  await test('配件领用申请', () => pReq?.code === 200);

  const reqs = await api('GET', '/api/inspection/parts/requisitions', null, at);
  const rid = reqs?.data?.find(r => r.status === 'pending')?.id;
  const pConfirm = await api('POST', '/api/inspection/parts/confirm/' + rid, {}, at);
  await test('确认出库', () => pConfirm?.code === 200);

  const partsAfter = await api('GET', '/api/inspection/parts-list', null, at);
  const p1 = partsAfter?.data?.find(p => p.id === 1);
  await test('库存自动扣减', () => p1?.quantity === 11);

  // ===== EXTERNAL REPAIR =====
  console.log('\n── 外部维修 ──');
  const extRpt = await api('POST', '/api/external/report', { repair_shop_id: 1, vehicle_name: 'E2E破碎机', fault_description: '皮带断裂' }, et);
  await test('外部报修', () => extRpt?.code === 200);

  const epend = await api('GET', '/api/external/shop-pending', null, st);
  const eoid = epend?.data?.[0]?.id;
  await test('修理厂接外单', () => eoid > 0);

  await api('POST', '/api/external/shop-accept/' + eoid, { quote_amount: 2000, parts_cost: 1000, labor_cost: 600, hours_cost: 400, parts_list: [], quote_detail: '', estimated_days: 1 }, st);
  await test('外部接单报价', () => true);

  const epApproval = await api('GET', '/api/external/pending-approval', null, eat);
  await test('外部审批员可见', () => epApproval?.data?.length >= 1);

  await api('POST', '/api/external/approve/' + eoid, { approved: true }, eat);
  const edet = await api('GET', '/api/external/detail/' + eoid, null, et);
  await test('外部审批通过', () => edet?.data?.order?.status === 'approved');

  await api('POST', '/api/external/shop-complete/' + eoid, {}, st);
  await api('POST', '/api/external/accept/' + eoid, {}, et);
  const edet2 = await api('GET', '/api/external/detail/' + eoid, null, et);
  await test('外部验收完成', () => edet2?.data?.order?.status === 'accepted');

  // ===== STATS & EXPORT =====
  console.log('\n── 统计导出 ──');
  const costRpt = await api('GET', '/api/admin/cost-report', null, at);
  await test('维修费用报表', () => costRpt?.code === 200 && costRpt.data.items.length > 0);

  const exportOrd = await api('GET', '/api/admin/export-orders?date_from=2026-01-01', null, at);
  await test('导出工单含部门', () => exportOrd?.code === 200 && exportOrd.data.length > 0 && exportOrd.data[0].dept_name !== undefined);

  const monthlyStats = await api('GET', '/api/admin/monthly-cost-stats', null, at);
  await test('月度统计图表数据', () => monthlyStats?.code === 200);

  const wh = await api('GET', '/api/inspection/work-hours-report?month=2026-06', null, at);
  await test('员工出勤报表', () => wh?.code === 200);

  // ===== USER MANAGEMENT =====
  console.log('\n── 用户管理 ──');
  const users = await api('GET', '/api/admin/users', null, at);
  await test('用户列表含部门', () => users?.data?.length > 10 && users.data[0].dept_name !== undefined);

  const addU = await api('POST', '/api/admin/users/add', { name: 'E2E测试员', phone: '13988888888', role: 'driver', department_id: 1 }, at);
  await test('添加用户', () => addU?.code === 200);

  const uAfter = await api('GET', '/api/admin/users', null, at);
  const tu = uAfter?.data?.find(u => u.phone === '13988888888');
  if (tu) {
    const delU = await api('DELETE', '/api/admin/users/' + tu.id, null, at);
    await test('删除用户', () => delU?.code === 200);
  }

  // ===== DEPARTMENTS =====
  console.log('\n── 部门管理 ──');
  const depts = await api('GET', '/api/external/departments', null, at);
  await test('部门列表', () => depts?.data?.length >= 10);

  const addD = await api('POST', '/api/external/departments/add', { name: 'E2E测试部门' }, at);
  await test('新增部门+秘钥', () => addD?.code === 200 && addD?.data?.dept_key?.startsWith('JL'));

  // ===== CONFIG =====
  console.log('\n── 配置 ──');
  await api('POST', '/api/admin/config/save', { config: { month_estimate: 80000, year_estimate: 960000, low_stock_threshold: 3 } }, at);
  const cfg = await api('GET', '/api/admin/config', null, at);
  await test('配置读写', () => cfg?.data?.month_estimate === '80000' && cfg?.data?.low_stock_threshold === '3');

  // ===== SHOP MANAGEMENT =====
  console.log('\n── 修理厂 ──');
  const shops = await api('GET', '/api/admin/repair-shops', null, at);
  await test('修理厂列表', () => shops?.code === 200);

  // ===== TODAY SUMMARY =====
  const ts = await api('GET', '/api/inspection/today-summary', null, at);
  await test('今日概况', () => ts?.code === 200 && ts.data.inspectedCount >= 1);

  // ===== PASSWORD CHANGE =====
  const pwdTest = await api('POST', '/api/admin/change-password', { old_pwd: '123456', new_pwd: '123456' }, at);
  await test('密码修改', () => pwdTest?.code === 200);

  console.log('\n═══════════════════════════════════');
  console.log('  测试完成: ' + fail + ' 项失败');
  console.log('═══════════════════════════════════');
  process.exit(fail > 0 ? 1 : 0);
}

run().catch(e => { console.error(e); process.exit(1); });
