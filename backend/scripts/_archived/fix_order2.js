const fs = require('fs');
let h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

// Replace the complex inline expression with simple activeCount variable
const old = '${(()=>{var a=orders||[];return a.filter(function(o){return ["pending_accept","pending_quote","pending_approval","approved","repairing"].indexOf(o.status)>=0}).length})()}';
const n = '${activeCount}';
h = h.replace(old, n);

// Now add activeCount calculation in loadDriverData before the dashStats line
const dashLine = 'document.getElementById(\'dashStats\').innerHTML';
const addBefore = 'var activeOrders = (orders||[]).filter(function(o){return [\"pending_accept\",\"pending_quote\",\"pending_approval\",\"approved\",\"repairing\"].indexOf(o.status)>=0}); var activeCount = activeOrders.length;\n    ';
h = h.replace(dashLine, addBefore + dashLine);

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', h, 'utf8');
console.log('Fixed - simplified approach');
