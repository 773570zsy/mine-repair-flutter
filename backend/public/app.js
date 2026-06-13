
// ==================== 核心框架：全局变量 / 工具 / 登录 / 模态框 ====================

// HTML 转义 — 全局 XSS 防护
function escHtml(s){if(s==null)return'';return String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;').replace(/'/g,'&#x27;');}

let TOKEN='',USER=null,LAST_DEPTS=[];
const API='/api',ROLE_MAP={driver:'驾驶员',repair_shop:'修理厂',leader:'科级审批',admin:'管理员',safety_officer:'安全员',dispatcher:'车辆调度员',applicant:'用车申请人'};
const STATUS_MAP={pending_accept:'待接单',pending_quote:'待报价',pending_approval:'待审批',approved:'已通过',rejected:'已驳回',repairing:'维修中',completed:'待验收',accepted:'已完成',cancelled:'已取消'};
const ST_TAG={pending_accept:'t-pending',pending_quote:'t-pending',pending_approval:'t-reject',approved:'t-progress',rejected:'t-reject',repairing:'t-progress',completed:'t-done',accepted:'t-done'};
const LEVEL_MAP={high:'高位',mid:'中位',low:'低位'},APPEAR_MAP={normal:'正常',damaged:'有损坏',dirty:'需清洁'},TIRE_MAP={normal:'正常',worn:'磨损',damaged:'损坏'};

function toast(m,t){var b=document.createElement('div');b.style.cssText='position:fixed;top:16px;right:16px;z-index:9999;padding:14px 24px;border-radius:8px;color:#fff;font-weight:600;font-size:15px;animation:slideIn .3s ease;max-width:350px;box-shadow:0 8px 24px rgba(0,0,0,.4);';b.style.background=t==='error'?'linear-gradient(135deg,#c0392b,#96281b)':'linear-gradient(135deg,#4a8f5a,#3d7349)';b.textContent=(t==='error'?'✕ ':'✓ ')+m;document.body.appendChild(b);setTimeout(function(){b.style.opacity='0';b.style.transition='opacity .3s';setTimeout(function(){b.remove()},300)},2000)}

function actionName(a){var m={accepted_order:"修理厂接单",quote_submitted:"提交报价",approved:"审批通过",rejected:"驳回",accepted_and_quoted:"接单并报价",department_approved:"部门审批通过",department_rejected:"部门驳回",progress:"维修进度",progress_update:"维修进度",completed:"维修完成",accepted:"验收通过",urgent:"标记加急"};return m[a]||a}
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

// ===== 登录 =====
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
  if(Notification&&Notification.permission==='default')Notification.requestPermission();
  renderPage();updateClock();pollNotifications();
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
function changePassword(){
  var old=prompt('请输入原密码（默认123456）：');if(old===null)return;
  var nw=prompt('请输入新密码（至少4位）：');if(!nw||nw.length<4)return alert('新密码至少4位');
  api('/admin/change-password',{method:'POST',data:{old_pwd:old,new_pwd:nw}}).then(function(){alert('密码修改成功请重新登录');doLogout()})
}
async function downloadXLSX(url,body,filename){
  try {
    var resp=await fetch(url,{method:'POST',headers:{'Content-Type':'application/json','Authorization':'Bearer '+TOKEN},body:JSON.stringify(body)});
    if(!resp.ok){var t=await resp.text();if(t.startsWith('{')){var j=JSON.parse(t);alert(j.msg||'导出失败')}else{alert('导出失败')}return}
    var blob=await resp.blob();
    var a=document.createElement('a');a.href=URL.createObjectURL(blob);a.download=filename+'.xlsx';document.body.appendChild(a);a.click();document.body.removeChild(a);
  }catch(e){alert('导出失败: '+e.message)}
}

// ===== 通知 =====
var NOTIF=[],NOTIF_UNREAD=0;
var NOTIF_TYPE_ICON={hazard_assigned:'⚠',hazard_completed:'✅',hazard_verified:'✅',hazard_rejected:'❌',assessment_new:'📋',quote_pending:'💰',quote_approved:'✅',quote_rejected:'❌',new_order:'🔧',order_accepted:'📦',order_urgent:'⚡',repair_completed:'✅'};
var NOTIF_LINK={hazard_assigned:'hazard',hazard_completed:'hazard',hazard_verified:'hazard',hazard_rejected:'hazard',assessment_new:'assessment'};
async function pollNotifications(){
  if(!TOKEN||!USER)return;
  try{var d=await api('/notifications');if(!d)return;NOTIF=d.list||[];NOTIF_UNREAD=d.unread||0}catch(e){}
  var badge=document.getElementById('notifyBadge');if(badge){if(NOTIF_UNREAD>0){badge.textContent=NOTIF_UNREAD>99?'99+':NOTIF_UNREAD;badge.style.display='flex'}else{badge.style.display='none'}}
}setInterval(pollNotifications,15000);
function toggleNotifPanel(){
  var p=document.getElementById('notifPanel');
  if(p.style.display==='block'){closeNotifPanel();return}
  // 动态计算位置：topbar底部 + 8px间距
  var topbar=document.querySelector('.topbar');
  var top=topbar?topbar.getBoundingClientRect().bottom+8:60;
  p.style.top=top+'px';p.style.display='block';
  var inner=p.querySelector('.notif-panel-inner');
  if(!NOTIF.length){
    inner.innerHTML='<div class="notif-empty">🔔<br>暂无通知</div>';
  }else{
    inner.innerHTML='<div class="notif-header"><b>通知</b><span style="font-size:12px;color:var(--gold)">'+NOTIF_UNREAD+'条未读</span><button class="btn btn-sm btn-o" onclick="markAllRead()">全部已读</button></div>'
    +NOTIF.slice(0,20).map(function(n){
      var icon=NOTIF_TYPE_ICON[n.type]||'📌';var unread=n.is_read?'':' unread';
      return '<div class="notif-item'+unread+'" onclick="openNotif(\''+n.type+'\','+n.id+','+(n.order_id||0)+')"><div class="notif-item-head">'+(n.is_read?'':'<span class="notif-dot"></span>')+'<span class="notif-item-icon">'+icon+'</span><span class="notif-item-title">'+n.title+'</span><span class="notif-item-time">'+n.created_at.slice(0,16)+'</span></div><div class="notif-item-body">'+n.content+'</div></div>';
    }).join('')
  }
  // 点空白处关闭（用mousedown比click更可靠）
  setTimeout(function(){
    document.addEventListener('mousedown',closeNotifOutside,true);
  },50);
}
function closeNotifPanel(){
  document.getElementById('notifPanel').style.display='none';
  document.removeEventListener('mousedown',closeNotifOutside,true);
}
function closeNotifOutside(e){
  var p=document.getElementById('notifPanel');if(!p||p.style.display!=='block')return;
  if(!p.contains(e.target)&&e.target.id!=='notifyBell'&&!document.getElementById('notifyBell').contains(e.target)){
    closeNotifPanel();
  }
}
function openNotif(type,id,orderId){
  closeNotifPanel();
  api('/notifications/'+id+'/read',{method:'PUT'});
  if(type==='hazard_assigned'||type==='hazard_completed')showHazardList();
  else if(type==='assessment_new'){if(typeof showAssessmentList==='function')showAssessmentList()}
  else if(type==='repair_completed'&&orderId&&typeof showOrderDetail==='function')showOrderDetail(orderId);
  else if(orderId&&typeof showOrderDetail==='function')showOrderDetail(orderId);
  else renderPage()
}
function markAllRead(){api('/notifications/read-all',{method:'PUT'});NOTIF_UNREAD=0;NOTIF=NOTIF.map(function(n){n.is_read=1;return n});document.getElementById('notifyBadge').style.display='none';toggleNotifPanel()}

// ===== 路由 =====
function renderPage(){
  var r=USER.role||getRole();
  if(r==='driver')renderDriver();else if(r==='repair_shop')renderShop();
  else if(r==='leader')renderLeader();else if(r==='admin')renderAdmin();
  else if(r==='safety_officer')renderSafetyOfficer();else if(r==='dispatcher')renderDispatcher();else if(r==='applicant')renderApplicant();
}
function getRole(){return USER?USER.role:'driver'}

// ===== 弹窗组件 =====
function showModal(title,content,onOk){var mask=document.createElement('div');mask.className='modal-mask';mask.innerHTML='<div class="modal"><h3 style="margin-bottom:16px">'+title+'</h3>'+content+'<div class="flex" style="justify-content:flex-end;margin-top:16px"><button class="btn" onclick="this.closest(\'.modal-mask\').remove()">取消</button><button class="btn btn-p" id="modalOkBtn">确认</button></div></div>';document.body.appendChild(mask);if(onOk){mask.querySelector('#modalOkBtn').onclick=async function(){var r=await onOk(mask);if(r!==false)mask.remove()}}mask.onclick=function(e){if(e.target===mask)mask.remove()}}

// ===== 时钟 =====
function updateClock(){var now=new Date(),t=now.getHours().toString().padStart(2,'0')+':'+now.getMinutes().toString().padStart(2,'0')+':'+now.getSeconds().toString().padStart(2,'0');var el=document.getElementById('liveClock');if(el)el.textContent=t}
setInterval(updateClock,1000);

// ===== 启动 =====
window._modalPhotos=[];var globalPhotoInput=document.createElement("input");globalPhotoInput.type="file";globalPhotoInput.accept="image/*";globalPhotoInput.multiple=true;globalPhotoInput.style.display="none";globalPhotoInput.onchange=async function(){if(!globalPhotoInput.files.length)return;var urls=[];for(var i=0;i<globalPhotoInput.files.length;i++){var fd=new FormData();fd.append("file",globalPhotoInput.files[i]);try{var r=await fetch("/api/upload/single",{method:"POST",headers:{"Authorization":"Bearer "+TOKEN},body:fd});var d=await r.json();if(d.code===200)urls.push(d.data.url)}catch(e){}}window._modalPhotos=window._modalPhotos.concat(urls)};document.body.appendChild(globalPhotoInput);function pickPhoto(){globalPhotoInput.click()}
window.onload=function(){
  var saved=localStorage.getItem('mp_token');
  if(saved){TOKEN=saved;USER=JSON.parse(localStorage.getItem('mp_user'));document.getElementById('loginPage').style.display='none';document.getElementById('mainPage').style.display='';document.getElementById('userArea').style.display='';document.getElementById('currentUser').textContent=USER.name+'（'+ROLE_MAP[USER.role]+'）';renderPage();updateClock();pollNotifications()}
};
