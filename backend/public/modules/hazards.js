// ⚠ 隐患闭环模块 - 独立文件
// HTML 转义 — 防止 XSS
function escHtml(s) {
  if (s == null) return '';
  return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;').replace(/'/g, '&#x27;');
}
function showHazardReport() {
  api('/inspection/all-users').then(function(users) {
    window._hzPhotoUrls = []; // photos.js 共用数组，重置
    var uOpts = users.map(function(u) { return '<option value="' + u.id + '">' + u.name + '（' + (ROLE_MAP[u.role] || u.role) + '）</option>'; }).join('');
    showModal('⚠ 隐患上报', [
      '<div class="form-group"><label>隐患地点</label><input id="hzLocation" /></div>',
      '<div class="form-group"><label>严重程度</label><select id="hzSeverity"><option value="低">低</option><option value="一般" selected>一般</option><option value="高">高</option><option value="紧急">紧急</option></select></div>',
      '<div class="form-group"><label>指定整改人</label><select id="hzResponsible"><option value="">暂不指定</option>' + uOpts + '</select></div>',
      '<div class="form-group"><label>整改期限</label><input id="hzDeadline" type="date" /></div>',
      '<div class="form-group"><label>隐患描述</label><textarea id="hzDesc" placeholder="请详细描述隐患..."></textarea></div>',
      '<div class="form-group">',
        '<label>📸 隐患照片</label>',
        '<div id="hzPhotoPreview" style="display:flex;gap:4px;flex-wrap:wrap;margin:6px 0"></div>',
        '<button type="button" class="btn btn-o btn-sm" id="hzPhotoBtn" style="width:100%">📷 选择照片 / 拍照</button>',
      '</div>'
    ].join(''), async function(mask) {
      var loc = document.getElementById('hzLocation').value.trim();
      var sv = document.getElementById('hzSeverity').value;
      var rid = +document.getElementById('hzResponsible').value || null;
      var dl = document.getElementById('hzDeadline').value;
      var desc = document.getElementById('hzDesc').value.trim();
      if (!desc) { alert('请填写隐患描述'); return false; }
      await api('/hazards/report', { method: 'POST', data: { location: loc, description: desc, severity: sv, responsible_id: rid, deadline: dl } });
      toast('上报成功'); mask.remove(); renderPage();
    });
    // 弹窗已创建，立即绑定照片按钮（不在 onOk 回调里，否则点确认才绑定）
    setTimeout(function() {
      var mask = document.querySelector('.modal-mask');
      if (!mask) return;
      var btn = mask.querySelector('#hzPhotoBtn');
      var preview = mask.querySelector('#hzPhotoPreview');
      if (btn) {
        btn.onclick = function(e) {
          e.preventDefault();
          window.pickPhotos(function(urls) {
            Array.prototype.push.apply(window._hzPhotoUrls, urls);
            preview.innerHTML = '';
            window._hzPhotoUrls.forEach(function(u) {
              var img = document.createElement('img');
              img.src = u;
              img.style.cssText = 'width:60px;height:60px;object-fit:cover;border-radius:4px;margin:2px;border:1px solid var(--border)';
              preview.appendChild(img);
            });
          });
        };
      }
    }, 50);
  });
}

function showHazardList() {
  var url = '/hazards/list';
  if (USER.role === 'driver') url += '?my=1';
  api(url).then(function(data) {
    if (!data || !data.length) return alert('暂无记录');
    var sm = { '低': 't-done', '一般': 't-pending', '高': 't-reject', '紧急': 't-reject' };
    var st = { reported: '待指派', assigned: '已指派', rectifying: '整改中', completed: '待确认', verified: '已闭环' };
    var rows = '';
    data.forEach(function(x) {
      rows += '<tr><td class="order-no"><b>' + escHtml(x.hazard_no) + '</b></td><td>' + escHtml(x.reporter_name) + '</td><td>' + escHtml(x.location) + '</td><td><span class="tag ' + (sm[x.severity] || '') + '">' + escHtml(x.severity) + '</span></td><td>' + escHtml(x.responsible_name) + '</td><td><span class="tag t-pending">' + escHtml(st[x.status] || x.status) + '</span></td><td>' + escHtml(x.deadline) + '</td><td><button class="btn btn-sm btn-p" onclick="showHazardDetail(' + x.id + ')">详情</button></td></tr>';
    });
    showModal('⚠ 隐患列表', '<table><tr><th>编号</th><th>上报人</th><th>地点</th><th>程度</th><th>整改人</th><th>状态</th><th>期限</th><th>操作</th></tr>' + rows + '</table>');
  });
}

async function showHazardDetail(id, context) {
  // 重置整改照片数组
  window._hzPhotoUrls = [];
  var d = await api('/hazards/detail/' + id);
  if (!d) return;
  var isBulletin = context === 'bulletin';
  var st = { reported: '待指派', assigned: '已指派', rectifying: '整改中', completed: '待确认', verified: '已闭环' };
  var h = '<div><b>编号：</b>' + escHtml(d.hazard_no) + ' | <b>状态：</b>' + escHtml(st[d.status] || d.status) + '</div>';
  h += '<div><b>上报人：</b>' + escHtml(d.reporter_name) + ' | <b>地点：</b>' + escHtml(d.location) + '</div>';
  h += '<div style="margin-top:8px"><b>描述：</b>' + escHtml(d.description) + '</div>';
  h += '<div><b>整改人：</b>' + escHtml(d.responsible_name || '未指定') + ' | <b>期限：</b>' + escHtml(d.deadline || '无') + '</div>';
  // 整改说明
  if (d.rectify_desc) {
    h += '<div style="margin-top:8px;padding:10px;background:rgba(90,158,95,.08);border-radius:6px"><b>📝 整改说明：</b>' + escHtml(d.rectify_desc) + '</div>';
  }
  // 驳回原因
  if (d.reject_reason) {
    h += '<div style="margin-top:8px;padding:10px;background:rgba(224,85,85,.08);border-radius:6px"><b>❌ 驳回原因：</b>' + escHtml(d.reject_reason) + '</div>';
  }
  // 整改前照片
  var beforeImgs = []; try { beforeImgs = JSON.parse(d.photos_before || '[]'); } catch(e) {}
  if (beforeImgs.length) {
    h += '<div style="margin-top:8px"><b>📸 整改前照片：</b></div><div class="hz-before-photos" style="display:flex;gap:4px;flex-wrap:wrap;margin-top:4px">';
    beforeImgs.forEach(function(u) {
      h += '<img src="' + u + '" style="width:70px;height:70px;object-fit:cover;border-radius:4px;cursor:pointer;border:1px solid var(--danger)" onclick="event.stopPropagation();showFaultPhotos(' + JSON.stringify(beforeImgs) + ',' + beforeImgs.indexOf(u) + ')" />';
    });
    h += '</div>';
  }
  // 整改后照片
  var afterImgs = []; try { afterImgs = JSON.parse(d.photos_after || '[]'); } catch(e) {}
  if (afterImgs.length) {
    h += '<div style="margin-top:8px"><b>✅ 整改后照片：</b></div><div class="hz-after-photos" style="display:flex;gap:4px;flex-wrap:wrap;margin-top:4px">';
    afterImgs.forEach(function(u) {
      h += '<img src="' + u + '" style="width:70px;height:70px;object-fit:cover;border-radius:4px;cursor:pointer;border:1px solid var(--success)" onclick="event.stopPropagation();showFaultPhotos(' + JSON.stringify(afterImgs) + ',' + afterImgs.indexOf(u) + ')" />';
    });
    h += '</div>';
  }
  // 整改人可见：整改后提交区域（内联表单）
  var isAssignedToMe = (d.status === 'assigned' || d.status === 'rectifying') && USER.id === d.responsible_id;
  if (isAssignedToMe && !isBulletin) {
    h += '<div style="margin-top:12px;padding:12px;background:rgba(90,158,95,.06);border:1px dashed var(--success);border-radius:8px" id="rectifyInline">';
    h += '<div style="font-weight:600;margin-bottom:8px">📝 提交整改</div>';
    h += '<div id="rectifyPhotoPreview" style="display:flex;gap:4px;flex-wrap:wrap;margin-bottom:8px"></div>';
    h += '<button class="btn btn-o btn-sm" onclick="window._hzPhotoUrls=[];pickHzRectifyPhoto()" style="width:100%;margin-bottom:8px">📷 添加整改后照片</button>';
    h += '<textarea id="rectifyDescInline" placeholder="请填写整改说明..." style="width:100%;min-height:60px;margin-bottom:8px;padding:8px;border:1px solid var(--border);border-radius:6px;font-size:13px;background:var(--bg);color:var(--text)"></textarea>';
    h += '<button class="btn btn-s" onclick="submitRectifyInline(' + id + ')" style="width:100%">✅ 提交整改</button>';
    h += '</div>';
  }
  var btns = '';
  var isSafety = USER.role === 'safety_officer' || USER.role === 'admin';
  // 公示栏纯展示
  if (!isBulletin) {
    if (d.status === 'reported') btns += '<button class="btn btn-p btn-sm" onclick="assignHazard(' + id + ')">指定整改人</button> ';
    // 整改人：提交整改（已改为内联表单，此处不再显示按钮）
    // 安全员/上报人：确认验收 or 驳回
    if (d.status === 'completed' && (isSafety || USER.id === d.reporter_id)) {
      btns += '<button class="btn btn-s btn-sm" onclick="verifyHazard(' + id + ')">✅ 确认验收</button> ';
      btns += '<button class="btn btn-d btn-sm" onclick="rejectRectifyHazard(' + id + ')">❌ 驳回</button> ';
    }
  }
  if (btns) h += '<div style="margin-top:12px;display:flex;gap:8px">' + btns + '</div>';
  showModal('隐患详情', h);
}

function assignHazard(id) {
  api('/inspection/all-users').then(function(users) {
    var o = users.map(function(u) { return '<option value="' + u.id + '">' + u.name + '（' + (ROLE_MAP[u.role] || u.role) + '）</option>'; }).join('');
    showModal('指派整改人', '<div class="form-group"><label>整改人</label><select id="hzAssRes">' + o + '</select></div><div class="form-group"><label>期限</label><input id="hzAssDL" type="date" /></div>', async function(mask) {
      var rid = +document.getElementById('hzAssRes').value;
      var dl = document.getElementById('hzAssDL').value;
      if (!rid) return alert('请选择');
      await api('/hazards/assign/' + id, { method: 'POST', data: { responsible_id: rid, deadline: dl } });
      toast('已指派'); mask.remove(); renderPage();
    });
  });
}

function rectifyHazard(id) {
  window._hzPhotoUrls = [];
  showModal('📸 提交整改', [
    '<div class="form-group"><label>整改后照片</label>',
    '<div id="rectifyPhotoPreview" style="display:flex;gap:4px;flex-wrap:wrap;margin-bottom:8px"></div>',
    '<button class="btn btn-o btn-sm" onclick="pickHzRectifyPhoto()" style="width:100%">📷 选择照片</button></div>',
    '<div class="form-group"><label>整改说明</label><textarea id="rectifyDescInput" placeholder="请描述整改内容和措施..."></textarea></div>'
  ].join(''), async function(mask) {
    var desc = document.getElementById('rectifyDescInput').value.trim();
    if (!desc) { alert('请填写整改说明'); return false; }
    await api('/hazards/rectify/' + id, { method: 'POST', data: { photos_after: window._hzPhotoUrls || [], rectify_desc: desc } });
    toast('整改已提交'); mask.remove(); renderPage();
  });
}
function pickHzRectifyPhoto() {
  var inp = document.createElement('input'); inp.type = 'file'; inp.accept = 'image/*'; inp.multiple = true;
  inp.onchange = async function() {
    if (!inp.files.length) return;
    for (var i = 0; i < inp.files.length; i++) {
      var fd = new FormData(); fd.append('file', inp.files[i]);
      try {
        var r = await fetch('/api/upload/single', { method: 'POST', headers: { 'Authorization': 'Bearer ' + TOKEN }, body: fd });
        var d = await r.json();
        if (d.code === 200) {
          window._hzPhotoUrls = window._hzPhotoUrls || [];
          window._hzPhotoUrls.push(d.data.url);
          var preview = document.getElementById('rectifyPhotoPreview');
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
// 内联提交整改（从详情页直接提交）
async function submitRectifyInline(id) {
  var desc = document.getElementById('rectifyDescInline').value.trim();
  if (!desc) { alert('请填写整改说明'); return; }
  await api('/hazards/rectify/' + id, { method: 'POST', data: { photos_after: window._hzPhotoUrls || [], rectify_desc: desc } });
  toast('整改已提交');
  // 关闭当前弹窗并刷新
  var mask = document.querySelector('.modal-mask');
  if (mask) mask.remove();
  if (typeof renderPage === 'function') renderPage();
}

async function verifyHazard(id) {
  if (!confirm('确认整改验收通过？')) return;
  await api('/hazards/verify/' + id, { method: 'POST' });
  toast('已验收通过'); renderPage();
}

function rejectRectifyHazard(id) {
  showModal('❌ 驳回整改', [
    '<div class="form-group"><label>驳回原因</label><textarea id="rejectReasonInput" placeholder="请说明驳回原因，整改人将看到此信息..."></textarea></div>'
  ].join(''), async function(mask) {
    var reason = document.getElementById('rejectReasonInput').value.trim();
    if (!reason) { alert('请填写驳回原因'); return false; }
    await api('/hazards/reject-rectify/' + id, { method: 'POST', data: { reject_reason: reason } });
    toast('已驳回'); mask.remove(); renderPage();
  });
}
