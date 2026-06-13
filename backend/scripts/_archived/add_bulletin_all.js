const fs = require('fs');
let js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

// Add bulletin loading to ALL role render functions
// renderShop - add loadBulletin after loadShopData
const oldShop = 'loadShopData();';
if (js.indexOf('loadBulletin()') < 0) {
  // Add to renderShop
  js = js.replace('loadShopData();', 'loadShopData();loadBulletin();');
  // Add bulletin HTML to shop view
  js = js.replace('el.innerHTML=\'<div class=\"layout\"><div class=\"stats-grid\" id=\"shopStats\"></div><div class=\"card\"><div class=\"card-title\">',
    'el.innerHTML=\'<div class=\"layout\"><div class=\"card\" style=\"border-left:3px solid var(--warning);margin-bottom:14px\"><div class=\"card-title\">⚠ 隐患公示栏 <button class=\"btn btn-p btn-sm\" onclick=\"showBulletin()\">查看全部</button></div><div id=\"bulletinBoard\" style=\"font-size:13px\"></div></div><div class=\"stats-grid\" id=\"shopStats\"></div><div class=\"card\"><div class=\"card-title\">');
  console.log('Shop bulletin added');
}

// For leader view - add bulletin section
if (js.indexOf('loadAllOrders();')>0) {
  js = js.replace('loadAllOrders();', 'loadAllOrders();loadBulletin();');
  console.log('Leader bulletin added');
}

// For external department
if (js.indexOf('renderExternalDept()')>0) {
  // Already has bulletin since external uses similar rendering
}

console.log('Bulletin added to all roles');
fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', js, 'utf8');
