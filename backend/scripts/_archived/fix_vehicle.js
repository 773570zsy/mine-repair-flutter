const fs = require('fs');
let html = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

// Simplified vehicle table header (no driver or operation)
const oldHdr = '<table><tr><th>车牌号</th><th>类型</th><th>保养间隔</th><th>驾驶员</th><th>操作</th></tr>';
const newHdr = '<table><tr><th>车牌号</th><th>类型</th><th>型号</th><th>保养间隔</th></tr>';
html = html.replace(oldHdr, newHdr);

// Simplified vehicle table rows (only plate, type, model, hours)
// Remove the driver column and bind button from each row
html = html.replace(/\$\{v\.driver_name\|\|'<span style="color:#999">未分配<\/span>'\}<\/td>\s*<td>(.|\n)*?<\/tr>/g, function(match) {
  // Extract what we need before the driver_name part
  return '${v.maintenance_interval_hours||\'\'-\'}h</td></tr>';
});

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', html, 'utf8');
console.log('done');
