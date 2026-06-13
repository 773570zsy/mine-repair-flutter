// ==================== 调度员仪表盘 ====================

async function renderDispatcher(){
  var el=document.getElementById('mainPage');
  var pendingRes=await api('/machinery/pending-list');
  var all=await api('/machinery/list-all');
  var pendingList = (pendingRes && pendingRes.list) || (Array.isArray(pendingRes) ? pendingRes : []);
  var pendingCount = pendingList.length;
  var todayCount=(all||[]).filter(function(a){return a.created_at&&a.created_at.slice(0,10)===new Date().toISOString().slice(0,10)}).length;
  el.innerHTML='<div class="layout">'+
    '<div class="stats-grid">'+
    '<div class="stat-item"><div class="stat-num" style="color:'+(pendingCount>0?'var(--danger)':'var(--success)')+'">'+pendingCount+'</div><div class="stat-label">待指派申请</div></div>'+
    '<div class="stat-item"><div class="stat-num">'+todayCount+'</div><div class="stat-label">今日申请</div></div>'+
    '<div class="stat-item" onclick="showPendingAssignments()" style="cursor:pointer"><div class="stat-num" style="color:var(--primary)">🚜</div><div class="stat-label">处理指派</div></div>'+
    '<div class="stat-item" onclick="showDispatchedOrders()" style="cursor:pointer"><div class="stat-num" style="color:var(--primary)">💰</div><div class="stat-label">已派车收益明细</div></div>'+
    '</div>'+
    '<div class="row2">'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showVehicleArchiveList()"><h3>📋</h3>在编车辆档案<br><span style="font-size:12px;color:var(--text2)">车辆详细档案查阅</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showAdminVehicles()"><h3>🚛</h3>车辆管理<br><span style="font-size:12px;color:var(--text2)">录入/管理车辆</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showMachineryList()"><h3>📋</h3>我的用车申请<br><span style="font-size:12px;color:var(--text2)">查看我的申请记录</span></div>'+
    '</div>'+
    '<div class="card" style="text-align:center;cursor:pointer;border-color:var(--gold);margin-top:12px" onclick="showWeatherDashboard()"><h3>🌤️</h3>天气预警<br><span style="font-size:12px;color:var(--text2)">查看矿区天气和预警（红色预警暂停派车）</span></div>'+
    '</div></div>';
  loadBulletin();
}
