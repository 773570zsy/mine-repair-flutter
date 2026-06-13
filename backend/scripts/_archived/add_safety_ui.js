const fs = require('fs');
let js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

// Add safety functions
const idx = js.indexOf('function showOperationLogs()');
if (idx > 0) {
  const safetyCode = [
    'function showSafetyReport(){showModal("🛡 安全事件上报","<div class=\\"form-group\\"><label>发生地点</label><input id=\\"sfLocation\\" /></div><div class=\\"form-group\\"><label>发生时间</label><input id=\\"sfTime\\" type=\\"datetime-local\\" /></div><div class=\\"form-group\\"><label>严重程度</label><select id=\\"sfSeverity\\"><option value=\\"轻微\\">轻微</option><option value=\\"一般\\" selected>一般</option><option value=\\"严重\\">严重</option><option value=\\"重大\\">重大</option></select></div><div class=\\"form-group\\"><label>事件描述</label><textarea id=\\"sfDesc\\" placeholder=\\"请详细描述事件经过...\\"></textarea></div>",async function(mask){var loc=document.getElementById("sfLocation").value.trim();var tm=document.getElementById("sfTime").value;var sv=document.getElementById("sfSeverity").value;var desc=document.getElementById("sfDesc").value.trim();if(!desc){alert("请填写事件描述");return false};var r=await api("/safety/report",{method:"POST",data:{location:loc,incident_time:tm,description:desc,severity:sv}});if(r){toast("上报成功");mask.remove();renderPage()}})}',
    'function showSafetyList(){api("/safety/list").then(function(data){if(!data||!data.length)return alert("暂无记录");var rows="";var sm={轻微:"t-done",一般:"t-pending",严重:"t-reject",重大:"t-reject"};data.forEach(function(x){rows+="<tr><td class=\\"order-no\\">"+x.incident_no+"</td><td>"+(x.reporter_name||"-")+"</td><td>"+x.location+"</td><td><span class=\\"tag "+(sm[x.severity]||"")+"\\">"+x.severity+"</span></td><td>"+(x.status==="pending"?"待调查":x.status==="investigating"?"调查中":x.status==="rectifying"?"整改中":"已关闭")+"</td><td>"+(x.created_at||"").slice(0,16)+"</td><td><button class=\\"btn btn-sm btn-p\\" onclick=\\"showSafetyDetail("+x.id+")\\">详情</button></td></tr>"});showModal("🛡 安全事件列表","<table><tr><th>编号</th><th>上报人</th><th>地点</th><th>程度</th><th>状态</th><th>时间</th><th>操作</th></tr>"+rows+"</table>")})}',
    'async function showSafetyDetail(id){var d=await api("/safety/detail/"+id);if(!d)return;var i=d.incident,inv=d.investigation,acts=d.actions;var h="<div><b>编号：</b>"+i.incident_no+" | <b>上报人：</b>"+(i.reporter_name||"-")+"</div><div><b>地点：</b>"+(i.location||"-")+" | <b>时间：</b>"+(i.incident_time||"-")+" | <b>程度：</b>"+i.severity+"</div><div style=\\"margin-top:8px\\"><b>描述：</b>"+i.description+"</div>";if(inv){h+="<div style=\\"margin-top:12px;padding:10px;background:rgba(200,160,74,.08);border-radius:6px\\"><b>📋 调查报告</b><br>调查人："+(inv.investigator_name||"-")+"<br>根本原因："+(inv.root_cause||"待填写")+"<br>发现："+(inv.findings||"待填写")+"</div>"}if(acts&&acts.length){h+="<div style=\\"margin-top:8px\\"><b>整改措施：</b></div>";acts.forEach(function(a){h+="<div style=\\"padding:6px 0;border-bottom:1px solid var(--border)\\">"+a.action_desc+" | 责任人："+(a.responsible_name||"-")+" | 期限："+(a.due_date||"-")+" | "+(a.status==="completed"?"✅已完成":"⏳进行中")+"</div>"})}showModal("事件详情",h)}'
  ].join('\n');
  js = js.substring(0, idx) + safetyCode + '\n' + js.substring(idx);
  console.log('Safety functions added');
}

// Add card to admin dashboard
const oldCard = 'showDeptManagement()"><h3>🏢</h3>外部门管理';
const newCard = 'showSafetyList()"><h3>🛡</h3>安全事件<br><span style="font-size:12px;color:var(--text2)">上报与追踪</span></div><div class="card" style="text-align:center;cursor:pointer" onclick="showDeptManagement()"><h3>🏢</h3>外部门管理';
if (js.indexOf(oldCard) > 0) { js = js.replace(oldCard, newCard); console.log('Admin safety card added'); }

// Add report button to driver dashboard
const oldDriver = '配件领用</div></div><div class="stat-item" onclick="showQuiz()"';
const newDriver = '配件领用</div></div><div class="stat-item" onclick="showSafetyReport()" style="cursor:pointer"><div class="stat-num" style="color:var(--danger)">🛡</div><div class="stat-label">安全上报</div></div><div class="stat-item" onclick="showQuiz()"';
if (js.indexOf(oldDriver) > 0) { js = js.replace(oldDriver, newDriver); console.log('Driver safety card added'); }

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', js, 'utf8');
console.log('Safety UI complete');
