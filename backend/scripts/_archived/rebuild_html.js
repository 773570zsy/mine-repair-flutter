// 重建完整 index.html - 保留CSS+HTML结构，替换JavaScript部分
const fs = require('fs');
const h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

// Find the script tag
const scriptStart = h.indexOf('<script>');
const scriptEnd = h.indexOf('</script>');
const before = h.substring(0, scriptStart + 8); // includes <script>
const after = h.substring(scriptEnd); // from </script> to end

// Build all JavaScript
const js = `
let TOKEN='',USER=null,LAST_DEPTS=[];
const API='/api',ROLE_MAP={driver:'驾驶员',repair_shop:'修理厂',leader:'科级审批',admin:'管理员',external:'外部门',external_approver:'外部审批'};
const STATUS_MAP={pending_accept:'待接单',pending_quote:'待报价',pending_approval:'待审批',approved:'已通过',rejected:'已驳回',repairing:'维修中',completed:'待验收',accepted:'已完成',cancelled:'已取消'};
const ST_TAG={pending_accept:'t-pending',pending_quote:'t-pending',pending_approval:'t-reject',approved:'t-progress',rejected:'t-reject',repairing:'t-progress',completed:'t-done',accepted:'t-done'};
const LEVEL_MAP={high:'高位',mid:'中位',low:'低位'},APPEAR_MAP={normal:'正常',damaged:'有损坏',dirty:'需清洁'},TIRE_MAP={normal:'正常',worn:'磨损',damaged:'损坏'};

function toast(m,t){var b=document.createElement('div');b.style.cssText='position:fixed;top:16px;right:16px;z-index:9999;padding:14px 24px;border-radius:8px;color:#fff;font-weight:600;font-size:15px;animation:slideIn .3s ease;max-width:350px;box-shadow:0 8px 24px rgba(0,0,0,.4);';b.style.background=t==='error'?'linear-gradient(135deg,#c0392b,#96281b)':'linear-gradient(135deg,#4a8f5a,#3d7349)';b.textContent=(t==='error'?'✕ ':'✓ ')+m;document.body.appendChild(b);setTimeout(function(){b.style.opacity='0';b.style.transition='opacity .3s';setTimeout(function(){b.remove()},300)},2000)}

async function api(url,opts){
  opts=opts||{};
  var hdr={'Content-Type':'application/json'};
  if(TOKEN)hdr['Authorization']='Bearer '+TOKEN;
  var r=await fetch(API+url,{headers:hdr,method:opts.method||'GET',body:opts.data?JSON.stringify(opts.data):undefined});
  var d=await r.json();
  if(d.code===401){doLogout();return null}
  if(d.code!==200){alert(d.msg||'操作失败');return null}
  return d.data;
}

// ===== LOGIN =====
async function doLogin(){
  var ph=document.getElementById('loginPhone').value.trim();
  var pw=document.getElementById('loginPwd').value.trim();
  if(!ph)return alert('请输入手机号');
  var d=await api('/auth/login',{method:'POST',data:{phone:ph,password:pw||'123456'}});
  if(!d)return;
  TOKEN=d.token;USER=d.user;
  localStorage.setItem('mp_token',TOKEN);localStorage.setItem('mp_user',JSON.stringify(USER));
  document.getElementById('loginPage').style.display='none';
  document.getElementById('mainPage').style.display='';
  document.getElementById('userArea').style.display='';
  document.getElementById('currentUser').textContent=USER.name+'（'+ROLE_MAP[USER.role]+'）';
  if(USER.role==='admin'){document.getElementById('roleFilter').style.display='';document.getElementById('roleFilter').innerHTML='<option value=\"\">管理员视角</option><option value=\"driver\">驾驶员视角</option><option value=\"repair_shop\">修理厂视角</option><option value=\"leader\">科级审批视角</option>'}
  if(Notification&&Notification.permission==='default')Notification.requestPermission();
  renderPage();updateClock();
}
function doLogout(){TOKEN='';USER=null;localStorage.clear();document.getElementById('loginPage').style.display='';document.getElementById('mainPage').style.display='none';document.getElementById('userArea').style.display='none'}
function changePwdAtLogin(){
  var ph=document.getElementById('loginPhone').value.trim();if(!ph)return alert('请先输入手机号');
  var old=prompt('请输入原密码（默认123456）：');if(old===null)return;
  var nw=prompt('请输入新密码（至少4位）：');if(!nw||nw.length<4)return alert('新密码至少4位');
  fetch('/api/auth/login',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({phone:ph,password:old||'123456'})}).then(function(r){return r.json()}).then(function(d){
    if(d.code!==200)return alert('原密码错误');
    return fetch('/api/admin/change-password',{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+d.data.token},body:JSON.stringify({old_pwd:old||'123456',new_pwd:nw})})
  }).then(function(r){return r.json()}).then(function(){alert('密码修改成功，请使用新密码登录')})
}
function switchRole(r){if(r){USER={...USER,role:r}}else{USER=JSON.parse(localStorage.getItem('mp_user'))}renderPage()}
function changePassword(){
  var old=prompt('请输入原密码（默认123456）：');if(old===null)return;
  var nw=prompt('请输入新密码（至少4位）：');if(!nw||nw.length<4)return alert('新密码至少4位');
  api('/admin/change-password',{method:'POST',data:{old_pwd:old,new_pwd:nw}}).then(function(){alert('密码修改成功请重新登录');doLogout()})
}

// ===== RENDER =====
function renderPage(){
  var r=USER.role||getRole();
  if(r==='driver')renderDriver();else if(r==='repair_shop')renderShop();
  else if(r==='leader')renderLeader();else if(r==='admin')renderAdmin();
  else if(r==='external')renderExternalDept();else if(r==='external_approver')renderExternalApprover();
}
function getRole(){return USER?USER.role:'driver'}

// ===== ADMIN DASHBOARD =====
async function renderAdmin(){
  var el=document.getElementById('mainPage');
  var dm=new Date().toISOString().slice(0,10);
  var [dashboard,summary,config,monthlyStats]=await Promise.all([api('/admin/dashboard'),api('/inspection/today-summary'),api('/admin/config'),api('/admin/monthly-cost-stats')]);
  el.innerHTML='<div class=\"layout\">'+
    '<div class=\"stats-grid\">'+
    '<div class=\"stat-item\" onclick=\"showVehiclesByStatus(\\'\\',\\'所有车辆\\')\" style=\"cursor:pointer\"><div class=\"stat-num\">'+dashboard.totalVehicles+'</div><div class=\"stat-label\">总车辆</div></div>'+
    '<div class=\"stat-item\" onclick=\"showVehiclesByStatus(\\'normal\\',\\'正常车辆\\')\" style=\"cursor:pointer\"><div class=\"stat-num\">'+dashboard.normalVehicles+'</div><div class=\"stat-label\">正常车辆</div></div>'+
    '<div class=\"stat-item\" onclick=\"showVehiclesByStatus(\\'repairing\\',\\'维修中车辆\\')\" style=\"cursor:pointer\"><div class=\"stat-num\" style=\"color:var(--danger)\">'+dashboard.repairingCount+'</div><div class=\"stat-label\">维修中</div></div>'+
    '<div class=\"stat-item\" onclick=\"showVehiclesByStatus(\\'expired\\',\\'保养过期车辆\\')\" style=\"cursor:pointer\"><div class=\"stat-num\" style=\"color:var(--warning)\">'+(dashboard.expiredCount||0)+'</div><div class=\"stat-label\">保养过期</div></div>'+
    '<div class=\"stat-item\" onclick=\"renderLeader()\" style=\"cursor:pointer\"><div class=\"stat-num\" style=\"color:var(--warning)\">'+dashboard.pendingApprovalCount+'</div><div class=\"stat-label\">待审批</div></div>'+
    '<div class=\"stat-item\"><div class=\"stat-num\">'+dashboard.monthCount+'</div><div class=\"stat-label\">本月报修</div></div>'+
    '<div class=\"stat-item\"><div class=\"stat-num\" style=\"color:var(--danger)\">¥'+dashboard.monthlyCost+'</div><div class=\"stat-label\">本月已维修费用</div></div>'+
    '<div class=\"stat-item\" style=\"display:flex;flex-direction:column;gap:8px\"><div onclick=\"editEstimate(\\'year_estimate\\',\\'本年度预估维修费用\\')\" style=\"cursor:pointer;flex:1\"><div class=\"stat-num\" style=\"color:#d48806;font-size:22px\" id=\"estYear\">¥'+(config.year_estimate||0)+'</div><div class=\"stat-label\" style=\"font-size:11px\">年度预估费用 ✎</div></div><div style=\"border-top:1px dashed #e0e0e0\"></div><div onclick=\"editEstimate(\\'month_estimate\\',\\'本月预估维修费用\\')\" style=\"cursor:pointer;flex:1\"><div class=\"stat-num\" style=\"color:#d48806;font-size:22px\" id=\"estMonth\">¥'+(config.month_estimate||0)+'</div><div class=\"stat-label\" style=\"font-size:11px\">本月预估费用 ✎</div></div></div>'+
    '</div>'+
    (renderMonthlyChart(monthlyStats||[])||'')+
    '<div class=\"card\" style=\"border-left:3px solid var(--warning);margin-bottom:14px\"><div class=\"card-title\">⚠ 系统预警</div><div id=\"sysAlerts\" style=\"font-size:13px\">检测中...</div></div>'+
    '<div class=\"row3\">'+
    '<div class=\"card\" style=\"text-align:center;cursor:pointer\" onclick=\"showAdminVehicles()\"><h3>🚛</h3>车辆管理<br><span style=\"font-size:12px;color:var(--text2)\">录入/管理车辆</span></div>'+
    '<div class=\"card\" style=\"text-align:center;cursor:pointer\" onclick=\"showAdminUsers()\"><h3>👥</h3>人员管理<br><span style=\"font-size:12px;color:var(--text2)\">添加/查看用户</span></div>'+
    '<div class=\"card\" style=\"text-align:center;cursor:pointer\" onclick=\"renderLeader()\"><h3>📋</h3>全部维修工单<br><span style=\"font-size:12px;color:var(--text2)\">查看/追溯</span></div>'+
    '<div class=\"card\" style=\"text-align:center;cursor:pointer\" onclick=\"showCostReport()\"><h3>💰</h3>维修费用报表<br><span style=\"font-size:12px;color:var(--text2)\">修理厂结算明细</span></div>'+
    '<div class=\"card\" style=\"text-align:center;cursor:pointer\" onclick=\"showExportOrders()\"><h3>📥</h3>导出工单<br><span style=\"font-size:12px;color:var(--text2)\">导出维修数据</span></div>'+
    '<div class=\"card\" style=\"text-align:center;cursor:pointer\" onclick=\"showTodayInspDetail()\"><h3>✅</h3>点检记录<br><span style=\"font-size:12px;color:var(--text2)\">每日检查情况</span></div>'+
    '<div class=\"card\" style=\"text-align:center;cursor:pointer\" onclick=\"showRepairShops()\"><h3>🔧</h3>修理厂管理<br><span style=\"font-size:12px;color:var(--text2)\">管理外包修理厂</span></div>'+
    '<div class=\"card\" style=\"text-align:center;cursor:pointer\" onclick=\"showPartsManagement()\"><h3>📦</h3>配件管理<br><span style=\"font-size:12px;color:var(--text2)\">库存/领用/出库</span></div>'+
    '<div class=\"card\" style=\"text-align:center;cursor:pointer\" onclick=\"showAttendanceReport()\"><h3>⏱</h3>员工出勤信息<br><span style=\"font-size:12px;color:var(--text2)\">出勤筛选导出</span></div>'+
    '<div class=\"card\" style=\"text-align:center;cursor:pointer\" onclick=\"backupDB()\"><h3>💾</h3>数据备份<br><span style=\"font-size:12px;color:var(--text2)\">一键备份</span></div>'+
    '<div class=\"card\" style=\"text-align:center;cursor:pointer\" onclick=\"showOperationLogs()\"><h3>📝</h3>操作日志<br><span style=\"font-size:12px;color:var(--text2)\">系统操作追溯</span></div>'+
    '<div class=\"card\" style=\"text-align:center;cursor:pointer\" onclick=\"showDeptManagement()\"><h3>🏢</h3>外部门管理<br><span style=\"font-size:12px;color:var(--text2)\">部门/账号管理</span></div>'+
    '</div></div>';
  loadSystemAlerts();
}

// ===== DRIVER DASHBOARD =====
async function renderDriver(){
  var el=document.getElementById('mainPage'),today=new Date().toISOString().slice(0,10),sub=today.slice(0,7);
  el.innerHTML='<div class=\"layout\"><div class=\"stats-grid\" id=\"dashStats\"></div>'+
    '<div class=\"card\" style=\"border-left:3px solid var(--warning);margin-bottom:0\"><div id=\"maintAlerts\" style=\"font-size:12px;color:var(--warning)\">检测中...</div></div>'+
    '<div class=\"row2\"><div class=\"card\"><div class=\"card-title\">🔧 快速报修 <button class=\"btn btn-p btn-sm\" onclick=\"showReport()\">+ 报修</button></div><div id=\"recentOrders\">加载中...</div></div>'+
    '<div class=\"card\"><div class=\"card-title\">✅ 今日点检 <span style=\"font-size:12px;color:var(--text2)\">'+today+'</span></div><div id=\"todayCheck\">加载中...</div></div></div>'+
    '<div class=\"card\"><div class=\"card-title\">🚛 车辆状态总览</div><div id=\"vehicleStatus\">加载中...</div></div>'+
    '<div class=\"row2\"><div class=\"card\"><div class=\"card-title\">📋 今日考勤</div><div id=\"attCard\">加载中...</div></div>'+
    '<div class=\"card\"><div class=\"card-title\">⏰ 今日加班</div><div id=\"otCard\">加载中...</div></div></div></div>';
  loadDriverData(today,sub);loadSystemAlerts();loadAttendanceCard();
}

async function loadDriverData(today,month){
  try{
    var [allVehicles,orders,inspRecords]=await Promise.all([api('/vehicles'),api('/repair/my-orders'),api('/inspection/my-records?month='+month)]);
    var todayInsp=(inspRecords||[]).filter(function(r){return r.inspection_date===today});
    var recentOrders=(orders||[]).slice(0,4);
    var activeOrders=(orders||[]).filter(function(o){return['pending_accept','pending_quote','pending_approval','approved','repairing'].indexOf(o.status)>=0});
    document.getElementById('dashStats').innerHTML=
      '<div class=\"stat-item\" onclick=\"showVehiclesByStatus(\\'\\',\\'所有车辆\\')\" style=\"cursor:pointer\"><div class=\"stat-num\">'+(allVehicles||[]).length+'</div><div class=\"stat-label\">总车辆</div></div>'+
      '<div class=\"stat-item\"><div class=\"stat-num\">'+activeOrders.length+'</div><div class=\"stat-label\">进行中工单</div></div>'+
      '<div class=\"stat-item\"><div class=\"stat-num\" style=\"color:'+(todayInsp.length?'var(--success)':'var(--danger)')+'\">'+(todayInsp.length?'已完成':'未提交')+'</div><div class=\"stat-label\">今日点检</div></div>'+
      '<div class=\"stat-item\" onclick=\"showPartsRequisition()\" style=\"cursor:pointer\"><div class=\"stat-num\" style=\"color:var(--primary)\">🔧</div><div class=\"stat-label\">配件领用</div></div>'+
      '<div class=\"stat-item\" onclick=\"showQuiz()\" style=\"cursor:pointer\"><div class=\"stat-num\" style=\"color:var(--gold)\">📝</div><div class=\"stat-label\">每日一测</div></div>';
    document.getElementById('recentOrders').innerHTML=recentOrders.length?recentOrders.map(function(o){return '<div style=\"padding:8px 0;border-bottom:1px solid var(--border);cursor:pointer\" onclick=\"showOrderDetail('+o.id+')\"><div class=\"flex\"><span class=\"order-no\">'+o.order_no+'</span><span class=\"tag '+ST_TAG[o.status]+'\">'+STATUS_MAP[o.status]+'</span></div><div style=\"font-size:11px;color:var(--text2);margin-top:4px\">'+o.plate_number+' | '+o.created_at+'</div></div>'}).join(''):'<div class=\"empty\">暂无工单</div>';
    document.getElementById('todayCheck').innerHTML=
      '<div style=\"display:flex;gap:8px;margin-bottom:10px\"><button class=\"btn btn-p btn-sm\" onclick=\"showInspection(\\'morning\\')\">☀ 早检</button><button class=\"btn btn-o btn-sm\" onclick=\"showInspection(\\'evening\\')\">🌙 晚检</button></div>'+
      (todayInsp.length?todayInsp.map(function(r){return '<div style=\"padding:8px 0;border-bottom:1px solid var(--border)\"><span style=\"font-weight:500\">'+r.plate_number+'</span> <span class=\"tag '+(r.overall_status==='normal'?'t-done':'t-reject')+'\">'+(r.overall_status==='normal'?'正常':'异常')+'</span>'+'<br><span style=\"font-size:11px;color:var(--text2)\">油位:'+(LEVEL_MAP[r.oil_level]||'-')+' / 水位:'+(LEVEL_MAP[r.coolant_level]||'-')+' / 九样:'+(r.toolkit_check==='ok'?'✅':'❌')+'</span>'+((r.start_hours||r.fuel_amount)?'<br><span style=\"font-size:11px;color:var(--text2)\">工时:'+(r.start_hours||0)+'h→'+(r.end_hours||0)+'h 加油:'+(r.fuel_amount||0)+'L 停车:'+(r.parking_location||'-')+'</span>':'')+'</div>'}).join(''):'<div class=\"empty\">今日暂无点检记录</div>');
    var vsHtml='<table><tr><th>内部编号</th><th>类型</th><th>型号</th><th>车龄</th><th>当前工时</th><th>下次保养</th><th>状态</th></tr>';
    (allVehicles||[]).forEach(function(v){
      var age=v.purchase_date?((new Date()-new Date(v.purchase_date))/(365.25*86400000)).toFixed(1)+'年':'-';
      var curH=v.latest_end_hours||v.initial_engine_hours||0;
      var next=v.next_maintenance_hours||0;
      var remain=curH&&next?next-curH:999;
      var st=remain<0?'<span class=\"tag t-reject\">过期</span>':remain<50?'<span class=\"tag t-pending\">即将保养</span>':'<span class=\"tag t-done\">正常</span>';
      vsHtml+='<tr><td><b>'+v.plate_number+'</b></td><td>'+(v.vehicle_type||'-')+'</td><td>'+(v.model||'-')+'</td><td>'+age+'</td><td>'+curH+'h</td><td>'+next+'h</td><td>'+st+'</td></tr>'
    });
    vsHtml+='</table>';document.getElementById('vehicleStatus').innerHTML=vsHtml;
  }catch(e){console.error(e)}
}

// ===== SHOP DASHBOARD =====
async function renderShop(){
  var el=document.getElementById('mainPage');
  el.innerHTML='<div class=\"layout\"><div class=\"stats-grid\" id=\"shopStats\"></div><div class=\"card\"><div class=\"card-title\">📋 工单列表</div><div class=\"tabs\" id=\"shopTabs\"></div><div id=\"shopOrders\">加载中...</div></div></div>';
  loadShopData();
}
async function loadShopData(tab){
  tab=tab||'all';
  var [myOrders,pendingAccept]=await Promise.all([api('/repair/shop-orders'+(tab!=='all'?'?status='+tab:'')),api('/repair/pending-accept')]);
  myOrders=myOrders||[];pendingAccept=pendingAccept||[];
  var displayOrders=myOrders.slice();
  if(tab==='all'||tab==='pending_accept'){var myIds={};myOrders.forEach(function(o){myIds[o.id]=true});pendingAccept.forEach(function(o){if(!myIds[o.id])displayOrders.unshift(o)})}
  document.getElementById('shopStats').innerHTML=
    '<div class=\"stat-item\"><div class=\"stat-num\">'+displayOrders.length+'</div><div class=\"stat-label\">全部工单</div></div>'+
    '<div class=\"stat-item\"><div class=\"stat-num\" style=\"color:var(--danger)\">'+pendingAccept.length+'</div><div class=\"stat-label\">待接单</div></div>'+
    '<div class=\"stat-item\"><div class=\"stat-num\" style=\"color:var(--warning)\">'+myOrders.filter(function(o){return o.status==='pending_quote'}).length+'</div><div class=\"stat-label\">待报价</div></div>'+
    '<div class=\"stat-item\"><div class=\"stat-num\" style=\"color:var(--primary)\">'+myOrders.filter(function(o){return['approved','repairing'].indexOf(o.status)>=0}).length+'</div><div class=\"stat-label\">维修中</div></div>';
  var tabs=[{l:'全部',v:'all'},{l:'待接单',v:'pending_accept'},{l:'待报价',v:'pending_quote'},{l:'待审批',v:'pending_approval'},{l:'维修中',v:'repairing'},{l:'待验收',v:'completed'},{l:'已完成',v:'accepted'}];
  document.getElementById('shopTabs').innerHTML=tabs.map(function(t){return '<button class=\"tab '+(tab===t.v?'active':'')+'\" onclick=\"loadShopData(\\''+t.v+'\\')\">'+t.l+'</button>'}).join('');
  document.getElementById('shopOrders').innerHTML=displayOrders.length?'<table><tr><th>工单号</th><th>车辆</th><th>报修人</th><th>故障描述</th><th>状态</th><th>操作</th></tr>'+displayOrders.map(function(o){
    return '<tr><td class=\"order-no\" style=\"font-size:12px\">'+o.order_no+(o.is_urgent?' <span style=\"background:#ff4d4f;color:#fff;padding:1px 5px;border-radius:3px;font-size:10px\">急</span>':'')+'</td><td>'+o.plate_number+'</td><td>'+(o.driver_name||'-')+'</td><td style=\"max-width:120px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;font-size:12px\">'+(o.fault_description||'-')+'</td><td><span class=\"tag '+ST_TAG[o.status]+'\">'+STATUS_MAP[o.status]+'</span></td><td>'+actionBtns(o)+'</td></tr>'
  }).join('')+'</table>':'<div class=\"empty\">暂无工单</div>';
}
function actionBtns(o){
  var b='<button class=\"btn btn-sm btn-p\" onclick=\"showOrderDetail('+o.id+')\">详情</button>';
  if(o.status==='pending_accept')b+=' <button class=\"btn btn-sm btn-s\" onclick=\"acceptOrder('+o.id+')\">接单</button>';
  if(o.status==='pending_quote')b+=' <button class=\"btn btn-sm btn-s\" onclick=\"showQuote('+o.id+')\">报价</button>';
  if(o.status==='approved'||o.status==='repairing'){b+=' <button class=\"btn btn-sm btn-p\" onclick=\"updateProgress('+o.id+')\">进度</button>';b+=' <button class=\"btn btn-sm btn-s\" onclick=\"completeOrder('+o.id+')\">完工</button>'}
  return b;
}

// ===== LEADER DASHBOARD =====
async function renderLeader(){
  var el=document.getElementById('mainPage'),backBtn=USER.role==='admin'?'<div style=\"position:fixed;top:90px;left:16px;z-index:99\"><button class=\"btn btn-o btn-sm\" onclick=\"renderAdmin()\" style=\"background:var(--surface);box-shadow:0 2px 8px rgba(0,0,0,.3)\">← 返回管理后台</button></div>':'';
  var [dashboard,pending,monthlyStats,config,summary]=await Promise.all([api('/admin/dashboard'),api('/repair/pending-approval'),api('/admin/monthly-cost-stats'),api('/admin/config'),api('/inspection/today-summary')]);
  el.innerHTML='<div class=\"layout\">'+backBtn+
    '<div class=\"stats-grid\">'+
    '<div class=\"stat-item\" onclick=\"showVehiclesByStatus(\\'\\',\\'所有车辆\\')\" style=\"cursor:pointer\"><div class=\"stat-num\">'+dashboard.totalVehicles+'</div><div class=\"stat-label\">总车辆</div></div>'+
    '<div class=\"stat-item\" onclick=\"showVehiclesByStatus(\\'normal\\',\\'正常车辆\\')\" style=\"cursor:pointer\"><div class=\"stat-num\">'+dashboard.normalVehicles+'</div><div class=\"stat-label\">正常车辆</div></div>'+
    '<div class=\"stat-item\" onclick=\"showVehiclesByStatus(\\'repairing\\',\\'维修中车辆\\')\" style=\"cursor:pointer\"><div class=\"stat-num\" style=\"color:var(--danger)\">'+dashboard.repairingCount+'</div><div class=\"stat-label\">维修中</div></div>'+
    '<div class=\"stat-item\" onclick=\"showVehiclesByStatus(\\'expired\\',\\'保养过期车辆\\')\" style=\"cursor:pointer\"><div class=\"stat-num\" style=\"color:var(--warning)\">'+(dashboard.expiredCount||0)+'</div><div class=\"stat-label\">保养过期</div></div>'+
    '</div>'+
    '<div class=\"card\"><div class=\"card-title\">✍ 待审批报价 ('+(pending||[]).length+')</div><div id=\"pendingList\"></div></div>'+
    (renderMonthlyChart(monthlyStats||[])||'')+
    '<div class=\"card\"><div class=\"card-title\">📋 全部维修工单</div><div id=\"allOrdersList\">加载中...</div></div></div>';
  document.getElementById('pendingList').innerHTML=(pending||[]).length?pending.map(function(o){
    var ph='';try{var pp=JSON.parse(o.parts_list||'[]');if(pp.length){ph='<table style=\"margin:6px 0;font-size:12px;width:100%\"><tr><th>配件</th><th>数量</th><th>单价</th><th>小计</th></tr>';pp.forEach(function(p){ph+='<tr><td>'+p.name+'</td><td>'+p.qty+'</td><td>¥'+p.price+'</td><td>¥'+(p.qty*p.price)+'</td></tr>'});ph+='</table>'}}catch(e){}
    return '<div style=\"padding:12px;border:1px solid var(--warning);background:rgba(212,160,23,.08);border-radius:8px;margin-bottom:10px\"><div class=\"flex\"><span class=\"order-no\">'+o.order_no+'</span><span class=\"tag t-pending\">待审批</span></div><div>'+o.plate_number+'（'+o.vehicle_type+'）| 报修人:'+o.driver_name+' | 修理厂:'+o.repair_shop_name+'</div>'+ph+'<div style=\"margin:8px 0;display:flex;gap:12px;font-size:13px;color:var(--text2)\"><span>配件费: ¥'+(o.parts_cost||0)+'</span><span>人工费: ¥'+(o.labor_cost||0)+'</span><span>工时费: ¥'+(o.hours_cost||0)+'</span></div><div class=\"flex\"><span style=\"font-size:20px;font-weight:bold;color:var(--danger)\">¥'+o.quote_amount+'</span><span style=\"display:flex;gap:4px\"><button class=\"btn btn-s btn-sm\" onclick=\"approveOrder('+o.id+',true)\">✓ 通过</button><button class=\"btn btn-d btn-sm\" onclick=\"showReject('+o.id+')\">✗ 驳回</button><button class=\"btn btn-sm\" style=\"background:#ff4d4f;color:#fff\" onclick=\"markUrgent('+o.id+')\">⚡加急</button><button class=\"btn btn-sm btn-p\" onclick=\"showOrderDetail('+o.id+')\">📋 详情</button></span></div></div>'
  }).join(''):'<div class=\"empty\">暂无待审批</div>';
  if(window._pendingTimer)clearInterval(window._pendingTimer);
  window._pendingTimer=setInterval(async function(){
    var fresh=await api('/repair/pending-approval');if(!fresh||!fresh.length)return;
    var pl=document.getElementById('pendingList');if(!pl)return;
    pl.innerHTML=fresh.map(function(o){return '<div style=\"padding:12px;border:1px solid var(--warning);background:rgba(212,160,23,.08);border-radius:8px;margin-bottom:10px\"><div class=\"flex\"><span class=\"order-no\">'+o.order_no+'</span><span class=\"tag t-pending\">待审批</span></div><div>'+o.plate_number+'</div><div class=\"flex\"><span style=\"font-size:18px;font-weight:bold;color:var(--danger)\">¥'+o.quote_amount+'</span><span><button class=\"btn btn-s btn-sm\" onclick=\"approveOrder('+o.id+',true)\">通过</button> <button class=\"btn btn-d btn-sm\" onclick=\"showReject('+o.id+')\">驳回</button> <button class=\"btn btn-sm\" style=\"background:#ff4d4f;color:#fff\" onclick=\"markUrgent('+o.id+')\">加急</button></span></div></div>'}).join('')
  },5000);
  loadAllOrders();
}
async function loadAllOrders(){
  var data=await api('/repair/all-orders?pageSize=200');
  document.getElementById('allOrdersList').innerHTML=data?'<table><tr><th>工单号</th><th>车辆</th><th>驾驶员</th><th>修理厂</th><th>报价</th><th>状态</th><th>时间</th><th>操作</th></tr>'+data.list.map(function(o){
    return '<tr><td class=\"order-no\" style=\"font-size:12px\">'+o.order_no+(o.is_urgent?' <span style=\"background:#ff4d4f;color:#fff;padding:1px 4px;border-radius:2px;font-size:10px\">急</span>':'')+'</td><td>'+o.plate_number+'</td><td>'+(o.driver_name||'-')+'</td><td>'+(o.repair_shop_name||'-')+'</td><td style=\"color:var(--danger)\">'+(o.quote_amount?'¥'+o.quote_amount:'-')+'</td><td><span class=\"tag '+ST_TAG[o.status]+'\">'+STATUS_MAP[o.status]+'</span></td><td>'+o.created_at.slice(0,16)+'</td><td><button class=\"btn btn-sm btn-p\" onclick=\"showOrderDetail('+o.id+')\">详情</button></td></tr>'
  }).join('')+'</table>':'<div class=\"empty\">暂无</div>';
}

// ===== EXTERNAL =====
async function renderExternalDept(){
  var el=document.getElementById('mainPage');
  var [dept,shops,orders]=await Promise.all([api('/external/departments'),api('/external/repair-shops'),api('/external/my-orders')]);
  var mx=dept.find(function(d){return d.id===USER.department_id});
  el.innerHTML='<div class=\"layout\"><div class=\"stats-grid\"><div class=\"stat-item\"><div class=\"stat-num\">'+(orders||[]).length+'</div><div class=\"stat-label\">我的报修</div></div><div class=\"stat-item\"><div class=\"stat-num\" style=\"color:var(--warning)\">'+(orders||[]).filter(function(o){return o.status==='pending_approval'}).length+'</div><div class=\"stat-label\">待审批</div></div><div class=\"stat-item\"><div class=\"stat-num\" style=\"color:var(--success)\">'+(orders||[]).filter(function(o){return o.status==='accepted'}).length+'</div><div class=\"stat-label\">已完成</div></div></div>'+
    '<div class=\"card\"><div class=\"card-title\">🔧 提交报修 — '+(mx?mx.name:'')+'</div><div class=\"row2\"><div class=\"form-group\"><label>修理厂</label><select id=\"extShop\">'+(shops||[]).map(function(s){return '<option value=\"'+s.id+'\">'+s.name+'</option>'}).join('')+'</select></div><div class=\"form-group\"><label>设备名称</label><input id=\"extVehicle\" /></div></div><div class=\"form-group\"><label>故障描述</label><textarea id=\"extDesc\"></textarea></div><button class=\"btn btn-p\" onclick=\"submitExtReport()\">提交报修</button></div>'+
    '<div class=\"card\"><div class=\"card-title\">📋 维修记录 <button class=\"btn btn-s btn-sm\" onclick=\"exportExtOrders()\">导出CSV</button></div>'+(orders||[]).length?'<table><tr><th>工单号</th><th>修理厂</th><th>设备</th><th>状态</th><th>报价</th><th>操作</th></tr>'+orders.map(function(o){return '<tr><td class=\"order-no\" style=\"font-size:12px\">'+o.order_no+'</td><td>'+(o.shop_name||'-')+'</td><td>'+(o.vehicle_name||'-')+'</td><td><span class=\"tag '+ST_TAG[o.status]+'\">'+STATUS_MAP[o.status]+'</span></td><td style=\"color:var(--danger)\">'+(o.quote_amount?'¥'+o.quote_amount:'-')+'</td><td><button class=\"btn btn-sm btn-p\" onclick=\"showExtOrderDetail('+o.id+')\">详情</button>'+(o.status==='completed'?' <button class=\"btn btn-sm btn-s\" onclick=\"extAccept('+o.id+')\">验收</button>':'')+'</td></tr>'}).join('')+'</table>':'<div class=\"empty\">暂无</div></div></div>';
}
async function submitExtReport(){var sid=+document.getElementById('extShop').value;var vn=document.getElementById('extVehicle').value.trim();var fd=document.getElementById('extDesc').value.trim();if(!fd)return alert('请填写故障描述');await api('/external/report',{method:'POST',data:{repair_shop_id:sid,vehicle_name:vn,fault_description:fd}});toast('报修已提交');renderPage()}
async function extAccept(id){if(!confirm('确认验收？'))return;await api('/external/accept/'+id,{method:'POST'});toast('验收成功');renderPage()}
async function showExtOrderDetail(id){
  var data=await api('/external/detail/'+id);if(!data)return;
  var o=data.order,p=data.progress||[];
  var tl=p.map(function(x){return '<div class=\"tl-item\"><div><b>'+x.action+'</b> <span style=\"color:var(--text2);font-size:11px\">'+(x.created_at||'').slice(0,16)+'</span></div><div style=\"font-size:12px\">'+(x.content||'')+' — '+x.uname+'</div></div>'}).join('');
  var m=document.createElement('div');m.className='modal-mask';
  m.innerHTML='<div class=\"modal\" style=\"max-width:550px\"><div class=\"flex\" style=\"margin-bottom:12px\"><h3>工单详情</h3><button class=\"btn\" onclick=\"this.closest(\\'.modal-mask\\').remove()\">✕</button></div><div class=\"flex\"><span class=\"order-no\">'+o.order_no+'</span><span class=\"tag '+ST_TAG[o.status]+'\">'+STATUS_MAP[o.status]+'</span></div><div>部门：'+(o.dept_name||'')+' | 修理厂：'+(o.shop_name||'待分配')+'</div><div>设备：'+(o.vehicle_name||'-')+'</div><div>故障：'+(o.fault_description||'')+'</div>'+((o.quote_amount)?'<div style=\"padding:8px;background:rgba(200,160,74,.08);border-radius:6px;margin:8px 0\">报价：¥'+o.quote_amount+'（配件:¥'+(o.parts_cost||0)+' 人工:¥'+(o.labor_cost||0)+' 工时:¥'+(o.hours_cost||0)+'）</div>':'')+'<div class=\"card-title\">进度</div><div class=\"timeline\">'+tl+'</div></div>';
  m.onclick=function(e){if(e.target===m)m.remove()};document.body.appendChild(m)
}
function exportExtOrders(){
  api('/external/export-orders').then(function(data){
    if(!data||!data.length)return alert('无数据');
    var csv='工单号,部门,修理厂,设备,故障,状态,报价,配件费,人工费,工时费,时间\\n';
    data.forEach(function(o){csv+=o.order_no+','+(o.dept_name||'')+','+(o.shop_name||'')+','+(o.vehicle_name||'')+',\"'+(o.fault_description||'').replace(/\"/g,'\"\"')+'\",'+STATUS_MAP[o.status]+','+(o.quote_amount||0)+','+(o.parts_cost||0)+','+(o.labor_cost||0)+','+(o.hours_cost||0)+','+o.created_at.slice(0,16)+'\\n'});
    var blob=new Blob(['﻿'+csv],{type:'text/csv;charset=utf-8'});var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='外部门报修记录.csv';a.click()
  })
}

async function renderExternalApprover(){
  var el=document.getElementById('mainPage');
  var pending=await api('/external/pending-approval');
  el.innerHTML='<div class=\"layout\"><div class=\"stats-grid\"><div class=\"stat-item\"><div class=\"stat-num\" style=\"color:var(--warning)\">'+(pending||[]).length+'</div><div class=\"stat-label\">待审批</div></div></div><div class=\"card\"><div class=\"card-title\">✍ 外部报修审批 ('+(pending||[]).length+')</div>'+(pending||[]).length?pending.map(function(o){return '<div style=\"padding:12px;border:1px solid var(--warning);background:rgba(212,160,23,.08);border-radius:8px;margin-bottom:10px\"><div class=\"flex\"><span class=\"order-no\">'+o.order_no+'</span><span class=\"tag t-pending\">待审批</span></div><div>部门：'+(o.dept_name||'')+' | 设备：'+(o.vehicle_name||'-')+' | 修理厂：'+(o.shop_name||'-')+'</div><div>故障：'+(o.fault_description||'')+'</div><div class=\"flex\" style=\"margin-top:8px\"><span style=\"font-size:20px;font-weight:bold;color:var(--danger)\">¥'+(o.quote_amount||0)+'</span><span><button class=\"btn btn-s btn-sm\" onclick=\"extApprove('+o.id+',true)\">✓ 通过</button><button class=\"btn btn-d btn-sm\" onclick=\"extReject('+o.id+')\">✗ 驳回</button></span></div></div>'}).join(''):'<div class=\"empty\">暂无</div></div></div>'
}
async function extApprove(id,approved){await api('/external/approve/'+id,{method:'POST',data:{approved:approved}});toast('已通过');renderPage()}
function extReject(id){var r=prompt('驳回原因：');if(!r)return;api('/external/approve/'+id,{method:'POST',data:{approved:false,reject_reason:r}}).then(function(){toast('已驳回');renderPage()})}

// ===== REPAIR =====
function showReport(){
  api('/vehicles').then(function(vs){
    var opts=vs.map(function(v){return '<option value=\"'+v.id+'\">'+v.plate_number+'（'+(v.vehicle_type||'')+'）</option>'}).join('');
    showModal('故障报修','<div class=\"form-group\"><label>车辆</label><select id=\"rptVehicle\">'+opts+'</select></div><div class=\"form-group\"><label>故障描述</label><textarea id=\"rptDesc\"></textarea></div>',async function(mask){
      var vid=+document.getElementById('rptVehicle').value;var desc=document.getElementById('rptDesc').value.trim();
      if(!desc){alert('请填写故障描述');return false}
      await api('/repair/report',{method:'POST',data:{vehicle_id:vid,fault_description:desc,fault_images:[]}});
      toast('报修成功');mask.remove();renderPage()
    })
  })
}
async function showOrderDetail(id){
  var data=await api('/repair/detail/'+id);if(!data)return;
  var o=data.order,p=data.progress||[];
  var tl=p.map(function(x){return '<div class=\"tl-item\"><div><b>'+x.action+'</b> <span style=\"color:var(--text2);font-size:11px\">'+(x.created_at||'').slice(0,16)+'</span></div><div style=\"font-size:12px\">'+(x.content||'')+' — '+(x.user_name||'')+'</div></div>'}).join('');
  var m=document.createElement('div');m.className='modal-mask';
  m.innerHTML='<div class=\"modal\" style=\"max-width:600px\"><div class=\"flex\" style=\"margin-bottom:12px\"><h3>工单详情</h3><button class=\"btn\" onclick=\"this.closest(\\'.modal-mask\\').remove()\">✕</button></div><div class=\"flex\"><span class=\"order-no\" style=\"font-size:16px\">'+o.order_no+'</span>'+'<span class=\"tag '+ST_TAG[o.status]+'\">'+STATUS_MAP[o.status]+'</span></div><div style=\"margin-top:10px;font-size:13px\"><div><b>车辆：</b>'+o.plate_number+'（'+(o.vehicle_type||'')+'/'+(o.model||'-')+'）</div><div><b>报修部门：</b>'+(o.dept_name||'总调度室')+' | <b>报修人：</b>'+o.driver_name+' '+(o.driver_phone||'')+'</div><div><b>修理厂：</b>'+(o.repair_shop_name||'待接单')+'</div><div><b>故障描述：</b>'+(o.fault_description||'')+'</div>'+((o.quote_amount)?'<div style=\"margin-top:8px;padding:10px;background:rgba(200,160,74,.08);border-radius:6px\"><b>报价：</b>¥'+o.quote_amount+'<br>'+(o.quote_detail||'')+'<br>预计'+(o.estimated_days||'?')+'天<br><span style=\"font-size:12px;color:var(--text2)\">配件费: ¥'+(o.parts_cost||0)+' | 人工费: ¥'+(o.labor_cost||0)+' | 工时费: ¥'+(o.hours_cost||0)+'</span></div>':'')+'</div><div class=\"card-title\">进度</div><div class=\"timeline\">'+(tl||'暂无')+'</div></div>';
  m.onclick=function(e){if(e.target===m)m.remove()};document.body.appendChild(m)
}
async function acceptOrder(id){await api('/repair/accept-order/'+id,{method:'POST'});toast('已接单');renderPage()}
function showQuote(id){
  showModal('提交报价','<div class=\"form-group\"><label>配件清单</label><div id=\"partsContainer\"><div class=\"flex\" style=\"margin-bottom:4px\"><input id=\"partName0\" placeholder=\"配件名称\" style=\"flex:2\" /><input id=\"partQty0\" placeholder=\"数量\" type=\"number\" style=\"flex:1;margin:0 4px\" /><input id=\"partPrice0\" placeholder=\"单价\" type=\"number\" style=\"flex:1\" /></div></div><button class=\"btn btn-o btn-sm\" onclick=\"addPartRow()\" style=\"margin-top:6px\">+ 添加配件</button></div><div class=\"row2\"><div class=\"form-group\"><label>配件总费用</label><input id=\"quoteParts\" type=\"number\" value=\"0\" onchange=\"updateQuoteTotal()\" /></div><div class=\"form-group\"><label>人工费</label><input id=\"quoteLabor\" type=\"number\" value=\"0\" onchange=\"updateQuoteTotal()\" /></div></div><div class=\"row2\"><div class=\"form-group\"><label>工时费</label><input id=\"quoteHoursCost\" type=\"number\" value=\"0\" onchange=\"updateQuoteTotal()\" /></div><div class=\"form-group\"><label>预计天数</label><input id=\"quoteDays\" type=\"number\" /></div></div><div class=\"form-group\"><label>合计报价</label><input id=\"quoteAmt\" type=\"number\" readonly style=\"font-size:20px;font-weight:bold;color:var(--danger)\" /></div><div class=\"form-group\"><label>报价说明</label><textarea id=\"quoteDetail\"></textarea></div>',async function(mask){
    var parts=[];var j=0;
    while(document.getElementById('partName'+j)){var nm=document.getElementById('partName'+j).value.trim();var qt=+document.getElementById('partQty'+j).value||0;var pr=+document.getElementById('partPrice'+j).value||0;if(nm)parts.push({name:nm,qty:qt,price:pr});j++}
    var pc=+document.getElementById('quoteParts').value||0;var lc=+document.getElementById('quoteLabor').value||0;var hc=+document.getElementById('quoteHoursCost').value||0;var amt=pc+lc+hc;
    if(!amt){alert('请填写费用');return false}
    await api('/repair/submit-quote/'+id,{method:'POST',data:{quote_amount:amt,parts_cost:pc,labor_cost:lc,hours_cost:hc,parts_list:parts,quote_detail:document.getElementById('quoteDetail').value,estimated_days:+document.getElementById('quoteDays').value||null}});
    toast('报价已提交');mask.remove();renderPage()
  });window._partRowCount=1
}
function addPartRow(){var i=window._partRowCount++;var d=document.createElement('div');d.className='flex';d.style.marginBottom='4px';d.innerHTML='<input id=\"partName'+i+'\" placeholder=\"配件名称\" style=\"flex:2\" /><input id=\"partQty'+i+'\" placeholder=\"数量\" type=\"number\" style=\"flex:1;margin:0 4px\" /><input id=\"partPrice'+i+'\" placeholder=\"单价\" type=\"number\" style=\"flex:1\" />';document.getElementById('partsContainer').appendChild(d)}
function updateQuoteTotal(){var p=+document.getElementById('quoteParts').value||0;var l=+document.getElementById('quoteLabor').value||0;var h=+document.getElementById('quoteHoursCost').value||0;document.getElementById('quoteAmt').value=p+l+h}
function updateProgress(id){showModal('更新进度','<div class=\"form-group\"><textarea id=\"progContent\"></textarea></div>',async function(mask){var c=document.getElementById('progContent').value.trim();if(!c){alert('请填写');return false};await api('/repair/update-progress/'+id,{method:'POST',data:{content:c}});toast('已更新');mask.remove();renderPage()})}
async function completeOrder(id){if(!confirm('确认完工？'))return;await api('/repair/complete/'+id,{method:'POST'});toast('已完工');renderPage()}
async function approveOrder(id,approved){await api('/repair/approve/'+id,{method:'POST',data:{approved:approved}});toast(approved?'已通过':'已驳回');renderPage()}
function showReject(id){showModal('驳回原因','<div class=\"form-group\"><textarea id=\"rejectReason\"></textarea></div>',async function(mask){var r=document.getElementById('rejectReason').value.trim();if(!r){alert('请填写');return false};await api('/repair/approve/'+id,{method:'POST',data:{approved:false,reject_reason:r}});toast('已驳回');mask.remove();renderPage()})}
async function markUrgent(id){if(!confirm('标记为加急维修？'))return;await api('/repair/urgent/'+id,{method:'POST'});toast('已标记加急');renderPage()}

// ===== INSPECTION =====
function showInspection(tab){tab=tab||'morning';
  Promise.all([api('/vehicles'),api('/inspection/driver-list')]).then(function(r){
    var vs=r[0]||[],ds=r[1]||[];
    var vOpts=vs.map(function(v){return '<option value=\"'+v.id+'\">'+v.plate_number+'（'+(v.vehicle_type||'')+'）</option>'}).join('');
    var dOpts=ds.map(function(d){return '<option value=\"'+d.id+'\">'+d.name+(USER.id===d.id?'（本人）':'')+'</option>'}).join('');
    var morningForm='<div class=\"form-group\"><label>司机</label><select id=\"inspDriver\">'+dOpts+'</select></div><div class=\"form-group\"><label>车辆</label><select id=\"inspVehicle\">'+vOpts+'</select></div><div class=\"row2\"><div class=\"form-group\"><label>机油液位</label><select id=\"inspOil\"><option value=\"\">请选择</option><option value=\"high\">高位</option><option value=\"mid\">中位</option><option value=\"low\">低位</option></select></div><div class=\"form-group\"><label>冷却液位</label><select id=\"inspCoolant\"><option value=\"\">请选择</option><option value=\"high\">高位</option><option value=\"mid\">中位</option><option value=\"low\">低位</option></select></div></div><div class=\"row2\"><div class=\"form-group\"><label>外观</label><select id=\"inspAppear\"><option value=\"\">请选择</option><option value=\"normal\">正常</option><option value=\"damaged\">有损坏</option><option value=\"dirty\">需清洁</option></select></div><div class=\"form-group\"><label>轮胎</label><select id=\"inspTire\"><option value=\"\">请选择</option><option value=\"normal\">正常</option><option value=\"worn\">磨损</option><option value=\"damaged\">损坏</option></select></div></div><div class=\"form-group\"><label>随车九样物品</label><select id=\"inspToolkit\"><option value=\"\">请选择</option><option value=\"ok\">齐全</option><option value=\"missing\">缺失</option></select></div><div class=\"form-group\"><label>发动机工时</label><input id=\"inspHours\" type=\"number\" /></div><div class=\"form-group\"><label>整体状态</label><select id=\"inspStatus\"><option value=\"normal\">正常</option><option value=\"abnormal\">异常</option></select></div><div class=\"form-group\"><label>备注</label><textarea id=\"inspNotes\"></textarea></div>';
    var eveningForm='<div class=\"form-group\"><label>司机</label><select id=\"inspDriver2\">'+dOpts+'</select></div><div class=\"form-group\"><label>车辆</label><select id=\"inspVehicle2\">'+vOpts+'</select></div><div class=\"row2\"><div class=\"form-group\"><label>上班启动工时(h)</label><input id=\"inspStartH\" type=\"number\" step=\"0.1\" /></div><div class=\"form-group\"><label>下班停车工时(h)</label><input id=\"inspEndH\" type=\"number\" step=\"0.1\" /></div></div><div class=\"form-group\"><label>加油数量(L)</label><input id=\"inspFuel\" type=\"number\" step=\"0.1\" /></div><div class=\"form-group\"><label>停车地点</label><input id=\"inspParking\" /></div><div style=\"background:rgba(200,160,74,.1);border:1px solid var(--gold);border-radius:6px;padding:10px 14px;margin-top:8px;font-size:12px;color:var(--gold-light)\">⚠ 温馨提示：下班请将车辆停在安全的地方，锁好门窗，并关闭电源。</div>';
    var m=document.createElement('div');m.className='modal-mask';m.id='inspectionModal';
    m.innerHTML='<div class=\"modal\" style=\"max-width:550px\"><div class=\"flex\" style=\"margin-bottom:16px\"><h3>每日点检</h3><span style=\"display:flex;gap:8px\"><button class=\"tab '+(tab==='morning'?'active':'')+'\" onclick=\"switchInspTab(\\'morning\\')\">☀ 早检</button><button class=\"tab '+(tab==='evening'?'active':'')+'\" onclick=\"switchInspTab(\\'evening\\')\">🌙 晚检</button></span></div><div id=\"inspFormContent\">'+(tab==='morning'?morningForm:eveningForm)+'</div><div style=\"text-align:right;margin-top:16px;display:flex;gap:10px;justify-content:flex-end\"><button class=\"btn\" onclick=\"document.getElementById(\\'inspectionModal\\').remove()\">取消</button><button class=\"btn btn-p\" onclick=\"submitInspection(\\''+tab+'\\')\">提交'+(tab==='morning'?'早检':'晚检')+'</button></div></div>';
    m.onclick=function(e){if(e.target===m)m.remove()};document.body.appendChild(m)
  })
}
function switchInspTab(tab){document.getElementById('inspectionModal').remove();showInspection(tab)}
async function submitInspection(tab){
  var id=tab==='morning'?'inspDriver':'inspDriver2',vid=tab==='morning'?'inspVehicle':'inspVehicle2';
  var driver_id=+document.getElementById(id)?.value||null,vehicle_id=+document.getElementById(vid)?.value||null;
  if(!vehicle_id){alert('请选择车辆');return}
  if(tab==='morning'){
    var d={vehicle_id:vehicle_id,driver_id:driver_id,oil_level:document.getElementById('inspOil').value,coolant_level:document.getElementById('inspCoolant').value,appearance:document.getElementById('inspAppear').value,tire_condition:document.getElementById('inspTire').value,toolkit_check:document.getElementById('inspToolkit').value,engine_hours:+(document.getElementById('inspHours')?.value)||0,overall_status:document.getElementById('inspStatus').value,notes:document.getElementById('inspNotes')?.value?.trim()||''};
    var r=await api('/inspection/morning-check',{method:'POST',data:d});if(r){toast('早检提交成功');document.getElementById('inspectionModal')?.remove();renderPage()}
  }else{
    var d2={vehicle_id:vehicle_id,driver_id:driver_id,start_hours:parseFloat(document.getElementById('inspStartH')?.value)||0,end_hours:parseFloat(document.getElementById('inspEndH')?.value)||0,fuel_amount:parseFloat(document.getElementById('inspFuel')?.value)||0,parking_location:document.getElementById('inspParking')?.value?.trim()||''};
    var r2=await api('/inspection/evening-check',{method:'POST',data:d2});if(r2){toast('晚检提交成功');document.getElementById('inspectionModal')?.remove();renderPage()}
  }
}

// ===== ATTENDANCE =====
function loadAttendanceCard(){
  api('/inspection/attendance/today').then(function(r){var rec=r||{},sym=rec.attendance_symbol||'';
    var attOpts=['','X','Y','Z','V','G','△','△/X','△/Y','△/Z','△/V'].map(function(s){return '<option value=\"'+s+'\"'+(s===sym?' selected':'')+'>'+(s||'请选择')+'</option>'}).join('');
    var ae=document.getElementById('attCard');
    if(sym){ae.innerHTML='<div class=\"tag t-done\" style=\"font-size:14px\">✓ 已提交: '+sym+'</div>'}
    else{ae.innerHTML='<select id=\"attSymbol\" style=\"margin-bottom:8px\">'+attOpts+'</select><br><button class=\"btn btn-p btn-sm\" onclick=\"submitAttendance()\">提交考勤</button>'}
    var oe=document.getElementById('otCard');
    if(rec.overtime_hours){var oI='✓ 已提交: '+rec.overtime_hours+'h';if(rec.overtime_start)oI+='<br><small style=\"color:var(--text2)\">'+rec.overtime_start+' → '+rec.overtime_end+'</small>';oe.innerHTML='<div class=\"tag t-done\" style=\"font-size:14px\">'+oI+'</div>'}
    else{oe.innerHTML='<div class=\"row2\" style=\"margin-bottom:8px\"><input id=\"otStart\" type=\"time\" value=\"'+(rec.overtime_start||'')+'\" /><input id=\"otEnd\" type=\"time\" value=\"'+(rec.overtime_end||'')+'\" /></div><input id=\"otLocation\" placeholder=\"加班地点\" value=\"'+(rec.overtime_location||'')+'\" style=\"margin-bottom:8px\" /><br><button class=\"btn btn-p btn-sm\" onclick=\"submitAttendance()\">提交加班</button>'}
  })
}
function submitAttendance(){
  var sym=document.getElementById('attSymbol')?.value||'',otS=document.getElementById('otStart')?.value||'',otE=document.getElementById('otEnd')?.value||'',loc=document.getElementById('otLocation')?.value?.trim()||'';
  api('/inspection/attendance/submit',{method:'POST',data:{attendance_symbol:sym,overtime_start:otS,overtime_end:otE,overtime_location:loc}}).then(function(){toast('提交成功');loadAttendanceCard()})
}

// ===== QUIZ =====
function showQuiz(){api('/quiz/today').then(function(d){if(!d)return;if(d.done){alert('今日已完成测试！得分：'+d.result.score+'/'+d.result.total);showLeaderboard()}else{startQuiz(d.questions)}})}
function startQuiz(qs){
  var i=0,answers=[],el=document.createElement('div'),selected=-1;el.className='modal-mask';
  var catIcons={'安全操作':'🔧','安全红线':'🚫','公司制度':'📋','十大禁令':'⛔','道路交通':'🚛','高原知识':'🏔','发动机理论':'⚙','电气系统':'⚡','液压系统':'💧','变速箱':'🔗','底盘':'🛞','轮胎':'⚫','故障判断':'🔍','日常保养':'🛢','工程机械':'🏗','矿山安全':'⛏','安全基础':'📖','四受控':'🔄','八大危险作业':'⚠'};
  function showQ(){
    if(i>=qs.length){submitQuiz(answers,el);return}var q=qs[i],opts='',labels=['A','B','C','D'];
    try{JSON.parse(q.options).forEach(function(o,j){opts+='<div class=\"quiz-opt\" id=\"opt'+j+'\" onclick=\"window.selOpt('+j+')\"><span class=\"q-opt-letter\">'+labels[j]+'</span> '+o+'</div>'})}catch(e){}
    var barW=((i+1)/qs.length*100).toFixed(0);
    el.innerHTML='<div class=\"modal quiz-modal\" style=\"max-width:560px;padding:0;overflow:hidden;border-radius:14px\"><div class=\"quiz-progress-bar\"><div class=\"quiz-progress-fill\" style=\"width:'+barW+'%\"></div></div><div class=\"quiz-body\"><div class=\"quiz-header\"><span class=\"tag t-progress\" style=\"font-size:11px\">'+(catIcons[q.category]||'📝')+' '+q.category+'</span><span style=\"color:var(--text2);font-size:12px\">'+(i+1)+'/'+qs.length+'</span></div><div class=\"quiz-question\">'+q.question+'</div><div class=\"quiz-options\">'+opts+'</div><div class=\"quiz-footer\"><button class=\"btn btn-p quiz-btn\" onclick=\"window.nextQ()\">'+(i<qs.length-1?'下一题 ▶':'✓ 提交')+'</button></div></div></div>';
    el.onclick=function(e){if(e.target===el)el.remove()};document.body.appendChild(el);selected=-1
  }
  window.selOpt=function(j){selected=j;document.querySelectorAll('.quiz-opt').forEach(function(o){o.classList.remove('quiz-selected')});var opt=document.getElementById('opt'+j);if(opt)opt.classList.add('quiz-selected')};
  window.nextQ=function(){answers.push({question_id:qs[i].id,user_answer:selected>=0?String.fromCharCode(65+selected):''});i++;showQ()};showQ()
}
function submitQuiz(as,el){api('/quiz/submit',{method:'POST',data:{answers:as}}).then(function(r){
  el.remove();var pct=Math.round(r.score/r.total*100),emoji=pct===100?'🌟':pct>=80?'🎉':pct>=60?'👍':'💪',bg=pct===100?'linear-gradient(135deg,#c8a04a,#b87333)':pct>=80?'linear-gradient(135deg,#4a8f5a,#3d7349)':pct>=60?'linear-gradient(135deg,#1677ff,#0958d9)':'linear-gradient(135deg,#c0392b,#96281b)';
  var re=document.createElement('div');re.className='modal-mask';
  re.innerHTML='<div class=\"modal\" style=\"max-width:400px;text-align:center;padding:0;overflow:hidden;border-radius:14px\"><div style=\"background:'+bg+';padding:30px 20px\"><div style=\"font-size:48px\">'+emoji+'</div><div style=\"font-size:42px;font-weight:900;color:#fff;margin:8px 0\">'+r.score+'<span style=\"font-size:20px\">/'+r.total+'</span></div><div style=\"color:rgba(255,255,255,.8);font-size:14px\">正确率 '+pct+'%</div></div><div style=\"padding:20px\"><button class=\"btn btn-p\" onclick=\"this.closest(\\'.modal-mask\\').remove();showLeaderboard()\">🏆 查看排行榜</button><br><button class=\"btn btn-o btn-sm\" style=\"margin-top:8px\" onclick=\"this.closest(\\'.modal-mask\\').remove()\">关闭</button></div></div>';
  re.onclick=function(e){if(e.target===re)re.remove()};document.body.appendChild(re)
})}
function showLeaderboard(){api('/quiz/leaderboard').then(function(d){if(!d)return;var rows='';(d.leaderboard||[]).forEach(function(r,i){var medal=i===0?'🥇':i===1?'🥈':i===2?'🥉':'';rows+='<tr><td>'+medal+' '+(i+1)+'</td><td>'+r.name+'</td><td>'+r.total_score+'分</td><td>'+r.days+'天</td><td>👍'+(r.likes||0)+'</td></tr>'});showModal('🏆 本月排行榜','<table><tr><th>排名</th><th>姓名</th><th>总分</th><th>天数</th><th>点赞</th></tr>'+rows+'</table>')})}

// ===== ADMIN FUNCTIONS =====
function showModal(title,content,onOk){
  var mask=document.createElement('div');mask.className='modal-mask';
  mask.innerHTML='<div class=\"modal\"><h3 style=\"margin-bottom:16px\">'+title+'</h3>'+content+'<div class=\"flex\" style=\"justify-content:flex-end;margin-top:16px\"><button class=\"btn\" onclick=\"this.closest(\\'.modal-mask\\').remove()\">取消</button>'+'<button class=\"btn btn-p\" id=\"modalOkBtn\">确认</button></div></div>';
  document.body.appendChild(mask);
  if(onOk){document.getElementById('modalOkBtn').onclick=async function(){var r=await onOk(mask);if(r!==false)mask.remove()}}
  mask.onclick=function(e){if(e.target===mask)mask.remove()}
}
function showAdminVehicles(){
  api('/vehicles').then(function(vs){var t='<table><tr><th>内部编号</th><th>类型</th><th>型号</th><th>车龄</th><th>工时</th><th>保养间隔</th><th>操作</th></tr>';
    vs.forEach(function(v){var age=v.purchase_date?((new Date()-new Date(v.purchase_date))/(365.25*86400000)).toFixed(1)+'年':'-';t+='<tr><td><b>'+v.plate_number+'</b></td><td>'+(v.vehicle_type||'-')+'</td><td>'+(v.model||'-')+'</td><td>'+age+'</td><td>'+(v.latest_end_hours||v.initial_engine_hours||0)+'h</td><td>'+(v.maintenance_interval_hours||'-')+'h</td><td><button class=\"btn btn-sm btn-d\" onclick=\"delVehicle('+v.id+',\\''+v.plate_number+'\\')\">删除</button></td></tr>'});
    t+='</table>';
    showModal('车辆管理','<div class=\"row2\"><div class=\"form-group\"><label>内部编号</label><input id=\"vPlate\" /></div><div class=\"form-group\"><label>类型</label><input id=\"vType\" /></div></div><div class=\"row2\"><div class=\"form-group\"><label>型号</label><input id=\"vModel\" /></div><div class=\"form-group\"><label>购买日期</label><input id=\"vDate\" type=\"date\" /></div></div><div class=\"row2\"><div class=\"form-group\"><label>初始工时(h)</label><input id=\"vHours\" type=\"number\" value=\"0\" /></div><div class=\"form-group\"><label>保养间隔(h)</label><input id=\"vInterval\" type=\"number\" value=\"500\" /></div></div><button class=\"btn btn-p btn-sm\" onclick=\"addSingleVehicle()\" style=\"margin-bottom:12px\">+ 添加车辆</button><div style=\"max-height:300px;overflow:auto\">'+t+'</div>')
  })
}
function addSingleVehicle(){var pn=document.getElementById('vPlate').value.trim();if(!pn)return alert('请输入编号');
  api('/admin/vehicles/import',{method:'POST',data:{vehicles:[{plate_number:pn,vehicle_type:document.getElementById('vType').value.trim(),model:document.getElementById('vModel').value.trim(),purchase_date:document.getElementById('vDate').value,initial_engine_hours:parseInt(document.getElementById('vHours').value)||0,maintenance_interval_hours:parseInt(document.getElementById('vInterval').value)||500}]}}).then(function(){toast('添加成功');document.querySelectorAll('.modal-mask').forEach(function(m){m.remove()});renderPage()})
}
async function delVehicle(id,name){if(!confirm('确认删除'+name+'？'))return;var r=await api('/admin/vehicles/'+id,{method:'DELETE'});if(r){toast('已删除');renderPage()}}
function showVehiclesByStatus(status,title){
  api('/vehicles').then(function(vs){var list=vs;
    if(status==='normal'){list=vs.filter(function(v){if(v.status!=='normal')return false;var cur=v.latest_end_hours||v.initial_engine_hours||0,next=v.next_maintenance_hours||0;return next===0||cur<next})}
    else if(status==='expired'){list=vs.filter(function(v){var cur=v.latest_end_hours||v.initial_engine_hours||0,next=v.next_maintenance_hours||0;return next>0&&cur>=next})}
    else if(status==='repairing'){list=vs.filter(function(v){return v.status==='repairing'})}
    else if(status){list=vs.filter(function(v){return v.status===status})}
    if(!list.length)return alert('暂无符合条件的车辆');
    var rows='';list.forEach(function(v){var age=v.purchase_date?((new Date()-new Date(v.purchase_date))/(365.25*86400000)).toFixed(1)+'年':'-',cur=v.latest_end_hours||v.initial_engine_hours||0,next=v.next_maintenance_hours||0,rem=cur&&next?next-cur:999,st=rem<0?'<span class=\"tag t-reject\">过期</span>':rem<50?'<span class=\"tag t-pending\">即将保养</span>':'<span class=\"tag t-done\">正常</span>';rows+='<tr><td><b>'+v.plate_number+'</b></td><td>'+(v.vehicle_type||'-')+'</td><td>'+(v.model||'-')+'</td><td>'+age+'</td><td>'+cur+'h</td><td>'+next+'h</td><td>'+st+'</td></tr>'});
    showModal(title+' ('+list.length+'辆)','<table><tr><th>编号</th><th>类型</th><th>型号</th><th>车龄</th><th>工时</th><th>下次保养</th><th>状态</th></tr>'+rows+'</table>')
  })
}
function showAdminUsers(){Promise.all([api('/admin/users'),api('/external/departments')]).then(function(r){var users=r[0],depts=r[1];LAST_DEPTS=depts||[];
  var rows='';users.forEach(function(u){rows+='<tr><td style=\"color:var(--primary);font-size:12px\">'+(u.dept_name||'-')+'</td><td>'+u.name+'</td><td>'+(u.phone||'-')+'</td><td><span class=\"tag t-progress\">'+ROLE_MAP[u.role]+'</span></td><td>'+(u.phone!=='15129505737'?'<button class=\"btn btn-sm btn-d\" onclick=\"delUser('+u.id+',\\''+u.name+'\\')\">删除</button>':'—')+'</td></tr>'});
  showModal('人员管理','<div class=\"form-group\"><div class=\"row2\"><input id=\"addName\" placeholder=\"姓名\" /><input id=\"addPhone\" placeholder=\"手机号\" /></div><div class=\"row2\" style=\"margin-top:6px\"><select id=\"addRole\"><option value=\"driver\">驾驶员</option><option value=\"repair_shop\">修理厂</option><option value=\"admin\">管理员</option><option value=\"leader\">科级审批</option><option value=\"external_approver\">外部审批</option></select><input id=\"addDept\" placeholder=\"部门（可选）\" list=\"deptList\" /></div><datalist id=\"deptList\">'+depts.map(function(d){return '<option value=\"'+d.name+'\">'}).join('')+'</datalist><button class=\"btn btn-p btn-sm\" style=\"margin-top:8px\" onclick=\"doAddUser()\">添加</button></div><table><tr><th>部门</th><th>姓名</th><th>手机号</th><th>角色</th><th>操作</th></tr>'+rows+'</table>')
})}
function doAddUser(){var name=document.getElementById('addName')?.value?.trim(),phone=document.getElementById('addPhone')?.value?.trim(),role=document.getElementById('addRole')?.value,deptInput=document.getElementById('addDept')?.value?.trim();if(!name)return alert('请填写姓名');
  (async function(){var deptId=null;if(deptInput){var match=(LAST_DEPTS||[]).find(function(d){return d.name===deptInput});if(match)deptId=match.id;else{var r=await api('/external/departments/add',{method:'POST',data:{name:deptInput}})}}
    await api('/admin/users/add',{method:'POST',data:{name:name,phone:phone||'',role:role,department_id:deptId}});toast('添加成功');document.querySelectorAll('.modal-mask').forEach(function(m){m.remove()});renderPage()
  })()
}
async function delUser(id,name){if(!confirm('确认删除\"'+name+'\"？'))return;await api('/admin/users/'+id,{method:'DELETE'});toast('已删除');document.querySelectorAll('.modal-mask').forEach(function(m){m.remove()});renderPage()}

function showRepairShops(){api('/admin/repair-shops').then(function(s){
  showModal('修理厂管理','<div class=\"form-group\"><div class=\"row2\"><input id=\"shopName\" placeholder=\"名称\" /><input id=\"shopContact\" placeholder=\"联系人\" /></div><div class=\"row2\" style=\"margin-top:8px\"><input id=\"shopPhone\" placeholder=\"电话\" /><input id=\"shopRemark\" placeholder=\"分工说明\" /></div><button class=\"btn btn-p btn-sm\" style=\"margin-top:8px\" onclick=\"doAddShop()\">添加</button></div><table><tr><th>名称</th><th>联系人</th><th>电话</th><th>分工</th><th>操作</th></tr>'+s.map(function(x){return '<tr><td><b>'+x.name+'</b></td><td>'+(x.contact_person||'-')+'</td><td>'+(x.contact_phone||'-')+'</td><td>'+(x.remark||'-')+'</td><td><button class=\"btn btn-sm btn-d\" onclick=\"delShop('+x.id+',\\''+x.name+'\\')\">删除</button></td></tr>'}).join('')+'</table>')
})}
function doAddShop(){var n=document.getElementById('shopName')?.value?.trim();if(!n)return alert('请填写名称');api('/admin/repair-shops/add',{method:'POST',data:{name:n,contact_person:document.getElementById('shopContact')?.value||'',contact_phone:document.getElementById('shopPhone')?.value||'',remark:document.getElementById('shopRemark')?.value||''}}).then(function(){toast('添加成功');renderPage()})}
async function delShop(id,name){if(!confirm('确认删除'+name+'？'))return;await api('/admin/repair-shops/'+id,{method:'DELETE'});toast('已删除');renderPage()}

// ===== COST & EXPORT =====
function showCostReport(){
  var today=new Date().toISOString().slice(0,10),fm=new Date().toISOString().slice(0,7)+'-01';
  api('/admin/repair-shops').then(function(s){var shopOpts='<option value=\"\">全部</option>'+s.map(function(x){return '<option value=\"'+x.id+'\">'+x.name+'</option>'}).join('');
    var m=document.createElement('div');m.className='modal-mask';m.id='costReportModal';
    m.innerHTML='<div class=\"modal\" style=\"max-width:900px;max-height:90vh\"><div class=\"flex\" style=\"margin-bottom:12px\"><h3>💰 维修费用报表</h3><button class=\"btn\" onclick=\"document.getElementById(\\'costReportModal\\').remove()\">✕ 关闭</button></div><div class=\"flex\" style=\"margin:12px 0\"><div class=\"form-group\" style=\"margin:0\"><label>开始</label><input id=\"crDateFrom\" type=\"date\" value=\"'+fm+'\" /></div><div class=\"form-group\" style=\"margin:0\"><label>结束</label><input id=\"crDateTo\" type=\"date\" value=\"'+today+'\" /></div><div class=\"form-group\" style=\"margin:0\"><label>修理厂</label><select id=\"crShop\">'+shopOpts+'</select></div><div class=\"form-group\" style=\"margin:0\"><label>类型</label><select id=\"crType\"><option value=\"\">全部</option><option value=\"internal\">内部</option><option value=\"external\">外部</option></select></div><button class=\"btn btn-p\" onclick=\"loadCostReport()\">查询</button> <button class=\"btn btn-s btn-sm\" onclick=\"exportCostCSV()\">导出CSV</button></div><div id=\"costReportContent\">点击查询加载数据</div></div>';
    m.onclick=function(e){if(e.target===m)m.remove()};document.body.appendChild(m)
  })
}
async function loadCostReport(){var df=document.getElementById('crDateFrom').value,dt=document.getElementById('crDateTo').value,sid=document.getElementById('crShop').value,dtp=document.getElementById('crType').value;var data=await api('/admin/cost-report?date_from='+df+'&date_to='+dt+(sid?'&repair_shop_id='+sid:'')+(dtp?'&dept_type='+dtp:''));if(!data)return;window._costData=data;
  var html='<div style=\"margin-bottom:16px;background:rgba(200,160,74,.08);padding:12px;border-radius:8px\"><b>汇总：</b>共 <b>'+data.summary.count+'</b> 单 | 总金额：<b style=\"color:var(--danger)\">¥'+data.summary.totalAmount.toFixed(2)+'</b></div>';
  html+='<table><tr><th>工单号</th><th>来源</th><th>设备</th><th>部门</th><th>修理厂</th><th>配件费</th><th>人工费</th><th>工时费</th><th>合计</th><th>审批日期</th></tr>';
  data.items.forEach(function(o){var ph='-';try{var ps=JSON.parse(o.parts_list||'[]');if(ps.length)ph=ps.map(function(p){return p.name+'×'+p.qty+' ¥'+(p.qty*p.price)}).join('<br>')}catch(e){}html+='<tr><td class=\"order-no\" style=\"font-size:12px\">'+o.order_no+'</td><td><span class=\"tag '+(o.source==='内部'?'t-progress':'t-pending')+'\">'+(o.source||'-')+'</span></td><td>'+(o.vehicle_name||o.plate_number||'-')+'</td><td>'+(o.dept_name||'总调度室')+'</td><td>'+(o.repair_shop_name||'-')+'</td><td>¥'+(o.parts_cost||0)+'</td><td>¥'+(o.labor_cost||0)+'</td><td>¥'+(o.hours_cost||0)+'</td><td style=\"font-weight:bold;color:var(--danger)\">¥'+(o.quote_amount||0)+'</td><td style=\"font-size:12px\">'+((o.approved_at||'').slice(0,10))+'</td></tr>'});
  html+='</table>';document.getElementById('costReportContent').innerHTML=html
}
function exportCostCSV(){var d=window._costData;if(!d||!d.items.length)return alert('请先查询');var csv='﻿工单号,来源,设备,部门,修理厂,配件费,人工费,工时费,合计,审批日期,配件明细\\n';d.items.forEach(function(o){var ps='';try{ps=JSON.parse(o.parts_list||'[]').map(function(p){return p.name+'×'+p.qty+' ¥'+p.price}).join(';')}catch(e){}csv+=o.order_no+','+(o.source||'-')+','+(o.vehicle_name||o.plate_number||'-')+','+(o.dept_name||'总调度室')+','+(o.repair_shop_name||'-')+','+(o.parts_cost||0)+','+(o.labor_cost||0)+','+(o.hours_cost||0)+','+(o.quote_amount||0)+','+((o.approved_at||'').slice(0,10))+',\"'+ps+'\"\\n'});var blob=new Blob([csv],{type:'text/csv;charset=utf-8'});var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='维修费用报表.csv';a.click()}

function showExportOrders(){
  var today=new Date().toISOString().slice(0,10);
  Promise.all([api('/admin/repair-shops'),api('/external/departments')]).then(function(r){var shops=r[0],depts=r[1];
    var shopOpts='<option value=\"\">全部</option>'+shops.map(function(s){return '<option value=\"'+s.id+'\">'+s.name+'</option>'}).join('');
    var deptOpts='<option value=\"\">全部</option>'+depts.map(function(d){return '<option value=\"'+d.id+'\">'+d.name+'</option>'}).join('');
    var m=document.createElement('div');m.className='modal-mask';
    m.innerHTML='<div class=\"modal\" style=\"max-width:900px;max-height:90vh\"><div class=\"flex\" style=\"margin-bottom:12px\"><h3>📥 导出工单数据</h3><button class=\"btn\" onclick=\"this.closest(\\'.modal-mask\\').remove()\">✕ 关闭</button></div><div class=\"flex\" style=\"margin:12px 0\"><div class=\"form-group\" style=\"margin:0\"><label>开始</label><input id=\"exDateFrom\" type=\"date\" /></div><div class=\"form-group\" style=\"margin:0\"><label>结束</label><input id=\"exDateTo\" type=\"date\" value=\"'+today+'\" /></div><div class=\"form-group\" style=\"margin:0\"><label>部门</label><select id=\"exDept\">'+deptOpts+'</select></div><div class=\"form-group\" style=\"margin:0\"><label>修理厂</label><select id=\"exShop\">'+shopOpts+'</select></div><div class=\"form-group\" style=\"margin:0\"><label>状态</label><select id=\"exStatus\"><option value=\"\">全部</option><option value=\"accepted\">已完成</option><option value=\"completed\">待验收</option><option value=\"repairing\">维修中</option></select></div></div><div style=\"margin-bottom:12px\"><button class=\"btn btn-p\" onclick=\"loadExportData()\">查询</button> <button class=\"btn btn-s btn-sm\" onclick=\"downloadExportCSV()\">导出CSV</button></div><div id=\"exportDataContent\" style=\"max-height:50vh;overflow:auto\">点击查询加载数据</div></div>';
    m.onclick=function(e){if(e.target===m)m.remove()};document.body.appendChild(m)
  })
}
async function loadExportData(){var p=new URLSearchParams(),df=document.getElementById('exDateFrom')?.value,dt=document.getElementById('exDateTo')?.value,did=document.getElementById('exDept')?.value,sid=document.getElementById('exShop')?.value,st=document.getElementById('exStatus')?.value;if(df)p.set('date_from',df);if(dt)p.set('date_to',dt);if(did)p.set('department_id',did);if(sid)p.set('repair_shop_id',sid);if(st)p.set('status',st);var data=await api('/admin/export-orders?'+p.toString());if(!data)return;window._exportData=data;
  var html='<table><tr><th>工单号</th><th>车辆</th><th>部门</th><th>报修人</th><th>修理厂</th><th>故障</th><th>状态</th><th>配件费</th><th>人工费</th><th>工时费</th><th>合计</th><th>报修</th><th>接单</th><th>报价</th><th>维修</th><th>完工</th><th>验收</th></tr>';
  data.forEach(function(o){html+='<tr><td style=\"font-size:11px\">'+o.order_no+'</td><td>'+(o.plate_number||'')+'</td><td>'+(o.dept_name||'总调度室')+'</td><td>'+(o.driver_name||'')+'</td><td>'+(o.repair_shop_name||'')+'</td><td style=\"font-size:11px;max-width:120px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis\">'+(o.fault_description||'').substring(0,30)+'</td><td>'+STATUS_MAP[o.status]+'</td><td>'+(o.parts_cost||0)+'</td><td>'+(o.labor_cost||0)+'</td><td>'+(o.hours_cost||0)+'</td><td style=\"font-weight:bold;color:var(--danger)\">'+(o.quote_amount||0)+'</td><td style=\"font-size:11px\">'+((o.report_date||'').slice(0,10))+'</td><td style=\"font-size:11px\">'+((o.accept_date||'').slice(0,10))+'</td><td style=\"font-size:11px\">'+((o.quote_date||'').slice(0,10))+'</td><td style=\"font-size:11px\">'+((o.repair_start_date||'').slice(0,10))+'</td><td style=\"font-size:11px\">'+((o.complete_date||'').slice(0,10))+'</td><td style=\"font-size:11px\">'+((o.accept_vehicle_date||'').slice(0,10))+'</td></tr>'});
  html+='</table>';document.getElementById('exportDataContent').innerHTML='<div style=\"margin-bottom:8px;color:var(--text2)\">共 '+(data||[]).length+' 条</div>'+html
}
function downloadExportCSV(){var data=window._exportData;if(!data||!data.length)return alert('请先查询');var sm={pending_accept:'待接单',pending_quote:'待报价',pending_approval:'待审批',approved:'已通过',rejected:'已驳回',repairing:'维修中',completed:'待验收',accepted:'已完成'};var csv='﻿工单号,车辆,部门,报修人,修理厂,故障,状态,配件费,人工费,工时费,合计,报修日期,接单日期,报价日期,维修日期,完工日期,验收日期\\n';data.forEach(function(o){csv+=o.order_no+','+(o.plate_number||'')+','+(o.dept_name||'总调度室')+','+(o.driver_name||'')+','+(o.repair_shop_name||'')+',\"'+(o.fault_description||'').replace(/\"/g,'\"\"')+'\",'+(sm[o.status]||o.status)+','+(o.parts_cost||0)+','+(o.labor_cost||0)+','+(o.hours_cost||0)+','+(o.quote_amount||0)+','+((o.report_date||'').slice(0,10))+','+((o.accept_date||'').slice(0,10))+','+((o.quote_date||'').slice(0,10))+','+((o.repair_start_date||'').slice(0,10))+','+((o.complete_date||'').slice(0,10))+','+((o.accept_vehicle_date||'').slice(0,10))+'\\n'});var blob=new Blob(['﻿'+csv],{type:'text/csv;charset=utf-8'});var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='维修工单导出.csv';a.click()}

// ===== PARTS =====
function showPartsManagement(){
  Promise.all([api('/inspection/parts-list'),api('/inspection/parts/requisitions?pageSize=200')]).then(function(r){var parts=r[0],reqs=r[1]||[];
    var m=document.createElement('div');m.className='modal-mask';
    m.innerHTML='<div class=\"modal\" style=\"max-width:900px;max-height:90vh\"><h3>🔧 配件管理</h3><div class=\"row2\"><div class=\"card\"><div class=\"card-title\">库存 <button class=\"btn btn-p btn-sm\" onclick=\"showAddPart()\">+添加</button></div><div style=\"max-height:300px;overflow:auto\"><table><tr><th>名称</th><th>编码</th><th>库存</th><th>单位</th></tr>'+(parts||[]).map(function(p){return '<tr><td>'+p.part_name+'</td><td>'+(p.part_code||'-')+'</td><td style=\"color:'+(p.quantity<5?'var(--danger)':'')+'\">'+p.quantity+'</td><td>'+p.unit+'</td></tr>'}).join('')+'</table></div></div><div class=\"card\"><div class=\"card-title\">领用记录 <button class=\"btn btn-s btn-sm\" onclick=\"exportPartsCSV()\">导出CSV</button></div><div style=\"max-height:300px;overflow:auto\"><table><tr><th>申请人</th><th>配件</th><th>车辆</th><th>数量</th><th>状态</th><th>时间</th><th>操作</th></tr>'+reqs.map(function(x){return '<tr><td>'+x.user_name+'</td><td>'+x.part_name+'</td><td>'+(x.plate_number||'-')+'</td><td>'+x.quantity+'</td><td><span class=\"tag '+(x.status==='completed'?'t-done':x.status==='rejected'?'t-reject':'t-pending')+'\">'+(x.status==='pending'?'待确认':x.status==='completed'?'已出库':'已驳回')+'</span></td><td style=\"font-size:12px\">'+(x.created_at||'').slice(0,16)+'</td><td>'+(x.status==='pending'?'<button class=\"btn btn-s btn-sm\" onclick=\"confirmPart('+x.id+',event)\">确认出库</button>':'')+'</td></tr>'}).join('')+'</table></div></div></div><div style=\"text-align:right;margin-top:12px\"><button class=\"btn\" onclick=\"this.closest(\\'.modal-mask\\').remove()\">关闭</button></div></div>';
    document.body.appendChild(m);window._partsReqData=reqs;m.onclick=function(e){if(e.target===m)m.remove()}
  })
}
function showAddPart(){showModal('添加配件','<div class=\"row2\"><div class=\"form-group\"><label>名称</label><input id=\"pname\" /></div><div class=\"form-group\"><label>编码</label><input id=\"pcode\" /></div></div><div class=\"row2\"><div class=\"form-group\"><label>数量</label><input id=\"pqty\" type=\"number\" value=\"0\" /></div><div class=\"form-group\"><label>单位</label><input id=\"punit\" value=\"个\" /></div></div>',async function(mask){var n=document.getElementById('pname').value.trim();if(!n){alert('请填写名称');return false};await api('/inspection/parts/add',{method:'POST',data:{part_name:n,part_code:document.getElementById('pcode').value,quantity:+document.getElementById('pqty').value||0,unit:document.getElementById('punit').value||'个'}});toast('添加成功');mask.remove();renderPage()})}
async function confirmPart(id,e){if(e)e.stopPropagation();if(!confirm('确认出库？'))return;await api('/inspection/parts/confirm/'+id,{method:'POST'});toast('已确认');renderPage()}
function exportPartsCSV(){var data=window._partsReqData;if(!data||!data.length)return alert('无数据');var csv='﻿申请人,配件,编码,车辆,数量,状态,时间\\n';data.forEach(function(x){csv+=x.user_name+','+x.part_name+','+(x.part_code||'')+','+(x.plate_number||'')+','+x.quantity+','+(x.status==='completed'?'已出库':x.status==='pending'?'待确认':'已驳回')+','+(x.created_at||'').slice(0,16)+'\\n'});var blob=new Blob([csv],{type:'text/csv;charset=utf-8'});var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='配件领用记录.csv';a.click()}
function showPartsRequisition(){Promise.all([api('/inspection/parts-list'),api('/vehicles')]).then(function(r){var parts=r[0],vs=r[1];if(!parts||!parts.length)return alert('暂无可用配件');var vOpts='<option value=\"\">不指定车辆</option>'+vs.map(function(v){return '<option value=\"'+v.id+'\">'+v.plate_number+'（'+(v.vehicle_type||'')+'）</option>'}).join('');showModal('配件领用申请','<div class=\"form-group\"><label>配件</label><select id=\"reqPartId\">'+parts.map(function(p){return '<option value=\"'+p.id+'\">'+p.part_name+' '+(p.part_code||'')+'（库存:'+p.quantity+(p.unit||'个')+'）</option>'}).join('')+'</select></div><div class=\"form-group\"><label>车辆</label><select id=\"reqVehicleId\">'+vOpts+'</select></div><div class=\"form-group\"><label>数量</label><input id=\"reqQty\" type=\"number\" value=\"1\" /></div><div class=\"form-group\"><label>原因</label><textarea id=\"reqReason\"></textarea></div>',async function(mask){var pid=+document.getElementById('reqPartId').value,vid=+document.getElementById('reqVehicleId').value||null,qty=+document.getElementById('reqQty').value;if(qty<1){alert('数量至少为1');return false};var reason=document.getElementById('reqReason').value.trim();await api('/inspection/parts/requisition',{method:'POST',data:{part_id:pid,vehicle_id:vid,quantity:qty,reason:reason}});toast('申请已提交');mask.remove();renderPage()})})}

// ===== ATTENDANCE REPORT =====
function showAttendanceReport(){api('/inspection/driver-list').then(function(ds){var dopts='<option value=\"\">全部员工</option>'+ds.map(function(d){return '<option value=\"'+d.id+'\">'+d.name+'</option>'}).join('');var m=new Date().toISOString().slice(0,7);showModal('员工出勤信息','<div class=\"flex\" style=\"margin-bottom:10px\"><div class=\"form-group\" style=\"margin:0\"><label>员工</label><select id=\"whDriver\">'+dopts+'</select></div></div><div class=\"form-group\"><label>月份</label><input id=\"whMonth\" type=\"month\" value=\"'+m+'\" /></div><div id=\"whContent\"><button class=\"btn btn-p\" onclick=\"loadAttendance()\">出勤工时</button> <button class=\"btn btn-o btn-sm\" onclick=\"loadAttReport()\">考勤加班</button></div>',function(mask){mask.remove()})})}
async function loadAttendance(){var m=document.getElementById('whMonth').value;if(!m)return alert('请选择月份');var data=await api('/inspection/work-hours-report?month='+m);if(!data)return;window._whData=data;var html='<div style=\"margin-bottom:8px\"><button class=\"btn btn-s btn-sm\" onclick=\"exportAttendanceCSV()\">导出CSV</button></div>';html+='<h4>按人汇总</h4><table><tr><th>姓名</th><th>出勤天数</th><th>总工时(h)</th><th>总加油(L)</th></tr>';(data.summary||[]).forEach(function(s){html+='<tr><td><b>'+s.driver_name+'</b></td><td>'+s.days+'天</td><td style=\"color:var(--primary)\">'+s.total_hours.toFixed(1)+'h</td><td>'+s.total_fuel.toFixed(1)+'L</td></tr>'});html+='</table><h4>每日明细</h4><table><tr><th>姓名</th><th>日期</th><th>车辆</th><th>工时</th><th>加油</th></tr>';(data.detail||[]).forEach(function(x){html+='<tr><td>'+x.driver_name+'</td><td>'+x.inspection_date+'</td><td>'+x.plate_number+'</td><td style=\"color:var(--primary)\">'+(x.work_hours>0?x.work_hours.toFixed(1)+'h':'-')+'</td><td>'+(x.fuel_amount>0?x.fuel_amount+'L':'-')+'</td></tr>'});html+='</table>';document.getElementById('whContent').innerHTML=html}
function exportAttendanceCSV(){var data=window._whData;if(!data||!data.detail||!data.detail.length)return alert('无');var csv='﻿姓名,日期,车辆,工时,加油\\n';data.detail.forEach(function(x){csv+=x.driver_name+','+x.inspection_date+','+x.plate_number+','+x.work_hours+','+(x.fuel_amount||0)+'\\n'});var blob=new Blob(['﻿'+csv],{type:'text/csv;charset=utf-8'});var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='员工出勤.csv';a.click()}
function loadAttReport(){var m=document.getElementById('whMonth').value,did=document.getElementById('whDriver')?.value;if(!m)return alert('请选择月份');api('/inspection/attendance/report?month='+m+(did?'&driver_id='+did:'')).then(function(data){if(!data||!data.length){document.getElementById('whContent').innerHTML='<div class=\"empty\">暂无</div>';return}window._attData=data;var html='<div style=\"margin-bottom:8px\"><button class=\"btn btn-s btn-sm\" onclick=\"expAttCSV()\">导出考勤CSV</button> <button class=\"btn btn-o btn-sm\" onclick=\"expOTCSV()\">导出加班CSV</button></div><table><tr><th>姓名</th><th>日期</th><th>考勤符号</th><th>加班时段</th><th>加班地点</th></tr>';data.forEach(function(x){var ot=x.overtime_hours>0?(x.overtime_start||'')+'→'+(x.overtime_end||'')+' ('+x.overtime_hours+'h)':'-';html+='<tr><td>'+x.driver_name+'</td><td>'+x.attendance_date+'</td><td>'+(x.attendance_symbol||'-')+'</td><td>'+ot+'</td><td>'+(x.overtime_location||'-')+'</td></tr>'});html+='</table>';document.getElementById('whContent').innerHTML=html})}
function expAttCSV(){var d=window._attData;if(!d)return;var csv='﻿姓名,日期,考勤符号\\n';d.forEach(function(x){csv+=x.driver_name+','+x.attendance_date+','+(x.attendance_symbol||'-')+'\\n'});var blob=new Blob([csv],{type:'text/csv;charset=utf-8'});var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='考勤记录.csv';a.click()}
function expOTCSV(){var d=window._attData;if(!d)return;var csv='﻿姓名,日期,加班开始,加班结束,加班小时,加班地点\\n';d.forEach(function(x){csv+=x.driver_name+','+x.attendance_date+','+(x.overtime_start||'')+','+(x.overtime_end||'')+','+x.overtime_hours+','+(x.overtime_location||'-')+'\\n'});var blob=new Blob([csv],{type:'text/csv;charset=utf-8'});var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download='加班记录.csv';a.click()}

// ===== OTHER FUNCTIONS =====
function showTodayInspDetail(){var today=new Date().toISOString().slice(0,10);api('/inspection/all-records?date='+today+'&pageSize=200').then(function(rs){showModal('点检记录 - '+today,(rs||[]).length?'<table><tr><th>车辆</th><th>检查人</th><th>油位</th><th>水位</th><th>外观</th><th>轮胎</th><th>工时</th><th>备注</th><th>状态</th></tr>'+rs.map(function(x){return '<tr><td>'+x.plate_number+'</td><td>'+x.driver_name+'</td><td>'+(LEVEL_MAP[x.oil_level]||'-')+'</td><td>'+(LEVEL_MAP[x.coolant_level]||'-')+'</td><td>'+(APPEAR_MAP[x.appearance]||'-')+'</td><td>'+(TIRE_MAP[x.tire_condition]||'-')+'</td><td>'+(x.engine_hours||'-')+'h</td><td>'+(x.notes||'-')+'</td><td><span class=\"tag '+(x.overall_status==='normal'?'t-done':'t-reject')+'\">'+(x.overall_status==='normal'?'正常':'异常')+'</span></td></tr>'}).join('')+'</table>':'<div class=\"empty\">暂无记录</div>')})}
function showDeptManagement(){Promise.all([api('/external/departments'),api('/admin/users?role=external')]).then(function(r){var depts=r[0],users=r[1]||[];showModal('外部门管理','<div class=\"row2\"><div class=\"card\"><div class=\"card-title\">部门 <button class=\"btn btn-p btn-sm\" onclick=\"addDept()\">+添加</button></div><table><tr><th>名称</th><th>操作</th></tr>'+depts.map(function(d){return '<tr><td>'+d.name+'</td><td><button class=\"btn btn-s btn-sm\" onclick=\"createDeptAccount('+d.id+',\\''+d.name+'\\')\">创建账号</button></td></tr>'}).join('')+'</table></div><div class=\"card\"><div class=\"card-title\">账号</div><table><tr><th>姓名</th><th>手机</th></tr>'+users.map(function(u){return '<tr><td>'+u.name+'</td><td>'+u.phone+'</td></tr>'}).join('')+'</table></div></div>')})}
function addDept(){var n=prompt('请输入部门名称：');if(!n)return;api('/external/departments/add',{method:'POST',data:{name:n}}).then(function(){toast('添加成功');renderPage()})}
function createDeptAccount(did,dn){var ph=prompt('为\"'+dn+'\"创建登录账号\\n请输入手机号：');if(!ph)return;api('/external/departments/create-account',{method:'POST',data:{department_id:did,phone:ph,name:dn}}).then(function(){toast('账号已创建默认密码123456');renderPage()})}
function showOperationLogs(){api('/admin/operation-logs').then(function(logs){showModal('操作日志','<div style=\"max-height:60vh;overflow:auto\"><table><tr><th>时间</th><th>操作人</th><th>操作</th><th>详情</th></tr>'+(logs||[]).map(function(l){return '<tr><td style=\"font-size:11px;white-space:nowrap\">'+(l.created_at||'').slice(0,16)+'</td><td>'+l.user_name+'</td><td>'+l.action+'</td><td style=\"font-size:11px\">'+(l.detail||'-')+'</td></tr>'}).join('')+'</table></div>')})}
function backupDB(){api('/admin/backup-db',{method:'POST'}).then(function(){toast('备份成功')})}
function editEstimate(key,title){var cur=document.getElementById(key==='month_estimate'?'estMonth':'estYear')?.textContent.replace('¥','')||'0';var val=prompt('请输入'+title+'（元）',cur);if(val===null)return;api('/admin/config/save',{method:'POST',data:{config:{[key]:parseFloat(val)||0}}}).then(function(){document.getElementById(key==='month_estimate'?'estMonth':'estYear').textContent='¥'+val})}
function renderMonthlyChart(data){if(!data||!data.length)return'<div class=\"card\"><div class=\"card-title\">📊 月度维修费用趋势</div><div class=\"empty\" style=\"padding:30px\">暂无数据</div></div>';var months=data.map(function(d){return d.month}).reverse(),costs=data.map(function(d){return d.total_cost}).reverse(),counts=data.map(function(d){return d.order_count}).reverse(),maxC=Math.max.apply(null,costs.concat([1]));var bars=months.map(function(m,i){var h=Math.max((costs[i]/maxC)*100,3);return'<div style=\"flex:1;display:flex;flex-direction:column;align-items:center;min-width:50px\"><div style=\"font-size:11px;color:var(--danger);font-weight:bold;margin-bottom:2px\">¥'+(costs[i]/10000).toFixed(1)+'万</div><div style=\"width:36px;height:'+h+'px;background:linear-gradient(to top,#1677ff,#69b1ff);border-radius:4px 4px 0 0\" title=\"'+m+': ¥'+costs[i]+' ('+counts[i]+'单)\"></div><div style=\"font-size:10px;color:var(--text2);margin-top:4px\">'+m.slice(2)+'</div></div>'}).join('');return'<div class=\"card\"><div class=\"card-title\">📊 月度维修费用趋势</div><div style=\"display:flex;align-items:flex-end;gap:8px;padding:10px 0;overflow-x:auto\">'+bars+'</div></div>'}
function showVehiclesByStatus(s,t){api('/vehicles').then(function(vs){var list=s==='normal'?vs.filter(function(v){if(v.status!=='normal')return false;var c=v.latest_end_hours||v.initial_engine_hours||0,n=v.next_maintenance_hours||0;return n===0||c<n}):s==='expired'?vs.filter(function(v){var c=v.latest_end_hours||v.initial_engine_hours||0,n=v.next_maintenance_hours||0;return n>0&&c>=n}):s==='repairing'?vs.filter(function(v){return v.status==='repairing'}):s?vs.filter(function(v){return v.status===s}):vs;if(!list.length)return alert('暂无');var rows='';list.forEach(function(v){var a=v.purchase_date?((new Date()-new Date(v.purchase_date))/(365.25*86400000)).toFixed(1)+'年':'-',c=v.latest_end_hours||v.initial_engine_hours||0,n=v.next_maintenance_hours||0,r=c&&n?n-c:999,st=r<0?'<span class=\"tag t-reject\">过期</span>':r<50?'<span class=\"tag t-pending\">即将保养</span>':'<span class=\"tag t-done\">正常</span>';rows+='<tr><td><b>'+v.plate_number+'</b></td><td>'+(v.vehicle_type||'-')+'</td><td>'+(v.model||'-')+'</td><td>'+a+'</td><td>'+c+'h</td><td>'+n+'h</td><td>'+st+'</td></tr>'});showModal(t+' ('+list.length+'辆)','<table><tr><th>编号</th><th>类型</th><th>型号</th><th>车龄</th><th>工时</th><th>下次保养</th><th>状态</th></tr>'+rows+'</table>')})}

// ===== ALERTS & CLOCK =====
async function loadSystemAlerts(){var vs=await api('/vehicles'),parts=await api('/inspection/parts-list'),config=await api('/admin/config');var threshold=parseInt(config.low_stock_threshold)||5;var maintSoon=(vs||[]).filter(function(v){return v.next_maintenance_hours&&v.latest_end_hours&&(v.next_maintenance_hours-v.latest_end_hours<50)});var lowStock=(parts||[]).filter(function(p){return p.quantity<threshold});var html='';if(maintSoon.length)html+='<div style=\"color:var(--warning);margin-bottom:4px\">🔧 '+maintSoon.length+'辆车即将到保养时间</div>';if(lowStock.length)html+='<div style=\"color:var(--danger);margin-bottom:4px\">📦 '+lowStock.length+'种配件库存低于'+threshold+'个</div>';if(!html)html='<div style=\"color:var(--success)\">✅ 系统正常，无预警</div>';html+='<div style=\"margin-top:6px\"><button class=\"btn btn-sm btn-o\" onclick=\"editStockThreshold()\">设置阈值:'+threshold+'个</button></div>';var el=document.getElementById('sysAlerts');if(el)el.innerHTML=html;var me=document.getElementById('maintAlerts');if(me&&maintSoon.length)me.innerHTML='⚠ '+maintSoon.map(function(v){return v.plate_number+'距保养仅剩'+(v.next_maintenance_hours-v.latest_end_hours)+'h'}).join('，');else if(me)me.innerHTML=''}
function editStockThreshold(){var v=prompt('设置库存预警阈值（当前：'+(parseInt((window._lastConfig||{}).low_stock_threshold)||5)+'个）',(parseInt((window._lastConfig||{}).low_stock_threshold)||5));if(v===null)return;api('/admin/config/save',{method:'POST',data:{config:{low_stock_threshold:parseInt(v)||5}}}).then(function(){toast('已设置');renderPage()})}

function updateClock(){var now=new Date(),t=now.getHours().toString().padStart(2,'0')+':'+now.getMinutes().toString().padStart(2,'0')+':'+now.getSeconds().toString().padStart(2,'0');var el=document.getElementById('liveClock');if(el)el.textContent=t}
setInterval(updateClock,1000);

// Init
window.onload=function(){
  var saved=localStorage.getItem('mp_token');
  if(saved){TOKEN=saved;USER=JSON.parse(localStorage.getItem('mp_user'));document.getElementById('loginPage').style.display='none';document.getElementById('mainPage').style.display='';document.getElementById('userArea').style.display='';document.getElementById('currentUser').textContent=USER.name+'（'+ROLE_MAP[USER.role]+'）';if(USER.role==='admin'){document.getElementById('roleFilter').style.display='';document.getElementById('roleFilter').innerHTML='<option value=\"\">管理员视角</option><option value=\"driver\">驾驶员</option><option value=\"repair_shop\">修理厂</option><option value=\"leader\">科级审批</option>'}renderPage();updateClock()}
};
`;

const result = before + js + after;
fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', result, 'utf8');
console.log('File rebuilt! Size:', result.length, 'bytes');
