const fs = require('fs');
let h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

const fnStart = h.indexOf('function showPartsRequisition()');
let fnEnd = h.indexOf('\nfunction showPartsManagement', fnStart);
if (fnEnd < 0) fnEnd = h.indexOf('\nfunction confirmPart', fnStart);
if (fnEnd < 0) fnEnd = h.indexOf('\nfunction showAdminVehicles', fnStart);
if (fnEnd < 0) {
  // Just find the closing brace of this function
  let brace = 0;
  for (let i = fnStart; i < h.length; i++) {
    if (h[i] === '{') brace++;
    if (h[i] === '}') { brace--; if (brace === 0) { fnEnd = i + 1; break; } }
  }
}

const newFn = `function showPartsRequisition() {
  Promise.all([api('/inspection/parts-list'), api('/vehicles')]).then(([parts, vehicles]) => {
    if (!parts||!parts.length) return alert('暂无可用配件');
    var vOpts = '<option value="">不指定车辆</option>'+(vehicles||[]).map(function(v){return '<option value="'+v.id+'">'+v.plate_number+'（'+(v.vehicle_type||'')+'）</option>';}).join('');
    showModal('配件领用申请', '<div class="form-group"><label>选择配件</label><select id="reqPartId">'+parts.map(function(p){return '<option value="'+p.id+'">'+p.part_name+' '+(p.part_code||'')+'（库存:'+p.quantity+(p.unit||'个')+'）</option>';}).join('')+'</select></div><div class="form-group"><label>领用车辆</label><select id="reqVehicleId">'+vOpts+'</select></div><div class="form-group"><label>数量</label><input id="reqQty" type="number" value="1" /></div><div class="form-group"><label>领用原因</label><textarea id="reqReason" placeholder="请说明领用原因..."></textarea></div>', async () => {
      const part_id = +document.getElementById('reqPartId').value;
      const vehicle_id = +document.getElementById('reqVehicleId').value || null;
      const quantity = +document.getElementById('reqQty').value;
      if (!quantity || quantity<1) { alert('数量至少为1'); return false; }
      const reason = document.getElementById('reqReason').value.trim();
      await api('/inspection/parts/requisition', {method:'POST', data:{part_id, vehicle_id, quantity, reason}});
      toast('申请已提交'); renderPage();
    });
  });
}`;

h = h.substring(0, fnStart) + newFn + h.substring(fnEnd);
fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', h, 'utf8');
console.log('Parts requisition updated with vehicle selection');
