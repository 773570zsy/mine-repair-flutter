const fs = require('fs');
let h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

// 1. Change label
h = h.replace('<div class="stat-label">维修工单</div>', '<div class="stat-label">进行中工单</div>');

// 2. Filter active orders only
const old = '${(orders||[]).length}';
const n = '${(()=>{var a=orders||[];return a.filter(function(o){return ["pending_accept","pending_quote","pending_approval","approved","repairing"].indexOf(o.status)>=0}).length})()}';
h = h.replace(old, n);

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', h, 'utf8');
console.log('Fixed');
