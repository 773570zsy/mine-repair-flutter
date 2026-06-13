const fs = require('fs');
let h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

const fnStart = h.indexOf('function submitAttendance');
let fnEnd = h.indexOf('function updateClock', fnStart);
if (fnEnd < 0) fnEnd = h.indexOf('\nfunction', fnStart + 30);

const newFn = `function submitAttendance() {
  var sym = document.getElementById('attSymbol')?.value || '';
  var otS = document.getElementById('otStart')?.value || '';
  var otE = document.getElementById('otEnd')?.value || '';
  var loc = document.getElementById('otLocation')?.value?.trim() || '';
  api('/inspection/attendance/submit', {method:'POST', data:{attendance_symbol:sym, overtime_start:otS, overtime_end:otE, overtime_location:loc}}).then(function() {
    toast('提交成功'); loadAttendanceCard();
  });
}`;

h = h.substring(0, fnStart) + newFn + '\n' + h.substring(fnEnd);
fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', h, 'utf8');
console.log('Submit function fixed', fnStart, fnEnd);
