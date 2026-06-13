// ==================== 在编车辆档案模块 ====================

// 档案列表（卡片网格）
async function showVehicleArchiveList() {
  var res = await api('/vehicle-archives/list');
  var list = res.data || [];
  if (!list.length) {
    showModal('在编车辆档案',
      '<div class="empty" style="padding:40px;text-align:center">暂无在编车辆档案</div>' +
      ((USER.role === 'admin' || USER.role === 'dispatcher')
        ? '<div style="text-align:center;margin-top:12px"><button class="btn btn-p" onclick="showVehicleArchiveForm()">+ 添加车辆档案</button></div>'
        : '')
    );
    return;
  }

  var cards = '';
  list.forEach(function(v) {
    var photos = [];
    try { photos = JSON.parse(v.photos || '[]'); } catch(e) { photos = []; }
    var thumb = photos.length > 0
      ? '<img src="' + photos[0] + '" style="width:100%;height:140px;object-fit:cover;border-radius:8px 8px 0 0" />'
      : '<div style="width:100%;height:140px;background:var(--surface2);border-radius:8px 8px 0 0;display:flex;align-items:center;justify-content:center;font-size:40px;color:var(--border)">🚛</div>';

    var curH = Number(v.current_hours) || 0;
    var next = Number(v.next_maintenance_hours) || 0;
    var remain = curH && next ? next - curH : 999;
    var maintSt, maintCls;
    if (!next) { maintSt = '未设置'; maintCls = 't-done'; }
    else if (remain < 0) { maintSt = '保养过期'; maintCls = 't-reject'; }
    else if (remain <= 50) { maintSt = '即将保养'; maintCls = 't-pending'; }
    else { maintSt = '正常'; maintCls = 't-done'; }

    // 公里保养状态
    var curKm = Number(v.current_km) || 0;
    var nextKm = Number(v.next_maintenance_km) || 0;
    var remainKm = curKm && nextKm ? nextKm - curKm : 999;
    var kmSt = '';
    if (nextKm > 0) {
      kmSt = remainKm < 0 ? ' <span class="tag t-reject" style="font-size:10px">km过期</span>' :
             remainKm <= 500 ? ' <span class="tag t-pending" style="font-size:10px">km即将</span>' : '';
    }

    // 底部显示：工时或公里（优先显示设置了保养的那个）
    var bottomInfo = '';
    if (next > 0) {
      bottomInfo = '<span style="color:var(--text2)">工时: ' + curH + 'h</span><span class="tag ' + maintCls + '">' + maintSt + '</span>';
    }
    if (nextKm > 0) {
      bottomInfo = (bottomInfo ? bottomInfo + ' ' : '') + '<span style="color:var(--text2)">km: ' + curKm + '</span>' + kmSt;
    }
    if (!bottomInfo) {
      bottomInfo = '<span style="color:var(--text2)">工时: ' + curH + 'h</span><span class="tag t-done">未设置</span>';
    }

    cards += '<div class="card" style="padding:0;cursor:pointer;overflow:hidden;transition:transform .2s" onmouseenter="this.style.transform=\'translateY(-4px)\'" onmouseleave="this.style.transform=\'\'" onclick="showVehicleArchiveDetail(\'' + v.plate_number + '\')">' +
      thumb +
      '<div style="padding:14px">' +
        '<div style="display:flex;justify-content:space-between;align-items:center"><span style="font-size:18px;font-weight:700;color:var(--text)">' + v.plate_number + '</span>' + (v.department && v.department !== '总调度室' ? '<span style="font-size:10px;background:#f0f0f0;color:#666;padding:2px 6px;border-radius:4px">' + v.department + '</span>' : '') + '</div>' +
        '<div style="font-size:13px;color:var(--text2);margin-top:4px">' + (v.vehicle_type || '-') + ' / ' + (v.model || '-') + '</div>' +
        '<div style="display:flex;justify-content:space-between;align-items:center;margin-top:10px;font-size:12px">' +
          bottomInfo +
        '</div>' +
        (v.driver_name ? '<div style="font-size:11px;color:var(--text2);margin-top:4px">驾驶员: ' + v.driver_name + '</div>' : '') +
      '</div></div>';
  });

  var addBtn = (USER.role === 'admin' || USER.role === 'dispatcher')
    ? '<div style="margin-bottom:16px"><button class="btn btn-p" onclick="showVehicleArchiveForm()">+ 添加车辆档案</button></div>'
    : '';

  showModal('在编车辆档案 (' + list.length + '辆)',
    addBtn + '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:16px;max-height:70vh;overflow:auto">' + cards + '</div>'
  );
}

// 车辆详情（全屏弹窗，顶部照片轮播）
function showVehicleArchiveDetail(plate) {
  api('/vehicle-archives/' + plate).then(function(res) {
    var v = res.data;
    if (!v) { toast('档案不存在'); return; }

    var photos = [];
    try { photos = JSON.parse(v.photos || '[]'); } catch(e) { photos = []; }

    // 照片轮播HTML
    var photoHtml = '';
    if (photos.length > 0) {
      photoHtml = '<div id="vaDetailPhotos" style="position:relative;width:100%;height:300px;background:#000;overflow:hidden;border-radius:12px;margin-bottom:20px">' +
        photos.map(function(url, i) {
          return '<img src="' + url + '" style="position:absolute;inset:0;width:100%;height:100%;object-fit:contain;transition:opacity .3s;opacity:' + (i === 0 ? '1' : '0') + ';pointer-events:' + (i === 0 ? 'auto' : 'none') + '" data-va-idx="' + i + '" />';
        }).join('') +
        (photos.length > 1
          ? '<div style="position:absolute;bottom:12px;left:50%;transform:translateX(-50%);display:flex;gap:6px;z-index:2">' +
              photos.map(function(_, i) {
                return '<span class="va-dot" style="width:8px;height:8px;border-radius:50%;background:' + (i === 0 ? '#fff' : 'rgba(255,255,255,.4)') + ';cursor:pointer" onclick="event.stopPropagation();vaSlideTo(' + i + ')"></span>';
              }).join('') +
            '</div>' +
            '<div style="position:absolute;top:50%;left:8px;transform:translateY(-50%);z-index:2;font-size:28px;color:#fff;cursor:pointer;background:rgba(0,0,0,.5);width:36px;height:36px;border-radius:50%;display:flex;align-items:center;justify-content:center" onclick="event.stopPropagation();vaSlide(-1)">‹</div>' +
            '<div style="position:absolute;top:50%;right:8px;transform:translateY(-50%);z-index:2;font-size:28px;color:#fff;cursor:pointer;background:rgba(0,0,0,.5);width:36px;height:36px;border-radius:50%;display:flex;align-items:center;justify-content:center" onclick="event.stopPropagation();vaSlide(1)">›</div>'
          : '') +
        '</div>';
    } else {
      photoHtml = '<div style="width:100%;height:200px;background:var(--surface2);border-radius:12px;display:flex;align-items:center;justify-content:center;font-size:48px;color:var(--border);margin-bottom:20px">🚛 暂无外观照片</div>';
    }

    var curH = Number(v.current_hours) || 0;
    var next = Number(v.next_maintenance_hours) || 0;
    var remain = curH && next ? next - curH : 999;
    var maintSt = !next ? '未设置' : remain < 0 ? '保养过期' : remain <= 50 ? '即将保养' : '正常';
    var maintColor = !next ? 'var(--text2)' : remain < 0 ? 'var(--danger)' : remain <= 50 ? 'var(--warning)' : 'var(--success)';

    // 公里保养状态
    var curKm = Number(v.current_km) || 0;
    var nextKm = Number(v.next_maintenance_km) || 0;
    var remainKm = curKm && nextKm ? nextKm - curKm : 999;
    var kmSt = !nextKm ? '未设置' : remainKm < 0 ? '保养过期' : remainKm <= 500 ? '即将保养' : '正常';
    var kmColor = !nextKm ? 'var(--text2)' : remainKm < 0 ? 'var(--danger)' : remainKm <= 500 ? 'var(--warning)' : 'var(--success)';

    var rows = [
      ['内部编号', v.plate_number],
      ['所属部门', v.department || '总调度室'],
      ['类型', v.vehicle_type || '-'],
      ['具体型号', v.model || '-'],
      ['出厂日期', v.manufacture_date || '-'],
      ['购买日期', v.purchase_date || '-'],
      ['车辆识别代码(VIN)', v.vin || '-'],
      ['保险到期日', v.insurance_expiry || '-'],
      ['年检日期', v.inspection_date || '-'],
      ['保养间隔', (v.maintenance_interval || 500) + 'h'],
      ['下次保养工时', (v.next_maintenance_hours || 0) + 'h'],
      ['当前工时', curH + 'h <span style="color:' + maintColor + ';font-weight:600">(' + maintSt + ')</span>'],
      ['保养间隔(km)', (v.maintenance_interval_km || 0) + 'km'],
      ['下次保养公里', (v.next_maintenance_km || 0) + 'km'],
      ['当前公里', curKm + 'km <span style="color:' + kmColor + ';font-weight:600">(' + kmSt + ')</span>'],
      ['行为监控', v.has_behavior_monitor ? '有' : '无'],
      ['360环影', v.has_360_camera ? '有' : '无'],
      ['当前驾驶员', v.driver_name || '无'],
      ['车辆状态', v.vehicle_status === 'repairing' ? '<span style="color:var(--warning)">维修中</span>' : '<span style="color:var(--success)">正常</span>']
    ];

    var infoTable = '<table style="width:100%">' +
      rows.map(function(r) {
        return '<tr><td style="padding:10px 14px;border-bottom:1px solid var(--border);color:var(--text2);font-size:14px;white-space:nowrap;width:140px">' + r[0] + '</td><td style="padding:10px 14px;border-bottom:1px solid var(--border);color:var(--text);font-size:15px">' + r[1] + '</td></tr>';
      }).join('') +
      '</table>';

    var btns = '';
    if (USER.role === 'admin' || USER.role === 'dispatcher') {
      btns += '<button class="btn btn-p btn-sm" style="margin-right:8px" onclick="showVehicleArchiveForm(\'' + v.plate_number + '\')">编辑</button>';
      if (v.maintenance_interval > 0) {
        btns += '<button class="btn btn-s btn-sm" style="margin-right:8px" onclick="maintenanceDoneVehicle(\'' + v.plate_number + '\')">已保养 (+' + (v.maintenance_interval || 500) + 'h)</button>';
      }
      if (v.maintenance_interval_km > 0) {
        btns += '<button class="btn btn-s btn-sm" style="margin-right:8px" onclick="maintenanceDoneVehicleKm(\'' + v.plate_number + '\')">已保养 (+' + (v.maintenance_interval_km || 10000) + 'km)</button>';
      }
    }
    btns += '<button class="btn btn-sm btn-o" onclick="showVehicleArchiveList()">返回列表</button>';

    var html = '<div style="max-width:800px;margin:0 auto">' +
      photoHtml +
      infoTable +
      '<div style="margin-top:20px;text-align:center">' + btns + '</div>' +
      '</div>';

    showModal(v.plate_number + ' — 车辆档案详情', html);

    // 存储当前照片数据供滑动使用
    window._vaPhotos = photos;
  });
}

// 照片滑动
function vaSlide(dir) {
  var photos = window._vaPhotos || [];
  if (!photos.length) return;
  var imgs = document.querySelectorAll('#vaDetailPhotos img');
  var current = 0;
  imgs.forEach(function(img, i) {
    if (img.style.opacity === '1') current = i;
  });
  var next = (current + dir + photos.length) % photos.length;
  vaSlideTo(next);
}
function vaSlideTo(idx) {
  var imgs = document.querySelectorAll('#vaDetailPhotos img');
  var dots = document.querySelectorAll('.va-dot');
  imgs.forEach(function(img, i) {
    img.style.opacity = i === idx ? '1' : '0';
    img.style.pointerEvents = i === idx ? 'auto' : 'none';
  });
  dots.forEach(function(d, i) {
    d.style.background = i === idx ? '#fff' : 'rgba(255,255,255,.4)';
  });
}

// 录入/编辑表单
function showVehicleArchiveForm(plate) {
  var isEdit = !!plate;
  var title = isEdit ? '编辑车辆档案 — ' + plate : '添加在编车辆档案';

  if (isEdit) {
    api('/vehicle-archives/' + plate).then(function(res) {
      var v = res.data;
      if (!v) { toast('档案不存在'); return; }
      renderForm(title, v);
    });
  } else {
    renderForm(title, null);
  }
}

function renderForm(title, v) {
  var isEdit = !!v;
  var plateDisabled = isEdit ? 'disabled' : '';
  var plateVal = isEdit ? v.plate_number : '';
  var deptVal = isEdit ? (v.department || '总调度室') : '总调度室';
  var typeVal = isEdit ? (v.vehicle_type || '') : '';
  var modelVal = isEdit ? (v.model || '') : '';
  var pdateVal = isEdit ? (v.purchase_date || '') : '';
  var mdateVal = isEdit ? (v.manufacture_date || '') : '';
  var vinVal = isEdit ? (v.vin || '') : '';
  var insVal = isEdit ? (v.insurance_expiry || '') : '';
  var inspVal = isEdit ? (v.inspection_date || '') : '';
  var intervVal = isEdit ? (v.maintenance_interval || 500) : 500;
  var nextVal = isEdit ? (v.next_maintenance_hours || 0) : 0;
  var intervKmVal = isEdit ? (v.maintenance_interval_km || 0) : 0;
  var nextKmVal = isEdit ? (v.next_maintenance_km || 0) : 0;
  var curKmVal = isEdit ? (v.current_km || 0) : 0;
  var deptZS = deptVal === '总调度室' ? 'selected' : '';
  var deptHJ = deptVal === '西藏恒骏' ? 'selected' : '';
  var bmYes = isEdit && v.has_behavior_monitor ? 'selected' : '';
  var bmNo = isEdit && !v.has_behavior_monitor ? 'selected' : '';
  var camYes = isEdit && v.has_360_camera ? 'selected' : '';
  var camNo = isEdit && !v.has_360_camera ? 'selected' : '';

  // 当前照片预览
  var photos = [];
  try { if (isEdit) photos = JSON.parse(v.photos || '[]'); } catch(e) { photos = []; }
  var photoPreviewHtml = '<div id="vaPhotoPreview" style="display:flex;gap:8px;flex-wrap:wrap;margin-top:8px">' +
    photos.map(function(url) {
      return '<div style="position:relative"><img src="' + url + '" style="width:80px;height:80px;object-fit:cover;border-radius:6px" /><span style="position:absolute;top:-6px;right:-6px;background:var(--danger);color:#fff;width:20px;height:20px;border-radius:50%;display:flex;align-items:center;justify-content:center;cursor:pointer;font-size:12px" onclick="vaRemovePhoto(\'' + url + '\')">✕</span></div>';
    }).join('') +
    '</div>';

  var html =
    '<div class="form-group"><label>内部编号 <span style="color:var(--danger)">*</span></label><input id="vaPlate" value="' + plateVal + '" ' + plateDisabled + ' placeholder="如：矿A-001" /></div>' +
    '<div class="form-group"><label>所属部门 <span style="color:var(--danger)">*</span></label><select id="vaDept"><option value="总调度室" ' + deptZS + '>总调度室</option><option value="西藏恒骏" ' + deptHJ + '>西藏恒骏</option></select></div>' +
    '<div class="row2"><div class="form-group"><label>类型</label><input id="vaType" value="' + typeVal + '" placeholder="如：履带挖掘机" /></div><div class="form-group"><label>具体型号</label><input id="vaModel" value="' + modelVal + '" placeholder="如：CAT 390D" /></div></div>' +
    '<div class="row2"><div class="form-group"><label>出厂日期</label><input id="vaMdate" type="date" value="' + mdateVal + '" /></div><div class="form-group"><label>购买日期</label><input id="vaPdate" type="date" value="' + pdateVal + '" /></div></div>' +
    '<div class="row2"><div class="form-group"><label>车辆识别代码(VIN)</label><input id="vaVin" value="' + vinVal + '" placeholder="VIN码" /></div><div class="form-group"><label>保险到期日</label><input id="vaIns" type="date" value="' + insVal + '" /></div></div>' +
    '<div class="form-group"><label>年检日期</label><input id="vaInsp" type="date" value="' + inspVal + '" /></div>' +
    '<div class="row2"><div class="form-group"><label>保养间隔(h)</label><input id="vaInterval" type="number" value="' + intervVal + '" /></div><div class="form-group"><label>下次保养工时(h)</label><input id="vaNextMaint" type="number" value="' + nextVal + '" /></div></div>' +
    '<div class="form-group" style="font-size:11px;color:var(--text2);margin-bottom:4px">📐 公里保养（汽车吊/吊车等按里程保养的车辆填写）</div>' +
    '<div class="row2"><div class="form-group"><label>保养间隔(km)</label><input id="vaIntervalKm" type="number" value="' + intervKmVal + '" placeholder="如：10000" /></div><div class="form-group"><label>下次保养公里(km)</label><input id="vaNextMaintKm" type="number" value="' + nextKmVal + '" /></div></div>' +
    '<div class="row2"><div class="form-group"><label>当前公里数(km)</label><input id="vaCurKm" type="number" value="' + curKmVal + '" /></div><div class="form-group"></div></div>' +
    '<div class="row2">' +
      '<div class="form-group"><label>行为监控</label><select id="vaBM"><option value="1" ' + bmYes + '>有</option><option value="0" ' + bmNo + '>无</option></select></div>' +
      '<div class="form-group"><label>360环影</label><select id="vaCam"><option value="1" ' + camYes + '>有</option><option value="0" ' + camNo + '>无</option></select></div>' +
    '</div>' +
    '<div class="form-group"><label>车辆外观照片</label>' +
      '<button class="btn btn-sm btn-o" onclick="vaPickPhotos()">📷 选择照片</button>' +
      photoPreviewHtml +
    '</div>';

  showModal(title, html, async function(mask) {
    var plateNumber = document.getElementById('vaPlate').value.trim();
    if (!plateNumber) { toast('请输入内部编号'); return; }

    var data = {
      department: document.getElementById('vaDept').value,
      vehicle_type: document.getElementById('vaType').value.trim(),
      model: document.getElementById('vaModel').value.trim(),
      manufacture_date: document.getElementById('vaMdate').value,
      purchase_date: document.getElementById('vaPdate').value,
      vin: document.getElementById('vaVin').value.trim(),
      insurance_expiry: document.getElementById('vaIns').value,
      inspection_date: document.getElementById('vaInsp').value,
      maintenance_interval: parseInt(document.getElementById('vaInterval').value) || 500,
      next_maintenance_hours: parseInt(document.getElementById('vaNextMaint').value) || 0,
      maintenance_interval_km: parseInt(document.getElementById('vaIntervalKm').value) || 0,
      next_maintenance_km: parseInt(document.getElementById('vaNextMaintKm').value) || 0,
      current_km: parseInt(document.getElementById('vaCurKm').value) || 0,
      has_behavior_monitor: document.getElementById('vaBM').value === '1',
      has_360_camera: document.getElementById('vaCam').value === '1',
      photos: window._vaNewPhotos || []
    };

    if (isEdit) {
      var res = await api('/vehicle-archives/' + plate, { method: 'PUT', data: data });
      if (res && res.code === 200) {
        toast('更新成功');
        mask.remove();
        showVehicleArchiveDetail(plateNumber);
      } else {
        toast(res && res.msg || '更新失败');
      }
    } else {
      data.plate_number = plateNumber;
      var res = await api('/vehicle-archives', { method: 'POST', data: data });
      if (res && res.code === 200) {
        toast('车辆档案已创建');
        mask.remove();
        showVehicleArchiveList();
      } else {
        toast(res && res.msg || '创建失败');
      }
    }
  });

  // 初始化照片数组
  window._vaNewPhotos = photos.slice();
}

// 选择照片（用于档案表单）
function vaPickPhotos() {
  window.pickPhotos(function(urls) {
    window._vaNewPhotos = (window._vaNewPhotos || []).concat(urls);
    var container = document.getElementById('vaPhotoPreview');
    if (!container) return;
    urls.forEach(function(url) {
      var div = document.createElement('div');
      div.style.position = 'relative';
      div.innerHTML = '<img src="' + url + '" style="width:80px;height:80px;object-fit:cover;border-radius:6px" /><span style="position:absolute;top:-6px;right:-6px;background:var(--danger);color:#fff;width:20px;height:20px;border-radius:50%;display:flex;align-items:center;justify-content:center;cursor:pointer;font-size:12px" onclick="vaRemovePhoto(\'' + url + '\')">✕</span>';
      container.appendChild(div);
    });
  });
}

// 移除照片
function vaRemovePhoto(url) {
  window._vaNewPhotos = (window._vaNewPhotos || []).filter(function(u) { return u !== url; });
  var container = document.getElementById('vaPhotoPreview');
  if (!container) return;
  var imgs = container.querySelectorAll('img');
  imgs.forEach(function(img) {
    if (img.src === url) {
      var wrapper = img.parentElement;
      if (wrapper) wrapper.remove();
    }
  });
}

// 保养完成（工时）
async function maintenanceDoneVehicle(plate) {
  if (!confirm('确认车辆 "' + plate + '" 已完成保养？\n下次保养工时将自动增加保养间隔。')) return;
  var res = await api('/vehicle-archives/' + plate + '/maintenance-done', { method: 'POST' });
  if (res && res.code === 200) {
    toast(res.msg);
    document.querySelectorAll('.modal-mask').forEach(function(m) { m.remove(); });
    showVehicleArchiveDetail(plate);
  } else {
    toast(res && res.msg || '操作失败');
  }
}

// 保养完成（公里）
async function maintenanceDoneVehicleKm(plate) {
  if (!confirm('确认车辆 "' + plate + '" 已完成公里保养？\n下次保养公里将自动增加保养间隔。')) return;
  var res = await api('/vehicle-archives/' + plate + '/maintenance-done-km', { method: 'POST' });
  if (res && res.code === 200) {
    toast(res.msg);
    document.querySelectorAll('.modal-mask').forEach(function(m) { m.remove(); });
    showVehicleArchiveDetail(plate);
  } else {
    toast(res && res.msg || '操作失败');
  }
}
