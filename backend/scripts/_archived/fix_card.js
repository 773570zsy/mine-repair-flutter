const fs = require('fs');
let h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

const fnStart = h.indexOf('function loadAttendanceCard()');
let fnEnd = h.indexOf('\nfunction submitAttendance');
if (fnEnd < 0) fnEnd = h.indexOf('function submitAttendance');

const newFn = `function loadAttendanceCard() {
  api('/inspection/attendance/today').then(function(r) {
    var rec = r || {};
    var sym = rec.attendance_symbol || '';
    var attOpts = ['','X','Y','Z','V','G','△','△/X','△/Y','△/Z','△/V'].map(function(s){return '<option value="'+s+'"'+(s===sym?' selected':'')+'>'+(s||'请选择')+'</option>';}).join('');

    var ael = document.getElementById('attCard');
    if (sym) {
      ael.innerHTML = '<div class="tag t-done" style="font-size:14px">✓ 已提交: '+sym+'</div>';
    } else {
      ael.innerHTML = '<select id="attSymbol" style="margin-bottom:8px">'+attOpts+'</select><br><button class="btn btn-p btn-sm" onclick="submitAttendance()">提交考勤</button>';
    }

    var oel = document.getElementById('otCard');
    if (rec.overtime_hours) {
      var otInfo = '✓ 已提交: '+rec.overtime_hours+'h';
      if (rec.overtime_start) otInfo += '<br><small style="color:var(--text2)">'+rec.overtime_start+' → '+rec.overtime_end+'</small>';
      oel.innerHTML = '<div class="tag t-done" style="font-size:14px">'+otInfo+'</div>';
    } else {
      oel.innerHTML = '<div class="row2" style="margin-bottom:8px"><input id="otStart" type="time" value="'+(rec.overtime_start||'')+'" /><input id="otEnd" type="time" value="'+(rec.overtime_end||'')+'" /></div><input id="otLocation" placeholder="加班地点" value="'+(rec.overtime_location||'')+'" style="margin-bottom:8px" /><br><button class="btn btn-p btn-sm" onclick="submitAttendance()">提交加班</button>';
    }
  });
}`;

h = h.substring(0, fnStart) + newFn + h.substring(fnEnd);
fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', h, 'utf8');
console.log('Attendance card rewritten');
