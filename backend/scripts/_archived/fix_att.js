const fs = require('fs');
let h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

// 1. Replace the query button in showAttendanceReport
const oldBtn = '<button class="btn btn-p" onclick="loadAttendance()">查询</button>';
const newBtn = '<button class="btn btn-p" onclick="loadAttendance()">出勤工时</button> <button class="btn btn-o btn-sm" onclick="loadAttReport()">考勤加班</button>';
h = h.replace(oldBtn, newBtn);
console.log('Button:', h.includes(newBtn) ? 'OK' : 'NOT FOUND');

// 2. Add new functions before showAttendanceReport
const fnStart = h.indexOf('function showAttendanceReport()');
const newFuncs = `
function loadAttReport() {
  var month = document.getElementById('whMonth').value;
  var did = document.getElementById('whDriver')?.value;
  if (!month) return alert('请选择月份');
  api('/inspection/attendance/report?month='+month+(did?'&driver_id='+did:'')).then(function(data) {
    if (!data || !data.length) { document.getElementById('whContent').innerHTML = '<div class="empty">暂无数据</div>'; return; }
    var x = '<div style="margin-bottom:8px"><button class="btn btn-s btn-sm" onclick="expAttCSV()">导出考勤CSV</button> <button class="btn btn-o btn-sm" onclick="expOTCSV()">导出加班CSV</button></div>';
    x += '<table><tr><th>姓名</th><th>日期</th><th>考勤符号</th><th>加班小时</th><th>加班地点</th></tr>';
    data.forEach(function(r) {
      x += '<tr><td>' + r.driver_name + '</td><td>' + r.attendance_date + '</td><td>' + (r.attendance_symbol || '-') + '</td><td>' + (r.overtime_hours > 0 ? r.overtime_hours + 'h' : '-') + '</td><td>' + (r.overtime_location || '-') + '</td></tr>';
    });
    x += '</table>';
    document.getElementById('whContent').innerHTML = x;
    window._attData = data;
  });
}
function expAttCSV() {
  var d = window._attData; if (!d) return;
  var csv = '姓名,日期,考勤符号\\n';
  d.forEach(function(r) { csv += r.driver_name + ',' + r.attendance_date + ',' + (r.attendance_symbol || '-') + '\\n'; });
  var blob = new Blob([String.fromCharCode(0xFEFF) + csv], { type: 'text/csv;charset=utf-8' });
  var a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = '考勤记录.csv'; a.click();
}
function expOTCSV() {
  var d = window._attData; if (!d) return;
  var csv = '姓名,日期,加班小时,加班地点\\n';
  d.forEach(function(r) { csv += r.driver_name + ',' + r.attendance_date + ',' + r.overtime_hours + ',' + (r.overtime_location || '-') + '\\n'; });
  var blob = new Blob([String.fromCharCode(0xFEFF) + csv], { type: 'text/csv;charset=utf-8' });
  var a = document.createElement('a'); a.href = URL.createObjectURL(blob); a.download = '加班记录.csv'; a.click();
}
`;
h = h.substring(0, fnStart) + newFuncs + h.substring(fnStart);
console.log('Functions added');

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', h, 'utf8');
console.log('Done');
