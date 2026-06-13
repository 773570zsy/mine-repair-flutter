const http = require('http');
function api(m,p,d,t){return new Promise(r=>{const b=d?JSON.stringify(d):'';const h={hostname:'localhost',port:3000,path:p,method:m,headers:{'Content-Type':'application/json','Content-Length':Buffer.byteLength(b)}};if(t)h.headers.Authorization='Bearer '+t;const q=http.request(h,res=>{let c='';res.on('data',x=>c+=x);res.on('end',()=>r(JSON.parse(c)))});q.on('error',()=>r(null));if(b)q.write(b);q.end()})}

async function seed(){
  console.log('=== 灌入数据 ===\n');

  const a=await api('POST','/api/auth/login',{phone:'13900000000',password:'123456'});
  const at=a.data.token;
  const d1=await api('POST','/api/auth/login',{phone:'13900000001',password:'123456'});
  const dt1=d1.data.token;
  const d2=await api('POST','/api/auth/login',{phone:'13900000002',password:'123456'});
  const dt2=d2.data.token;
  const d3=await api('POST','/api/auth/login',{phone:'13900000003',password:'123456'});
  const dt3=d3.data.token;
  const s1=await api('POST','/api/auth/login',{phone:'13900000011',password:'123456'});
  const s1t=s1.data.token;
  const s2=await api('POST','/api/auth/login',{phone:'13900000022',password:'123456'});
  const s2t=s2.data.token;
  const ldr=await api('POST','/api/auth/login',{phone:'13900000099',password:'123456'});
  const lt=ldr.data.token;
  const extAppr=await api('POST','/api/auth/login',{phone:'13900000088',password:'123456'});
  const eat=extAppr.data.token;

  // 先分配驾驶员到总调度室部门(id=1)
  await api('POST','/api/admin/config/save',{config:{dummy:1}},at); // no-op

  // ====== 内部维修：每月4-6单，共6个月(1月-6月) ======
  console.log('--- 内部维修 ---');
  const faultDescs = [
    '发动机异响，动力明显下降，检查发现活塞环磨损严重',
    '液压系统压力不稳，举升大臂时抖动异常',
    '空调制冷效果差，出风口温度高于标准值',
    '刹车系统失灵报警，制动距离明显延长',
    '变速箱换挡顿挫，3档升4档时有打齿声',
    '底盘异响，行走时右侧履带有金属摩擦声',
    '电路故障，仪表盘多个警告灯同时亮起',
    '机油消耗异常，每500小时消耗超过标准值3倍',
    '转向系统沉重，方向盘回正力不足',
    '排气冒黑烟，涡轮增压器异响',
    '冷却系统漏水，水温持续偏高',
    '起动机无力，冷车启动困难',
    '工作装置联动不协调，多路阀卡滞',
    '发电机不充电，电瓶频繁亏电',
    '回转支承异响，回转时有明显间隙',
    '油缸活塞杆拉伤，密封圈漏油',
    '斗齿磨损严重超出使用标准',
    '张紧油缸泄压，履带松弛打滑',
    '驾驶室减震失效，操作舒适度极差',
    '传动轴万向节磨损，高速行驶抖动',
    '水泵密封损坏，冷却液循环不畅',
    '燃油系统进气，发动机间歇性熄火',
    '破碎锤打击力不足，氮气压力偏低',
    '液压油箱呼吸器堵塞，系统背压过高'
  ];

  const partsPool = [
    ['活塞环','缸套','机油','密封垫','O型圈'],
    ['液压油管','密封圈','多路阀修理包','液压油','高压滤芯'],
    ['空调压缩机','制冷剂','冷凝器','膨胀阀','干燥瓶'],
    ['刹车片','刹车油','制动总泵','刹车分泵','制动盘'],
    ['变速箱油','离合器片','同步器','轴承','密封垫'],
    ['支重轮','拖链轮','驱动齿','履带板','张紧弹簧'],
    ['线束总成','传感器','仪表盘','保险丝','继电器'],
    ['机油泵','机油滤芯','缸垫','气门油封','正时链条'],
    ['转向泵','转向油缸','方向机','液压油','滤芯'],
    ['涡轮增压器','空气滤芯','排气管垫','机油管','卡箍'],
    ['水泵','水箱','节温器','冷却液','水管'],
    ['起动机','电瓶','点火开关','线束','继电器'],
    ['多路阀','先导阀','液压泵','油管','密封件'],
    ['发电机','电压调节器','皮带','电瓶线','保险盒'],
    ['回转支承','回转马达','回转减速器','黄油','密封圈'],
    ['油缸活塞杆','密封组件','导向套','防尘圈','液压油'],
    ['斗齿','齿座','销轴','卡簧','垫片'],
    ['张紧油缸','黄油嘴','履带板螺栓','支重轮螺栓','密封件'],
    ['驾驶室减震器','座椅','操纵杆','密封条','空调滤芯'],
    ['传动轴','万向节','过桥轴承','十字轴','黄油'],
    ['水泵总成','水封','轴承','叶轮','密封圈'],
    ['输油泵','柴油滤芯','油水分离器','高压油管','喷油嘴'],
    ['氮气瓶','换向阀','活塞','密封圈','钎杆'],
    ['呼吸器','液压油滤芯','回油滤芯','吸油滤芯','空气滤芯']
  ];

  const costs = [5200,3800,2400,6500,8900,4200,3100,7500,4600,5800,2900,1800,6700,3500,9100,4400,1600,5300,2800,7200,2100,3900,8600,3400];
  const shops = [s1t, s2t, s1t, s2t, s1t, s2t, s1t, s2t, s1t, s2t, s1t, s2t, s1t, s2t, s1t, s2t, s1t, s2t, s1t, s2t, s1t, s2t, s1t, s2t];
  const drivers = [dt1, dt2, dt3, dt1, dt2, dt3, dt1, dt2, dt3, dt1, dt2, dt3, dt1, dt2, dt3, dt1, dt2, dt3, dt1, dt2, dt3, dt1, dt2, dt3];
  const vehicles = [1,2,3,4,1,3,2,4,1,2,3,4,1,3,2,4,1,2,3,4,1,2,3,4];

  let orderCount = 0;
  for (let i = 0; i < 24; i++) {
    const vid = vehicles[i];
    const driver = drivers[i];
    const shop = shops[i];
    const cost = costs[i];
    const parts = partsPool[i].map((name, j) => ({name, qty: Math.ceil(Math.random()*4)+1, price: Math.floor(cost*0.1*(j+1)/5)}));
    const pc = parts.reduce((s,p)=>s+p.qty*p.price, 0);
    const lc = Math.floor(cost*0.25);
    const hc = cost - pc - lc;

    const r = await api('POST','/api/repair/report',{vehicle_id:vid,fault_description:faultDescs[i]},driver);
    const p = await api('GET','/api/repair/pending-accept',null,shop);
    if (!p?.data?.[0]) { console.log('  skip',i); continue; }
    const oid = p.data[0].id;
    await api('POST','/api/repair/accept-order/'+oid,{},shop);
    await api('POST','/api/repair/submit-quote/'+oid,{
      quote_amount:cost,parts_cost:pc,labor_cost:lc,hours_cost:hc,
      parts_list:parts,quote_detail:'',estimated_days:Math.ceil((i%5)+1)
    },shop);

    // 随机加急
    if (i%7===0) await api('POST','/api/repair/urgent/'+oid,{},lt);

    // 大部分通过，偶尔驳回
    if (i%8===0) {
      await api('POST','/api/repair/approve/'+oid,{approved:false,reject_reason:'报价偏高需重新评估'},lt);
    } else {
      await api('POST','/api/repair/approve/'+oid,{approved:true},lt);
      await api('POST','/api/repair/update-progress/'+oid,{content:'已拆解检查，配件已到货，正在更换维修中...'},shop);
      await api('POST','/api/repair/complete/'+oid,{},shop);
      await api('POST','/api/repair/accept/'+oid,{},driver);
      orderCount++;
    }
    console.log('  '+faultDescs[i].substring(0,20)+'... OK');
  }

  // 手动设置审批月份（1月-6月分布）
  console.log('\n设置审批日期分布...');
  const initSqlJs = require('sql.js');
  const fs = require('fs');
  const SQL = await initSqlJs();
  const buf = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/data/mine_repair.db');
  const db = new SQL.Database(buf);
  const quotes = db.exec("SELECT id FROM repair_quotes WHERE approved_at IS NOT NULL ORDER BY id");
  if (quotes[0]) {
    const ids = quotes[0].values;
    const months = ['2026-01','2026-02','2026-03','2026-04','2026-05','2026-06'];
    ids.forEach((row, i) => {
      const m = months[Math.floor(i / (ids.length / months.length))] || months[5];
      const d = String(Math.floor(Math.random()*25)+1).padStart(2,'0');
      db.run('UPDATE repair_quotes SET approved_at=? WHERE id=?', [`${m}-${d} 10:00:00`, row[0]]);
      db.run('UPDATE repair_orders SET created_at=?, updated_at=? WHERE id IN (SELECT order_id FROM repair_quotes WHERE id=?)',
        [`${m}-${d} 08:00:00`, `${m}-${d} 16:00:00`, row[0]]);
    });
  }
  const buf2 = db.export();
  fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/data/mine_repair.db', Buffer.from(buf2));
  console.log('审批日期已分布到1-6月');

  // ====== 外部维修 ======
  console.log('\n--- 外部维修 ---');
  const extDepts = [4,5,6,7,8,9,10]; // 7个外部门
  const extPhones = ['13900000101','13900000102','13900000103','13900000104','13900000105','13900000106','13900000107'];
  const extVehicles = ['球磨机','浮选机','破碎机','磁选机','推土机','装载机','挖掘机','分级机','搅拌槽','过滤机','浓缩机','给矿机'];
  const extFaults = [
    '主轴轴承异响，振动值超标',
    '叶轮磨损严重，选矿效率下降',
    '传动皮带断裂，设备停机',
    '磁系退磁，精矿品位下降',
    '履带张紧失效，行走跑偏',
    '液压缸漏油，铲斗举升无力',
    '斗齿断裂，铲装效率下降',
    '槽体衬板脱落，搅拌不均匀',
    '滤布破损，过滤效果差',
    '耙架变形，底流浓度不稳',
    '给矿漏斗堵塞，下料不畅'
  ];
  const extCosts = [4500,2800,6200,3800,5500,7200,3400,2100,4100,5600,1900];

  for (let i = 0; i < 11; i++) {
    const eu = await api('POST','/api/auth/login',{phone:extPhones[i%7],password:'123456'});
    const et = eu.data.token;
    const sid = i%2===0?1:2;
    await api('POST','/api/external/report',{repair_shop_id:sid,vehicle_name:extVehicles[i],fault_description:extFaults[i]},et);
    const ep = await api('GET','/api/external/shop-pending',null,i%2===0?s1t:s2t);
    if (!ep?.data?.[0]) { console.log('  skip',i); continue; }
    const eoid = ep.data[0].id;
    const ecost = extCosts[i];
    await api('POST','/api/external/shop-accept/'+eoid,{
      quote_amount:ecost,parts_cost:Math.floor(ecost*0.55),labor_cost:Math.floor(ecost*0.3),
      hours_cost:Math.floor(ecost*0.15),parts_list:[{name:'配件',qty:1,price:Math.floor(ecost*0.55)}],
      quote_detail:'',estimated_days:Math.ceil((i%4)+1)
    },i%2===0?s1t:s2t);
    await api('POST','/api/external/approve/'+eoid,{approved:true},eat);
    await api('POST','/api/external/shop-complete/'+eoid,{},i%2===0?s1t:s2t);
    await api('POST','/api/external/accept/'+eoid,{},et);
    console.log('  '+extVehicles[i]+' '+extFaults[i].substring(0,15)+'... OK');
  }

  // ====== 点检数据：随机生成 ======
  console.log('\n--- 点检数据 ---');
  const days = ['2026-06-01','2026-06-02','2026-06-03','2026-06-04','2026-06-05','2026-06-06','2026-06-07',
                '2026-06-08','2026-06-09','2026-06-10','2026-06-11','2026-06-12','2026-06-13','2026-06-14',
                '2026-06-15','2026-06-16','2026-06-17','2026-06-18','2026-06-19','2026-06-20'];
  const atts = ['X','Y','Z','V','G','△','△/X','△/Y','△/Z','△/V'];
  for (const day of days) {
    for (const did of [dt1,dt2]) {
      try {
        // Morning check on random vehicle
        const mv = Math.ceil(Math.random()*4);
        try { await api('POST','/api/inspection/morning-check',{
          vehicle_id:mv,oil_level:Math.random()>0.2?'high':'mid',
          coolant_level:Math.random()>0.1?'high':'mid',
          appearance:Math.random()>0.3?'normal':(Math.random()>0.5?'damaged':'dirty'),
          tire_condition:Math.random()>0.2?'normal':'worn',
          toolkit_check:Math.random()>0.1?'ok':'missing',
          overall_status:Math.random()>0.15?'normal':'abnormal',
          notes:Math.random()>0.6?'一切正常':(Math.random()>0.5?'轻微磨损':'需关注'),
          engine_hours:1200+Math.floor(Math.random()*500)
        },did); } catch(e){}

        // Evening check
        const ev = Math.ceil(Math.random()*4);
        const sh = 1250+Math.random()*50;
        try { await api('POST','/api/inspection/evening-check',{
          vehicle_id:ev,start_hours:sh,end_hours:sh+8+Math.random()*4,
          fuel_amount:30+Math.random()*30,attendance_symbol:atts[Math.floor(Math.random()*10)],
          parking_location:['1号矿场','2号矿场','3号矿场','修理车间'][Math.floor(Math.random()*4)]
        },did); } catch(e){}
      } catch(e){}
    }
  }
  console.log('点检数据生成完成');

  // ====== 配件领用 ======
  console.log('\n--- 配件领用 ---');
  for (let i = 1; i <= 5; i++) {
    await api('POST','/api/inspection/parts/requisition',{part_id:i,quantity:Math.ceil(Math.random()*3),reason:'日常维修更换'},dt1);
    await api('POST','/api/inspection/parts/requisition',{part_id:i+5,quantity:Math.ceil(Math.random()*2),reason:'设备检修'},dt2);
  }
  const reqs = await api('GET','/api/inspection/parts/requisitions',null,at);
  for (const r of (reqs?.data||[]).slice(0, 8)) {
    try { await api('POST','/api/inspection/parts/confirm/'+r.id,{},at); } catch(e){}
  }
  console.log('配件领用+出库完成');

  console.log('\n=== 数据灌入完成 ===');
  console.log('内部维修: '+orderCount+' 单已完成验收');
  console.log('外部维修: 11 单');
  console.log('点检记录: 80 条(20天×2人×早晚检)');
  console.log('配件领用: 10 条, 已出库 8 条');
}
seed().catch(e=>console.error(e));
