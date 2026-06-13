
// ==================== 用车申请人仪表盘 ====================

async function renderApplicant(){
  var el=document.getElementById('mainPage');
  try {
    var [stats, active] = await Promise.all([
      api('/machinery/my-cost-stats'),
      api('/machinery/active')
    ]);
    var s = stats || {};
    var tm = s.thisMonth || {};
    var at = s.allTime || {};
    var activeCount = (active || []).length;

    // 构建进行中用车卡片
    var activeCards = '';
    if (active && active.length > 0) {
      active.forEach(function(item) {
        var isHazardous = Number(item.is_hazardous) ? '<span class="tag t-reject" style="margin-left:6px">⚠ 危险</span>' : '';
        activeCards += '<div class="card" style="border-left:3px solid var(--success);margin-bottom:10px">'+
          '<div style="display:flex;justify-content:space-between;align-items:center;flex-wrap:wrap;gap:8px">'+
            '<div><b style="font-size:15px;color:var(--gold-light)">'+item.application_no+'</b><span class="tag t-progress" style="margin-left:8px">'+MA_ST_MAP[item.status]+'</span>'+isHazardous+'</div>'+
            '<button class="btn btn-sm btn-s" onclick="event.stopPropagation();earlyEndMachinery('+item.id+')">⏹ 提前结束</button>'+
          '</div>'+
          '<div style="margin-top:8px;font-size:13px;line-height:1.7">'+
            '<div><b>📋 车型：</b>'+item.vehicle_type+' | <span class="tag">'+(MA_TYPE_MAP[item.application_type]||'短期')+'用车</span></div>'+
            (item.assigned_plate ?
              '<div style="margin-top:4px;padding:8px;background:rgba(200,160,74,.06);border-radius:6px">'+
                '<div><b>🚛 指派车辆：</b><span style="color:var(--primary);font-weight:600">'+item.assigned_plate+'</span>（'+item.assigned_vehicle_type+' '+item.assigned_vehicle_model+'）</div>'+
                (item.driver_name ? '<div><b>👤 驾驶员：</b>'+item.driver_name+' 📞 <a href="tel:'+item.driver_phone+'" style="color:var(--gold)">'+item.driver_phone+'</a></div>' : '')+
                (item.hourly_rate ? '<div><b>💰 小时单价：</b>¥'+item.hourly_rate+'/h</div>' : '')+
              '</div>' : '<div style="margin-top:4px;padding:8px;background:rgba(212,160,23,.08);border-radius:6px;color:var(--warning);font-size:12px">⏳ 等待调度员分派车辆…</div>')+
            '<div style="margin-top:6px"><b>⏰ 时段：</b>'+(item.scheduled_start||'')+' — '+(item.scheduled_end||'')+'</div>'+
            '<div><b>📍 地点：</b>'+item.work_location+(item.work_altitude ? ' ('+item.work_altitude+')' : '')+'</div>'+
            '<div><b>📝 用途：</b>'+item.work_purpose+'</div>'+
          '</div>'+
        '</div>';
      });
    }

    el.innerHTML='<div class="layout">'+
      '<div class="stats-grid">'+
      '<div class="stat-item" onclick="showMachineryApply()" style="cursor:pointer"><div class="stat-num" style="color:var(--primary)">🚜</div><div class="stat-label">申请用车</div></div>'+
      '<div class="stat-item"><div class="stat-num" style="color:'+(activeCount>0?'var(--success)':'var(--text2)')+'">'+activeCount+'</div><div class="stat-label">进行中</div></div>'+
      '<div class="stat-item"><div class="stat-num">'+(tm.totalCount||0)+'</div><div class="stat-label">本月申请</div></div>'+
      '<div class="stat-item"><div class="stat-num" style="color:var(--danger)">¥'+(tm.totalCost||0).toFixed(0)+'</div><div class="stat-label">本月费用</div></div>'+
      '</div>'+
      (activeCards ? '<div style="margin-bottom:14px">'+activeCards+'</div>' : '')+
      '<div class="row2">'+
      '<div class="card" style="text-align:center;cursor:pointer" onclick="showMachineryList()"><h3>📋</h3>申请记录<br><span style="font-size:12px;color:var(--text2)">查看·提前结束</span></div>'+
      '<div class="card" style="text-align:center;cursor:pointer" onclick="showMachineryCostStats()"><h3>💰</h3>费用统计<br><span style="font-size:12px;color:var(--text2)">累计 ¥'+((at.totalCost||0)).toFixed(0)+'</span></div>'+
      '</div></div>';
  } catch(e) {
    el.innerHTML='<div class="layout"><div class="stats-grid">'+
      '<div class="stat-item" onclick="showMachineryApply()" style="cursor:pointer"><div class="stat-num" style="color:var(--primary)">🚜</div><div class="stat-label">申请用车</div></div>'+
      '</div>'+
      '<div class="card" style="text-align:center;cursor:pointer" onclick="showMachineryList()"><h3>📋</h3>申请记录<br><span style="font-size:12px;color:var(--text2)">查看·提前结束</span></div>'+
      '</div>';
  }
  loadBulletin();
}
