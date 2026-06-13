
// ==================== 管理员仪表盘 ====================

async function renderAdmin(){
  var el=document.getElementById('mainPage');
  var dm=new Date().toISOString().slice(0,10);
  var [dashboard,summary,config,monthlyStats,machPendingRes]=await Promise.all([api('/admin/dashboard'),api('/inspection/today-summary'),api('/admin/config'),api('/admin/monthly-cost-stats'),api('/machinery/pending-list').catch(function(){return {list:[]}})]);
  var machPending = (machPendingRes && machPendingRes.list) || (Array.isArray(machPendingRes) ? machPendingRes : []);
  var machPendingCount = machPending.length;
  el.innerHTML='<div class="layout">'+
    '<div class="stats-grid">'+
    '<div class="stat-item" onclick="showVehiclesByStatus(\'\',\'所有车辆\')" style="cursor:pointer"><div class="stat-num">'+dashboard.totalVehicles+'</div><div class="stat-label">总车辆</div></div>'+
    '<div class="stat-item" onclick="showVehiclesByStatus(\'normal\',\'正常车辆\')" style="cursor:pointer"><div class="stat-num">'+dashboard.normalVehicles+'</div><div class="stat-label">正常车辆</div></div>'+
    '<div class="stat-item" onclick="showVehiclesByStatus(\'repairing\',\'维修中车辆\')" style="cursor:pointer"><div class="stat-num" style="color:var(--danger)">'+dashboard.repairingCount+'</div><div class="stat-label">维修中</div></div>'+
    '<div class="stat-item" onclick="showVehiclesByStatus(\'expired\',\'保养过期车辆\')" style="cursor:pointer"><div class="stat-num" style="color:var(--warning)">'+(dashboard.expiredCount||0)+'</div><div class="stat-label">保养过期</div></div>'+
    '<div class="stat-item" onclick="renderLeader()" style="cursor:pointer"><div class="stat-num" style="color:var(--warning)">'+dashboard.pendingApprovalCount+'</div><div class="stat-label">待审批报价</div></div>'+
    '<div class="stat-item" onclick="showPendingAssignments()" style="cursor:pointer"><div class="stat-num" style="color:'+(machPendingCount>0?'var(--warning)':'var(--text2)')+'">'+machPendingCount+'</div><div class="stat-label">待指派用车</div></div>'+
    '<div class="stat-item"><div class="stat-num">'+dashboard.monthCount+'</div><div class="stat-label">本月报修</div></div>'+
    '<div class="stat-item"><div class="stat-num" style="color:var(--danger)">¥'+dashboard.monthlyCost+'</div><div class="stat-label">本月已维修费用</div></div>'+
    '<div class="stat-item" style="display:flex;flex-direction:column;gap:8px"><div onclick="editEstimate(\'year_estimate\',\'本年度预估维修费用\')" style="cursor:pointer;flex:1"><div class="stat-num" style="color:#d48806;font-size:22px" id="estYear">¥'+(config.year_estimate||0)+'</div><div class="stat-label" style="font-size:11px">年度预估费用 ✎</div></div><div style="border-top:1px dashed #e0e0e0"></div><div onclick="editEstimate(\'month_estimate\',\'本月预估维修费用\')" style="cursor:pointer;flex:1"><div class="stat-num" style="color:#d48806;font-size:22px" id="estMonth">¥'+(config.month_estimate||0)+'</div><div class="stat-label" style="font-size:11px">本月预估费用 ✎</div></div></div>'+
    '</div>'+
    (renderMonthlyChart(monthlyStats||[])||'')+
    '<div class="card" style="border-left:3px solid var(--warning);margin-bottom:14px"><div class="card-title">⚠ 系统预警</div><div id="sysAlerts" style="font-size:13px">检测中...</div></div>'+
    '<div class="row3">'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showVehicleArchiveList()"><h3>📋</h3>在编车辆档案<br><span style="font-size:12px;color:var(--text2)">车辆详细档案查阅</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showAdminVehicles()"><h3>🚛</h3>车辆管理<br><span style="font-size:12px;color:var(--text2)">录入/管理车辆</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showAdminUsers()"><h3>👥</h3>人员管理<br><span style="font-size:12px;color:var(--text2)">添加/查看用户</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="renderLeader()"><h3>📋</h3>维修进度详情<br><span style="font-size:12px;color:var(--text2)">查看/追溯</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showCostReport()"><h3>💰</h3>维修费用报表<br><span style="font-size:12px;color:var(--text2)">修理厂结算明细</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showExportOrders()"><h3>📥</h3>导出工单<br><span style="font-size:12px;color:var(--text2)">导出维修数据</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showTodayInspDetail()"><h3>✅</h3>点检记录<br><span style="font-size:12px;color:var(--text2)">每日检查情况</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showRepairShops()"><h3>🔧</h3>修理厂管理<br><span style="font-size:12px;color:var(--text2)">管理外包修理厂</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showPartsManagement()"><h3>📦</h3>配件管理<br><span style="font-size:12px;color:var(--text2)">库存/领用/出库</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showAttendanceReport()"><h3>⏱</h3>员工出勤信息<br><span style="font-size:12px;color:var(--text2)">出勤筛选导出</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="backupDB()"><h3>💾</h3>数据备份<br><span style="font-size:12px;color:var(--text2)">一键备份</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showMachineryListAll()"><h3>🚜</h3>用车审批<br><span style="font-size:12px;color:var(--text2)">查看全部用车记录</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showHazardList()"><h3>⚠</h3>隐患闭环<br><span style="font-size:12px;color:var(--text2)">上报整改确认</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer;border-color:var(--gold)" onclick="showWeatherDashboard()"><h3>🌤️</h3>天气预警<br><span style="font-size:12px;color:var(--text2)">矿区天气/预警管理</span></div>'+
    '</div></div>';
  loadSystemAlerts();loadBulletin();
}
