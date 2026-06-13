const fs = require('fs');
let h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

// Find the overtime card HTML in loadAttendanceCard
const idx = h.indexOf('var oe = document.getElementById');
const ctx = h.substring(idx, idx + 500);
console.log('OT card HTML:', ctx);

// Replace the entire line that creates the overtime card
const oldLine = h.substring(idx, h.indexOf('\n  });', idx));
const newLine = `var oe = document.getElementById('otCard');
    if (oe) oe.innerHTML = '<div class="row2" style="margin-bottom:8px"><input id="otStart" type="time" value="'+(rec.overtime_start||'')+'" /><input id="otEnd" type="time" value="'+(rec.overtime_end||'')+'" /></div><input id="otLocation" placeholder="加班地点" value="'+(rec.overtime_location||'')+'" style="margin-bottom:8px" /><br><button class="btn btn-p btn-sm" onclick="submitAttendance()">提交加班</button>'+(rec.overtime_hours?' <span class="tag t-done">已提交:'+rec.overtime_hours+'h</span>':'')`;

h = h.substring(0, idx) + newLine + h.substring(h.indexOf('\n  });', idx));
fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', h, 'utf8');
console.log('OT card fixed');
