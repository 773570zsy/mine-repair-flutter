// ==================== 驾驶员仪表盘 ====================

async function renderDriver(){
  var el=document.getElementById('mainPage'),today=new Date().toISOString().slice(0,10),sub=today.slice(0,7);
  el.innerHTML='<div class="layout"><div class="stats-grid" id="dashStats"></div>'+
    '<div class="card" style="border-left:3px solid var(--warning);margin-bottom:0"><div id="maintAlerts" style="font-size:12px;color:var(--warning)">检测中...</div></div>'+
    '<div id="pendingAcceptCard" style="display:none"><div class="card" style="border-left:3px solid var(--success)"><div class="card-title">✅ 待验收工单 <span style="font-size:12px;color:var(--success)">维修完毕，请确认验收</span></div><div id="pendingAcceptList"></div></div></div>'+
    '<div class="row2"><div class="card"><div class="card-title">🔧 快速报修 <button class="btn btn-p btn-sm" onclick="showReport()">+ 报修</button></div><div id="recentOrders">加载中...</div></div>'+
    '<div class="card"><div class="card-title">✅ 今日点检 <span style="font-size:12px;color:var(--text2)">'+today+'</span></div><div id="todayCheck">加载中...</div></div></div>'+
    '<div class="card"><div class="card-title">🚛 车辆状态总览</div><div id="vehicleStatus">加载中...</div></div>'+
    '<div class="row2"><div class="card"><div class="card-title">📋 今日考勤</div><div id="attCard">加载中...</div></div>'+
    '<div class="card"><div class="card-title">⏰ 今日加班</div><div id="otCard">加载中...</div></div></div>'+
    '<div class="row2"><div class="card" style="text-align:center;cursor:pointer" onclick="showVehicleArchiveList()"><h3>📋</h3>在编车辆档案<br><span style="font-size:12px;color:var(--text2)">车辆详细档案查阅</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer" onclick="showDriverTasks()"><h3>🚜</h3>工程机械派车任务<br><span style="font-size:12px;color:var(--text2)">查看指派详情</span></div>'+
    '<div class="card" style="text-align:center;cursor:pointer;border-color:var(--gold)" onclick="showWeatherDashboard()"><h3>🌤️</h3>天气预警<br><span style="font-size:12px;color:var(--text2)">查看矿区天气</span></div></div></div>';
  loadDriverData(today,sub);loadSystemAlerts();loadAttendanceCard();loadBulletin();
}

async function loadDriverData(today,month){
  try{
    var [allVehicles,orders,inspRecords]=await Promise.all([api('/vehicles'),api('/repair/my-orders'),api('/inspection/my-records?month='+month)]);
    var todayInsp=(inspRecords||[]).filter(function(r){return r.inspection_date===today});
    var recentOrders=(orders||[]).slice(0,4);
    var activeOrders=(orders||[]).filter(function(o){return['pending_accept','pending_quote','pending_approval','approved','repairing'].indexOf(o.status)>=0});
    var pendingAccept=(orders||[]).filter(function(o){return o.status==='completed'});
    document.getElementById('dashStats').innerHTML=
      '<div class="stat-item" onclick="showVehiclesByStatus(\'\',\'所有车辆\')" style="cursor:pointer"><div class="stat-num">'+(allVehicles||[]).length+'</div><div class="stat-label">总车辆</div></div>'+
      '<div class="stat-item"><div class="stat-num">'+activeOrders.length+'</div><div class="stat-label">进行中工单</div></div>'+
      '<div class="stat-item"><div class="stat-num" style="color:'+(todayInsp.length?'var(--success)':'var(--danger)')+'">'+(todayInsp.length?'已完成':'未提交')+'</div><div class="stat-label">今日点检</div></div>'+
      '<div class="stat-item" onclick="showPartsRequisition()" style="cursor:pointer"><div class="stat-num" style="color:var(--primary)">🔧</div><div class="stat-label">配件领用</div></div>'+
      '<div class="stat-item" onclick="showQuiz()" style="cursor:pointer"><div class="stat-num" style="color:var(--gold)">📝</div><div class="stat-label">每日一测</div></div>';
    document.getElementById('recentOrders').innerHTML=recentOrders.length?recentOrders.map(function(o){return '<div style="padding:8px 0;border-bottom:1px solid var(--border);cursor:pointer" onclick="showOrderDetail('+o.id+')"><div class="flex"><span class="order-no">'+o.order_no+'</span><span class="tag '+ST_TAG[o.status]+'">'+STATUS_MAP[o.status]+'</span></div><div style="font-size:11px;color:var(--text2);margin-top:4px">'+o.plate_number+' | '+o.created_at+'</div></div>'}).join(''):'<div class="empty">暂无工单</div>';
    document.getElementById('todayCheck').innerHTML=
      '<div style="display:flex;gap:8px;margin-bottom:10px"><button class="btn btn-p btn-sm" onclick="showInspection(\'morning\')">☀ 早检</button><button class="btn btn-o btn-sm" onclick="showInspection(\'evening\')">🌙 晚检</button></div>'+
      (todayInsp.length?todayInsp.map(function(r){return '<div style="padding:8px 0;border-bottom:1px solid var(--border);cursor:pointer" onclick="showInspectionDetail('+r.id+')"><span style="font-weight:500">'+r.plate_number+'</span> <span class="tag '+(r.overall_status==='normal'?'t-done':'t-reject')+'">'+(r.overall_status==='normal'?'正常':'异常')+'</span>'+'<br><span style="font-size:11px;color:var(--text2)">油位:'+(LEVEL_MAP[r.oil_level]||'-')+' / 水位:'+(LEVEL_MAP[r.coolant_level]||'-')+' / 九样:'+(r.toolkit_check==='ok'?'✅':'❌')+'</span>'+((r.start_hours||r.fuel_amount)?'<br><span style="font-size:11px;color:var(--text2)">工时:'+(r.start_hours||0)+'h→'+(r.end_hours||0)+'h 加油:'+(r.fuel_amount||0)+'L 停车:'+(r.parking_location||'-')+'</span>':'')+'</div>'}).join(''):'<div class="empty">今日暂无点检记录</div>');
    var vsHtml='<table><tr><th>内部编号</th><th>类型</th><th>型号</th><th>当前工时</th><th>下次保养</th><th>状态</th></tr>';
    (allVehicles||[]).filter(function(v){return v.archive_department!=='西藏恒骏'}).forEach(function(v){
      var curH=v.archive_current_hours||v.latest_end_hours||0;
      var next=v.archive_next_maintenance||v.next_maintenance_hours||0;
      var remain=curH&&next?next-curH:999;
      var st=remain<0?'<span class="tag t-reject">过期</span>':remain<50?'<span class="tag t-pending">即将保养</span>':'<span class="tag t-done">正常</span>';
      vsHtml+='<tr><td><b>'+v.plate_number+'</b></td><td>'+(v.vehicle_type||'-')+'</td><td>'+(v.model||'-')+'</td><td>'+curH+'h</td><td>'+next+'h</td><td>'+st+'</td></tr>'
    });
    vsHtml+='</table>';document.getElementById('vehicleStatus').innerHTML=vsHtml;
    // 待验收工单
    var pac=document.getElementById('pendingAcceptCard');if(pendingAccept.length>0){pac.style.display='';document.getElementById('pendingAcceptList').innerHTML='<table><tr><th>工单号</th><th>车辆</th><th>修理厂</th><th>完工时间</th><th>操作</th></tr>'+pendingAccept.map(function(o){return '<tr style="background:rgba(90,158,95,.06)"><td><b>'+o.order_no+'</b></td><td>'+o.plate_number+'</td><td>'+(o.repair_shop_name||'-')+'</td><td>'+(o.updated_at||'').slice(0,16)+'</td><td><button class="btn btn-s btn-sm" onclick="acceptCompletedOrder('+o.id+')">✅ 验收</button> <button class="btn btn-sm btn-o" onclick="showOrderDetail('+o.id+')">详情</button></td></tr>'}).join('')+'</table>'}else{pac.style.display='none'}
  }catch(e){console.error(e)}
}
