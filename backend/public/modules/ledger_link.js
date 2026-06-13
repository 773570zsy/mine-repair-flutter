// 单车核算模块 — 仪表盘快捷入口注入
// 通过MutationObserver监听管理员仪表盘渲染，动态注入导航卡片
(function() {
  'use strict';

  function injectLedgerCard() {
    // 找到管理员仪表盘的功能卡片网格(.row3)
    var grid = document.querySelector('#mainPage .row3');
    if (!grid) return false;

    // 避免重复注入
    if (document.getElementById('ledgerNavCard')) return true;

    // 是否有管理员权限
    var user = null;
    try { user = JSON.parse(localStorage.getItem('mp_user') || 'null'); } catch(e) {}
    if (!user || (user.role !== 'admin' && user.role !== 'leader')) return true;

    var card = document.createElement('div');
    card.id = 'ledgerNavCard';
    card.className = 'card';
    card.style.cssText = 'text-align:center;cursor:pointer;border-left:3px solid var(--gold);background:linear-gradient(135deg,rgba(200,160,74,.08),rgba(200,160,74,.02))';
    card.onclick = function() { showLedgerModule(); };
    card.innerHTML = '<h3>📊</h3>单车核算<br><span style="font-size:12px;color:var(--text2)">油耗/配件/KPI考核</span>';
    grid.appendChild(card);
    return true;
  }

  function showLedgerModule() {
    var mp = document.getElementById('mainPage');
    if (!mp) return;
    mp.innerHTML = '<div class="layout">' +
      '<div class="card" style="margin-bottom:14px">' +
        '<div class="card-title">📊 单车核算 <span style="font-size:12px;color:var(--text2)">油耗管理 | 配件台账 | KPI考核</span>' +
        '<button class="btn btn-o btn-sm" onclick="renderPage()">← 返回</button></div>' +
      '</div>' +
      '<div class="stats-grid">' +
        '<div class="stat-item" onclick="openMonthlyLedger()" style="cursor:pointer"><div class="stat-num">📋</div><div class="stat-label">月度清单</div></div>' +
        '<div class="stat-item" onclick="openKpiRanking()" style="cursor:pointer"><div class="stat-num">🏆</div><div class="stat-label">KPI排名</div></div>' +
        '<div class="stat-item" onclick="openThresholdConfig()" style="cursor:pointer"><div class="stat-num">⚙</div><div class="stat-label">阈值配置</div></div>' +
      '</div>' +
      '<div id="ledgerContent" style="margin-top:14px"></div>' +
    '</div>';

    // 默认加载当月汇总
    loadLedgerSummary();
  }

  // ---- API helpers (复用全局api函数) ----
  async function ledgerApi(url, opts) {
    var hdr = {'Content-Type':'application/json'};
    var token = localStorage.getItem('mp_token');
    if (token) hdr['Authorization'] = 'Bearer ' + token;
    var r = await fetch('/api' + url, {headers: hdr, method: (opts||{}).method || 'GET', body: (opts||{}).data ? JSON.stringify((opts||{}).data) : undefined});
    var d = await r.json();
    if (d.code === 401) { if (typeof doLogout === 'function') doLogout(); return null; }
    if (d.code !== 200) { alert(d.msg || '操作失败'); return null; }
    return d.data;
  }

  // ---- 燃油记录页面 ----
  window.openFuelRecords = function() {
    var container = document.getElementById('ledgerContent');
    if (!container) return;
    container.innerHTML = '<div class="card"><div class="card-title">⛽ 燃油消耗记录 <button class="btn btn-p btn-sm" onclick="showFuelForm()">+ 录入</button></div><div id="fuelList">加载中...</div></div>';
    loadFuelList();
  };

  window.showFuelForm = function(record) {
    var isEdit = !!record;
    var title = isEdit ? '修改燃油记录' : '录入燃油记录';
    var data = record || {};
    var vehiclesHtml = '';
    // 简化：用固定车辆列表
    showFuelModal(title, data, isEdit);
  };

  function showFuelModal(title, data, isEdit) {
    var mask = document.createElement('div');
    mask.className = 'modal-mask';
    mask.onclick = function(e) { if (e.target === mask) mask.remove(); };
    mask.innerHTML = '<div class="modal">' +
      '<h2 style="margin-bottom:16px">' + title + '</h2>' +
      '<div class="form-group"><label>车辆</label><select id="frmFuelVehicle">' +
      '<option value="1">矿A-001 履带挖掘机</option><option value="2">矿A-002 装载机</option>' +
      '</select></div>' +
      '<div class="form-group"><label>日期</label><input id="frmFuelDate" type="date" value="' + (data.record_date || new Date().toISOString().slice(0,10)) + '"></div>' +
      '<div class="form-group"><label>加油量(升)</label><input id="frmFuelAmount" type="number" step="0.1" value="' + (data.fuel_amount || '') + '" placeholder="例:200"></div>' +
      '<div class="form-group"><label>金额(元)</label><input id="frmFuelCost" type="number" step="0.01" value="' + (data.fuel_cost || '') + '" placeholder="例:1600"></div>' +
      '<div class="form-group"><label>工时表读数</label><input id="frmFuelHours" type="number" value="' + (data.hour_meter || '') + '" placeholder="例:1200"></div>' +
      '<div style="text-align:right;margin-top:16px"><button class="btn btn-o" onclick="this.closest(\'.modal-mask\').remove()">取消</button>' +
      '<button class="btn btn-p" style="margin-left:8px" id="btnSaveFuel">保存</button></div></div>';
    document.body.appendChild(mask);

    if (data.vehicle_id) document.getElementById('frmFuelVehicle').value = data.vehicle_id;

    document.getElementById('btnSaveFuel').onclick = async function() {
      var body = {
        vehicle_id: Number(document.getElementById('frmFuelVehicle').value),
        record_date: document.getElementById('frmFuelDate').value,
        fuel_amount: Number(document.getElementById('frmFuelAmount').value) || 0,
        fuel_cost: Number(document.getElementById('frmFuelCost').value) || 0,
        hour_meter: Number(document.getElementById('frmFuelHours').value) || 0
      };
      var url = '/ledger/fuel-records' + (isEdit ? '/' + data.id : '');
      var method = isEdit ? 'PUT' : 'POST';
      var result = await ledgerApi(url, {method: method, data: body});
      if (result || (isEdit && result !== null)) {
        mask.remove();
        loadFuelList();
      }
    };
  }

  async function loadFuelList() {
    var container = document.getElementById('fuelList');
    if (!container) return;
    var month = new Date().toISOString().slice(0,7);
    var data = await ledgerApi('/ledger/fuel-records?year_month=' + month + '&pageSize=50');
    if (!data) { container.innerHTML = '<div class="empty">加载失败</div>'; return; }
    if (!data.length) { container.innerHTML = '<div class="empty">暂无燃油记录</div>'; return; }
    container.innerHTML = '<table><tr><th>日期</th><th>车辆</th><th>油量(L)</th><th>金额(元)</th><th>工时表</th><th>操作</th></tr>' +
      data.map(function(r) {
        return '<tr><td>' + r.record_date + '</td><td><b>' + r.plate_number + '</b></td><td>' + r.fuel_amount + '</td><td>¥' + r.fuel_cost + '</td><td>' + r.hour_meter + 'h</td><td><button class="btn btn-sm btn-o" onclick="editFuel(' + r.id + ')">编辑</button> <button class="btn btn-sm btn-d" onclick="deleteFuel(' + r.id + ')">删</button></td></tr>';
      }).join('') + '</table>';
  }

  window.editFuel = async function(id) {
    var data = await ledgerApi('/ledger/fuel-records?pageSize=100');
    var record = (data||[]).find(function(r) { return r.id === id; });
    if (record) window.showFuelForm(record);
  };

  window.deleteFuel = async function(id) {
    if (!confirm('确认删除这条燃油记录？')) return;
    var result = await fetch('/api/ledger/fuel-records/' + id, {method:'DELETE', headers:{'Authorization':'Bearer '+localStorage.getItem('mp_token')}});
    var d = await result.json();
    if (d.code === 200) loadFuelList(); else alert(d.msg);
  };

  // ---- 配件更换页面 ----
  window.openPartReplacements = function() {
    var container = document.getElementById('ledgerContent');
    if (!container) return;
    container.innerHTML = '<div class="card"><div class="card-title">🔧 高价值配件更换台账 <button class="btn btn-p btn-sm" onclick="showPartForm()">+ 录入</button></div><div id="partList">加载中...</div></div>';
    loadPartList();
  };

  window.showPartForm = function(record) {
    var isEdit = !!record;
    var data = record || {};
    var mask = document.createElement('div');
    mask.className = 'modal-mask';
    mask.onclick = function(e) { if (e.target === mask) mask.remove(); };
    mask.innerHTML = '<div class="modal">' +
      '<h2 style="margin-bottom:16px">' + (isEdit ? '修改配件更换' : '录入配件更换') + '</h2>' +
      '<div class="form-group"><label>车辆</label><select id="frmPartVehicle">' +
      '<option value="1">矿A-001 履带挖掘机</option><option value="2">矿A-002 装载机</option>' +
      '</select></div>' +
      '<div class="form-group"><label>部件名称</label><input id="frmPartName" value="' + (data.part_name || '') + '" placeholder="例:左前轮胎"></div>' +
      '<div class="form-group"><label>部件类型</label><select id="frmPartType"><option value="tire">轮胎</option><option value="engine">发动机</option><option value="hydraulic">液压</option><option value="transmission">变速箱</option><option value="brake">刹车</option><option value="other">其他</option></select></div>' +
      '<div class="form-group"><label>更换日期</label><input id="frmPartDate" type="date" value="' + (data.replace_date || new Date().toISOString().slice(0,10)) + '"></div>' +
      '<div class="form-group"><label>费用(元)</label><input id="frmPartCost" type="number" step="0.01" value="' + (data.cost || '') + '" placeholder="例:8500"></div>' +
      '<div class="form-group"><label>更换时工时</label><input id="frmPartHours" type="number" value="' + (data.current_hours || '') + '"></div>' +
      '<div class="form-group"><label>更换原因</label><input id="frmPartReason" value="' + (data.reason || '') + '"></div>' +
      '<div style="text-align:right;margin-top:16px"><button class="btn btn-o" onclick="this.closest(\'.modal-mask\').remove()">取消</button>' +
      '<button class="btn btn-p" style="margin-left:8px" id="btnSavePart">保存</button></div></div>';
    document.body.appendChild(mask);
    if (data.vehicle_id) document.getElementById('frmPartVehicle').value = data.vehicle_id;
    if (data.part_type) document.getElementById('frmPartType').value = data.part_type;

    document.getElementById('btnSavePart').onclick = async function() {
      var body = {
        vehicle_id: Number(document.getElementById('frmPartVehicle').value),
        part_name: document.getElementById('frmPartName').value,
        part_type: document.getElementById('frmPartType').value,
        replace_date: document.getElementById('frmPartDate').value,
        cost: Number(document.getElementById('frmPartCost').value) || 0,
        current_hours: Number(document.getElementById('frmPartHours').value) || 0,
        reason: document.getElementById('frmPartReason').value
      };
      var url = '/ledger/part-replacements' + (isEdit ? '/' + data.id : '');
      var method = isEdit ? 'PUT' : 'POST';
      var result = await ledgerApi(url, {method: method, data: body});
      if (result || (isEdit && result !== null)) { mask.remove(); loadPartList(); }
    };
  };

  async function loadPartList() {
    var container = document.getElementById('partList');
    if (!container) return;
    var data = await ledgerApi('/ledger/part-replacements?pageSize=100');
    if (!data || !data.length) { container.innerHTML = '<div class="empty">暂无配件更换记录</div>'; return; }
    container.innerHTML = '<table><tr><th>日期</th><th>车辆</th><th>部件</th><th>类型</th><th>费用</th><th>工时</th><th>原因</th><th>操作</th></tr>' +
      data.map(function(r) {
        var typeLabel = {tire:'轮胎',engine:'发动机',hydraulic:'液压',transmission:'变速箱',brake:'刹车',other:'其他'}[r.part_type] || r.part_type;
        return '<tr><td>' + r.replace_date + '</td><td><b>' + r.plate_number + '</b></td><td>' + r.part_name + '</td><td>' + typeLabel + '</td><td>¥' + r.cost + '</td><td>' + r.current_hours + 'h</td><td>' + (r.reason||'-') + '</td><td><button class="btn btn-sm btn-o" onclick="editPart(' + r.id + ')">编辑</button> <button class="btn btn-sm btn-d" onclick="deletePart(' + r.id + ')">删</button></td></tr>';
      }).join('') + '</table>';
  }

  window.editPart = async function(id) {
    var data = await ledgerApi('/ledger/part-replacements?pageSize=100');
    var record = (data||[]).find(function(r) { return r.id === id; });
    if (record) window.showPartForm(record);
  };

  window.deletePart = async function(id) {
    if (!confirm('确认删除？')) return;
    var result = await fetch('/api/ledger/part-replacements/' + id, {method:'DELETE', headers:{'Authorization':'Bearer '+localStorage.getItem('mp_token')}});
    var d = await result.json();
    if (d.code === 200) loadPartList(); else alert(d.msg);
  };

  // ---- 月度清单页面 ----
  window.openMonthlyLedger = async function() {
    var container = document.getElementById('ledgerContent');
    if (!container) return;
    var curMonth = new Date().toISOString().slice(0,7);
    container.innerHTML = '<div class="card"><div class="card-title">📋 月度单车核算清单' +
      '<span style="display:flex;gap:8px;align-items:center">' +
        '<input id="ledgerMonthFilter" type="month" value="' + curMonth + '" style="width:auto;padding:6px 10px;font-size:13px" onchange="loadLedgerList()" />' +
        '<button class="btn btn-p btn-sm" onclick="generateLedger()">生成</button>' +
      '</span></div><div id="ledgerList">加载中...</div></div>';
    loadLedgerList();
  };

  async function loadLedgerList() {
    var container = document.getElementById('ledgerList');
    if (!container) return;
    var monthEl = document.getElementById('ledgerMonthFilter');
    var month = monthEl ? monthEl.value : new Date().toISOString().slice(0,7);
    var data = await ledgerApi('/ledger/monthly?year_month=' + month);
    if (!data || !data.length) { container.innerHTML = '<div class="empty">暂无核算清单，请先生成</div>'; return; }
    container.innerHTML = '<table style="font-size:12px"><tr><th>车辆</th><th>月份</th><th>工时</th><th>总成本</th><th>总收入</th><th>盈亏</th><th>出勤</th><th>状态</th><th>操作</th></tr>' +
      data.map(function(r) {
        var statusTag = r.status === 'approved' ? 't-done' : r.status === 'submitted' ? 't-pending' : 't-progress';
        var statusLabel = r.status === 'approved' ? '已审批' : r.status === 'submitted' ? '待审批' : '草稿';
        var actions = '';
        if (r.status === 'draft') actions = '<button class="btn btn-sm btn-s" onclick="submitLedger(' + r.id + ')">提交</button>';
        if (r.status === 'submitted') actions = '<button class="btn btn-sm btn-s" onclick="approveLedger(' + r.id + ')">审批</button>';
        var rev = r.revenue || 0, pf = r.profit || 0;
        var pfColor = pf >= 0 ? 'var(--success)' : 'var(--danger)';
        var pfSign = pf >= 0 ? '+' : '';
        return '<tr><td><b>' + r.plate_number + '</b><br><small>' + r.vehicle_type + '</small></td><td>' + r.year_month + '</td><td>' + Math.round(r.total_hours) + 'h</td><td style="color:var(--danger)">¥' + r.total_cost + '</td><td style="color:var(--gold)">¥' + rev + '</td><td style="font-weight:700;color:' + pfColor + '">' + pfSign + '¥' + pf + '</td><td>' + r.work_days + '天</td><td><span class="tag ' + statusTag + '">' + statusLabel + '</span></td><td>' + actions + '</td></tr>';
      }).join('') + '</table>';
  }

  window.generateLedger = async function() {
    var monthEl = document.getElementById('ledgerMonthFilter');
    var month = monthEl ? monthEl.value : new Date().toISOString().slice(0,7);
    if (!month) { alert('请选择月份'); return; }
    var result = await ledgerApi('/ledger/monthly/generate', {method: 'POST', data: {year_month: month}});
    if (result) { alert(result.msg || '生成成功'); loadLedgerList(); }
  };

  window.submitLedger = async function(id) {
    var result = await ledgerApi('/ledger/monthly/' + id + '/submit', {method: 'PUT'});
    if (result) { loadLedgerList(); }
  };

  window.approveLedger = async function(id) {
    var result = await ledgerApi('/ledger/monthly/' + id + '/approve', {method: 'PUT'});
    if (result) { loadLedgerList(); }
  };

  // ---- KPI排名页面 ----
  window.openKpiRanking = async function() {
    var container = document.getElementById('ledgerContent');
    if (!container) return;
    container.innerHTML = '<div class="card"><div class="card-title">🏆 KPI考核排名 <button class="btn btn-p btn-sm" onclick="calculateKpi()">重新计算</button></div><div id="kpiList">加载中...</div></div>';
    loadKpiList();
  };

  async function loadKpiList() {
    var container = document.getElementById('kpiList');
    if (!container) return;
    var month = new Date().toISOString().slice(0,7);
    var data = await ledgerApi('/ledger/kpi?year_month=' + month);
    if (!data || !data.length) { container.innerHTML = '<div class="empty">暂无KPI数据，请先生成月度清单并审批后再计算</div>'; return; }
    var tableHtml = '<table style="font-size:12px"><tr><th>排名</th><th>车辆</th><th>燃油成本<br>(25%)</th><th>维修费率<br>(20%)</th><th>利用率<br>(20%)</th><th>单位成本<br>(15%)</th><th>完好率<br>(15%)</th><th>安全<br>(5%)</th><th>总分</th><th>奖惩</th></tr>';
    for (var i = 0; i < data.length; i++) {
      var r = data[i];
      var rankIcon = r.rank === 1 ? '🥇' : r.rank === 2 ? '🥈' : r.rank === 3 ? '🥉' : r.rank;
      var penalty = r.total_penalty || 0;
      var reward = r.total_reward || 0;
      var badge = '';
      if (penalty > 0) badge = '<span style="color:var(--danger);font-weight:600">罚¥' + penalty + '</span>';
      if (reward > 0) badge = '<span style="color:var(--success);font-weight:600">奖¥' + reward + '</span>';
      if (penalty > 0 && reward > 0) badge = '<span style="color:var(--warning);font-weight:600">奖¥' + reward + ' / 罚¥' + penalty + '</span>';
      tableHtml += '<tr>' +
        '<td style="font-size:18px;font-weight:700">' + rankIcon + '</td>' +
        '<td><b>' + r.plate_number + '</b><br><small>' + r.vehicle_type + '</small></td>' +
        '<td>' + r.fuel_cost_per_unit.toFixed(1) + '</td>' +
        '<td>' + r.repair_rate.toFixed(1) + '%</td>' +
        '<td>' + r.utilization_rate.toFixed(1) + '%</td>' +
        '<td>¥' + r.unit_cost.toFixed(2) + '</td>' +
        '<td>' + r.availability_rate.toFixed(1) + '%</td>' +
        '<td>' + r.safety_score + '</td>' +
        '<td style="font-weight:700;color:var(--gold)">' + r.total_score.toFixed(2) + '</td>' +
        '<td>' + badge + '</td>' +
        '</tr>';
    }
    tableHtml += '</table>';
    container.innerHTML = tableHtml;
  }

  window.calculateKpi = async function() {
    var month = new Date().toISOString().slice(0,7);
    var result = await ledgerApi('/ledger/kpi/calculate', {method: 'POST', data: {year_month: month}});
    if (result) { alert(result.msg || '计算完成'); loadKpiList(); }
  };

  // ---- 阈值配置页面 ----
  window.openThresholdConfig = async function() {
    var container = document.getElementById('ledgerContent');
    if (!container) return;
    var data = await ledgerApi('/ledger/thresholds');
    var grouped = (data && data.grouped) || {};
    var vehicleTypes = ['履带挖掘机','装载机','轮式挖掘机','汽车吊','吊车'];
    var kpiLabels = {fuel_cost_per_unit:'燃油成本指标',repair_rate:'维修费用率',utilization_rate:'车辆利用率',unit_cost:'单位工时成本',availability_rate:'设备完好率',safety_score:'安全得分'};
    var kpiDesc = {fuel_cost_per_unit:'月燃油费 ÷ 出勤天数（元/天），越低越好',repair_rate:'月维修费 ÷ 车辆资产净值（%），越低越好',utilization_rate:'出勤天数 ÷ 26天制度台班（%），越高越好',unit_cost:'月总成本 ÷ 月总工时（元/h），越低越好',availability_rate:'(26天−维修天数) ÷ 26天（%），越高越好',safety_score:'100−事故次数×10，越高越好'};

    var html = '';
    for (var v = 0; v < vehicleTypes.length; v++) {
      var vt = vehicleTypes[v];
      var items = grouped[vt] || [];
      html += '<div class="card"><div class="card-title">' + vt + '</div><table><tr><th>KPI指标</th><th>说明</th><th>上限</th><th>下限</th><th>罚金</th><th>奖金</th></tr>';
      for (var j = 0; j < items.length; j++) {
        var item = items[j];
        html += '<tr><td><b>' + (kpiLabels[item.kpi_key] || item.kpi_key) + '</b></td>' +
          '<td style="font-size:11px;color:var(--text2)">' + (kpiDesc[item.kpi_key]||'') + '</td>' +
          '<td>' + (item.upper_limit||'-') + '</td><td>' + (item.lower_limit||'-') + '</td>' +
          '<td style="color:var(--danger)">¥' + item.penalty_amount + '</td>' +
          '<td style="color:var(--success)">¥' + item.reward_amount + '</td></tr>';
      }
      html += '</table></div>';
    }
    container.innerHTML = html;
  };

  // ---- 仪表盘汇总 ----
  async function loadLedgerSummary() {
    var container = document.getElementById('ledgerContent');
    if (!container) return;
    var month = new Date().toISOString().slice(0,7);
    var data = await ledgerApi('/ledger/summary?month=' + month);
    if (!data) { container.innerHTML = '<div class="empty">加载失败</div>'; return; }
    var rev = data.totalRevenue || 0, pf = data.totalProfit || 0;
    var pfColor = pf >= 0 ? 'var(--success)' : 'var(--danger)';
    container.innerHTML =
      '<div class="stats-grid">' +
        '<div class="stat-item"><div class="stat-num" style="color:var(--danger)">¥' + data.totalCost + '</div><div class="stat-label">本月总成本</div></div>' +
        '<div class="stat-item"><div class="stat-num" style="color:var(--gold)">¥' + rev + '</div><div class="stat-label">本月总收入</div></div>' +
        '<div class="stat-item"><div class="stat-num" style="color:' + pfColor + '">¥' + pf + '</div><div class="stat-label">本月盈亏</div></div>' +
        '<div class="stat-item"><div class="stat-num">' + data.approvedLedgers + '</div><div class="stat-label">已审批清单</div></div>' +
        '<div class="stat-item"><div class="stat-num">' + (data.hasKpi ? '✅' : '❌') + '</div><div class="stat-label">KPI状态</div></div>' +
      '</div>' +
      (data.hasKpi ? '' : '<div class="card" style="border-left:3px solid var(--warning);margin-top:14px"><span style="color:var(--warning)">⚠ KPI尚未计算，请先生成月度清单并审批后，在KPI排名页面点击"重新计算"</span></div>');
  }

  // ---- MutationObserver: 在管理员仪表盘渲染后注入卡片 ----
  var observer = new MutationObserver(function() {
    if (injectLedgerCard()) {
      // 持续观察，因为角色切换会重新渲染
    }
  });

  function startObserving() {
    var target = document.getElementById('mainPage');
    if (target) {
      observer.observe(target, { childList: true, subtree: true });
      // 立即尝试注入（如果仪表盘已渲染）
      setTimeout(function() { injectLedgerCard(); }, 300);
    } else {
      setTimeout(startObserving, 200);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', startObserving);
  } else {
    startObserving();
  }
})();
