// ==================== 工程机械用车申请与指派模块 ====================

var MA_URG_MAP = { normal:'普通', urgent:'紧急', emergency:'特急' };
var MA_ST_MAP = { pending:'待指派', assigned:'用车中', in_progress:'用车中', completed:'已完成', early_completed:'提前结束', cancelled:'已取消' };
var MA_ST_CLS = { pending:'t-pending', assigned:'t-progress', in_progress:'t-progress', completed:'t-done', early_completed:'t-done', cancelled:'' };
var MA_TYPE_MAP = { short_term:'短期', long_term:'长期' };

var VEHICLE_TYPES = [
  '履带挖掘机','轮式挖掘机','装载机','汽车吊',
  '吊车25吨','吊车50吨','吊车75吨','吊车100吨','吊车300吨','吊车500吨'
];

// 预用车时间段选项（短期）
var TIME_SLOTS = [
  '08:00-12:00','08:00-17:00','08:00-18:00',
  '08:30-12:00','08:30-17:30',
  '09:00-17:00','09:00-18:00','09:30-17:00',
  '13:00-17:00','13:00-18:00',
  '14:00-18:00','14:00-22:00',
  '20:00-08:00','22:00-06:00'
];

// ==================== 申请方：新建申请（支持短期/长期） ====================
function showMachineryApply() {
  var today = new Date().toISOString().slice(0,10);
  var slotOpts = TIME_SLOTS.map(function(s) { return '<option value="'+s+'">'+s+'</option>'; }).join('');
  var urgOpts = ['normal','urgent','emergency'].map(function(u) { return '<option value="'+u+'">'+MA_URG_MAP[u]+'</option>'; }).join('');

  var typeOpts = VEHICLE_TYPES.map(function(t) { return '<option value="'+t+'">'+t+'</option>'; }).join('');

  var html = [
    '<div class="form-group"><label>申请类型</label><select id="maAppType" onchange="toggleAppTypeFields()"><option value="short_term">短期用车</option><option value="long_term">长期用车</option></select></div>',
    '<div class="form-group"><label>所需车型 <span style="color:var(--danger)">*</span></label><select id="maVType" onchange="toggleCustomVType()">'+typeOpts+'<option value="__custom__">✏ 自定义输入...</option></select><input id="maVTypeCustom" placeholder="请输入车型" style="display:none;margin-top:6px" /></div>',
    '<div class="row2"><div class="form-group"><label>申请部门 <span style="color:var(--danger)">*</span></label><input id="maDept" placeholder="如：第一选矿厂精尾车间" /></div><div class="form-group"><label>申请人姓名 <span style="color:var(--danger)">*</span></label><input id="maName" placeholder="申请人姓名" /></div></div>',
    '<div class="row2"><div class="form-group"><label>申请人电话 <span style="color:var(--danger)">*</span></label><input id="maPhone" type="tel" placeholder="联系电话" /></div><div class="form-group"><label>紧急程度</label><select id="maUrgency">'+urgOpts+'</select></div></div>',
    '<div id="shortTermFields"><div class="form-group"><label>用车日期 <span style="color:var(--danger)">*</span></label><input id="maDate" type="date" value="'+today+'" /></div><div class="row2"><div class="form-group"><label>开始时间 <span style="color:var(--danger)">*</span></label><input id="maStartTime" type="time" value="08:00" /></div><div class="form-group"><label>结束时间 <span style="color:var(--danger)">*</span></label><input id="maEndTime" type="time" value="17:00" /></div></div></div>',
    '<div id="longTermFields" style="display:none"><div class="row2"><div class="form-group"><label>开始日期时间 <span style="color:var(--danger)">*</span></label><input id="maStartDT" type="datetime-local" /></div><div class="form-group"><label>结束日期时间 <span style="color:var(--danger)">*</span></label><input id="maEndDT" type="datetime-local" /></div></div></div>',
    '<div class="row2"><div class="form-group"><label>作业地点 <span style="color:var(--danger)">*</span></label><input id="maLocation" placeholder="如：采矿场3号平台" /></div><div class="form-group"><label>作业海拔</label><input id="maAltitude" placeholder="如：4600m" /></div></div>',
    '<div class="form-group"><label>作业用途 <span style="color:var(--danger)">*</span></label><textarea id="maPurpose" placeholder="请描述作业用途..." rows="3"></textarea></div>',
    '<div class="form-group"><label>是否涉及危险作业</label><select id="maHazardous" onchange="toggleHazardousFields()"><option value="0">否</option><option value="1">是</option></select></div>',
    '<div id="hazardousFields" style="display:none;border:1px solid var(--danger);border-radius:8px;padding:14px;margin-top:10px;background:rgba(192,57,43,.05)">',
      '<div style="font-weight:600;color:var(--danger);margin-bottom:10px;font-size:14px">⚠ 危险作业审批与安全交底</div>',
      '<div style="margin-bottom:10px"><span style="color:var(--text2);font-size:13px;display:block;margin-bottom:8px">选择交底方式</span>',
        '<div class="radio-pill-group">',
          '<label class="radio-pill active" id="pillAttachment" onclick="selectBriefingPill(\'attachment\')">',
            '<input type="radio" name="briefingMethod" value="attachment" checked style="display:none" />📎 上传附件交底</label>',
          '<label class="radio-pill" id="pillOnsite" onclick="selectBriefingPill(\'onsite\')">',
            '<input type="radio" name="briefingMethod" value="onsite" style="display:none" />👤 现场交底</label>',
        '</div>',
      '</div>',
      '<div id="briefingUploadArea">',
        '<div style="color:var(--text2);font-size:13px;margin-bottom:6px">上传交底文件/照片</div>',
        '<label for="briefingFiles" class="upload-btn" style="display:flex;align-items:center;justify-content:center;gap:6px;padding:12px 20px;background:var(--surface2);border:2px dashed var(--border);border-radius:8px;cursor:pointer;transition:all .2s;text-align:center;color:var(--text2);font-size:13px">📂 点击选择文件（图片/PDF/文档）</label>',
        '<input type="file" id="briefingFiles" multiple accept="image/*,.pdf,.doc,.docx" onchange="previewBriefingFiles()" style="display:none" />',
        '<div id="briefingPreview" style="display:flex;gap:8px;flex-wrap:wrap;margin-top:8px"></div>',
      '</div>',
    '</div>'
  ].join('');

  showModal('🚜 工程机械用车申请', html, async function(mask) {
    var appType = document.getElementById('maAppType').value;
    var vtypeSel = document.getElementById('maVType').value;
    var vtype = vtypeSel === '__custom__' ? document.getElementById('maVTypeCustom').value.trim() : vtypeSel;
    if (!vtype) { alert('请选择车型'); return false; }
    var dept = document.getElementById('maDept').value.trim();
    var name = document.getElementById('maName').value.trim();
    var phone = document.getElementById('maPhone').value.trim();
    var loc = document.getElementById('maLocation').value.trim();
    var altitude = document.getElementById('maAltitude').value.trim();
    var purpose = document.getElementById('maPurpose').value.trim();
    var hazardous = document.getElementById('maHazardous').value;
    var urg = document.getElementById('maUrgency').value;

    if (!dept) { alert('请填写申请部门'); return false; }
    if (!name) { alert('请填写申请人姓名'); return false; }
    if (!phone) { alert('请填写申请人电话'); return false; }
    if (!loc) { alert('请填写作业地点'); return false; }
    if (!purpose) { alert('请填写作业用途'); return false; }

    var schedStart, schedEnd;
    if (appType === 'long_term') {
      schedStart = document.getElementById('maStartDT').value;
      schedEnd = document.getElementById('maEndDT').value;
      if (!schedStart || !schedEnd) { alert('请选择起止日期时间'); return false; }
      schedStart = schedStart.replace('T', ' ');
      schedEnd = schedEnd.replace('T', ' ');
    } else {
      var d = document.getElementById('maDate').value;
      if (!d) { alert('请选择用车日期'); return false; }
      var st = document.getElementById('maStartTime').value;
      var et = document.getElementById('maEndTime').value;
      if (!st || !et) { alert('请选择开始和结束时间'); return false; }
      schedStart = d + ' ' + st;
      schedEnd = d + ' ' + et;
    }

    var briefingMethod = '', briefingFiles = '[]';
    if (hazardous === '1') {
      var mr = document.querySelector('input[name="briefingMethod"]:checked');
      briefingMethod = mr ? mr.value : '';
      var fi = document.getElementById('briefingFiles');
      if (fi && fi.files.length > 0 && briefingMethod === 'attachment') {
        var urls = await uploadMultipleFiles(fi.files);
        briefingFiles = JSON.stringify(urls);
      }
    }

    await api('/machinery/apply', { method: 'POST', data: {
      applicant_dept: dept, applicant_name: name, applicant_phone: phone,
      vehicle_type: vtype, application_type: appType,
      scheduled_start: schedStart, scheduled_end: schedEnd,
      work_location: loc, work_altitude: altitude, work_purpose: purpose,
      is_hazardous: hazardous === '1', urgency: urg,
      briefing_method: briefingMethod, briefing_files: briefingFiles
    }});
    toast('申请已提交');
    mask.remove();
    renderPage();
  });
}

function toggleCustomVType() {
  var sel = document.getElementById('maVType');
  var input = document.getElementById('maVTypeCustom');
  if (input) input.style.display = sel && sel.value === '__custom__' ? 'block' : 'none';
}
function toggleAppTypeFields() {
  var sel = document.getElementById('maAppType');
  var isLong = sel && sel.value === 'long_term';
  var s = document.getElementById('shortTermFields');
  var l = document.getElementById('longTermFields');
  if (s) s.style.display = isLong ? 'none' : 'block';
  if (l) l.style.display = isLong ? 'block' : 'none';
}

// 上传多文件辅助函数
async function uploadMultipleFiles(files) {
  var urls = [];
  for (var i = 0; i < files.length; i++) {
    var fd = new FormData();
    fd.append('file', files[i]);
    var r = await fetch(API + '/upload/single', { method: 'POST', headers: { 'Authorization': 'Bearer ' + TOKEN }, body: fd });
    var d = await r.json();
    if (d.code === 200 && d.data) urls.push(d.data.url);
  }
  return urls;
}

function toggleHazardousFields() {
  var sel = document.getElementById('maHazardous');
  var div = document.getElementById('hazardousFields');
  if (div) div.style.display = sel && sel.value === '1' ? 'block' : 'none';
}
function selectBriefingPill(method) {
  // Update hidden radios
  var radios = document.querySelectorAll('input[name="briefingMethod"]');
  radios.forEach(function(r) { r.checked = (r.value === method); });
  // Update pill styles
  document.querySelectorAll('.radio-pill').forEach(function(p) { p.classList.remove('active'); });
  var targetPill = document.getElementById(method === 'attachment' ? 'pillAttachment' : 'pillOnsite');
  if (targetPill) targetPill.classList.add('active');
  // Toggle upload area
  toggleBriefingUpload();
}
function toggleBriefingUpload() {
  var radio = document.querySelector('input[name="briefingMethod"]:checked');
  var area = document.getElementById('briefingUploadArea');
  if (area) area.style.display = radio && radio.value === 'attachment' ? 'block' : 'none';
}
function previewBriefingFiles() {
  var files = document.getElementById('briefingFiles').files;
  var preview = document.getElementById('briefingPreview');
  if (!preview) return;
  preview.innerHTML = '';
  for (var i = 0; i < files.length; i++) {
    (function(file) {
      if (file.type.startsWith('image/')) {
        var reader = new FileReader();
        reader.onload = function(e) {
          preview.innerHTML += '<div style="width:80px;height:80px;overflow:hidden;border-radius:4px;border:1px solid var(--border)"><img src="'+e.target.result+'" style="width:100%;height:100%;object-fit:cover" title="'+file.name+'" /></div>';
        };
        reader.readAsDataURL(file);
      } else {
        preview.innerHTML += '<div style="width:80px;height:80px;display:flex;align-items:center;justify-content:center;border-radius:4px;border:1px solid var(--border);font-size:12px;text-align:center">📄 '+file.name+'</div>';
      }
    })(files[i]);
  }
}

// ==================== 申请方：我的申请列表 ====================
function showMachineryList() {
  api('/machinery/my-applications').then(function(data) {
    if (!data || !data.length) return showModal('📋 我的用车申请', '<div class="empty">暂无申请记录</div><button class="btn btn-p btn-sm" onclick="showMachineryApply()" style="margin-top:12px">+ 新建申请</button>');

    var rows = '';
    data.forEach(function(item) {
      var isActive = (item.status === 'assigned' || item.status === 'in_progress');
      var vehicleCell = '';
      if (item.assigned_plate) {
        vehicleCell = '<td><span style="color:var(--primary);font-weight:600">'+item.assigned_plate+'</span><br><span style="font-size:11px">'+item.assigned_vehicle_type+' '+item.assigned_vehicle_model+'</span>'+(item.driver_name?'<br><span style="font-size:11px">👤 '+item.driver_name+'</span>':'')+'</td>';
      } else {
        vehicleCell = '<td style="color:var(--text2)">待分派</td>';
      }
      rows += '<tr>'+
        '<td class="order-no">'+item.application_no+'</td>'+
        '<td><span class="tag">'+(MA_TYPE_MAP[item.application_type]||'短期')+'</span></td>'+
        '<td>'+item.applicant_dept+'</td>'+
        '<td>'+(item.scheduled_start||'').replace(' ','<br>')+' — '+(item.scheduled_end||'').replace(' ','<br>')+'</td>'+
        '<td>'+item.work_location+'</td>'+
        '<td><span class="tag '+(item.urgency==='emergency'?'t-reject':item.urgency==='urgent'?'t-pending':'')+'">'+MA_URG_MAP[item.urgency]+'</span></td>'+
        '<td><span class="tag '+MA_ST_CLS[item.status]+'">'+MA_ST_MAP[item.status]+'</span></td>'+
        vehicleCell+
        '<td>'+
          '<button class="btn btn-sm btn-p" onclick="showMachineryDetail('+item.id+')">详情</button>'+
          (isActive ? ' <button class="btn btn-sm btn-s" onclick="earlyEndMachinery('+item.id+')">提前结束</button>' : '')+
          (item.status==='pending' ? ' <button class="btn btn-sm btn-d" onclick="cancelMachinery('+item.id+')">取消</button>' : '')+
        '</td></tr>';
    });

    showModal('🚜 我的用车申请',
      '<button class="btn btn-p btn-sm" onclick="showMachineryApply()" style="margin-bottom:12px">+ 新建申请</button>'+
      '<table><tr><th>编号</th><th>类型</th><th>部门</th><th>时段</th><th>地点</th><th>紧急</th><th>状态</th><th>指派车辆</th><th>操作</th></tr>'+rows+'</table>'
    );
  });
}

// ==================== 申请方：费用统计 ====================
function showMachineryCostStats() {
  api('/machinery/my-cost-stats').then(function(data) {
    if (!data) return alert('暂无数据');
    var tm = data.thisMonth || {};
    var at = data.allTime || {};
    var items = data.recentItems || [];

    var h = '<div class="stats-grid" style="margin-bottom:12px">'+
      '<div class="stat-item"><div class="stat-num">'+(tm.totalCount||0)+'</div><div class="stat-label">本月申请</div></div>'+
      '<div class="stat-item"><div class="stat-num">'+(tm.activeCount||0)+'</div><div class="stat-label">进行中</div></div>'+
      '<div class="stat-item"><div class="stat-num">'+(tm.totalHours||0).toFixed(1)+'h</div><div class="stat-label">本月工时</div></div>'+
      '<div class="stat-item"><div class="stat-num" style="color:var(--danger)">¥'+(tm.totalCost||0).toFixed(0)+'</div><div class="stat-label">本月费用</div></div>'+
      '</div>';

    if (items.length) {
      h += '<div style="font-weight:600;margin:8px 0">📋 费用明细</div><table><tr><th>编号</th><th>部门</th><th>工时</th><th>单价</th><th>费用</th><th>时间</th></tr>';
      items.forEach(function(r) {
        h += '<tr><td class="order-no">'+r.application_no+'</td><td>'+r.applicant_dept+'</td><td>'+r.working_hours+'h</td><td>¥'+r.hourly_rate+'/h</td><td style="font-weight:bold;color:var(--danger)">¥'+r.total_cost+'</td><td>'+(r.updated_at||r.created_at||'').slice(0,10)+'</td></tr>';
      });
      h += '</table>';
    } else {
      h += '<div class="empty">暂无费用明细</div>';
    }

    h += '<div style="margin-top:12px;padding:8px;background:var(--bg);border-radius:8px;font-size:13px">累计申请 <b>'+(at.totalCount||0)+'</b> 单 | 累计费用 <b style="color:var(--danger)">¥'+(at.totalCost||0).toFixed(0)+'</b></div>';

    showModal('💰 用车费用统计', h);
  });
}

// ==================== 申请方：提前结束 ====================
function earlyEndMachinery(id) {
  if (!confirm('确认提前结束该用车申请？\n\n结算时间将后推30分钟（用于返程路途）。')) return;
  api('/machinery/early-end/'+id, { method: 'POST' }).then(function(r) {
    if (r) toast('用车已结束，工时：'+r.working_hours+'h，费用：¥'+r.total_cost);
    document.querySelectorAll('.modal-mask').forEach(function(m) { m.remove(); });
    renderPage();
  });
}

// ==================== 取消申请 ====================
function cancelMachinery(id) {
  if (!confirm('确认取消该申请？')) return;
  api('/machinery/cancel/'+id, { method: 'POST' }).then(function() {
    toast('已取消');
    document.querySelectorAll('.modal-mask').forEach(function(m) { m.remove(); });
    renderPage();
  });
}

// ==================== 调度员：待指派列表 ====================
function showPendingAssignments() {
  Promise.all([api('/machinery/pending-list'), api('/vehicles'), api('/admin/users?role=driver')]).then(function(r) {
    var result = r[0];
    var pending = (result && result.list) || (Array.isArray(result) ? result : []);
    var stats = (result && result.stats) || null;
    var vehicles = r[1] || [], drivers = r[2] || [];
    if (!pending.length) return alert('暂无待指派申请');

    // 计算长期车辆（申请时长>2天）
    function isLongTerm(item) {
      if (!item.scheduled_start || !item.scheduled_end) return false;
      var start = new Date(item.scheduled_start.replace(' ','T'));
      var end = new Date(item.scheduled_end.replace(' ','T'));
      return (end - start) > 2 * 24 * 60 * 60 * 1000;
    }

    // 收集所有车型 + 长期车辆选项
    var typeSet = {};
    var hasLongTerm = false;
    pending.forEach(function(item) {
      if (item.vehicle_type) typeSet[item.vehicle_type] = (typeSet[item.vehicle_type]||0)+1;
      if (isLongTerm(item)) hasLongTerm = true;
    });
    var types = Object.keys(typeSet).sort();

    // 构建筛选下拉
    var filterOpts = '<option value="__all__">全部申请 ('+pending.length+')</option>';
    types.forEach(function(t) {
      filterOpts += '<option value="'+t.replace(/"/g,'&quot;')+'">'+t+' ('+typeSet[t]+')</option>';
    });
    if (hasLongTerm) {
      var ltCount = pending.filter(function(item){return isLongTerm(item);}).length;
      filterOpts += '<option value="__long_term__">长期车辆 ('+ltCount+')</option>';
    }

    // 统计栏
    var statsBar = '';
    if (stats) {
      statsBar = '<div style="display:flex;gap:16px;padding:10px 14px;background:var(--bg);border-radius:8px;margin-bottom:12px;font-size:13px;flex-wrap:wrap">'+
        '<span>🚛 剩余可派车辆：<b style="color:'+(stats.availableVehicles>0?'var(--success)':'var(--danger)')+'">'+stats.availableVehicles+'</b>/'+stats.totalVehicles+' 台</span>'+
        '<span>👤 剩余驾驶员：<b style="color:'+(stats.availableDrivers>0?'var(--success)':'var(--danger)')+'">'+stats.availableDrivers+'</b>/'+stats.totalDrivers+' 人</span>'+
        '</div>';
    }

    // 渲染表格行的函数
    function renderRows(filtered) {
      var rows = '';
      filtered.forEach(function(item) {
        var ht = Number(item.is_hazardous) ? '<span class="tag t-reject">危险</span> ' : '';
        var ltTag = isLongTerm(item) ? ' <span class="tag t-pending">长期</span>' : '';
        var vtypeDisplay = item.vehicle_type ? '<span style="color:var(--primary);font-weight:600">'+item.vehicle_type+'</span>' : '<span style="color:var(--text2)">未指定</span>';
        rows += '<tr><td class="order-no">'+item.application_no+'</td><td><span class="tag">'+(MA_TYPE_MAP[item.application_type]||'短期')+'</span>'+ltTag+'</td><td>'+vtypeDisplay+'</td><td><b>'+item.applicant_dept+'</b></td><td>'+item.applicant_name+'<br><span style="font-size:11px">'+item.applicant_phone+'</span></td><td>'+(item.scheduled_start||'').replace(' ','<br>')+'-'+(item.scheduled_end||'').replace(' ','<br>')+'</td><td>'+item.work_location+'</td><td>'+ht+'<span class="tag '+(item.urgency==='emergency'?'t-reject':'t-pending')+'">'+MA_URG_MAP[item.urgency]+'</span></td><td><button class="btn btn-sm btn-p" onclick="showAssignForm('+item.id+')">指派</button> <button class="btn btn-sm btn-s" onclick="showMachineryDetail('+item.id+')">详情</button></td></tr>';
      });
      return rows;
    }

    window._maVehicles = vehicles;
    window._maDrivers = drivers;
    window._maPending = pending;

    var modalContent = statsBar +
      '<div style="margin-bottom:10px;display:flex;align-items:center;gap:8px">'+
        '<span style="font-size:13px;white-space:nowrap">🔍 筛选：</span>'+
        '<select id="pendingVTypeFilter" onchange="filterPendingByType()" style="font-size:13px;max-width:280px">'+filterOpts+'</select>'+
        '<span id="pendingFilterCount" style="font-size:12px;color:var(--text2)"></span>'+
      '</div>'+
      '<div id="pendingTableWrap"><table><tr><th>编号</th><th>类型</th><th>所需车型</th><th>部门</th><th>申请人</th><th>时段</th><th>地点</th><th>标签</th><th>操作</th></tr>'+renderRows(pending)+'</table></div>';

    showModal('📋 待指派用车申请', modalContent);
  });
}

// 筛选待指派列表
function filterPendingByType() {
  var sel = document.getElementById('pendingVTypeFilter');
  var countEl = document.getElementById('pendingFilterCount');
  var wrap = document.getElementById('pendingTableWrap');
  if (!sel || !wrap) return;
  var val = sel.value;
  var pending = window._maPending || [];

  var filtered;
  if (val === '__all__') {
    filtered = pending;
  } else if (val === '__long_term__') {
    filtered = pending.filter(function(item) {
      if (!item.scheduled_start || !item.scheduled_end) return false;
      var start = new Date(item.scheduled_start.replace(' ','T'));
      var end = new Date(item.scheduled_end.replace(' ','T'));
      return (end - start) > 2 * 24 * 60 * 60 * 1000;
    });
  } else {
    filtered = pending.filter(function(item) { return item.vehicle_type === val; });
  }

  var rows = '';
  filtered.forEach(function(item) {
    var ht = Number(item.is_hazardous) ? '<span class="tag t-reject">危险</span> ' : '';
    function isLT(it) {
      if (!it.scheduled_start || !it.scheduled_end) return false;
      return (new Date(it.scheduled_end.replace(' ','T')) - new Date(it.scheduled_start.replace(' ','T'))) > 2*24*60*60*1000;
    }
    var ltTag = isLT(item) ? ' <span class="tag t-pending">长期</span>' : '';
    var vtypeDisplay = item.vehicle_type ? '<span style="color:var(--primary);font-weight:600">'+item.vehicle_type+'</span>' : '<span style="color:var(--text2)">未指定</span>';
    rows += '<tr><td class="order-no">'+item.application_no+'</td><td><span class="tag">'+(MA_TYPE_MAP[item.application_type]||'短期')+'</span>'+ltTag+'</td><td>'+vtypeDisplay+'</td><td><b>'+item.applicant_dept+'</b></td><td>'+item.applicant_name+'<br><span style="font-size:11px">'+item.applicant_phone+'</span></td><td>'+(item.scheduled_start||'').replace(' ','<br>')+'-'+(item.scheduled_end||'').replace(' ','<br>')+'</td><td>'+item.work_location+'</td><td>'+ht+'<span class="tag '+(item.urgency==='emergency'?'t-reject':'t-pending')+'">'+MA_URG_MAP[item.urgency]+'</span></td><td><button class="btn btn-sm btn-p" onclick="showAssignForm('+item.id+')">指派</button> <button class="btn btn-sm btn-s" onclick="showMachineryDetail('+item.id+')">详情</button></td></tr>';
  });

  wrap.innerHTML = filtered.length
    ? '<table><tr><th>编号</th><th>类型</th><th>所需车型</th><th>部门</th><th>申请人</th><th>时段</th><th>地点</th><th>标签</th><th>操作</th></tr>'+rows+'</table>'
    : '<div class="empty">该筛选项下暂无待指派申请</div>';
  if (countEl) countEl.textContent = '共 '+filtered.length+' 条';
}

// ==================== 调度员：指派表单 ====================
function showAssignForm(id) {
  var vehicles = window._maVehicles || [];
  var drivers = window._maDrivers || [];
  var pending = window._maPending || [];

  // 查找对应申请
  var app = null;
  for (var i = 0; i < pending.length; i++) {
    if (pending[i].id === id) { app = pending[i]; break; }
  }
  if (!app) { alert('申请数据丢失，请返回重试'); return; }

  if (!vehicles.length) return alert('请先录入车辆');
  if (!drivers.length) return alert('暂无可用驾驶员');

  // 按车型匹配排序：完全匹配 → 部分匹配 → 其他
  var reqType = (app.vehicle_type || '').toLowerCase();
  var scored = vehicles.map(function(v) {
    var vt = (v.vehicle_type || '').toLowerCase();
    var score = 0;
    if (reqType && vt === reqType) score = 3;
    else if (reqType && vt.indexOf(reqType) >= 0) score = 2;
    else if (reqType && reqType.indexOf(vt) >= 0) score = 1;
    return { v: v, score: score };
  });
  scored.sort(function(a, b) { return b.score - a.score; });

  var vOpts = scored.map(function(s) {
    var v = s.v;
    var matchBadge = s.score >= 3 ? ' ✅ 车型匹配' : s.score >= 2 ? ' 🔶 部分匹配' : '';
    return '<option value="'+v.id+'"'+(s.score >= 3 ? ' style="color:var(--success);font-weight:600"' : '')+'>'+v.plate_number+'（'+v.vehicle_type+' '+v.model+'） ¥'+(v.hourly_rate||0)+'/h'+matchBadge+'</option>';
  }).join('');

  var dOpts = drivers.map(function(d) { return '<option value="'+d.id+'">'+d.name+'（'+d.phone+'）</option>'; }).join('');

  // 申请摘要卡片
  var summaryHtml = '<div style="background:var(--bg);border:1px solid var(--border);border-radius:8px;padding:14px;margin-bottom:16px;line-height:1.8">'+
    '<div style="font-weight:700;color:var(--gold-light);margin-bottom:6px;font-size:14px">'+app.application_no+' — '+(MA_TYPE_MAP[app.application_type]||'短期')+'用车</div>'+
    '<div><b>所需车型：</b><span style="color:var(--primary);font-weight:600;font-size:15px">'+(app.vehicle_type || '未指定')+'</span></div>'+
    '<div><b>申请部门：</b>'+app.applicant_dept+' | <b>申请人：</b>'+app.applicant_name+' | <b>电话：</b>'+app.applicant_phone+'</div>'+
    '<div><b>用车时段：</b>'+(app.scheduled_start||'')+' — '+(app.scheduled_end||'')+'</div>'+
    '<div><b>作业地点：</b>'+app.work_location+(app.work_altitude ? ' ('+app.work_altitude+')' : '')+'</div>'+
    '<div><b>作业用途：</b>'+app.work_purpose+'</div>'+
    '<div><b>紧急程度：</b><span class="tag '+(app.urgency==='emergency'?'t-reject':app.urgency==='urgent'?'t-pending':'')+'">'+MA_URG_MAP[app.urgency]+'</span>'+
      (Number(app.is_hazardous) ? ' <span class="tag t-reject">危险作业</span>' : '')+
      (app.briefing_method ? ' | <b>交底方式：</b>'+(app.briefing_method==='attachment'?'附件交底':'现场交底') : '')+
    '</div>'+
  '</div>';

  // 统计匹配数量
  var matchCount = scored.filter(function(s) { return s.score >= 3; }).length;
  if (matchCount === 0) {
    summaryHtml += '<div style="padding:10px;background:rgba(212,160,23,.1);border:1px solid var(--warning);border-radius:6px;margin-bottom:14px;font-size:13px;color:var(--warning)">⚠ 警告：车辆列表中没有与所需车型 <b>"'+app.vehicle_type+'"</b> 完全匹配的车辆，请核实或指派近似车型。</div>';
  }

  showModal('🚛 指派车辆 — '+app.application_no,
    summaryHtml +
    '<div class="form-group"><label>选择车辆 <span style="font-size:11px;color:var(--text2)">（✅ 车型匹配优先）</span></label><select id="assignVehicle" style="font-size:13px">'+vOpts+'</select></div>'+
    '<div class="form-group"><label>选择驾驶员</label><select id="assignDriver">'+dOpts+'</select></div>',
    async function(mask) {
      var vid = parseInt(document.getElementById('assignVehicle').value);
      var did = parseInt(document.getElementById('assignDriver').value);
      if (!vid || !did) { alert('请选择车辆和驾驶员'); return false; }
      var result = await api('/machinery/assign/'+id, { method: 'POST', data: { assigned_vehicle_id: vid, assigned_driver_id: did }});
      if (!result) return false; // api 失败时已弹错误提示，不继续
      toast('派车成功！已通知驾驶员和申请方');
      mask.remove();
      document.querySelectorAll('.modal-mask').forEach(function(m) { m.remove(); });
      renderPage();
    }
  );
}

// ==================== 驾驶员：派车任务 ====================
function showDriverTasks() {
  api('/machinery/driver-tasks').then(function(data) {
    if (!data || !data.length) return showModal('🚛 派车任务', '<div class="empty">暂无进行中的派车任务</div>');

    var cards = data.map(function(item) {
      return '<div class="card" style="border-left:3px solid var(--primary);margin-bottom:12px">'+
        '<div style="display:flex;justify-content:space-between"><div><b style="font-size:18px;color:var(--primary)">'+item.assigned_plate+'</b></div><span class="tag '+(item.urgency==='emergency'?'t-reject':'t-progress')+'">'+MA_URG_MAP[item.urgency]+'</span></div>'+
        '<div style="margin-top:8px;font-size:13px">'+
          '<div><b>申请人所需车型：</b><span style="color:var(--gold-light);font-weight:600">'+(item.vehicle_type || '-')+'</span></div>'+
          '<div><b>指派车辆/型号：</b><span style="color:var(--primary)">'+item.assigned_vehicle_type+' '+item.assigned_vehicle_model+'</span></div>'+
          '<div><b>服务部门：</b>'+item.applicant_dept+'</div>'+
          '<div><b>作业时段：</b>'+(item.scheduled_start||'')+' — '+(item.scheduled_end||'')+'</div>'+
          '<div><b>作业地点：</b>'+item.work_location+(item.work_altitude ? ' ('+item.work_altitude+')' : '')+'</div>'+
          '<div><b>作业用途：</b>'+item.work_purpose+'</div>'+
          '<div><b>申请人：</b>'+item.applicant_name+' 📞 <a href="tel:'+item.applicant_phone+'">'+item.applicant_phone+'</a></div>'+
          (item.briefing_files && item.briefing_files !== '[]' ? renderBriefingFiles(item.briefing_files) : '')+
        '</div></div>';
    }).join('');

    showModal('🚛 我的派车任务 ('+data.length+'条)', cards);
  });
}

function renderBriefingFiles(filesJson) {
  try {
    var files = JSON.parse(filesJson);
    if (!files.length) return '';
    // 收集所有图片URL用于查看器
    var imgUrls = files.filter(function(u) { return /\.(jpg|jpeg|png|gif|webp)/i.test(u); });
    var h = '<div style="display:flex;gap:6px;flex-wrap:wrap;margin-top:4px">';
    files.forEach(function(url) {
      if (/\.(jpg|jpeg|png|gif|webp)/i.test(url)) {
        var idx = imgUrls.indexOf(url);
        h += '<img src="'+url+'" style="width:60px;height:60px;object-fit:cover;border-radius:4px;cursor:pointer;border:1px solid var(--border)" onclick="event.stopPropagation();showFaultPhotos('+JSON.stringify(imgUrls)+','+idx+')" />';
      } else {
        h += '<a href="'+url+'" target="_blank" style="font-size:11px;padding:4px 8px;background:var(--bg);border-radius:4px;text-decoration:none;color:var(--text)">📄 文件</a>';
      }
    });
    return h + '</div>';
  } catch(e) { return ''; }
}

// ==================== 调度员：全部记录 ====================
function showMachineryListAll() {
  api('/machinery/list-all').then(function(data) {
    if (!data || !data.length) return alert('暂无用车记录');
    var rows = '';
    data.forEach(function(item) {
      rows += '<tr><td class="order-no">'+item.application_no+'</td><td><span class="tag">'+(MA_TYPE_MAP[item.application_type]||'短期')+'</span></td><td>'+item.applicant_dept+'</td><td>'+(item.vehicle_type || '-')+'</td><td>'+item.applicant_name+'</td><td>'+(item.assigned_plate||'-')+'</td><td>'+(item.driver_name||'-')+'</td><td><span class="tag '+MA_ST_CLS[item.status]+'">'+MA_ST_MAP[item.status]+'</span></td><td>¥'+(item.total_cost||0)+'</td><td>'+(item.created_at||'').slice(0,10)+'</td><td><button class="btn btn-sm btn-s" onclick="showMachineryDetail('+item.id+')">详情</button></td></tr>';
    });
    showModal('📊 全部用车记录', '<table><tr><th>编号</th><th>类型</th><th>部门</th><th>所需车型</th><th>申请人</th><th>车辆</th><th>驾驶员</th><th>状态</th><th>费用</th><th>日期</th><th>操作</th></tr>'+rows+'</table>');
  });
}

// ==================== 通用详情 ====================
function showMachineryDetail(id) {
  api('/machinery/detail/'+id).then(function(item) {
    if (!item) return;
    var h = '<div style="line-height:1.8">';
    h += '<div><b>编号：</b>'+item.application_no+' | <span class="tag '+MA_ST_CLS[item.status]+'">'+MA_ST_MAP[item.status]+'</span> | <span class="tag">'+(MA_TYPE_MAP[item.application_type]||'短期')+'用车</span></div>';
    h += '<div style="border-top:1px solid var(--border);margin:8px 0"></div>';
    h += '<div><b>申请部门：</b>'+item.applicant_dept+'</div>';
    h += '<div><b>申请人：</b>'+item.applicant_name+' | <b>电话：</b>'+item.applicant_phone+'</div>';
    h += '<div><b>🚜 所需车型：</b><span style="color:var(--primary);font-weight:600">'+(item.vehicle_type || '未指定')+'</span></div>';
    h += '<div><b>📅 计划用车：</b>'+item.scheduled_start+' — '+item.scheduled_end+'</div>';
    if (item.status === 'completed' || item.status === 'early_completed') {
      var actualEnd = item.settlement_end_time || item.actual_end_time;
      if (actualEnd) {
        var startTime = item.scheduled_start; if (startTime.includes(' ')) startTime = startTime.split(' ')[1];
        h += '<div><b>⏱ 实际用车：</b>'+item.scheduled_start+' → '+actualEnd+' <span style="color:var(--warning)">('+item.working_hours+'h)</span></div>';
      }
    }
    h += '<div><b>作业地点：</b>'+item.work_location+(item.work_altitude ? ' | <b>海拔：</b>'+item.work_altitude : '')+'</div>';
    h += '<div><b>作业用途：</b>'+item.work_purpose+'</div>';
    h += '<div><b>紧急程度：</b>'+MA_URG_MAP[item.urgency]+' | <b>危险作业：</b>'+(Number(item.is_hazardous)?'<span style="color:var(--danger)">是</span>':'否')+'</div>';
    if (item.briefing_method) {
      h += '<div><b>交底方式：</b>'+(item.briefing_method==='attachment'?'📎 附件交底':'👤 现场交底')+'</div>';
      if (item.briefing_files && item.briefing_files !== '[]') h += '<div><b>交底文件：</b>'+renderBriefingFiles(item.briefing_files)+'</div>';
    }
    if (item.assigned_plate) {
      h += '<div style="border-top:1px solid var(--border);margin:8px 0"></div>';
      h += '<div style="color:var(--primary)"><b>🚛 指派车辆：</b>'+item.assigned_plate+'（'+item.assigned_vehicle_type+' '+item.assigned_vehicle_model+'）</div>';
      h += '<div><b>驾驶员：</b>'+(item.driver_name||'-')+' | <b>电话：</b>'+(item.driver_phone||'-')+'</div>';
      h += '<div><b>调度员：</b>'+(item.dispatcher_name||'-')+'</div><div><b>小时单价：</b>¥'+(item.hourly_rate||0)+'/h</div>';
    }
    if (item.status === 'completed' || item.status === 'early_completed') {
      h += '<div style="border-top:1px solid var(--border);margin:8px 0"></div>';
      h += '<div style="color:var(--success)"><b>✅ 结算</b></div>';
      h += '<div><b>工作工时：</b>'+item.working_hours+'h | <b>总费用：</b>¥'+item.total_cost+'</div>';
    }
    h += '<div style="border-top:1px solid var(--border);margin:8px 0"></div>';
    h += '<div style="font-size:12px;color:var(--text2)">申请时间：'+(item.created_at||'').slice(0,16)+' | 更新：'+(item.updated_at||'').slice(0,16)+'</div></div>';
    showModal('用车详情 — '+item.application_no, h);
  });
}

// ==================== 导出Excel ====================
function exportMachineryCSV() {
  var df = prompt('开始日期（留空=全部）：', '');
  if (df === null) return;
  var dt = prompt('结束日期（留空=全部）：', '');
  if (dt === null) return;
  var body = {};
  if (df) body.date_from = df;
  if (dt) body.date_to = dt;
  downloadXLSX('/api/machinery/export-xlsx', body, '工程机械用车导出');
}

// ==================== 调度员：已派车收益明细 ====================
var _dispatchedPeriod = 'month'; // 默认本月

function showDispatchedOrders(period) {
  if (period) _dispatchedPeriod = period;
  var params = '?period=' + _dispatchedPeriod;

  api('/machinery/dispatched-list' + params).then(function(result) {
    var data = result.list || [];
    var stats = result.stats || {};

    var tabLabels = { today:'今日', month:'本月', year:'本年', custom:'自定义' };
    var tabs = ['today','month','year','custom'].map(function(p) {
      var active = _dispatchedPeriod === p ? ' style="background:var(--primary);color:#fff"' : '';
      return '<button class="btn btn-sm"'+active+' onclick="showDispatchedOrders(\''+p+'\')">'+tabLabels[p]+'</button>';
    }).join(' ');

    var customHtml = '';
    if (_dispatchedPeriod === 'custom') {
      customHtml = '<span style="margin-left:8px;font-size:13px">从 <input type="date" id="dispDateFrom" style="width:130px" /> 到 <input type="date" id="dispDateTo" style="width:130px" /> <button class="btn btn-sm btn-p" onclick="showDispatchedOrdersCustom()">查询</button></span>';
    }

    var summaryHtml = '<div class="stats-grid" style="margin-bottom:12px">'+
      '<div class="stat-item"><div class="stat-num">'+stats.totalCount+'</div><div class="stat-label">已派车订单</div></div>'+
      '<div class="stat-item"><div class="stat-num">'+stats.totalHours+'h</div><div class="stat-label">总工时</div></div>'+
      '<div class="stat-item"><div class="stat-num" style="color:var(--success)">¥'+stats.totalRevenue.toFixed(0)+'</div><div class="stat-label">总收益</div></div>'+
      '<div class="stat-item" onclick="exportDispatchedCSV()" style="cursor:pointer"><div class="stat-num" style="color:var(--primary)">📥</div><div class="stat-label">导出数据</div></div>'+
      '</div>';

    if (!data.length) {
      return showModal('💰 已派车收益明细',
        summaryHtml +
        '<div style="margin-bottom:8px">'+tabs+' '+customHtml+'</div>'+
        '<div class="empty">暂无已派车订单</div>'
      );
    }

    var rows = '';
    data.forEach(function(item) {
      var vehicle = (item.assigned_plate || '') + ' ' + (item.assigned_vehicle_type || '') + ' ' + (item.assigned_vehicle_model || '');
      var workTime = (item.scheduled_start || '') + ' ~ ' + (item.scheduled_end || '');
      var costDisplay = Number(item.total_cost) > 0 ? '¥' + Number(item.total_cost).toFixed(0) : '-';
      rows += '<tr>'+
        '<td>'+(item.created_at||'').slice(0,10)+'</td>'+
        '<td>'+item.applicant_dept+'</td>'+
        '<td>'+item.applicant_name+'</td>'+
        '<td><span style="color:var(--primary);font-weight:600">'+vehicle.trim()+'</span>'+(item.driver_name?'<br><span style="font-size:11px">👤 '+item.driver_name+'</span>':'')+'</td>'+
        '<td>'+item.work_location+'</td>'+
        '<td style="font-size:12px">'+workTime+'</td>'+
        '<td style="font-weight:bold;color:'+(Number(item.total_cost)>0?'var(--success)':'var(--text2)')+'">'+costDisplay+'</td>'+
        '<td><button class="btn btn-sm btn-s" onclick="showMachineryDetail('+item.id+')">详情</button></td>'+
        '</tr>';
    });

    var tableHtml = '<table><tr><th>申请日期</th><th>申请部门</th><th>申请人</th><th>车辆</th><th>作业地点</th><th>作业时间</th><th>产生费用</th><th>操作</th></tr>'+rows+'</table>';

    showModal('💰 已派车收益明细',
      summaryHtml +
      '<div style="margin-bottom:8px">'+tabs+' '+customHtml+'</div>'+
      tableHtml
    );
  });
}

// 自定义日期查询
function showDispatchedOrdersCustom() {
  var df = document.getElementById('dispDateFrom');
  var dt = document.getElementById('dispDateTo');
  if (!df || !dt) { alert('请至少选择一个日期'); return; }
  var dfVal = df.value, dtVal = dt.value;
  if (!dfVal && !dtVal) { alert('请至少选择一个日期'); return; }
  var params = [];
  if (dfVal) params.push('date_from=' + encodeURIComponent(dfVal));
  if (dtVal) params.push('date_to=' + encodeURIComponent(dtVal));
  api('/machinery/dispatched-list?' + params.join('&')).then(function(result) {
    var data = result.list || [];
    var stats = result.stats || {};

    var summaryHtml = '<div class="stats-grid" style="margin-bottom:12px">'+
      '<div class="stat-item"><div class="stat-num">'+stats.totalCount+'</div><div class="stat-label">已派车订单</div></div>'+
      '<div class="stat-item"><div class="stat-num">'+stats.totalHours+'h</div><div class="stat-label">总工时</div></div>'+
      '<div class="stat-item"><div class="stat-num" style="color:var(--success)">¥'+stats.totalRevenue.toFixed(0)+'</div><div class="stat-label">总收益</div></div>'+
      '<div class="stat-item" onclick="exportDispatchedCSV()" style="cursor:pointer"><div class="stat-num" style="color:var(--primary)">📥</div><div class="stat-label">导出数据</div></div>'+
      '</div>';

    if (!data.length) {
      var mask = document.querySelector('.modal-mask');
      if (mask) {
        var box = mask.querySelector('.modal-box');
        if (box) box.innerHTML = '<h2>💰 已派车收益明细</h2>' + summaryHtml + '<div class="empty">该日期范围内暂无已派车订单</div>';
      }
      return;
    }

    var rows = '';
    data.forEach(function(item) {
      var vehicle = (item.assigned_plate || '') + ' ' + (item.assigned_vehicle_type || '') + ' ' + (item.assigned_vehicle_model || '');
      var workTime = (item.scheduled_start || '') + ' ~ ' + (item.scheduled_end || '');
      var costDisplay = Number(item.total_cost) > 0 ? '¥' + Number(item.total_cost).toFixed(0) : '-';
      rows += '<tr>'+
        '<td>'+(item.created_at||'').slice(0,10)+'</td>'+
        '<td>'+item.applicant_dept+'</td>'+
        '<td>'+item.applicant_name+'</td>'+
        '<td><span style="color:var(--primary);font-weight:600">'+vehicle.trim()+'</span>'+(item.driver_name?'<br><span style="font-size:11px">👤 '+item.driver_name+'</span>':'')+'</td>'+
        '<td>'+item.work_location+'</td>'+
        '<td style="font-size:12px">'+workTime+'</td>'+
        '<td style="font-weight:bold;color:'+(Number(item.total_cost)>0?'var(--success)':'var(--text2)')+'">'+costDisplay+'</td>'+
        '<td><button class="btn btn-sm btn-s" onclick="showMachineryDetail('+item.id+')">详情</button></td>'+
        '</tr>';
    });

    var tableHtml = '<table><tr><th>申请日期</th><th>申请部门</th><th>申请人</th><th>车辆</th><th>作业地点</th><th>作业时间</th><th>产生费用</th><th>操作</th></tr>'+rows+'</table>';

    var mask = document.querySelector('.modal-mask');
    if (mask) {
      var box = mask.querySelector('.modal-box');
      if (box) box.innerHTML = '<h2>💰 已派车收益明细</h2>' + summaryHtml + tableHtml;
    }
  });
}

// 导出当前已派车收益CSV
function exportDispatchedCSV() {
  var params = [];
  if (_dispatchedPeriod === 'custom') {
    var df = document.getElementById('dispDateFrom');
    var dt = document.getElementById('dispDateTo');
    if (df && df.value) params.push('date_from=' + encodeURIComponent(df.value));
    if (dt && dt.value) params.push('date_to=' + encodeURIComponent(dt.value));
  } else {
    params.push('period=' + _dispatchedPeriod);
  }
  var qs = params.length ? '?' + params.join('&') : '';

  var xbody = {};
  if (_dispatchedPeriod === 'custom') {
    var df = document.getElementById('dispDateFrom')?.value;
    var dt = document.getElementById('dispDateTo')?.value;
    if (df) xbody.date_from = df;
    if (dt) xbody.date_to = dt;
  } else if (_dispatchedPeriod) {
    xbody.period = _dispatchedPeriod;
  }
  downloadXLSX('/api/machinery/export-xlsx', xbody, '已派车收益明细');
}
