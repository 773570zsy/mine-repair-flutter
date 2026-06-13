const fs = require('fs');
let h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

// ==== 1. Add password change button in topbar ====
let topBar = '<button class="btn btn-sm btn-o" onclick="doLogout()" style="color:var(--text);border-color:var(--border)">退出</button>';
let topBarNew = '<button class="btn btn-sm btn-o" onclick="changePassword()" style="color:var(--text);border-color:var(--border);margin-right:4px">修改密码</button><button class="btn btn-sm btn-o" onclick="doLogout()" style="color:var(--text);border-color:var(--border)">退出</button>';
if (h.includes(topBar)) {
  h = h.replace(topBar, topBarNew);
  console.log('1. Added password change button');
}

// ==== 2. Add changePassword function ====
let logoutFunc = 'function doLogout() {';
let pwdFunc = `
function changePassword() {
  const oldPwd = prompt('请输入原密码（默认123456）：');
  if (oldPwd === null) return;
  const newPwd = prompt('请输入新密码（至少4位）：');
  if (!newPwd || newPwd.length < 4) return alert('新密码至少4位');
  api('/admin/change-password', {method:'POST', data:{old_pwd:oldPwd, new_pwd:newPwd}}).then(()=>{
    alert('密码修改成功，请重新登录');
    doLogout();
  });
}

function doLogout() {`;
if (h.includes(logoutFunc)) {
  h = h.replace(logoutFunc, pwdFunc);
  console.log('2. Added changePassword function');
}

// ==== 3. Add operation log viewer to admin ====
let deptMgmt = 'onclick="showDeptManagement()"';
let logCard = 'onclick="showOperationLogs()"><h3>📝</h3>操作日志<br><span style="font-size:12px;color:var(--text2)">系统操作追溯</span></div>\n      <div class="card" style="text-align:center;cursor:pointer" onclick="showDeptManagement()"';
if (h.includes(deptMgmt)) {
  // Add log card before dept management
  h = h.replace(deptMgmt, logCard);
  console.log('3. Added operation log card');
}

// ==== 4. Add showOperationLogs function ====
let initSection = '\n// ==================== 初始化 ====================';
let logFunc = `
// ========== 操作日志 ==========
function showOperationLogs() {
  api('/admin/operation-logs').then(logs => {
    showModal('操作日志', \`
      <div style="max-height:60vh;overflow:auto">
        <table><tr><th>时间</th><th>操作人</th><th>操作</th><th>详情</th></tr>
        \${(logs||[]).map(l=>\`<tr><td style="font-size:11px;white-space:nowrap">\${(l.created_at||'').slice(0,16)}</td><td>\${l.user_name}</td><td>\${l.action}</td><td style="font-size:11px">\${l.detail||'-'}</td></tr>\`).join('')}
      </table></div>
    \`);
  });
}

${initSection}`;
if (h.includes(initSection)) {
  h = h.replace(initSection, logFunc);
  console.log('4. Added showOperationLogs function');
}

// ==== 5. Add stock threshold and maintenance alert to admin dashboard ====
// Add alert cards before the row3 cards
let row3Start = '<div class="row3">';
let alertCards = `<div class="card" style="border-left:3px solid var(--danger)">
    <div class="card-title">⚠ 系统预警</div>
    <div id="sysAlerts" style="font-size:13px">正在检测...</div>
  </div>
  <div class="row3">`;
if (h.includes(row3Start)) {
  h = h.replace(row3Start, alertCards);
  console.log('5. Added system alerts section');
}

// ==== 6. Add updateSystemAlerts function to renderAdmin ====
let renderAdminEnd = 'el.innerHTML = `<div class="layout">';
let renderAdminAlert = 'el.innerHTML = `<div class="layout">\n    <div class="card" style="border-left:3px solid var(--warning);margin-bottom:16px"><div class="card-title">⚠ 系统预警</div><div id="sysAlerts" style="font-size:13px">检测中...</div></div>';
if (h.includes(renderAdminEnd)) {
  // Replace only in renderAdmin context
  h = h.replace('async function renderAdmin() {', 'async function renderAdmin() { loadSystemAlerts();');
  console.log('6. Added alert loading to renderAdmin');
}

// ==== 7. Add maintenance alerts to driver dashboard ====
let driverDashCard = '<div class="card"><div class="card-title">🔧 快速报修';
let maintAlert = '<div class="card" style="border-left:3px solid var(--warning);margin-bottom:0"><div id="maintAlerts" style="font-size:12px;color:var(--warning)">检测中...</div></div>\n    <div class="card"><div class="card-title">🔧 快速报修';
if (h.includes(driverDashCard)) {
  h = h.replace(driverDashCard, maintAlert);
  console.log('7. Added maintenance alert to driver dashboard');
}

// ==== 8. Add the alert loading functions ====
let renderPageFunc = 'function renderPage() {';
let alertFunctions = `
async function loadSystemAlerts() {
  const [vehicles, parts, config] = await Promise.all([
    api('/vehicles'), api('/inspection/parts-list'), api('/admin/config')
  ]);
  const threshold = parseInt(config.low_stock_threshold) || 5;
  const maintSoon = (vehicles||[]).filter(v=>v.next_maintenance_hours&&v.engine_hours&&(v.next_maintenance_hours-v.engine_hours<50));
  const lowStock = (parts||[]).filter(p=>p.quantity < threshold);

  let html = '';
  if (maintSoon.length) html += '<div style="color:var(--warning);margin-bottom:4px">🔧 '+maintSoon.length+'辆车即将到保养时间</div>';
  if (lowStock.length) html += '<div style="color:var(--danger);margin-bottom:4px">📦 '+lowStock.length+'种配件库存低于'+threshold+'个</div>';
  if (!html) html = '<div style="color:var(--success)">✅ 系统正常，无预警</div>';
  html += '<div style="margin-top:6px"><button class="btn btn-sm btn-o" onclick="editStockThreshold()">设置库存阈值:'+threshold+'个</button></div>';

  const el = document.getElementById('sysAlerts');
  if (el) el.innerHTML = html;

  const me = document.getElementById('maintAlerts');
  if (me && maintSoon.length) me.innerHTML = '⚠ '+maintSoon.map(v=>v.plate_number+'距保养仅剩'+(v.next_maintenance_hours-v.engine_hours)+'h').join('，');
  else if (me) me.innerHTML = '';
}

function editStockThreshold() {
  const v = prompt('设置库存预警阈值（当前：'+(parseInt((window._lastConfig||{}).low_stock_threshold)||5)+'个）', (parseInt((window._lastConfig||{}).low_stock_threshold)||5));
  if (v===null) return;
  api('/admin/config/save', {method:'POST', data:{config:{low_stock_threshold:parseInt(v)||5}}}).then(()=>{
    alert('已设置'); renderPage();
  });
}

function renderPage() {`;
if (h.includes(renderPageFunc)) {
  h = h.replace(renderPageFunc, alertFunctions);
  console.log('8. Added alert functions');
}

// ==== 9. Mobile responsive improvements ====
let mediaQuery = '@media(max-width:768px){.row2,.row3,.grid-3{grid-template-columns:1fr}.stats-grid{grid-template-columns:repeat(2,1fr)}}';
let newMedia = `@media(max-width:768px){
  .row2,.row3,.grid-3{grid-template-columns:1fr}
  .stats-grid{grid-template-columns:repeat(2,1fr)}
  .topbar h1{font-size:15px}
  .topbar{padding:10px 12px}
  .layout{padding:12px}
  .card{padding:12px;margin-bottom:10px}
  .modal{width:95%;padding:16px;max-width:95%}
  .btn{padding:10px 16px;font-size:15px}
  table{font-size:11px}
  th,td{padding:6px 8px}
  .stat-num{font-size:22px}
}`;
if (h.includes(mediaQuery)) {
  h = h.replace(mediaQuery, newMedia);
  console.log('9. Improved mobile styles');
}

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', h, 'utf8');
console.log('\nAll v2 changes applied!');
