const http = require('http');
let fail = 0, pass = 0;

function api(m, p, d, t) {
  return new Promise(r => {
    const b = d ? JSON.stringify(d) : '';
    const h = { hostname: 'localhost', port: 3000, path: p, method: m, headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(b) } };
    if (t) h.headers['Authorization'] = 'Bearer ' + t;
    const q = http.request(h, res => { let c = ''; res.on('data', x => c += x); res.on('end', () => { try { var j = JSON.parse(c); r(j); } catch (e) { r(null); } }); });
    q.on('error', () => r(null));
    if (b) q.write(b);
    q.end();
  });
}

function ok(r) { return r && r.code === 200; }

async function test(name, result) {
  if (result) { console.log('✅ ' + name); pass++; }
  else { console.log('❌ ' + name); fail++; }
}

async function run() {
  console.log('═══ 全功能E2E测试 ═══\n');

  // Login
  const a = await api('POST', '/api/auth/login', { phone: '13900000000', password: '123456' });
  const at = a?.data?.token;
  await test('管理员登录', ok(a));

  const d = await api('POST', '/api/auth/login', { phone: '13900000001', password: '123456' });
  const dt = d?.data?.token;
  await test('驾驶员登录', ok(d));

  const s = await api('POST', '/api/auth/login', { phone: '13900000011', password: '123456' });
  const st = s?.data?.token;
  await test('修理厂登录', ok(s));

  const l = await api('POST', '/api/auth/login', { phone: '13900000099', password: '123456' });
  const lt = l?.data?.token;
  await test('科级审批登录', ok(l));

  const ea = await api('POST', '/api/auth/login', { phone: '13900000088', password: '123456' });
  const eat = ea?.data?.token;
  await test('外部审批员', ok(ea));

  const e = await api('POST', '/api/auth/login', { phone: '13900000106', password: '123456' });
  const et = e?.data?.token;
  await test('外部部门登录', ok(e) && e.data.department?.name === '巨龙铜业采矿场');

  // Dashboard
  const dash = await api('GET', '/api/admin/dashboard', null, at);
  await test('仪表盘', ok(dash) && dash.data.totalVehicles > 0);

  // Vehicles
  const vehs = await api('GET', '/api/vehicles', null, at);
  await test('车辆列表', ok(vehs) && vehs.data.length > 0);

  const addV = await api('POST', '/api/admin/vehicles/import', { vehicles: [{ plate_number: 'TEST-01', vehicle_type: '测试', model: 'T1', initial_engine_hours: 1000, maintenance_interval_hours: 500 }] }, at);
  await test('添加车辆', ok(addV));

  const vAll = await api('GET', '/api/vehicles', null, at);
  const tv = vAll.data.find(v => v.plate_number === 'TEST-01');
  if (tv) {
    const dv = await api('DELETE', '/api/admin/vehicles/' + tv.id, null, at);
    await test('删除车辆', ok(dv));
  }

  // Full repair cycle
  console.log('\n── 维修流程 ──');
  const r = await api('POST', '/api/repair/report', { vehicle_id: 1, fault_description: '测试故障' }, dt);
  await test('报修', ok(r));

  const p = await api('GET', '/api/repair/pending-accept', null, st);
  const oid = p?.data?.[0]?.id;
  await test('待接单', !!oid);

  if (oid) {
    await api('POST', '/api/repair/accept-order/' + oid, {}, st);
    await api('POST', '/api/repair/submit-quote/' + oid, { quote_amount: 3000, parts_cost: 1500, labor_cost: 1000, hours_cost: 500, parts_list: [{ name: '零件', qty: 2, price: 500 }], quote_detail: '', estimated_days: 1 }, st);
    await test('报价', true);

    await api('POST', '/api/repair/urgent/' + oid, {}, lt);
    await test('加急', true);

    await api('POST', '/api/repair/approve/' + oid, { approved: true }, lt);
    await test('审批通过', true);

    await api('POST', '/api/repair/complete/' + oid, {}, st);
    await api('POST', '/api/repair/accept/' + oid, {}, dt);
    const det = await api('GET', '/api/repair/detail/' + oid, null, at);
    await test('验收完成', det?.data?.order?.status === 'accepted');
  }

  // Reject
  await api('POST', '/api/repair/report', { vehicle_id: 2, fault_description: '驳回测试' }, dt);
  const p2 = await api('GET', '/api/repair/pending-accept', null, st);
  const oid2 = p2?.data?.[0]?.id;
  if (oid2) {
    await api('POST', '/api/repair/accept-order/' + oid2, {}, st);
    await api('POST', '/api/repair/submit-quote/' + oid2, { quote_amount: 1000, parts_cost: 500, labor_cost: 300, hours_cost: 200, parts_list: [], quote_detail: '', estimated_days: 1 }, st);
    await api('POST', '/api/repair/approve/' + oid2, { approved: false, reject_reason: '太贵' }, lt);
    const d2 = await api('GET', '/api/repair/detail/' + oid2, null, at);
    await test('驳回', d2?.data?.order?.status === 'rejected');
  }

  // Inspection
  console.log('\n── 点检 ──');
  const mc = await api('POST', '/api/inspection/morning-check', { vehicle_id: 1, oil_level: 'high', coolant_level: 'mid', appearance: 'normal', tire_condition: 'normal', toolkit_check: 'ok', overall_status: 'normal' }, dt);
  await test('早检', ok(mc));

  const dup = await api('POST', '/api/inspection/morning-check', { vehicle_id: 1 }, dt);
  await test('重复早检拒绝', dup?.code === 400);

  const ec = await api('POST', '/api/inspection/evening-check', { vehicle_id: 1, start_hours: 1250, end_hours: 1260, fuel_amount: 45, attendance_symbol: 'X', parking_location: '3号矿场' }, dt);
  await test('晚检', ok(ec));

  const nm = await api('POST', '/api/inspection/evening-check', { vehicle_id: 3 }, dt);
  await test('无早检拒晚检', nm?.code === 400);

  // Parts
  console.log('\n── 配件 ──');
  const parts = await api('GET', '/api/inspection/parts-list', null, at);
  await test('配件列表', ok(parts) && parts.data.length >= 10);

  const pr = await api('POST', '/api/inspection/parts/requisition', { part_id: 1, quantity: 2, reason: '测试' }, dt);
  await test('领用申请', ok(pr));

  const reqs = await api('GET', '/api/inspection/parts/requisitions', null, at);
  const rid = reqs?.data?.find(r => r.status === 'pending')?.id;
  if (rid) {
    await api('POST', '/api/inspection/parts/confirm/' + rid, {}, at);
    const pa = await api('GET', '/api/inspection/parts-list', null, at);
    const p1 = pa?.data?.find(p => p.id === 1);
    await test('出库扣减', p1?.quantity < 15);
  }

  // External
  console.log('\n── 外部维修 ──');
  const er = await api('POST', '/api/external/report', { repair_shop_id: 1, vehicle_name: '测试设备', fault_description: '故障' }, et);
  await test('外部报修', ok(er));

  const ep = await api('GET', '/api/external/shop-pending', null, st);
  const eoid = ep?.data?.[0]?.id;
  if (eoid) {
    await api('POST', '/api/external/shop-accept/' + eoid, { quote_amount: 2000, parts_cost: 1000, labor_cost: 600, hours_cost: 400, parts_list: [], quote_detail: '', estimated_days: 1 }, st);
    await test('外部接单', true);

    const eap = await api('GET', '/api/external/pending-approval', null, eat);
    await test('外部审批员可见', ok(eap) && eap.data.length >= 1);

    await api('POST', '/api/external/approve/' + eoid, { approved: true }, eat);
    await api('POST', '/api/external/shop-complete/' + eoid, {}, st);
    await api('POST', '/api/external/accept/' + eoid, {}, et);
    const ed = await api('GET', '/api/external/detail/' + eoid, null, at);
    await test('外部验收', ed?.data?.order?.status === 'accepted');
  }

  // Stats & Export
  console.log('\n── 统计导出 ──');
  const cr = await api('GET', '/api/admin/cost-report', null, at);
  await test('费用报表', ok(cr) && cr.data.items.length > 0);

  const ex = await api('GET', '/api/admin/export-orders?date_from=2026-01-01', null, at);
  await test('导出工单', ok(ex) && ex.data.length > 0);

  const ms = await api('GET', '/api/admin/monthly-cost-stats', null, at);
  await test('月度统计', ok(ms));

  const wh = await api('GET', '/api/inspection/work-hours-report?month=2026-06', null, at);
  await test('工时报表', ok(wh));

  // Users & Depts
  console.log('\n── 用户部门 ──');
  const us = await api('GET', '/api/admin/users', null, at);
  await test('用户列表', ok(us) && us.data.length > 10);

  const addU = await api('POST', '/api/admin/users/add', { name: '测试', phone: '13999999999', role: 'driver' }, at);
  await test('添加用户', ok(addU));
  const us2 = await api('GET', '/api/admin/users', null, at);
  const tu = us2?.data?.find(u => u.phone === '13999999999');
  if (tu) { await api('DELETE', '/api/admin/users/' + tu.id, null, at); await test('删除用户', true); }

  const depts = await api('GET', '/api/external/departments', null, at);
  await test('部门列表', ok(depts) && depts.data.length >= 10);

  // Config
  await api('POST', '/api/admin/config/save', { config: { month_estimate: 50000, low_stock_threshold: 3 } }, at);
  const cfg = await api('GET', '/api/admin/config', null, at);
  await test('配置读写', cfg?.data?.low_stock_threshold === '3');

  console.log('\n═══ 结果: ' + pass + '通过 / ' + fail + '失败 ═══');
  process.exit(fail > 0 ? 1 : 0);
}
run().catch(e => { console.error(e); process.exit(1); });
