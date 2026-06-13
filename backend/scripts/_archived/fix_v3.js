const fs = require('fs');
let h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

// Find showAdminVehicles function
const fnStart = h.indexOf('function showAdminVehicles()');
let fnEnd = h.indexOf('\nfunction showRepairShops', fnStart);
if (fnEnd < 0) fnEnd = h.indexOf('\nfunction doImportVehicles', fnStart);

console.log('fnStart:', fnStart, 'fnEnd:', fnEnd);

// Clean replacement with individual form fields
const cleanFn = `function showAdminVehicles() {
  api('/vehicles').then(function(vs) {
    var t = '<table><tr><th>内部编号</th><th>类型</th><th>型号</th><th>车龄</th><th>工时</th><th>保养间隔</th><th>操作</th></tr>';
    for (var i = 0; i < vs.length; i++) {
      var v = vs[i];
      var age = v.purchase_date ? ((new Date() - new Date(v.purchase_date)) / (365.25 * 86400000)).toFixed(1) + '年' : '-';
      t += '<tr>';
      t += '<td><b>' + v.plate_number + '</b></td>';
      t += '<td>' + (v.vehicle_type || '-') + '</td>';
      t += '<td>' + (v.model || '-') + '</td>';
      t += '<td>' + age + '</td>';
      t += '<td>' + (v.latest_end_hours || v.initial_engine_hours || 0) + 'h</td>';
      t += '<td>' + (v.maintenance_interval_hours || '-') + 'h</td>';
      t += '<td style="white-space:nowrap">';
      t += '<button class="btn btn-sm btn-s" onclick="maintenanceDone(' + v.id + ',\\'' + v.plate_number + '\\')">保养完成</button> ';
      t += '<button class="btn btn-sm btn-d" onclick="delVehicle(' + v.id + ',\\'' + v.plate_number + '\\')">删除</button>';
      t += '</td></tr>';
    }
    t += '</table>';
    var form = '<div><div class="row2"><div class="form-group"><label>内部编号</label><input id="vPlate" /></div><div class="form-group"><label>类型</label><input id="vType" /></div></div>';
    form += '<div class="row2"><div class="form-group"><label>型号</label><input id="vModel" /></div><div class="form-group"><label>购买日期</label><input id="vDate" type="date" /></div></div>';
    form += '<div class="row2"><div class="form-group"><label>初始工时(h)</label><input id="vHours" type="number" value="0" /></div><div class="form-group"><label>保养间隔(h)</label><input id="vInterval" type="number" value="500" /></div></div>';
    form += '<button class="btn btn-p btn-sm" onclick="addSingleVehicle()" style="margin-bottom:12px">+ 添加车辆</button></div>';
    showModal('车辆管理', form + '<div style="margin-top:12px;max-height:400px;overflow:auto">' + t + '</div>');
  });
}

function addSingleVehicle() {
  var pn = document.getElementById('vPlate').value.trim();
  if (!pn) return alert('请输入内部编号');
  var v = {
    plate_number: pn,
    vehicle_type: document.getElementById('vType').value.trim(),
    model: document.getElementById('vModel').value.trim(),
    purchase_date: document.getElementById('vDate').value,
    initial_engine_hours: parseInt(document.getElementById('vHours').value) || 0,
    maintenance_interval_hours: parseInt(document.getElementById('vInterval').value) || 500
  };
  api('/admin/vehicles/import', {method: 'POST', data: {vehicles: [v]}}).then(function() {
    alert('添加成功');
    document.querySelectorAll('.modal-mask').forEach(function(m){m.remove()});
    renderPage();
  });
}`;

let result = h.substring(0, fnStart) + cleanFn + '\n' + h.substring(fnEnd);
fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', result, 'utf8');
console.log('Done - replaced with individual fields form');
