// ⚠ 天气预警模块 - 独立文件
// 依赖全局: api, showModal, toast, USER, ROLE_MAP, renderPage

var WEATHER_LABELS = {
  rainstorm: '暴雨', thunderstorm: '雷电', strong_wind: '大风',
  snowstorm: '暴雪', sandstorm: '沙尘暴', low_visibility: '大雾/低能见度'
};
var WEATHER_ICONS = {
  rainstorm: '🌧️', thunderstorm: '⛈️', strong_wind: '💨',
  snowstorm: '🌨️', sandstorm: '🌪️', low_visibility: '🌫️'
};
var LEVEL_COLORS = { red: 't-reject', orange: 't-pending', yellow: 't-pending', blue: 't-progress' };
var LEVEL_EMOJI = { red: '🔴', orange: '🟠', yellow: '🟡', blue: '🔵' };

// ==================== 仪表盘卡片 ====================

function showWeatherDashboard() {
  api('/weather/dashboard').then(function(d) {
    if (!d || !d.zones) return;
    var html = '<div class="card"><div class="card-title">🌤️ 矿区天气预警';
    if (USER.role === 'admin') {
      html += '<div><button class="btn btn-sm btn-o" onclick="showWeatherZones()">📋 区域管理</button> ';
      html += '<button class="btn btn-sm btn-o" onclick="showWeatherThresholds()">⚙ 阈值配置</button></div>';
    }
    html += '</div>';

    // 预警汇总
    if (d.summary && d.summary.totalActive > 0) {
      html += '<div class="stats-grid">';
      html += '<div class="stat-item" style="border-color:var(--danger)"><div class="stat-num" style="color:var(--danger)">' + d.summary.totalActive + '</div><div class="stat-label">活跃预警</div></div>';
      html += '<div class="stat-item" style="border-color:#e05555"><div class="stat-num" style="color:var(--danger)">' + (d.summary.redCount || 0) + '</div><div class="stat-label">🔴 红色预警</div></div>';
      html += '<div class="stat-item" style="border-color:#d4a017"><div class="stat-num" style="color:var(--warning)">' + (d.summary.orangeCount || 0) + '</div><div class="stat-label">🟠 橙色预警</div></div>';
      html += '</div>';
    }

    // 各区域卡片
    html += '<div style="display:grid;grid-template-columns:repeat(auto-fill,minmax(280px,1fr));gap:12px">';
    d.zones.forEach(function(z) {
      var borderColor = z.hasRedWarning ? 'var(--danger)' : (z.warningCount > 0 ? 'var(--warning)' : 'var(--border)');
      html += '<div class="card" style="border:2px solid ' + borderColor + ';cursor:pointer" onclick="showWeatherZoneDetail(' + z.zone.id + ')">';
      html += '<div style="font-weight:700;margin-bottom:6px">🏔️ ' + z.zone.zone_name + ' <span style="font-size:11px;color:var(--text2)">' + (z.zone.altitude || '') + '</span></div>';
      html += '<div style="font-size:10px;color:var(--text3);margin-bottom:4px">🧭 ' + (z.zone.latitude || '?') + ', ' + (z.zone.longitude || '?') + '</div>';

      // 最新天气数据 - 天气预报风格
      if (z.latestData && z.latestData.length) {
        var readings = {};
        z.latestData.forEach(function(d) { if (!readings[d.data_type]) readings[d.data_type] = d; });
        // 根据温度选天气图标
        var temp = readings.temperature ? readings.temperature.value : null;
        var rain = readings.rainfall ? readings.rainfall.value : 0;
        var wind = readings.wind_speed ? readings.wind_speed.value : 0;
        var weatherIcon = '☀️';
        if (rain > 5) weatherIcon = '🌧️';
        else if (rain > 1) weatherIcon = '🌦️';
        else if (wind > 30) weatherIcon = '🌬️';
        else if (temp !== null && temp < 0) weatherIcon = '❄️';
        else if (temp !== null && temp < 10) weatherIcon = '⛅';

        html += '<div style="display:flex;align-items:center;gap:12px;margin-bottom:8px">';
        // 左侧：天气图标+温度大字
        html += '<div style="text-align:center;min-width:60px">';
        html += '<div style="font-size:32px">' + weatherIcon + '</div>';
        html += '<div style="font-size:22px;font-weight:700;color:var(--gold-light)">' + (temp !== null ? temp + '°' : '--') + '</div>';
        html += '</div>';
        // 右侧：天气详情（全中文）
        html += '<div style="font-size:12px;line-height:1.9">';
        if (readings.humidity) { html += '💧 湿度 <b>' + readings.humidity.value + '%</b>  '; }
        if (readings.wind_speed) {
          var windDesc = readings.wind_speed.value < 12 ? '微风' : (readings.wind_speed.value < 24 ? '大风' : '暴风');
          html += '🌬 风速 <b>' + readings.wind_speed.value + 'km/h</b> <span style="color:var(--text2)">' + windDesc + '</span><br>';
        }
        if (readings.rainfall) { html += '🌧 降雨 <b>' + readings.rainfall.value + 'mm/h</b>  '; }
        if (readings.snowfall) { html += '🌨 降雪 <b>' + readings.snowfall.value + 'mm/h</b>  '; }
        if (readings.pressure) { html += '📊 气压 <b>' + readings.pressure.value + 'hPa</b><br>'; }
        if (readings.visibility) { html += '👁 能见度 <b>' + (readings.visibility.value >= 1000 ? (readings.visibility.value/1000).toFixed(1)+'km' : readings.visibility.value+'m') + '</b>  '; }
        if (readings.cloud_cover) { html += '☁ 云量 <b>' + readings.cloud_cover.value + '%</b>'; }
        html += '</div></div>';
      } else {
        html += '<div style="color:var(--text2);font-size:12px;margin-bottom:8px">暂无实时数据</div>';
      }

      // 活跃预警标签
      if (z.warnings && z.warnings.length) {
        html += '<div style="display:flex;gap:4px;flex-wrap:wrap">';
        z.warnings.forEach(function(w) {
          html += '<span class="tag ' + (LEVEL_COLORS[w.level] || 't-progress') + '" style="cursor:pointer" onclick="event.stopPropagation();showWeatherWarningDetail(' + w.id + ')">' + (LEVEL_EMOJI[w.level] || '') + ' ' + (WEATHER_LABELS[w.weather_type] || w.weather_type) + '</span>';
        });
        html += '</div>';
      } else {
        html += '<span class="tag t-done">✅ 无预警</span>';
      }

      html += '</div>';
    });
    html += '</div></div>';

    // 预警列表按钮
    html += '<div class="card"><div class="card-title">📋 预警记录 <button class="btn btn-sm btn-o" onclick="showWeatherWarningList()">查看全部</button></div></div>';

    showModal('🌤️ 天气预警', html, null, '98%', '900px');
  });
}

// ==================== 区域详情 ====================

function showWeatherZoneDetail(zoneId) {
  api('/weather/dashboard').then(function(d) {
    var zone = (d.zones || []).find(function(z) { return z.zone.id === zoneId; });
    if (!zone) return alert('区域不存在');

    var h = '<div style="margin-bottom:16px;line-height:2">';
    h += '<b>🏔️ 区域：</b>' + zone.zone.zone_name + '  |  <b>📋 编码：</b>' + zone.zone.zone_code;
    h += '  |  <b>🧭 经纬度：</b>' + (zone.zone.latitude || '?') + ', ' + (zone.zone.longitude || '?');
    h += '  |  <b>⛰ 海拔：</b>' + (zone.zone.altitude || '-') + '</div>';

    // 活跃预警
    if (zone.warnings && zone.warnings.length) {
      h += '<div class="card" style="border-color:var(--danger)"><div class="card-title">🚨 活跃预警</div>';
      zone.warnings.forEach(function(w) {
        h += '<div style="padding:8px 0;border-bottom:1px solid var(--border);cursor:pointer" onclick="showWeatherWarningDetail(' + w.id + ')">';
        h += '<span class="tag ' + (LEVEL_COLORS[w.level] || 't-progress') + '">' + (LEVEL_EMOJI[w.level] || '') + ' ' + (WEATHER_LABELS[w.weather_type] || w.weather_type) + '</span> ';
        h += '<span style="font-size:13px">' + w.title + '</span>';
        h += '<span style="font-size:11px;color:var(--text2);float:right">' + (w.triggered_at || '').slice(0,16) + '</span>';
        h += '</div>';
      });
      h += '</div>';
    }

    // 最近数据
    if (zone.latestData && zone.latestData.length) {
      h += '<div class="card"><div class="card-title">📊 最近1小时数据</div>';
      h += '<table><tr><th>数据类型</th><th>数值</th><th>单位</th><th>时间</th></tr>';
      var shown = {};
      zone.latestData.forEach(function(d) {
        var key = d.data_type;
        if (shown[key]) return; shown[key] = true;
        var label = d.data_type;
        if (d.data_type === 'temperature') label = '🌡 温度';
        else if (d.data_type === 'wind_speed') label = '🌬 风速';
        else if (d.data_type === 'wind_gust') label = '💨 阵风';
        else if (d.data_type === 'rainfall') label = '🌧 降雨量';
        else if (d.data_type === 'snowfall') label = '🌨 降雪量';
        else if (d.data_type === 'humidity') label = '💧 湿度';
        else if (d.data_type === 'visibility') label = '👁 能见度';
        else if (d.data_type === 'pressure') label = '📊 气压';
        else if (d.data_type === 'cloud_cover') label = '☁ 云量';
        else if (d.data_type === 'weather_code') label = '🌤 天气码';
        var unit = d.unit || '';
        var displayValue = d.value;
        if (d.data_type === 'visibility' && d.value >= 1000) { unit = 'km'; displayValue = (d.value/1000).toFixed(1); }
        h += '<tr><td>' + label + '</td><td><b>' + displayValue + '</b></td><td>' + unit + '</td><td>' + (d.recorded_at || '').slice(11,16) + '</td></tr>';
      });
      h += '</table></div>';
    }

    showModal('🏔️ ' + zone.zone.zone_name, h, null, '98%', '700px');
  });
}

// ==================== 预警列表 ====================

function showWeatherWarningList() {
  api('/weather/warnings').then(function(data) {
    var rows = '';
    (data || []).forEach(function(w) {
      var stLabel = w.status === 'active' ? '⚠ 活跃' : w.status === 'acknowledged' ? '👁 已确认' : w.status === 'resolved' ? '✅ 已解除' : '❌ 已取消';
      rows += '<tr style="cursor:pointer" onclick="showWeatherWarningDetail(' + w.id + ')">';
      rows += '<td class="order-no">' + w.warning_no + '</td>';
      rows += '<td>' + (w.zone_name || '-') + '</td>';
      rows += '<td>' + (WEATHER_LABELS[w.weather_type] || w.weather_type) + '</td>';
      rows += '<td><span class="tag ' + (LEVEL_COLORS[w.level] || 't-progress') + '">' + (LEVEL_EMOJI[w.level] || '') + ' ' + w.level + '</span></td>';
      rows += '<td><span class="tag ' + (w.status === 'active' ? 't-reject' : w.status === 'acknowledged' ? 't-pending' : 't-done') + '">' + stLabel + '</span></td>';
      rows += '<td>' + (w.triggered_at || '').slice(0,16) + '</td>';
      rows += '<td><button class="btn btn-sm btn-p" onclick="event.stopPropagation();showWeatherWarningDetail(' + w.id + ')">详情</button></td>';
      rows += '</tr>';
    });
    if (!rows) rows = '<tr><td colspan="7" class="empty">暂无预警记录</td></tr>';
    showModal('📋 预警记录', '<table><tr><th>编号</th><th>区域</th><th>类型</th><th>等级</th><th>状态</th><th>触发时间</th><th>操作</th></tr>' + rows + '</table>', null, '98%', '800px');
  });
}

// ==================== 预警详情 ====================

function showWeatherWarningDetail(id) {
  api('/weather/warnings/' + id).then(function(w) {
    if (!w) return;
    var stLabel = w.status === 'active' ? '⚠ 活跃' : w.status === 'acknowledged' ? '👁 已确认' : w.status === 'resolved' ? '✅ 已解除' : '已取消';
    var h = '<div style="margin-bottom:12px">';
    h += '<div style="font-size:18px;font-weight:700;margin-bottom:8px">' + (LEVEL_EMOJI[w.level] || '') + ' ' + w.title + '</div>';
    h += '<div><b>编号：</b>' + w.warning_no + ' | <b>状态：</b><span class="tag ' + (w.status === 'active' ? 't-reject' : 't-done') + '">' + stLabel + '</span></div>';
    h += '<div><b>区域：</b>' + (w.zone_name || '-') + ' (' + (w.zone_code || '') + ')</div>';
    h += '<div><b>类型：</b>' + (WEATHER_LABELS[w.weather_type] || w.weather_type) + ' | <b>等级：</b>' + (LEVEL_EMOJI[w.level] || '') + ' ' + w.level + '</div>';
    h += '<div><b>实测值：</b>' + (w.measured_value || '-') + (w.measured_unit || '') + '</div>';
    h += '<div><b>触发时间：</b>' + (w.triggered_at || '-') + '</div>';
    if (w.resolved_at) h += '<div><b>解除时间：</b>' + w.resolved_at + ' | <b>操作人：</b>' + (w.resolver_name || '系统自动') + '</div>';
    h += '</div>';

    // 描述
    h += '<div style="padding:12px;background:var(--surface2);border-radius:8px;margin-bottom:12px">' + (w.description || '无详细描述') + '</div>';

    // 自动动作
    var actions = []; try { actions = JSON.parse(w.auto_actions || '[]'); } catch(e) {}
    if (actions.length) {
      h += '<div class="card"><div class="card-title">🔧 自动联动动作</div>';
      actions.forEach(function(a) {
        var aLabel = a === 'suspend_dispatch' ? '🛑 暂停车辆调度' : a === 'recall_drivers' ? '📢 通知驾驶员回撤' : a;
        h += '<div style="padding:4px 0;font-size:13px">' + aLabel + '</div>';
      });
      h += '</div>';
    }

    // 响应动作日志
    if (w.actions && w.actions.length) {
      h += '<div class="card"><div class="card-title">📝 响应记录</div>';
      w.actions.forEach(function(a) {
        var aLabel = a.action_type === 'acknowledge' ? '👁 确认收到' : a.action_type === 'resolve' ? '✅ 解除预警' : a.action_type === 'suspend_dispatch' ? '🛑 暂停调度' : a.action_type;
        h += '<div style="padding:4px 0;font-size:12px;border-bottom:1px solid var(--border)">';
        h += '<b>' + aLabel + '</b> — ' + (a.action_detail || '') + ' <span style="color:var(--text2)">' + (a.executed_at || '').slice(0,16) + '</span>';
        h += '</div>';
      });
      h += '</div>';
    }

    // 操作按钮
    var btns = '';
    if (w.status === 'active') {
      btns += '<button class="btn btn-p btn-sm" onclick="acknowledgeWarning(' + w.id + ')">👁 确认收到</button> ';
      if (USER.role === 'admin' || USER.role === 'safety_officer' || USER.role === 'dispatcher') {
        btns += '<button class="btn btn-s btn-sm" onclick="resolveWeatherWarning(' + w.id + ')">✅ 解除预警</button>';
      }
    }
    if (btns) h += '<div style="margin-top:12px;display:flex;gap:8px">' + btns + '</div>';

    showModal('预警详情', h);
  });
}

// ==================== 确认/解除操作 ====================

function acknowledgeWarning(id) {
  api('/weather/warnings/' + id + '/acknowledge', { method: 'POST' }).then(function() {
    toast('已确认收到预警');
    var mask = document.querySelector('.modal-mask');
    if (mask) mask.remove();
    renderPage();
  });
}

function resolveWeatherWarning(id) {
  showModal('✅ 解除预警', [
    '<div class="form-group"><label>解除原因</label><textarea id="resolveReason" placeholder="请说明解除原因..."></textarea></div>'
  ].join(''), async function(mask) {
    var reason = document.getElementById('resolveReason').value.trim();
    if (!reason) { alert('请填写解除原因'); return false; }
    await api('/weather/warnings/' + id + '/resolve', { method: 'POST', data: { reason: reason } });
    toast('预警已解除'); mask.remove(); renderPage();
  });
}

// ==================== 区域管理（admin） ====================

function showWeatherZones() {
  api('/weather/zones').then(function(zones) {
    var rows = '';
    (zones || []).forEach(function(z) {
      rows += '<tr><td>' + z.zone_name + '</td><td>' + z.zone_code + '</td><td style="font-size:11px">' + (z.latitude || '-') + ', ' + (z.longitude || '-') + '</td><td>' + (z.altitude || '-') + '</td><td>' + (z.description || '-') + '</td><td><span class="tag ' + (z.status === 1 ? 't-done' : 't-reject') + '">' + (z.status === 1 ? '启用' : '停用') + '</span></td><td><button class="btn btn-sm btn-p" onclick="editWeatherZone(' + z.id + ')">编辑</button> <button class="btn btn-sm btn-d" onclick="deleteWeatherZone(' + z.id + ',\'' + (z.zone_name || '') + '\')">删除</button></td></tr>';
    });
    if (!rows) rows = '<tr><td colspan="8" class="empty">暂无区域，请先添加</td></tr>';
    var h = '<button class="btn btn-p btn-sm" style="margin-bottom:12px" onclick="editWeatherZone()">+ 新增区域</button>';
    h += '<table><tr><th>名称</th><th>编码</th><th>经纬度</th><th>海拔</th><th>描述</th><th>状态</th><th>操作</th></tr>' + rows + '</table>';
    showModal('📋 区域管理', h, null, '98%', '700px');
  });
}

var _zoneFormHtml = [
  '<div class="form-group"><label>区域名称</label><input id="wzName" /></div>',
  '<div class="form-group"><label>区域编码</label><input id="wzCode" placeholder="如 ZONE-001" /></div>',
  '<div style="display:grid;grid-template-columns:1fr 1fr;gap:8px">',
    '<div class="form-group"><label>纬度 (latitude)</label><input id="wzLat" type="number" step="any" placeholder="如 29.77" /></div>',
    '<div class="form-group"><label>经度 (longitude)</label><input id="wzLon" type="number" step="any" placeholder="如 91.65" /></div>',
  '</div>',
  '<div class="form-group"><label>海拔范围</label><input id="wzAltitude" placeholder="如 4800-5100m" /></div>',
  '<div class="form-group"><label>描述</label><textarea id="wzDesc" placeholder="区域描述..."></textarea></div>'
].join('');

function editWeatherZone(id) {
  var isEdit = !!id;
  if (isEdit) {
    api('/weather/zones').then(function(zones) {
      var z = zones.find(function(x) { return x.id === id; });
      if (!z) return;
      showEditZoneModal(z);
    });
  } else {
    showEditZoneModal(null);
  }
}

function showEditZoneModal(z) {
  showModal((z ? '编辑' : '新增') + '区域', _zoneFormHtml, async function(mask) {
    var data = {
      zone_name: document.getElementById('wzName').value.trim(),
      zone_code: document.getElementById('wzCode').value.trim(),
      latitude: parseFloat(document.getElementById('wzLat').value) || 0,
      longitude: parseFloat(document.getElementById('wzLon').value) || 0,
      altitude: document.getElementById('wzAltitude').value.trim(),
      description: document.getElementById('wzDesc').value.trim()
    };
    if (!data.zone_name || !data.zone_code) { alert('请填写名称和编码'); return false; }
    if (z) {
      await api('/weather/zones/' + z.id, { method: 'PUT', data: data });
    } else {
      await api('/weather/zones', { method: 'POST', data: data });
    }
    toast(z ? '已更新' : '已新增'); mask.remove(); showWeatherZones();
  });
  if (z) {
    document.getElementById('wzName').value = z.zone_name || '';
    document.getElementById('wzCode').value = z.zone_code || '';
    document.getElementById('wzLat').value = z.latitude || 0;
    document.getElementById('wzLon').value = z.longitude || 0;
    document.getElementById('wzAltitude').value = z.altitude || '';
    document.getElementById('wzDesc').value = z.description || '';
  }
}

function deleteWeatherZone(id, name) {
  if (!confirm('确定删除区域「' + name + '」？相关数据和预警也会被删除。')) return;
  api('/weather/zones/' + id, { method: 'DELETE' }).then(function() {
    toast('已删除'); showWeatherZones();
  });
}

// ==================== 阈值管理（admin） ====================

function showWeatherThresholds() {
  api('/weather/thresholds').then(function(data) {
    var rows = '';
    (data || []).forEach(function(t) {
      rows += '<tr><td>' + (t.zone_name || '全局默认') + '</td><td>' + (WEATHER_LABELS[t.weather_type] || t.weather_type) + '</td><td><span class="tag ' + (LEVEL_COLORS[t.level] || 't-progress') + '">' + (LEVEL_EMOJI[t.level] || '') + ' ' + t.level + '</span></td><td>' + t.threshold_value + ' ' + (t.threshold_unit || '') + '</td><td>' + (t.duration_minutes || 30) + '分钟</td><td><button class="btn btn-sm btn-p" onclick="editWeatherThreshold(' + t.id + ')">编辑</button> <button class="btn btn-sm btn-d" onclick="deleteWeatherThreshold(' + t.id + ')">删除</button></td></tr>';
    });
    if (!rows) rows = '<tr><td colspan="6" class="empty">暂无阈值配置</td></tr>';
    var h = '<button class="btn btn-p btn-sm" style="margin-bottom:12px" onclick="editWeatherThreshold()">+ 新增阈值</button>';
    h += '<table><tr><th>区域</th><th>天气类型</th><th>预警等级</th><th>阈值</th><th>持续时长</th><th>操作</th></tr>' + rows + '</table>';
    h += '<div style="margin-top:12px;font-size:11px;color:var(--text2)">💡 阈值判断规则：暴雨/大风/暴雪/雷电为「大于等于阈值」触发；沙尘暴/大雾为「小于等于阈值」触发</div>';
    showModal('⚙ 阈值配置', h, null, '98%', '800px');
  });
}

function editWeatherThreshold(id) {
  var hasId = !!id;
  api('/weather/zones').then(function(zones) {
    api('/weather/dict').then(function(dict) {
      var zoneOpts = '<option value="">全局默认</option>';
      zones.forEach(function(z) { zoneOpts += '<option value="' + z.id + '">' + z.zone_name + '</option>'; });
      var typeOpts = dict.weatherTypes.map(function(t) { return '<option value="' + t.key + '">' + t.label + '</option>'; }).join('');
      var levelOpts = dict.levels.map(function(l) { return '<option value="' + l.key + '">' + LEVEL_EMOJI[l.key] + ' ' + l.label + '</option>'; }).join('');

      var html = [
        '<div class="form-group"><label>区域</label><select id="wtZone">' + zoneOpts + '</select></div>',
        '<div class="form-group"><label>天气类型</label><select id="wtType">' + typeOpts + '</select></div>',
        '<div class="form-group"><label>预警等级</label><select id="wtLevel">' + levelOpts + '</select></div>',
        '<div class="form-group"><label>阈值</label><input id="wtValue" type="number" step="0.1" /></div>',
        '<div class="form-group"><label>单位</label><input id="wtUnit" placeholder="如 mm/h, m/s, m" /></div>',
        '<div class="form-group"><label>持续时间(分钟)</label><input id="wtDuration" type="number" value="30" /></div>',
      ].join('');

      showModal((hasId ? '编辑' : '新增') + '阈值', html, async function(mask) {
        var data = {
          zone_id: document.getElementById('wtZone').value || null,
          weather_type: document.getElementById('wtType').value,
          level: document.getElementById('wtLevel').value,
          threshold_value: parseFloat(document.getElementById('wtValue').value),
          threshold_unit: document.getElementById('wtUnit').value.trim(),
          duration_minutes: parseInt(document.getElementById('wtDuration').value) || 30
        };
        if (!data.weather_type || !data.level || isNaN(data.threshold_value)) { alert('请完整填写'); return false; }
        data.zone_id = data.zone_id ? parseInt(data.zone_id) : null;
        if (hasId) {
          await api('/weather/thresholds/' + id, { method: 'PUT', data: data });
        } else {
          await api('/weather/thresholds', { method: 'POST', data: data });
        }
        toast(hasId ? '已更新' : '已新增'); mask.remove(); showWeatherThresholds();
      });

      if (hasId) {
        api('/weather/thresholds').then(function(all) {
          var t = all.find(function(x) { return x.id === id; });
          if (!t) return;
          document.getElementById('wtZone').value = t.zone_id || '';
          document.getElementById('wtType').value = t.weather_type || '';
          document.getElementById('wtLevel').value = t.level || '';
          document.getElementById('wtValue').value = t.threshold_value || 0;
          document.getElementById('wtUnit').value = t.threshold_unit || '';
          document.getElementById('wtDuration').value = t.duration_minutes || 30;
        });
      }
    });
  });
}

function deleteWeatherThreshold(id) {
  if (!confirm('确定删除此阈值配置？')) return;
  api('/weather/thresholds/' + id, { method: 'DELETE' }).then(function() {
    toast('已删除'); showWeatherThresholds();
  });
}

// ==================== IoT传感器数据上报工具（admin测试用） ====================

function showWeatherIngestTest() {
  api('/weather/zones').then(function(zones) {
    var zoneOpts = zones.map(function(z) { return '<option value="' + z.zone_code + '">' + z.zone_name + ' (' + z.zone_code + ')</option>'; }).join('');
    var html = [
      '<div class="form-group"><label>区域</label><select id="ingestZone">' + zoneOpts + '</select></div>',
      '<div class="form-group"><label>数据类型</label><select id="ingestType">',
      '<option value="rainfall">降雨量 (mm/h)</option>',
      '<option value="wind_speed">风速 (m/s)</option>',
      '<option value="visibility">能见度 (m)</option>',
      '<option value="temperature">温度 (℃)</option>',
      '<option value="humidity">湿度 (%)</option>',
      '<option value="snowfall">降雪量 (mm/h)</option>',
      '<option value="lightning">雷电次数 (次/10min)</option>',
      '<option value="dust">沙尘浓度 (μg/m³)</option>',
      '</select></div>',
      '<div class="form-group"><label>数值</label><input id="ingestValue" type="number" step="0.1" /></div>',
      '<div class="form-group"><label>单位</label><input id="ingestUnit" placeholder="自动填充" /></div>',
    ].join('');

    showModal('📡 模拟传感器上报', html, async function(mask) {
      var zoneCode = document.getElementById('ingestZone').value;
      var dataType = document.getElementById('ingestType').value;
      var value = parseFloat(document.getElementById('ingestValue').value);
      var unit = document.getElementById('ingestUnit').value.trim();
      if (isNaN(value)) { alert('请填写数值'); return false; }
      await api('/weather/data/ingest', {
        method: 'POST',
        data: { items: [{ zone_code: zoneCode, data_type: dataType, value: value, unit: unit }] }
      });
      toast('数据已上报，规则引擎将在5分钟内处理'); mask.remove(); renderPage();
    });

    // 监听类型变化自动填充单位
    var typeEl = document.getElementById('ingestType');
    var unitEl = document.getElementById('ingestUnit');
    function updateUnit() {
      var units = { rainfall: 'mm/h', wind_speed: 'm/s', visibility: 'm', temperature: '℃', humidity: '%', snowfall: 'mm/h', lightning: '次/10min', dust: 'μg/m³' };
      unitEl.value = units[typeEl.value] || '';
      unitEl.placeholder = units[typeEl.value] || '';
    }
    typeEl.onchange = updateUnit;
    updateUnit();
  });
}
