// Write the final clean HTML file
const fs = require('fs');
const path = require('path');

// Read the extracted JS (use __dirname for portability)
const dashboardDir = path.join(__dirname, 'public', 'dashboard');
const modulesDir = path.join(__dirname, 'public', 'modules');

const appJs = fs.readFileSync(path.join(__dirname, 'public', 'app.js'), 'utf8');

// Read all modules and dashboards (order: shared tools first, then dashboards)
const moduleFiles = [
  'admin-tools.js',  // shared admin utilities
  'repair.js',       // repair workflow
  'inspection.js',   // inspection forms
  'attendance.js',   // attendance/overtime
  'quiz.js',             // daily quiz
  'vehicle-archive.js', // vehicle archives
];
const dashboardFiles = [
  'admin.js',
  'dispatcher.js',
  'applicant.js',
  'driver.js',
  'shop.js',
  'leader.js',
];

let allModulesJs = '';
moduleFiles.forEach(f => {
  try { allModulesJs += fs.readFileSync(path.join(modulesDir, f), 'utf8') + '\n'; } catch(e) { console.log('Skip missing module:', f); }
});
dashboardFiles.forEach(f => {
  try { allModulesJs += fs.readFileSync(path.join(dashboardDir, f), 'utf8') + '\n'; } catch(e) { console.log('Skip missing dashboard:', f); }
});

// Read machinery module for inline embedding
const machineryJs = fs.readFileSync(path.join(__dirname, 'public', 'modules', 'machinery.js'), 'utf8');

// Full CSS
const css = `
*{margin:0;padding:0;box-sizing:border-box}
:root{--gold:#c8a04a;--gold-light:#e0c878;--copper:#b87333;--steel:#7a8a9a;--danger:#e05555;--warning:#d4a017;--success:#5a9e5f;--bg:#1a1d23;--surface:#242830;--surface2:#2a2e38;--border:#3a3f4a;--text:#d0d4dc;--text2:#9098a6}
body{font-family:-apple-system,BlinkMacSystemFont,'Microsoft YaHei',sans-serif;background:var(--bg);color:var(--text);min-height:100vh;background-image:radial-gradient(ellipse at 20% 50%,rgba(200,160,74,.04)0%,transparent 50%),radial-gradient(ellipse at 80% 20%,rgba(184,115,51,.04)0%,transparent 50%)}
.topbar{background:linear-gradient(180deg,#2a2e38 0%,#1e2128 100%);border-bottom:1px solid var(--border);color:var(--text);padding:14px 24px;display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:10px;box-shadow:0 2px 12px rgba(0,0,0,.3);position:sticky;top:0;z-index:100}
.topbar h1{font-size:18px;font-weight:700;letter-spacing:1px;background:linear-gradient(135deg,var(--gold-light),var(--copper));-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.user-area{display:flex;align-items:center;gap:12px;font-size:13px;color:var(--text2)}
.user-area select{padding:7px 12px;border-radius:6px;border:1px solid var(--border);background:var(--surface);color:var(--text);font-size:13px;outline:none}
.btn{padding:8px 18px;border:none;border-radius:6px;cursor:pointer;font-size:14px;font-weight:500;transition:all .2s;letter-spacing:.5px}
.btn:hover{transform:translateY(-1px);box-shadow:0 4px 12px rgba(0,0,0,.3)}
.btn-p{background:linear-gradient(135deg,var(--gold),var(--copper));color:#1a1d23;font-weight:600}
.btn-s{background:linear-gradient(135deg,#4a8f5a,#3d7349);color:#fff}
.btn-d{background:linear-gradient(135deg,#c0392b,#96281b);color:#fff}
.btn-o{background:transparent;color:var(--gold);border:1px solid var(--gold)}
.btn-o:hover{background:rgba(200,160,74,.1)}
.btn-sm{padding:5px 12px;font-size:12px}
.layout{max-width:1200px;margin:0 auto;padding:20px}
.card{background:var(--surface);border:1px solid var(--border);border-radius:10px;padding:18px;margin-bottom:16px;box-shadow:0 2px 8px rgba(0,0,0,.2);transition:border-color .2s}
.card:hover{border-color:#4a4f5a}
.card-title{font-size:16px;font-weight:700;margin-bottom:14px;padding-bottom:10px;border-bottom:1px solid var(--border);display:flex;justify-content:space-between;align-items:center;color:var(--text)}
.stats-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:14px;margin-bottom:18px}
.stat-item{text-align:center;padding:18px 14px;background:var(--surface2);border:1px solid var(--border);border-radius:10px;transition:all .2s;position:relative;overflow:hidden}
.stat-item::before{content:'';position:absolute;top:0;left:0;right:0;height:2px;background:linear-gradient(90deg,transparent,var(--gold),transparent);opacity:0;transition:opacity .3s}
.stat-item:hover::before,.stat-item:hover::after{opacity:1}
.stat-item:hover{border-color:var(--gold);transform:translateY(-2px);box-shadow:0 6px 20px rgba(0,0,0,.3)}
.stat-num{font-size:30px;font-weight:800;color:var(--gold)}
.stat-label{font-size:12px;color:var(--text2);margin-top:6px;text-transform:uppercase;letter-spacing:1px}
table{width:100%;border-collapse:collapse;font-size:13px}
th{background:var(--surface2);padding:10px 12px;text-align:left;border-bottom:2px solid var(--border);font-weight:600;color:var(--text2);white-space:nowrap;letter-spacing:.5px;font-size:11px;text-transform:uppercase}
td{padding:10px 12px;border-bottom:1px solid var(--border);color:var(--text)}
tr:hover td{background:rgba(200,160,74,.04)}
.tag{display:inline-block;padding:3px 10px;border-radius:4px;font-size:11px;font-weight:500;white-space:nowrap;letter-spacing:.5px}
.t-pending{background:rgba(212,160,23,.15);color:var(--warning);border:1px solid rgba(212,160,23,.3)}
.t-progress{background:rgba(122,138,154,.15);color:#a0b0c0;border:1px solid rgba(122,138,154,.3)}
.t-done{background:rgba(90,158,95,.15);color:var(--success);border:1px solid rgba(90,158,95,.3)}
.t-reject{background:rgba(224,85,85,.15);color:var(--danger);border:1px solid rgba(224,85,85,.3)}
.form-group{margin-bottom:14px}
.form-group label{display:block;margin-bottom:6px;font-weight:500;font-size:13px;color:var(--text2);letter-spacing:.5px}
input,select,textarea{width:100%;padding:10px 14px;border:1px solid var(--border);border-radius:6px;font-size:14px;background:var(--bg);color:var(--text);transition:all .2s;outline:none}
input:focus,select:focus,textarea:focus{border-color:var(--gold);box-shadow:0 0 0 3px rgba(200,160,74,.12)}
input[type=number]::-webkit-inner-spin-button,input[type=number]::-webkit-outer-spin-button{-webkit-appearance:none;margin:0}
input[type=number]{-moz-appearance:textfield}
textarea{resize:vertical;min-height:80px}
::placeholder{color:#5a5e68}
.modal-mask{position:fixed;inset:0;background:rgba(0,0,0,.7);backdrop-filter:blur(4px);-webkit-backdrop-filter:blur(4px);z-index:1000;display:flex;align-items:center;justify-content:center}
.modal{background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:28px;width:90%;max-width:550px;max-height:85vh;overflow:auto;box-shadow:0 16px 48px rgba(0,0,0,.5)}
.tabs{display:flex;gap:8px;flex-wrap:wrap;margin-bottom:14px}
.tab{padding:7px 16px;border-radius:20px;background:var(--surface2);color:var(--text2);font-size:13px;cursor:pointer;border:1px solid var(--border);transition:all .2s;white-space:nowrap}
.tab:hover{border-color:var(--gold);color:var(--text)}
.tab.active{background:linear-gradient(135deg,var(--gold),var(--copper));color:#1a1d23;border-color:transparent;font-weight:600}
.empty{text-align:center;padding:50px 20px;color:var(--text2)}
.order-no{font-family:'JetBrains Mono','Fira Code',monospace;font-weight:700;color:var(--gold-light)}
.flex{display:flex;justify-content:space-between;align-items:center;gap:10px;flex-wrap:wrap}
.timeline{border-left:2px solid var(--border);padding-left:18px;margin-left:8px}
.tl-item{padding:8px 0;position:relative}
.tl-item::before{content:'';position:absolute;left:-24px;top:12px;width:10px;height:10px;border-radius:50%;background:var(--border);border:2px solid var(--surface)}
.tl-item:last-child::before{background:var(--gold);box-shadow:0 0 8px rgba(200,160,74,.4)}
.row2{display:grid;grid-template-columns:1fr 1fr;gap:14px}
.row3{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}
.quiz-modal{max-width:560px;padding:0;overflow:hidden;background:var(--surface);border-radius:14px}
.quiz-progress-bar{width:100%;height:4px;background:var(--surface2)}
.quiz-progress-fill{height:100%;background:linear-gradient(to right,var(--gold),var(--copper));transition:width .3s ease}
.quiz-body{padding:24px}
.quiz-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:16px}
.quiz-question{font-size:16px;font-weight:600;color:var(--text);line-height:1.6;margin-bottom:20px}
.quiz-options{display:flex;flex-direction:column;gap:10px}
.quiz-opt{padding:14px 16px;background:var(--surface2);border:2px solid var(--border);border-radius:10px;cursor:pointer;display:flex;align-items:center;gap:12px;transition:all .2s;font-size:14px;color:var(--text)}
.quiz-opt:hover{border-color:var(--gold);background:rgba(200,160,74,.06)}
.quiz-selected{border-color:var(--gold)!important;background:rgba(200,160,74,.12)!important;box-shadow:0 0 0 1px var(--gold)}
.q-opt-letter{width:28px;height:28px;border-radius:50%;background:var(--border);display:flex;align-items:center;justify-content:center;font-weight:700;font-size:13px;flex-shrink:0}
.quiz-selected .q-opt-letter{background:var(--gold);color:#1a1d23}
.quiz-footer{text-align:right;margin-top:20px}
.quiz-btn{padding:12px 32px;font-size:15px;border-radius:8px}
.like-btn{background:transparent;border:1px solid var(--border);color:var(--text2);padding:4px 10px;border-radius:14px;cursor:pointer;font-size:12px;transition:all .2s}
.like-btn:hover{border-color:var(--primary);color:var(--primary)}
.like-btn.liked{background:rgba(200,160,74,.12);border-color:var(--gold);color:var(--gold)}
.quiz-result-top{text-align:center;padding:30px 20px}
.radio-pill-group{display:flex;gap:10px;flex-wrap:wrap}
.radio-pill{display:flex;align-items:center;gap:6px;padding:10px 16px;background:var(--surface2);border:2px solid var(--border);border-radius:8px;cursor:pointer;font-size:13px;color:var(--text2);transition:all .2s;flex:1;text-align:center;justify-content:center;min-width:120px}
.radio-pill:hover{border-color:var(--gold);color:var(--text)}
.radio-pill.active{border-color:var(--gold);background:rgba(200,160,74,.12);color:var(--gold);font-weight:600;box-shadow:0 0 0 1px var(--gold)}
.upload-btn:hover{border-color:var(--gold)!important;background:rgba(200,160,74,.06)!important;color:var(--text)!important}
/* 通知面板 */
.notif-panel{position:fixed;right:16px;width:380px;max-width:92vw;z-index:2000;animation:notifIn .2s ease}
.notif-panel-inner{max-height:420px;overflow-y:auto;background:var(--surface);border:1px solid var(--border);border-radius:12px;box-shadow:0 12px 48px rgba(0,0,0,.55)}
.notif-header{display:flex;justify-content:space-between;align-items:center;padding:12px 16px;border-bottom:1px solid var(--border);position:sticky;top:0;background:var(--surface);border-radius:12px 12px 0 0;z-index:2}
.notif-header b{font-size:15px}
.notif-empty{padding:32px 16px;text-align:center;color:var(--text2);font-size:14px}
.notif-item{display:block;padding:12px 16px;border-bottom:1px solid var(--border);cursor:pointer;transition:background .12s;text-decoration:none;color:inherit;width:100%}
.notif-item:last-child{border-bottom:none;border-radius:0 0 12px 12px}
.notif-item:hover{background:rgba(200,160,74,.08)}
.notif-item:active{background:rgba(200,160,74,.15)}
.notif-item.unread{background:rgba(200,160,74,.04)}
.notif-item.unread:hover{background:rgba(200,160,74,.12)}
.notif-item-head{display:flex;align-items:flex-start;gap:8px;margin-bottom:4px}
.notif-item-icon{flex-shrink:0;font-size:18px;width:24px;text-align:center}
.notif-item-title{flex:1;font-weight:600;font-size:14px;line-height:1.3}
.notif-item-time{flex-shrink:0;font-size:11px;color:var(--text2);white-space:nowrap}
.notif-item-body{font-size:12px;color:var(--text2);line-height:1.4;margin-left:32px}
.notif-dot{display:inline-block;width:7px;height:7px;border-radius:50%;background:var(--gold);margin-right:6px;flex-shrink:0}
@keyframes notifIn{from{transform:translateY(-10px);opacity:0}to{transform:translateY(0);opacity:1}}
@keyframes slideIn{from{transform:translateX(100px);opacity:0}to{transform:translateX(0);opacity:1}}
@media(max-width:768px){
  .row2,.row3,.grid-3{grid-template-columns:1fr}
  .stats-grid{grid-template-columns:repeat(2,1fr)}
  .topbar h1{font-size:12px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
  .topbar{padding:6px 10px;position:sticky;top:0}
  .layout{padding:8px}
  .card{padding:10px;margin-bottom:8px;overflow:auto}
  .modal{width:98%;padding:14px;max-width:98%}
  .btn{padding:10px 14px;font-size:14px}
  table{font-size:11px;min-width:600px}
  th,td{padding:5px 7px}
  .stat-num{font-size:20px}
  .stat-item{padding:12px 8px}
  .stat-label{font-size:10px}
  .card{overflow-x:auto;-webkit-overflow-scrolling:touch}
  .flex{flex-wrap:wrap;gap:6px}
  .order-no{font-size:11px}
  input,select,textarea{font-size:16px;padding:8px 10px}
  #liveClock{display:none}
}
`;

// Build complete HTML
const html = `<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
<title>总调度室综合管理系统</title>
<link rel="manifest" href="/manifest.json">
<meta name="theme-color" content="#1a1d23">
<meta name="apple-mobile-web-app-capable" content="yes">
<style>${css}</style>
</head>
<body>
<div class="topbar">
  <h1>🛠️ 总调度室综合管理系统 <span id="liveClock" style="font-size:14px;margin-left:12px;color:var(--gold);font-family:monospace">--:--:--</span></h1>
  <div class="user-area" id="userArea" style="display:none">
    <span id="notifyBell" style="cursor:pointer;position:relative;margin-right:10px;font-size:20px" onclick="toggleNotifPanel()" title="通知">🔔<span id="notifyBadge" style="position:absolute;top:-6px;right:-10px;background:var(--danger);color:#fff;border-radius:50%;min-width:18px;height:18px;font-size:10px;display:none;align-items:center;justify-content:center;padding:0 3px;line-height:18px">0</span></span>
    <span id="currentUser"></span>

    <button class="btn btn-sm btn-o" onclick="changePassword()" style="color:var(--text);border-color:var(--border);margin-right:4px">修改密码</button>
    <button class="btn btn-sm btn-o" onclick="doLogout()" style="color:var(--text);border-color:var(--border)">退出</button>
  </div>
</div>
<div id="notifPanel" class="notif-panel" style="display:none">
  <div class="notif-panel-inner"></div>
</div>
<div id="app">
  <div id="loginPage" class="modal-mask">
    <div class="modal" style="text-align:center">
      <h2 style="margin-bottom:8px">🛠️</h2>
      <h2>总调度室综合管理系统</h2>
      <p style="color:var(--text2);margin:8px 0 24px">请输入手机号登录</p>
      <div class="form-group"><input id="loginPhone" placeholder="手机号" /></div>
      <div class="form-group"><input id="loginPwd" type="password" placeholder="请输入密码" /></div>
      <button class="btn btn-p" style="width:100%" onclick="doLogin()">登录</button>
      <p style="text-align:right;margin-top:10px"><a style="color:var(--text2);font-size:12px;cursor:pointer" onclick="changePwdAtLogin()">修改密码</a></p>
    </div>
  </div>
  <div id="mainPage" style="display:none"></div>
</div>

<script>
${appJs}
${allModulesJs}
</script>
<script src="/modules/weather.js"></script>
<script src="/modules/hazards.js"></script>
<script src="/modules/photos.js"></script>
<script src="/modules/photo_viewer.js"></script>
<script src="/modules/safety_officer.js"></script>
<script src="/modules/ledger_link.js"></script>
<script src="/modules/parts_search.js"></script>
<script>
// ====== 工程机械用车申请模块（内嵌） ======
${machineryJs}
</script>
<script>
(function(){
  var sx=0,sy=0,tracking=false;
  document.addEventListener('touchstart',function(e){if(e.touches.length===1){sx=e.touches[0].clientX;sy=e.touches[0].clientY;tracking=(sx<30)}},{passive:true});
  document.addEventListener('touchmove',function(e){if(tracking&&e.touches[0].clientX-sx>80&&Math.abs(e.touches[0].clientY-sy)<50){tracking=false;var modals=document.querySelectorAll('.modal-mask');if(modals.length){modals[modals.length-1].remove()}else{history.back()}}},{passive:true});
  document.addEventListener('touchend',function(){tracking=false},{passive:true});
})();
if('serviceWorker' in navigator){navigator.serviceWorker.register('/sw.js').then(function(){}).catch(function(){})}
</script>
</body>
</html>`;

fs.writeFileSync(path.join(__dirname, 'public', 'index.html'), html, 'utf8');
console.log('Final HTML written:', html.length, 'bytes');
