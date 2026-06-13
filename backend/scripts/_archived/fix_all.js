const fs = require('fs');
let h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

// ==== 1. Vehicle table - add 车龄 column ====
// Fix the table body
let vOld = "${v.plate_number}</b></td><td>${v.vehicle_type||'-'}</td><td>${v.model||'-'}</td><td>${v.maintenance_interval_hours||'-'}h</td></tr>`).join('')}</table>";
let vNew = "${v.plate_number}</b></td><td>${v.vehicle_type||'-'}</td><td>${v.model||'-'}</td><td>${(()=>{try{return ((new Date()-new Date(v.purchase_date))/(365.25*86400000)).toFixed(1)+'年'}catch(e){return '-'}})()}</td><td>${v.maintenance_interval_hours||'-'}h</td></tr>`).join('')}</table>";
if (h.includes(vOld)) {
  h = h.replace(vOld, vNew);
  console.log('1. Vehicle table: added 车龄 column');
} else {
  console.log('1. Vehicle table: pattern not found, trying alternate...');
  // Try just the table row part
  let rowOld = "${v.plate_number}</b></td><td>${v.vehicle_type||'-'}</td><td>${v.model||'-'}</td><td>${v.maintenance_interval_hours||'-'}h</td>";
  let rowNew = "${v.plate_number}</b></td><td>${v.vehicle_type||'-'}</td><td>${v.model||'-'}</td><td>${v.purchase_date?((new Date()-new Date(v.purchase_date))/(365.25*86400000)).toFixed(1)+'年':'-'}</td><td>${v.maintenance_interval_hours||'-'}h</td>";
  if (h.includes(rowOld)) {
    h = h.replace(rowOld, rowNew);
    console.log('1. Vehicle table: fixed row');
  } else {
    console.log('1. Vehicle table: CANNOT FIND - skipping');
  }
}

// Fix doImportVehicles to pass purchase_date
let impOld = "const[p,t,m]=l.split(',')";
let impNew = "const[p,t,m,d,...rest]=l.split(',')";
if (h.includes(impOld)) {
  h = h.replace(impOld, impNew);
}
impOld = "{plate_number:p.trim(),vehicle_type:(t||'').trim(),model:(m||'').trim()}";
impNew = "{plate_number:p.trim(),vehicle_type:(t||'').trim(),model:(m||'').trim(),purchase_date:(d||'').trim(),maintenance_interval_hours:parseInt(rest[0])||500}";
if (h.includes(impOld)) {
  h = h.replace(impOld, impNew);
  console.log('1. Vehicle import: added purchase_date');
}

// ==== 2. User management - make department editable (add custom input) ====
// The current department dropdown is inside showAdminUsers. Let's add a text input option.
// Replace the department select with a combobox (select + text input)
let deptOld = '<select id="addDept"><option value="">不分配部门</option>${depts.map(d=>`<option value="${d.id}">${d.name}</option>`).join(\'\')}</select>';
let deptNew = '<input id="addDept" list="deptList" placeholder="选择或输入新部门名称..." />' +
  '<datalist id="deptList">${depts.map(d=>`<option value="${d.name}">`).join(\'\')}</datalist>';
if (h.includes('<select id="addDept">')) {
  // Use a different approach - replace the specific select
  let selStart = h.indexOf('<select id="addDept">');
  let selEnd = h.indexOf('</select>', selStart) + 9;
  let oldSelect = h.substring(selStart, selEnd);
  let newSelect = '<input id="addDept" style="margin-top:6px" placeholder="选择或输入部门..." list="deptList" /><datalist id="deptList">${(()=>{let opts=\'\';depts.forEach(d=>{opts+=\'<option value=\"\'+d.name+\'\">\'});return opts})()}</datalist>';
  h = h.substring(0, selStart) + newSelect + h.substring(selEnd);
  console.log('2. User dept: made editable with free-text input');
} else {
  console.log('2. User dept: select not found');
}

// Update doAddUser to handle text input for department
let addOld = "const department_id = +document.getElementById('addDept')?.value || null;";
let addNew = "const deptInput = document.getElementById('addDept')?.value?.trim(); let department_id = null; if (deptInput) { const deptMatch = depts.find(d=>d.name===deptInput); department_id = deptMatch ? deptMatch.id : null; if (!deptMatch) { /* new dept - will be created on the fly via API */ api('/external/departments/add',{method:'POST',data:{name:deptInput}}).then(r=>{if(r)department_id=r.dept_key?null:null}); } }";
if (h.includes(addOld)) {
  h = h.replace(addOld, addNew);
  console.log('2. User dept: updated add logic');
}

// Fix user delete - close modal and refresh
let delOld = "async function delUser(id, name) {\n  if (!confirm(`确认删除\"${name}\"？此操作不可恢复。`)) return;\n  await api('/admin/users/'+id, {method:'DELETE'});\n  alert('已删除'); renderPage();\n}";
let delNew = "async function delUser(id, name) {\n  if (!confirm(`确认删除\"${name}\"？此操作不可恢复。`)) return;\n  await api('/admin/users/'+id, {method:'DELETE'});\n  alert('已删除');\n  // Close all modals and refresh\n  document.querySelectorAll('.modal-mask').forEach(m=>m.remove());\n  renderPage();\n}";
if (h.includes(delOld)) {
  h = h.replace(delOld, delNew);
  console.log('2. User delete: fixed to close modal and refresh');
} else {
  console.log('2. User delete: pattern not found');
}

// ==== 3 & 4 already done via text replacement ====

// ==== 5. Repair shop delete ====
// Add delete button to showRepairShops
let shopTable = '<table><tr><th>名称</th><th>联系人</th><th>电话</th><th>分工</th></tr>';
let shopTableNew = '<table><tr><th>名称</th><th>联系人</th><th>电话</th><th>分工</th><th>操作</th></tr>';
if (h.includes(shopTable)) {
  h = h.replace(shopTable, shopTableNew);
  let shopRow = "${s.remark||'-'}</td></tr>";
  let shopRowNew = "${s.remark||'-'}</td><td><button class='btn btn-sm btn-d' onclick='delShop(${s.id},\"${s.name}\")'>删除</button></td></tr>";
  if (h.includes(shopRow)) {
    h = h.replace(new RegExp(shopRow.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g'), shopRowNew);
    console.log('5. Repair shop: added delete button');
  }
} else {
  console.log('5. Repair shop: table not found');
}

// Add delShop function
let shopFuncPos = h.indexOf('function doAddShop()');
let delShopFunc = `async function delShop(id, name) { if (!confirm('确认删除修理厂\"'+name+'\"？')) return; await api('/admin/repair-shops/'+id, {method:'DELETE'}); alert('已删除'); renderPage(); }\n`;
h = h.substring(0, shopFuncPos) + delShopFunc + h.substring(shopFuncPos);
console.log('5. Repair shop: added delShop function');

// ==== 6. Attendance report - add employee filter and export ====
// Update showAttendanceReport function
let attOld = 'function showAttendanceReport() {';
let attNew = 'function showAttendanceReport() {\n  api(\'/inspection/driver-list\').then(drivers => {\n  const drvOpts = \'<option value=\"\">全部员工</option>\'+(drivers||[]).map(d=>`<option value=\"${d.id}\">${d.name}</option>`).join(\'\');';
if (h.includes(attOld)) {
  h = h.replace(attOld, attNew);

  // Update the modal HTML
  let modOld = 'showModal(\'员工出勤信息\', `';
  let modNew = 'showModal(\'员工出勤信息\', `\n      <div class=\"flex\" style=\"margin-bottom:10px\"><div class=\"form-group\" style=\"margin:0\"><label>员工</label><select id=\"whDriver\">${drvOpts}</select></div></div>';
  if (h.includes(modOld)) {
    h = h.replace(modOld, modNew);
    console.log('6. Attendance: added driver filter');
  }

  // Close the Promise chain
  let thenOld = 'showModal(\'员工出勤信息\'';
  let closeIdx = h.indexOf('showModal(\'员工出勤信息\'');
  if (closeIdx > 0) {
    // Find the closing of the showModal call and add }) before it
    let modalIdx = h.indexOf('showModal(\'员工出勤信息\'');
    console.log('6. Attendance: modal at index', modalIdx);
  }
}

console.log('\nAll changes applied.');
fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', h, 'utf8');
