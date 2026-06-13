const http = require('http');

const BASE = 'http://localhost:3000';
let TOKEN = '';
let DISP_TOKEN = '';
let DRIVER_TOKEN = '';
let FAIL = 0, PASS = 0;
const RESULTS = [];

function req(method, path, body, auth) {
  return new Promise((resolve, reject) => {
    const url = new URL(BASE + path);
    const opts = {
      hostname: url.hostname, port: url.port, path: url.pathname + url.search,
      method, headers: { 'Content-Type': 'application/json' }
    };
    if (auth) opts.headers['Authorization'] = 'Bearer ' + auth;
    const r = http.request(opts, (res) => {
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => {
        const raw = Buffer.concat(chunks).toString();
        try { resolve({ code: res.statusCode, body: JSON.parse(raw), raw }); }
        catch(e) { resolve({ code: res.statusCode, body: null, raw }); }
      });
    });
    r.on('error', e => reject(e));
    if (body) r.write(JSON.stringify(body));
    r.end();
  });
}

async function test(name, fn) {
  try {
    const ok = await fn();
    if (ok) { PASS++; RESULTS.push('✅ ' + name); }
    else { FAIL++; RESULTS.push('❌ ' + name); }
  } catch(e) {
    FAIL++; RESULTS.push('💥 ' + name + ': ' + e.message);
  }
}

async function run() {
  console.log('===========================================');
  console.log('  总调度室综合管理系统 — 全量测试');
  console.log('  ' + new Date().toISOString().replace('T',' ').slice(0,19));
  console.log('===========================================\n');

  // ===== 0. 登录 =====
  console.log('【0. 获取各角色Token】');
  await test('管理员登录', async () => {
    const r = await req('POST','/api/auth/login',{phone:'13900000000',password:'123456'});
    if (r.code===200 && r.body?.data?.token) { TOKEN = r.body.data.token; return true; }
    return false;
  });
  await test('调度员登录', async () => {
    const r = await req('POST','/api/auth/login',{phone:'13900000123',password:'123456'});
    if (r.code===200) { DISP_TOKEN = r.body.data.token; return true; }
    return false;
  });
  await test('驾驶员登录', async () => {
    const r = await req('POST','/api/auth/login',{phone:'13900000001',password:'123456'});
    if (r.code===200) { DRIVER_TOKEN = r.body.data.token; return true; }
    return false;
  });
  await test('科级审批登录', async () => {
    const r = await req('POST','/api/auth/login',{phone:'13900000099',password:'123456'});
    return r.code===200;
  });
  await test('错误密码拒绝', async () => {
    const r = await req('POST','/api/auth/login',{phone:'13900000000',password:'WRONG'});
    return r.code===401 || r.body?.code===401;
  });

  // ===== 1. 车辆管理 =====
  console.log('【1. 车辆管理】2项');
  await test('车辆列表(GET /api/vehicles)', async () => {
    const r = await req('GET','/api/vehicles',null,TOKEN);
    return r.code===200 && Array.isArray(r.body?.data) && r.body.data.length >= 4;
  });
  await test('车辆编辑+删除', async () => {
    const edit = await req('PUT','/api/admin/vehicles/1',{vehicle_type:'挖掘机-改'},TOKEN);
    const delCheck = await req('DELETE','/api/admin/vehicles/999',null,TOKEN);
    return edit.code===200 && delCheck.code===200;
  });

  // ===== 2. 内部维修 =====
  console.log('【2. 内部维修】2项');
  await test('全部维修单', async () => {
    const r = await req('GET','/api/repair/all-orders',null,TOKEN);
    return r.code===200;
  });
  await test('创建报修单', async () => {
    const r = await req('POST','/api/repair/report',{
      vehicle_id:1, fault_description:'测试报修', vehicle_name:'测试车'
    },DRIVER_TOKEN);
    return r.code===200;
  });

  // ===== 3. 点检 =====
  console.log('【3. 点检】1项');
  await test('今日点检汇总', async () => {
    const r = await req('GET','/api/inspection/today-summary',null,TOKEN);
    return r.code===200;
  });

  // ===== 4. 工程机械派车 =====
  console.log('【4. 工程机械派车】2项');
  await test('待指派列表', async () => {
    const r = await req('GET','/api/machinery/pending-list',null,DISP_TOKEN);
    return r.code===200 && Array.isArray(r.body?.data);
  });
  await test('全部用车申请', async () => {
    const r = await req('GET','/api/machinery/list-all',null,TOKEN);
    return r.code===200;
  });

  // ===== 5. 天气预警 ★ =====
  console.log('【5. 天气预警】8项');
  await test('8区域含坐标', async () => {
    const r = await req('GET','/api/weather/zones',null,TOKEN);
    const zones = r.body?.data || [];
    return zones.length===8 && zones.every(z => z.latitude && z.longitude);
  });
  await test('天气仪表盘(实时数据)', async () => {
    const r = await req('GET','/api/weather/dashboard',null,TOKEN);
    const zones = r.body?.data?.zones || [];
    return zones.length===8 && zones.some(z => (z.latestData||[]).length > 0);
  });
  await test('阈值配置', async () => {
    const r = await req('GET','/api/weather/thresholds',null,TOKEN);
    return r.code===200 && (r.body?.data||[]).length >= 24;
  });
  await test('预警字典', async () => {
    const r = await req('GET','/api/weather/dict',null,TOKEN);
    return r.code===200 && r.body?.data?.weatherTypes;
  });
  await test('IoT传感器数据上报', async () => {
    const r = await req('POST','/api/weather/data/ingest',{
      items:[{zone_code:'ZONE-001',data_type:'rainfall',value:5.5,unit:'mm/h'}]
    },null);
    return r.code===200;
  });
  await test('调度区域检查(无预警)', async () => {
    const r = await req('POST','/api/weather/check-zone',{zone_id:1},TOKEN);
    return r.code===200 && !r.body?.data?.blocked;
  });
  // 注入暴雨超标数据触发红色预警
  await test('注入超标数据触发红色预警', async () => {
    const r = await req('POST','/api/weather/data/ingest',{
      items:[{zone_code:'ZONE-001',data_type:'rainfall',value:85.0,unit:'mm/h'}]
    },null);
    return r.code===200;
  });
  await test('规则引擎生成预警', async () => {
    // 规则引擎每5分钟运行一次，手动触发
    const { execSync } = require('child_process');
    await new Promise(r => setTimeout(r, 2000));
    const w = await req('GET','/api/weather/warnings/active',null,TOKEN);
    const warnings = w.body?.data || [];
    const hasRed = warnings.some(x => x.level==='red' && x.zone_id===1);
    return warnings.length > 0 && hasRed;
  });

  // ===== 6. 管理员 =====
  console.log('【6. 管理功能】3项');
  await test('管理仪表盘', async () => {
    const r = await req('GET','/api/admin/dashboard',null,TOKEN);
    return r.code===200 && r.body?.data?.totalVehicles > 0;
  });
  await test('系统统计', async () => {
    const r = await req('GET','/api/admin/stats',null,TOKEN);
    return r.code===200;
  });
  await test('月度费用统计', async () => {
    const r = await req('GET','/api/admin/monthly-cost-stats',null,TOKEN);
    return r.code===200;
  });

  // ===== 7. 安全&隐患 =====
  console.log('【7. 安全与隐患】2项');
  await test('安全报告', async () => {
    const r = await req('GET','/api/safety/reports',null,TOKEN);
    return r.code===200;
  });
  await test('隐患列表', async () => {
    const r = await req('GET','/api/hazards/list',null,TOKEN);
    return r.code===200;
  });

  // ===== 8. 通知&题库 =====
  console.log('【8. 通知+题库+核算】4项');
  await test('通知列表', async () => {
    const r = await req('GET','/api/notifications',null,TOKEN);
    return r.code===200;
  });
  await test('标记全部已读', async () => {
    const r = await req('PUT','/api/notifications/read-all',null,TOKEN);
    return r.code===200;
  });
  await test('题库列表', async () => {
    const r = await req('GET','/api/quiz/list',null,TOKEN);
    return r.code===200;
  });
  await test('单车核算', async () => {
    const r = await req('GET','/api/ledger/list',null,TOKEN);
    return r.code===200;
  });

  // ===== 9. 权限 =====
  console.log('【9. 权限控制】3项');
  await test('驾驶员被拒管理接口', async () => {
    const r = await req('GET','/api/admin/dashboard',null,DRIVER_TOKEN);
    return r.code!==200 || r.body?.code!==200;
  });
  await test('无效token返回401', async () => {
    const r = await req('GET','/api/vehicles',null,'bad_token');
    return r.code===401 || r.body?.code===401;
  });
  await test('无token被拦截', async () => {
    const r = await req('GET','/api/vehicles',null,null);
    return r.code===401 || r.body?.code===401;
  });

  // ===== 10. 前端 =====
  console.log('【10. 前端资源】3项');
  await test('首页HTML', async () => {
    const r = await req('GET','/','','');
    return r.raw && r.raw.includes('天气预警');
  });
  await test('weather.js模块', async () => {
    const r = await req('GET','/modules/weather.js','','');
    return r.raw && r.raw.includes('showWeatherDashboard');
  });
  await test('index.html完整', async () => {
    const r = await req('GET','/index.html','','');
    return r.raw && r.raw.length > 150000;
  });

  // ===== 汇总 =====
  console.log('\n===========================================');
  RESULTS.forEach(r => console.log(r));
  console.log('===========================================');
  const total = PASS + FAIL;
  console.log('模块: 10 | 测试项: ' + total + ' | ✅ 通过: ' + PASS + ' | ❌ 失败: ' + FAIL);
  console.log('通过率: ' + Math.round(PASS/total*100) + '%');
  console.log('===========================================');

  // 模块汇总
  console.log('\n模块通过情况:');
  const mods = [
    ['认证',0,1,5],['车辆',6,7],['维修',8,9],['点检',10,10],
    ['派车',11,12],['天气',13,20],['管理',21,23],['安全',24,25],
    ['通知题库',26,29],['权限',30,32],['前端',33,35]
  ];
  mods.forEach(([name,start,end]) => {
    const items = RESULTS.slice(start, end+1);
    const ok = items.filter(i => i.startsWith('✅')).length;
    const all = items.length;
    console.log('  ' + (ok===all?'✅':'❌') + ' ' + name + ': ' + ok + '/' + all);
  });

  process.exit(FAIL > 0 ? 1 : 0);
}

run().catch(e => { console.error('FATAL:', e.message); process.exit(2); });
