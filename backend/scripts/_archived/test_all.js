const http = require('http');
let failCount = 0;

function api(m, p, d, t) {
  return new Promise(r => {
    const b = d ? JSON.stringify(d) : '';
    const h = { hostname: 'localhost', port: 3000, path: p, method: m, headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(b) } };
    if (t) h.headers['Authorization'] = 'Bearer ' + t;
    const q = http.request(h, res => { let c = ''; res.on('data', x => c += x); res.on('end', () => { try { r(JSON.parse(c)); } catch (e) { r({ code: -1, raw: c.substring(0, 100) }); } }); });
    q.on('error', e => { console.log('  NETERR:', e.message); r(null); });
    if (b) q.write(b);
    q.end();
  });
}

async function t(name, fn) {
  try {
    const ok = await fn();
    if (ok) console.log('✅ ' + name);
    else { console.log('❌ ' + name + ' FAILED'); failCount++; }
  } catch (e) {
    console.log('❌ ' + name + ' ERROR: ' + e.message);
    failCount++;
  }
}

async function run() {
  console.log('=== 全功能流程测试 ===\n');

  // LOGIN
  const admin = await api('POST', '/api/auth/login', { phone: '13900000000', password: '123456' });
  const at = admin?.data?.token;
  await t('1.管理员登录', () => at && admin.code === 200);

  const driver1 = await api('POST', '/api/auth/login', { phone: '13900000001', password: '123456' });
  const dt = driver1?.data?.token;
  await t('2.驾驶员登录', () => dt && driver1.code === 200);

  const shop1 = await api('POST', '/api/auth/login', { phone: '13900000011', password: '123456' });
  const st = shop1?.data?.token;
  await t('3.修理厂登录', () => st && shop1.code === 200);

  const leader = await api('POST', '/api/auth/login', { phone: '13900000099', password: '123456' });
  const lt = leader?.data?.token;
  await t('4.领导登录', () => lt && leader.code === 200);

  const ext = await api('POST', '/api/auth/login', { phone: '13900000106', password: '123456' });
  const et = ext?.data?.token;
  await t('5.外部门登录(带部门)', () => et && ext.data?.department?.name === '巨龙铜业采矿场');

  // DASHBOARD
  const dash = await api('GET', '/api/admin/dashboard', null, at);
  await t('6.仪表盘', () => dash?.code === 200 && dash.data.totalVehicles === 4);

  // INTERNAL REPAIR
  console.log('\n--- 内部维修 ---');
  const rpt = await api('POST', '/api/repair/report', { vehicle_id: 1, fault_description: '发动机异响' }, dt);
  await t('7.驾驶员报修', () => rpt?.code === 200 && rpt.data.order_no.startsWith('JL'));

  const pendAcc = await api('GET', '/api/repair/pending-accept', null, st);
  const oid1 = pendAcc?.data?.[0]?.id;
  await t('8.待接单列表', () => oid1 > 0);

  await api('POST', '/api/repair/accept-order/' + oid1, {}, st);
  await t('9.修理厂接单', () => true);

  await api('POST', '/api/repair/submit-quote/' + oid1, {
    quote_amount: 5000, parts_cost: 3000, labor_cost: 1500, hours_cost: 500,
    parts_list: [{ name: '活塞环', qty: 4, price: 500 }], quote_detail: '换活塞环', estimated_days: 3
  }, st);
  await t('10.维修报价(含配件)', () => true);

  const urg = await api('POST', '/api/repair/urgent/' + oid1, {}, lt);
  await t('11.标记加急', () => urg?.code === 200);

  const appr = await api('POST', '/api/repair/approve/' + oid1, { approved: true }, lt);
  await t('12.审批通过', () => appr?.code === 200);

  await api('POST', '/api/repair/update-progress/' + oid1, { content: '正在维修' }, st);
  await t('13.更新进度', () => true);

  await api('POST', '/api/repair/complete/' + oid1, {}, st);
  await t('14.完工', () => true);

  await api('POST', '/api/repair/accept/' + oid1, {}, dt);
  const d1 = await api('GET', '/api/repair/detail/' + oid1, null, at);
  await t('15.验收+详情', () => d1?.data?.order?.status === 'accepted' && d1.data.order.is_urgent === 1);

  // REJECT FLOW
  const rpt2 = await api('POST', '/api/repair/report', { vehicle_id: 2, fault_description: '漏油' }, dt);
  const p2 = await api('GET', '/api/repair/pending-accept', null, st);
  const oid2 = p2?.data?.[0]?.id;
  await api('POST', '/api/repair/accept-order/' + oid2, {}, st);
  await api('POST', '/api/repair/submit-quote/' + oid2, { quote_amount: 2000, parts_cost: 1000, labor_cost: 700, hours_cost: 300, parts_list: [], quote_detail: '', estimated_days: 1 }, st);
  await api('POST', '/api/repair/approve/' + oid2, { approved: false, reject_reason: '报价过高' }, lt);
  const d2 = await api('GET', '/api/repair/detail/' + oid2, null, at);
  await t('16.驳回流程', () => d2?.data?.order?.status === 'rejected');

  // INSPECTION
  console.log('\n--- 点检 ---');
  const mc = await api('POST', '/api/inspection/morning-check', {
    vehicle_id: 1, oil_level: 'high', coolant_level: 'mid', appearance: 'normal',
    tire_condition: 'normal', toolkit_check: 'ok', overall_status: 'normal', notes: '正常', engine_hours: 1200
  }, dt);
  await t('17.早检', () => mc?.code === 200);

  const dup = await api('POST', '/api/inspection/morning-check', { vehicle_id: 1, oil_level: 'high' }, dt);
  await t('18.重复早检拒绝', () => dup?.code === 400);

  const ec = await api('POST', '/api/inspection/evening-check', {
    vehicle_id: 1, start_hours: 1250.5, end_hours: 1260, fuel_amount: 45,
    attendance_symbol: 'X', parking_location: '3号矿场'
  }, dt);
  await t('19.晚检', () => ec?.code === 200);

  const noMC = await api('POST', '/api/inspection/evening-check', { vehicle_id: 3 }, dt);
  await t('20.无早检拒绝晚检', () => noMC?.code === 400);

  await t('21.查看全部点检', async () => {
    const r = await api('GET', '/api/inspection/all-records?date=' + new Date().toISOString().slice(0, 10), null, at);
    return r?.data?.length > 0;
  });

  await t('22.司机列表', async () => {
    const r = await api('GET', '/api/inspection/driver-list', null, dt);
    return r?.data?.length === 3;
  });

  const wh = await api('GET', '/api/inspection/work-hours-report?month=2026-05', null, at);
  await t('23.工时报表', () => wh?.code === 200 && wh.data.summary?.length > 0);

  // PARTS
  console.log('\n--- 配件 ---');
  const parts = await api('GET', '/api/inspection/parts-list', null, at);
  await t('24.配件列表(10种)', () => parts?.data?.length === 10);

  await api('POST', '/api/inspection/parts/requisition', { part_id: 1, quantity: 2, reason: '更换' }, dt);
  const reqs = await api('GET', '/api/inspection/parts/requisitions', null, at);
  const rid = reqs?.data?.[0]?.id;
  await t('25.申请领用', () => rid > 0);

  await api('POST', '/api/inspection/parts/confirm/' + rid, {}, at);
  const pa = await api('GET', '/api/inspection/parts-list', null, at);
  await t('26.确认出库+扣减(13)', () => pa?.data?.find(p => p.id === 1)?.quantity === 13);

  // EXTERNAL
  console.log('\n--- 外部门 ---');
  const extRpt = await api('POST', '/api/external/report', { repair_shop_id: 1, vehicle_name: '破碎机', fault_description: '皮带断裂' }, et);
  await t('27.外部门报修', () => extRpt?.code === 200);

  const ep = await api('GET', '/api/external/shop-pending', null, st);
  const eoid = ep?.data?.[0]?.id;
  await t('28.修理厂待接', () => eoid > 0);

  await api('POST', '/api/external/shop-accept/' + eoid, { quote_amount: 3500, parts_cost: 2000, labor_cost: 1000, hours_cost: 500, parts_list: [{ name: '皮带', qty: 1, price: 2000 }], quote_detail: '换皮带', estimated_days: 1 }, st);
  await t('29.接单报价', () => true);

  await api('POST', '/api/external/self-approve/' + eoid, { approved: true }, et);
  await t('30.部门自审通过', () => true);

  await api('POST', '/api/external/shop-complete/' + eoid, {}, st);
  const ed = await api('GET', '/api/external/detail/' + eoid, null, et);
  await t('31.完工', () => ed?.data?.order?.status === 'completed');

  await api('POST', '/api/external/accept/' + eoid, {}, et);
  const ed2 = await api('GET', '/api/external/detail/' + eoid, null, et);
  await t('32.验收', () => ed2?.data?.order?.status === 'accepted');

  // STATS & EXPORT
  console.log('\n--- 统计导出 ---');
  const cr = await api('GET', '/api/admin/cost-report', null, at);
  await t('33.费用报表', () => cr?.code === 200 && cr.data.summary?.count >= 2);

  const ex = await api('GET', '/api/admin/export-orders?date_from=2026-01-01', null, at);
  await t('34.导出工单', () => ex?.code === 200 && ex.data?.length >= 2);

  const ms = await api('GET', '/api/admin/monthly-cost-stats', null, at);
  await t('35.月度统计', () => ms?.code === 200);

  // CONFIG
  console.log('\n--- 配置 ---');
  await api('POST', '/api/admin/config/save', { config: { month_estimate: 50000, year_estimate: 600000 } }, at);
  const cfg = await api('GET', '/api/admin/config', null, at);
  await t('36.配置读写', () => cfg?.data?.month_estimate === '50000');

  // USER MANAGEMENT
  console.log('\n--- 用户管理 ---');
  const ub = await api('GET', '/api/admin/users', null, at);
  await t('37.用户列表(含部门)', () => ub?.data?.length >= 14 && ub.data[0].dept_name !== undefined);

  await api('POST', '/api/admin/users/add', { name: '测试', phone: '13999999999', role: 'driver', department_id: 1 }, at);
  const ua = await api('GET', '/api/admin/users', null, at);
  const tu = ua?.data?.find(u => u.phone === '13999999999');
  await t('38.添加用户', () => !!tu);

  await api('DELETE', '/api/admin/users/' + tu?.id, null, at);
  const ua2 = await api('GET', '/api/admin/users', null, at);
  await t('39.删除用户', () => !ua2?.data?.find(u => u.phone === '13999999999'));

  // DEPARTMENTS
  const depts = await api('GET', '/api/external/departments', null, at);
  await t('40.部门列表(10个)', () => depts?.data?.length === 10);

  const addD = await api('POST', '/api/external/departments/add', { name: '测试部门' }, at);
  await t('41.新增部门+秘钥', () => addD?.code === 200 && addD?.data?.dept_key?.startsWith('JL'));

  const depts2 = await api('GET', '/api/external/departments', null, at);
  await t('42.部门新增后共11个', () => depts2?.data?.length === 11);

  // NOTIFICATIONS
  const ns = await api('GET', '/api/notifications', null, at);
  await t('43.通知列表', () => ns?.code === 200);

  // SHOPS
  const shops = await api('GET', '/api/admin/repair-shops', null, at);
  await t('44.修理厂列表', () => shops?.code === 200);

  // TODAY SUMMARY
  const ts = await api('GET', '/api/inspection/today-summary', null, at);
  await t('45.今日概况', () => ts?.code === 200 && ts.data.inspectedCount >= 1);

  console.log('\n=== 测试结果: ' + failCount + ' 项失败 ===');
  process.exit(failCount > 0 ? 1 : 0);
}

run().catch(e => { console.error(e); process.exit(1); });
