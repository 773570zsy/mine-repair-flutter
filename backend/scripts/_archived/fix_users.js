const fs=require('fs');
let html=fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html','utf8');

// Add delete column header
html = html.replace('<th>角色</th>', '<th>角色</th><th>操作</th>');

// Add delete button to each row
const old = '<span class="tag t-progress">${ROLE_MAP[u.role]}</span></td></tr>';
const newStr = '<span class="tag t-progress">${ROLE_MAP[u.role]}</span></td><td><button class="btn btn-sm btn-d" onclick="delUser(${u.id},\'${u.name}\')">删除</button></td></tr>';
html = html.replace(old, newStr);

// Also fix colspan for empty state
html = html.replace('colspan="4">暂无', 'colspan="5">暂无');

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html',html,'utf8');
console.log('OK');
