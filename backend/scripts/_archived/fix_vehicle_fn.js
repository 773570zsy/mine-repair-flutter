// Generate the showAdminVehicles function code and insert into HTML
const fs = require('fs');
const h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

const fnStart = h.indexOf('function showAdminVehicles()');
const fnEnd = h.indexOf('function doImportVehicles', fnStart);

let cleanFn = `function showAdminVehicles() {
  api('/vehicles').then(function(vs) {
    var t = '<table><tr><th>内部编号</th><th>类型</th><th>型号</th><th>车龄</th><th>保养间隔</th><th>操作</th></tr>';
    for (var i = 0; i < vs.length; i++) {
      var v = vs[i];
      var a = v.purchase_date ? ((new Date() - new Date(v.purchase_date)) / (365.25 * 86400000)).toFixed(1) + '年' : '-';
      t += '<tr><td><b>' + v.plate_number + '</b></td>';
      t += '<td>' + (v.vehicle_type || '-') + '</td>';
      t += '<td>' + (v.model || '-') + '</td>';
      t += '<td>' + a + '</td>';
      t += '<td>' + (v.maintenance_interval_hours || '-') + 'h</td>';
      t += '<td>';
      t += '<button class="btn btn-sm btn-s" onclick="event.stopPropagation();maintenanceDone(' + v.id + ',\\'' + v.plate_number + '\\')">保养完成</button> ';
      t += '<button class="btn btn-sm btn-d" onclick="event.stopPropagation();delVehicle(' + v.id + ',\\'' + v.plate_number + '\\')">删除</button>';
      t += '</td></tr>';
    }
    t += '</table>';
    showModal('车辆管理',
      '<div class="form-group"><label>批量导入（每行：内部编号,类型,型号,购买日期,初始工时,保养间隔小时）</label><textarea id="importVeh" rows="4" placeholder="001,挖掘机,小松PC360,2024-03-15,5000,500"></textarea></div>' +
      '<button class="btn btn-p btn-sm" onclick="doImportVehicles()" style="margin-bottom:12px">导入</button>' + t
    );
  });
}`;

const result = h.substring(0, fnStart) + cleanFn + '\n' + h.substring(fnEnd);
fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', result, 'utf8');
console.log('Vehicle function replaced successfully');
