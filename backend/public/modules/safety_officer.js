// 🛡 安全员模块

// 三角叹号图标：隐患用橙色，考核用红色
function triIcon(color) {
  return '<span style="color:' + color + ';font-size:20px;font-weight:900;line-height:1;flex-shrink:0">⚠</span>';
}
var HZ_ICON = triIcon('var(--warning)');   // 隐患: 橙色
var KP_ICON = triIcon('var(--danger)');    // 考核: 红色
var OK_ICON = '<span style="color:var(--success);font-size:20px;font-weight:900;line-height:1">✓</span>'; // 已闭环: 绿色

// 安全员专属仪表盘
async function renderSafetyOfficer() {
  var el = document.getElementById('mainPage');
  var [hazards, alerts] = await Promise.all([
    api('/hazards/list'),
    api('/hazards/alerts').catch(function() { return null; })
  ]);
  var hz = hazards || [];
  var pending = hz.filter(function(h) { return h.status !== 'verified'; });
  var verified = hz.filter(function(h) { return h.status === 'verified'; });
  var overdue = (alerts && alerts.overdue) ? alerts.overdue.length : 0;

  el.innerHTML = '<div class="layout">' +
    '<div class="stats-grid">' +
      '<div class="stat-item"><div class="stat-num">' + pending.length + '</div><div class="stat-label">待处理隐患</div></div>' +
      '<div class="stat-item"><div class="stat-num" style="color:var(--danger)">' + overdue + '</div><div class="stat-label">已逾期</div></div>' +
      '<div class="stat-item"><div class="stat-num">' + verified.length + '</div><div class="stat-label">已闭环</div></div>' +
      '<div class="stat-item" onclick="showHazardReport()" style="cursor:pointer"><div class="stat-num">' + HZ_ICON + '</div><div class="stat-label">上报隐患</div></div>' +
      '<div class="stat-item" onclick="showAssessmentForm()" style="cursor:pointer"><div class="stat-num">' + KP_ICON + '</div><div class="stat-label">考核通报</div></div>' +
    '</div>' +
    '<div class="row2"><div class="card" style="text-align:center;cursor:pointer" onclick="showVehicleArchiveList()"><h3>📋</h3>在编车辆档案<br><span style="font-size:12px;color:var(--text2)">车辆详细档案查阅</span></div></div>' +
    '<div class="card">' +
      '<div class="card-title" style="justify-content:flex-start;gap:6px">' +
        HZ_ICON + KP_ICON +
        '<span style="margin:0 4px">隐患通报列表</span>' +
      '</div>' +
      '<div class="tabs" style="margin-bottom:12px">' +
        '<button class="tab active" id="tabHazard" onclick="switchSafetyTab(\'hazard\')">' + HZ_ICON + ' 隐患</button>' +
        '<button class="tab" id="tabAssess" onclick="switchSafetyTab(\'assess\')">' + KP_ICON + ' 通报</button>' +
        '<button class="tab" id="tabClosed" onclick="switchSafetyTab(\'closed\')">' + OK_ICON + ' 已闭环</button>' +
      '</div>' +
      '<div id="safetyList">加载中...</div>' +
    '</div>' +
  '</div>';
  switchSafetyTab('hazard');
}

// 切换标签
var _safetyTab = 'hazard';
function switchSafetyTab(tab) {
  _safetyTab = tab;
  document.getElementById('tabHazard').className = 'tab' + (tab === 'hazard' ? ' active' : '');
  document.getElementById('tabAssess').className = 'tab' + (tab === 'assess' ? ' active' : '');
  document.getElementById('tabClosed').className = 'tab' + (tab === 'closed' ? ' active' : '');
  if (tab === 'hazard') loadHazardList();
  else if (tab === 'assess') loadAssessmentList();
  else loadClosedList();
}

// ==================== 隐患列表（黄标） ====================
async function loadHazardList() {
  var el = document.getElementById('safetyList');
  if (!el) return;
  try {
    var data = await api('/hazards/list');
    data = data || [];
  } catch(e) { data = []; }

  if (!data.length) { el.innerHTML = '<div class="empty">暂无隐患记录</div>'; return; }

  var st = { reported: '待指派', assigned: '已指派', rectifying: '整改中', completed: '待确认', verified: '已闭环' };
  var sm = { '低': 't-done', '一般': 't-pending', '高': 't-reject', '紧急': 't-reject' };

  var rows = data.map(function(x) {
    var statusTag = x.status === 'verified' ? 't-done' : (x.status === 'completed' ? 't-pending' : 't-progress');
    var btns = '<button class="btn btn-sm btn-p" onclick="showHazardDetail(' + x.id + ')">详情</button>';

    // 待指派：直接可指定整改人
    if (x.status === 'reported') {
      btns += ' <button class="btn btn-sm btn-s" onclick="assignHazard(' + x.id + ')">指派</button>';
    }
    // 待确认：安全员可直接验收闭环或驳回
    if (x.status === 'completed') {
      btns += ' <button class="btn btn-sm btn-s" onclick="verifyHazard(' + x.id + ')">验收闭环</button>';
      btns += ' <button class="btn btn-sm btn-d" onclick="rejectRectifyHazard(' + x.id + ')">驳回</button>';
    }

    return '<tr>' +
      '<td class="order-no"><b>' + escHtml(x.hazard_no) + '</b></td>' +
      '<td>' + escHtml(x.location) + '</td>' +
      '<td><span class="tag ' + (sm[x.severity] || '') + '">' + escHtml(x.severity) + '</span></td>' +
      '<td>' + escHtml(x.responsible_name || '-') + '</td>' +
      '<td><span class="tag ' + statusTag + '">' + escHtml(st[x.status] || x.status) + '</span></td>' +
      '<td style="font-size:12px">' + escHtml(x.deadline || '-') + '</td>' +
      '<td style="white-space:nowrap">' + btns + '</td>' +
    '</tr>';
  }).join('');

  el.innerHTML = '<table>' +
    '<tr><th>编号</th><th>地点</th><th>程度</th><th>整改人</th><th>状态</th><th>期限</th><th>操作</th></tr>' +
    rows +
  '</table>';
}

// ==================== 通报列表（红标） ====================
async function loadAssessmentList() {
  var el = document.getElementById('safetyList');
  if (!el) return;
  try {
    var data = await api('/safety/assessments');
    data = data || [];
  } catch(e) { data = []; }

  if (!data.length) { el.innerHTML = '<div class="empty">暂无通报记录</div>'; return; }

  var typeColors = { '表扬': 't-done', '通报': 't-pending', '警告': 't-reject', '处罚': 't-reject' };

  var rows = data.map(function(x) {
    return '<tr>' +
      '<td class="order-no"><b>' + escHtml(x.assess_no) + '</b></td>' +
      '<td>' + escHtml(x.title) + '</td>' +
      '<td>' + escHtml(x.target_name || '-') + '</td>' +
      '<td><span class="tag ' + (typeColors[x.assess_type] || '') + '">' + escHtml(x.assess_type) + '</span></td>' +
      '<td>' + escHtml(x.issuer_name || '-') + '</td>' +
      '<td style="font-size:12px">' + escHtml((x.created_at||'').slice(0,10)) + '</td>' +
      '<td><button class="btn btn-sm btn-p" onclick="showAssessmentDetail(' + x.id + ')">详情</button></td>' +
    '</tr>';
  }).join('');

  el.innerHTML = '<table>' +
    '<tr><th>编号</th><th>标题</th><th>被考核人</th><th>类型</th><th>下发人</th><th>日期</th><th>操作</th></tr>' +
    rows +
  '</table>';
}

// ==================== 已闭环列表（绿标，仅展示） ====================
async function loadClosedList() {
  var el = document.getElementById('safetyList');
  if (!el) return;
  try {
    var data = await api('/hazards/list');
    data = (data || []).filter(function(h) { return h.status === 'verified'; });
  } catch(e) { data = []; }

  if (!data.length) { el.innerHTML = '<div class="empty">暂无已闭环记录</div>'; return; }

  var sm = { '低': 't-done', '一般': 't-pending', '高': 't-reject', '紧急': 't-reject' };
  var rows = data.map(function(x) {
    return '<tr>' +
      '<td class="order-no"><b>' + escHtml(x.hazard_no) + '</b></td>' +
      '<td>' + escHtml(x.location) + '</td>' +
      '<td><span class="tag ' + (sm[x.severity] || '') + '">' + escHtml(x.severity) + '</span></td>' +
      '<td>' + escHtml(x.responsible_name || '-') + '</td>' +
      '<td><span class="tag t-done">已闭环</span></td>' +
      '<td style="font-size:12px">' + escHtml(x.deadline || '-') + '</td>' +
      '<td><button class="btn btn-sm btn-p" onclick="showHazardDetail(' + x.id + ')">详情</button></td>' +
    '</tr>';
  }).join('');

  el.innerHTML = '<table>' +
    '<tr><th>编号</th><th>地点</th><th>程度</th><th>整改人</th><th>状态</th><th>期限</th><th>操作</th></tr>' +
    rows +
  '</table>';
}

// ==================== 全局浮动按钮弹窗（只展示，无操作按钮） ====================
var _bulletinTab = 'hazard';
var _bulletinHazards = [];
var _bulletinAssessments = [];

function showBulletinBoard() {
  _bulletinTab = 'hazard';
  Promise.all([
    api('/hazards/list'),
    api('/safety/assessments')
  ]).then(function(results) {
    _bulletinHazards = results[0] || [];
    _bulletinAssessments = results[1] || [];
    renderBulletinModal(true);
  });
}

function switchBulletinTab(tab) {
  _bulletinTab = tab;
  renderBulletinModal(false);
}

function renderBulletinModal(createNew) {
  var st = { reported: '待指派', assigned: '已指派', rectifying: '整改中', completed: '待确认', verified: '已闭环' };
  var sm = { '低': 't-done', '一般': 't-pending', '高': 't-reject', '紧急': 't-reject' };
  var typeColors = { '表扬': 't-done', '通报': 't-pending', '警告': 't-reject', '处罚': 't-reject' };

  var tabHazardClass = 'tab' + (_bulletinTab === 'hazard' ? ' active' : '');
  var tabAssessClass = 'tab' + (_bulletinTab === 'assess' ? ' active' : '');
  var tabClosedClass = 'tab' + (_bulletinTab === 'closed' ? ' active' : '');

  var rows = '';
  if (_bulletinTab === 'closed') {
    var closedData = _bulletinHazards.filter(function(h) { return h.status === 'verified'; });
    if (!closedData.length) {
      rows = '<div class="empty">暂无已闭环记录</div>';
    } else {
      rows = '<table><tr><th>编号</th><th>地点</th><th>程度</th><th>整改人</th><th>状态</th><th>期限</th><th>描述</th></tr>' +
        closedData.map(function(x) {
          return '<tr>' +
            '<td class="order-no"><b>' + escHtml(x.hazard_no) + '</b></td>' +
            '<td>' + escHtml(x.location) + '</td>' +
            '<td><span class="tag ' + (sm[x.severity] || '') + '">' + escHtml(x.severity) + '</span></td>' +
            '<td>' + escHtml(x.responsible_name || '-') + '</td>' +
            '<td><span class="tag t-done">已闭环</span></td>' +
            '<td style="font-size:12px">' + escHtml(x.deadline || '-') + '</td>' +
            '<td style="font-size:12px;max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + escHtml((x.description||'').substring(0, 40)) + '</td>' +
          '</tr>';
        }).join('') + '</table>';
    }
  } else if (_bulletinTab === 'hazard') {
    if (!_bulletinHazards.length) {
      rows = '<div class="empty">暂无隐患记录</div>';
    } else {
      rows = '<table><tr><th>编号</th><th>地点</th><th>程度</th><th>整改人</th><th>状态</th><th>期限</th><th>描述</th></tr>' +
        _bulletinHazards.map(function(x) {
          var statusTag = x.status === 'verified' ? 't-done' : (x.status === 'completed' ? 't-pending' : 't-progress');
          return '<tr>' +
            '<td class="order-no"><b>' + escHtml(x.hazard_no) + '</b></td>' +
            '<td>' + escHtml(x.location) + '</td>' +
            '<td><span class="tag ' + (sm[x.severity] || '') + '">' + escHtml(x.severity) + '</span></td>' +
            '<td>' + escHtml(x.responsible_name || '-') + '</td>' +
            '<td><span class="tag ' + statusTag + '">' + escHtml(st[x.status] || x.status) + '</span></td>' +
            '<td style="font-size:12px">' + escHtml(x.deadline || '-') + '</td>' +
            '<td style="font-size:12px;max-width:160px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">' + escHtml((x.description||'').substring(0, 40)) + '</td>' +
          '</tr>';
        }).join('') + '</table>';
    }
  } else {
    if (!_bulletinAssessments.length) {
      rows = '<div class="empty">暂无通报记录</div>';
    } else {
      rows = '<table><tr><th>编号</th><th>标题</th><th>被考核人</th><th>类型</th><th>下发人</th><th>日期</th></tr>' +
        _bulletinAssessments.map(function(x) {
          return '<tr>' +
            '<td class="order-no"><b>' + escHtml(x.assess_no) + '</b></td>' +
            '<td>' + escHtml(x.title) + '</td>' +
            '<td>' + escHtml(x.target_name || '-') + '</td>' +
            '<td><span class="tag ' + (typeColors[x.assess_type] || '') + '">' + escHtml(x.assess_type) + '</span></td>' +
            '<td>' + escHtml(x.issuer_name || '-') + '</td>' +
            '<td style="font-size:12px">' + escHtml((x.created_at||'').slice(0,10)) + '</td>' +
          '</tr>';
        }).join('') + '</table>';
    }
  }

  var content = '<div class="tabs" style="margin-bottom:12px">' +
    '<button class="' + tabHazardClass + '" id="btnBulletinHz" onclick="switchBulletinTab(\'hazard\')">' + HZ_ICON + ' 隐患</button>' +
    '<button class="' + tabAssessClass + '" id="btnBulletinKp" onclick="switchBulletinTab(\'assess\')">' + KP_ICON + ' 通报</button>' +
    '<button class="' + tabClosedClass + '" id="btnBulletinCl" onclick="switchBulletinTab(\'closed\')">' + OK_ICON + ' 已闭环</button>' +
  '</div>' +
  '<div id="bulletinTableWrap">' + rows + '</div>';

  if (createNew) {
    // Remove old bulletin modal if exists
    var old = document.querySelector('.bulletin-mask');
    if (old) old.remove();
    // Manually build modal for tab switching support
    var mask = document.createElement('div');
    mask.className = 'modal-mask bulletin-mask';
    mask.style.cssText = 'position:fixed;top:0;left:0;right:0;bottom:0;background:rgba(0,0,0,.6);z-index:1000;display:flex;align-items:center;justify-content:center';
    mask.onclick = function(e) { if (e.target === mask) mask.remove(); };
    var box = document.createElement('div');
    box.style.cssText = 'background:var(--surface);border:1px solid var(--border);border-radius:12px;padding:20px;max-width:900px;width:95%;max-height:85vh;overflow-y:auto;box-shadow:0 8px 32px rgba(0,0,0,.4)';
    var title = document.createElement('div');
    title.style.cssText = 'display:flex;justify-content:space-between;align-items:center;margin-bottom:14px;font-size:16px;font-weight:700';
    title.innerHTML = '<span>' + HZ_ICON + KP_ICON + ' 隐患通报列表</span><button class="btn" onclick="this.closest(\'.modal-mask\').remove()" style="padding:4px 12px">✕</button>';
    box.appendChild(title);
    var body = document.createElement('div');
    body.className = 'bulletin-modal-body';
    body.innerHTML = content;
    box.appendChild(body);
    mask.appendChild(box);
    document.body.appendChild(mask);
  } else {
    // Update existing modal in-place
    var body = document.querySelector('.bulletin-modal-body');
    if (body) body.innerHTML = content;
  }
}

// 所有页面底部添加隐患通报浮动按钮
(function() {
  window.addEventListener('load', function() {
    setTimeout(function() {
      if (document.getElementById('hazardFloatBtn')) return;
      var btn = document.createElement('div');
      btn.id = 'hazardFloatBtn';
      btn.innerHTML = triIcon('var(--warning)');
      btn.title = '隐患通报列表';
      btn.style.cssText = 'position:fixed;bottom:20px;right:20px;width:44px;height:44px;background:var(--surface);border:2px solid var(--warning);border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:20px;cursor:pointer;z-index:99;box-shadow:0 0 12px rgba(212,160,23,.3)';
      btn.onclick = showBulletinBoard;
      document.body.appendChild(btn);
    }, 500);
  });
})();

// ==================== 考核通报 ====================
function showAssessmentForm() {
  api('/inspection/all-users').then(function(users) {
    var uOpts = users.map(function(u) { return '<option value="' + u.id + '">' + u.name + '（' + (ROLE_MAP[u.role] || u.role) + '）</option>'; }).join('');
    // 重置照片数组
    window._assessPhotoUrls = [];
    showModal('📋 下发考核通报', [
      '<div class="form-group"><label>被考核人</label><select id="assessTarget">' + uOpts + '</select></div>',
      '<div class="form-group"><label>考核类型</label><select id="assessType"><option value="表扬">表扬</option><option value="通报" selected>通报</option><option value="警告">警告</option><option value="处罚">处罚</option></select></div>',
      '<div class="form-group"><label>标题</label><input id="assessTitle" placeholder="如：6月安全隐患排查表扬" /></div>',
      '<div class="form-group"><label>内容</label><textarea id="assessContent" placeholder="请详细描述考核内容..."></textarea></div>',
      '<div class="form-group"><label>相关照片</label><div id="assessPhotoPreview" style="display:flex;gap:4px;flex-wrap:wrap;margin-bottom:8px"></div><button class="btn btn-o btn-sm" onclick="pickAssessPhoto()" style="width:100%">📷 选择照片</button></div>'
    ].join(''), async function(mask) {
      var tid = +document.getElementById('assessTarget').value;
      var tp = document.getElementById('assessType').value;
      var tl = document.getElementById('assessTitle').value.trim();
      var ct = document.getElementById('assessContent').value.trim();
      if (!tid) { alert('请选择被考核人'); return false; }
      if (!tl) { alert('请填写标题'); return false; }
      await api('/safety/assessment', { method: 'POST', data: { target_id: tid, title: tl, content: ct, assess_type: tp, photos: window._assessPhotoUrls || [] } });
      toast('通报已下发'); mask.remove(); if (typeof renderPage === 'function') renderPage();
    });
  });
}
function pickAssessPhoto() {
  var inp = document.createElement('input'); inp.type = 'file'; inp.accept = 'image/*'; inp.multiple = true;
  inp.onchange = async function() {
    if (!inp.files.length) return;
    for (var i = 0; i < inp.files.length; i++) {
      var fd = new FormData(); fd.append('file', inp.files[i]);
      try {
        var r = await fetch('/api/upload/single', { method: 'POST', headers: { 'Authorization': 'Bearer ' + TOKEN }, body: fd });
        var d = await r.json();
        if (d.code === 200) {
          window._assessPhotoUrls = window._assessPhotoUrls || [];
          window._assessPhotoUrls.push(d.data.url);
          var preview = document.getElementById('assessPhotoPreview');
          if (preview) {
            var img = document.createElement('img');
            img.src = d.data.url; img.style.cssText = 'width:60px;height:60px;object-fit:cover;border-radius:4px;border:1px solid var(--border)';
            preview.appendChild(img);
          }
        }
      } catch(e) {}
    }
  };
  inp.click();
}

function showAssessmentList() {
  api('/safety/assessments').then(function(data) {
    if (!data || !data.length) return alert('暂无考核记录');
    var typeColors = { '表扬': 't-done', '通报': 't-pending', '警告': 't-reject', '处罚': 't-reject' };
    var rows = data.map(function(x) {
      return '<tr><td class="order-no"><b>' + escHtml(x.assess_no) + '</b></td><td>' + escHtml(x.target_name) + '</td><td>' + escHtml(x.issuer_name) + '</td><td>' + escHtml(x.title) + '</td><td><span class="tag ' + (typeColors[x.assess_type] || '') + '">' + escHtml(x.assess_type) + '</span></td><td>' + escHtml(x.created_at.slice(0,10)) + '</td><td><button class="btn btn-sm btn-p" onclick="showAssessmentDetail(' + x.id + ')">详情</button></td></tr>';
    }).join('');
    showModal('📋 考核通报', '<table><tr><th>编号</th><th>被考核人</th><th>下发人</th><th>标题</th><th>类型</th><th>日期</th><th>操作</th></tr>' + rows + '</table>');
  });
}

async function showAssessmentDetail(id) {
  var d = await api('/safety/assessment/' + id);
  if (!d) return;
  var h = '<div><b>编号：</b>' + escHtml(d.assess_no) + ' | <b>类型：</b>' + escHtml(d.assess_type) + '</div>';
  h += '<div><b>标题：</b>' + escHtml(d.title) + '</div>';
  h += '<div><b>被考核人：</b>' + escHtml(d.target_name) + '</div>';
  h += '<div><b>下发人：</b>' + escHtml(d.issuer_name) + ' | <b>日期：</b>' + escHtml(d.created_at.slice(0,10)) + '</div>';
  h += '<div style="margin-top:8px;padding:10px;background:var(--surface2);border-radius:6px"><b>内容：</b><br>' + escHtml(d.content || '无') + '</div>';
  // 相关照片
  var assessImgs = []; try { assessImgs = JSON.parse(d.photos || '[]'); } catch(e) {}
  if (assessImgs.length) {
    h += '<div style="margin-top:8px"><b>📸 相关照片：</b></div><div style="display:flex;gap:4px;flex-wrap:wrap;margin-top:4px">';
    assessImgs.forEach(function(u) {
      h += '<img src="' + u + '" style="width:70px;height:70px;object-fit:cover;border-radius:4px;cursor:pointer;border:1px solid var(--border)" onclick="event.stopPropagation();showFaultPhotos(' + JSON.stringify(assessImgs) + ',' + assessImgs.indexOf(u) + ')" />';
    });
    h += '</div>';
  }
  showModal('📋 考核详情', h);
}
