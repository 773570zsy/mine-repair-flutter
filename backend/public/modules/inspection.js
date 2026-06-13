// ==================== 点检模块 ====================

function showInspection(tab){tab=tab||'morning';
  Promise.all([api('/vehicles'),api('/inspection/driver-list')]).then(function(r){
    var vs=r[0]||[],ds=r[1]||[];
    var vOpts=vs.map(function(v){return '<option value="'+v.id+'">'+v.plate_number+'（'+(v.vehicle_type||'')+'）</option>'}).join('');
    var dOpts=ds.map(function(d){return '<option value="'+d.id+'">'+d.name+(USER.id===d.id?'（本人）':'')+'</option>'}).join('');
    var morningForm='<div class="form-group"><label>司机</label><select id="inspDriver">'+dOpts+'</select></div><div class="form-group"><label>车辆</label><select id="inspVehicle">'+vOpts+'</select></div><div class="row2"><div class="form-group"><label>机油液位</label><select id="inspOil"><option value="">请选择</option><option value="high">高位</option><option value="mid">中位</option><option value="low">低位</option></select></div><div class="form-group"><label>冷却液位</label><select id="inspCoolant"><option value="">请选择</option><option value="high">高位</option><option value="mid">中位</option><option value="low">低位</option></select></div></div><div class="row2"><div class="form-group"><label>外观</label><select id="inspAppear"><option value="">请选择</option><option value="normal">正常</option><option value="damaged">有损坏</option><option value="dirty">需清洁</option></select></div><div class="form-group"><label>轮胎</label><select id="inspTire"><option value="">请选择</option><option value="normal">正常</option><option value="worn">磨损</option><option value="damaged">损坏</option></select></div></div><div class="form-group"><label>随车九样物品</label><select id="inspToolkit"><option value="">请选择</option><option value="ok">齐全</option><option value="missing">缺失</option></select></div><div class="form-group"><label>整体状态</label><select id="inspStatus"><option value="normal">正常</option><option value="abnormal">异常</option></select></div><div class="form-group"><label>备注</label><textarea id="inspNotes"></textarea></div>';
    var eveningForm='<div class="form-group"><label>司机</label><select id="inspDriver2">'+dOpts+'</select></div><div class="form-group"><label>车辆</label><select id="inspVehicle2">'+vOpts+'</select></div><div class="row2"><div class="form-group"><label>上班启动工时(h)</label><input id="inspStartH" type="number" step="0.1" /></div><div class="form-group"><label>下班停车工时(h)</label><input id="inspEndH" type="number" step="0.1" /></div></div><div class="row2"><div class="form-group"><label>开始公里数(km)</label><input id="inspStartKm" type="number" step="0.1" /></div><div class="form-group"><label>下班公里数(km)</label><input id="inspEndKm" type="number" step="0.1" /></div></div><div class="form-group"><label>加油数量(L)</label><input id="inspFuel" type="number" step="0.1" /></div><div class="form-group"><label>停车地点</label><input id="inspParking" /></div><div style="background:rgba(200,160,74,.1);border:1px solid var(--gold);border-radius:6px;padding:10px 14px;margin-top:8px;font-size:12px;color:var(--gold-light)">⚠ 温馨提示：下班请将车辆停在安全的地方，锁好门窗，并关闭电源。</div>';
    var m=document.createElement('div');m.className='modal-mask';m.id='inspectionModal';
    m.innerHTML='<div class="modal" style="max-width:550px"><div class="flex" style="margin-bottom:16px"><h3>每日点检</h3><span style="display:flex;gap:8px"><button class="tab '+(tab==='morning'?'active':'')+'" onclick="switchInspTab(\'morning\')">☀ 早检</button><button class="tab '+(tab==='evening'?'active':'')+'" onclick="switchInspTab(\'evening\')">🌙 晚检</button></span></div><div id="inspFormContent">'+(tab==='morning'?morningForm:eveningForm)+'</div><div style="text-align:right;margin-top:16px;display:flex;gap:10px;justify-content:flex-end"><button class="btn" onclick="document.getElementById(\'inspectionModal\').remove()">取消</button><button class="btn btn-p" id="inspSubmitBtn" onclick="submitInspection(\''+tab+'\')">提交'+(tab==='morning'?'早检':'晚检')+'</button></div></div>';
    m.onclick=function(e){if(e.target===m)m.remove()};document.body.appendChild(m)
  })
}
function switchInspTab(tab){document.getElementById('inspectionModal').remove();showInspection(tab)}
async function submitInspection(tab){
  var id=tab==='morning'?'inspDriver':'inspDriver2',vid=tab==='morning'?'inspVehicle':'inspVehicle2';
  var driver_id=+document.getElementById(id)?.value||null,vehicle_id=+document.getElementById(vid)?.value||null;
  if(!vehicle_id){alert('请选择车辆');return}
  var label=tab==='morning'?'早检':'晚检';
  if(tab==='morning'){
    var d={vehicle_id:vehicle_id,driver_id:driver_id,oil_level:document.getElementById('inspOil').value,coolant_level:document.getElementById('inspCoolant').value,appearance:document.getElementById('inspAppear').value,tire_condition:document.getElementById('inspTire').value,toolkit_check:document.getElementById('inspToolkit').value,overall_status:document.getElementById('inspStatus').value,notes:document.getElementById('inspNotes')?.value?.trim()||''};
    var r=await api('/inspection/morning-check',{method:'POST',data:d});if(r){toast('✓ '+label+'提交成功');document.getElementById('inspectionModal')?.remove();renderPage()}
  }else{
    var d2={vehicle_id:vehicle_id,driver_id:driver_id,start_hours:parseFloat(document.getElementById('inspStartH')?.value)||0,end_hours:parseFloat(document.getElementById('inspEndH')?.value)||0,start_km:parseFloat(document.getElementById('inspStartKm')?.value)||0,end_km:parseFloat(document.getElementById('inspEndKm')?.value)||0,fuel_amount:parseFloat(document.getElementById('inspFuel')?.value)||0,parking_location:document.getElementById('inspParking')?.value?.trim()||''};
    var r2=await api('/inspection/evening-check',{method:'POST',data:d2});if(r2){toast('✓ '+label+'提交成功');document.getElementById('inspectionModal')?.remove();renderPage()}
  }
}

// ==================== 点检详情查看（历史追溯 + 照片）====================
async function showInspectionDetail(recordId) {
  var records = await api('/inspection/all-records?pageSize=500');
  var r = (records || []).find(function(x) { return x.id === recordId; });
  if (!r) { alert('记录不存在'); return; }
  var isMorning = r.start_hours === undefined || r.start_hours === null;
  var lm = { normal: '正常', low: '偏低', empty: '需补充' };
  var h = '<div style="font-size:14px">';
  h += '<div><b>车辆：</b>' + r.plate_number + '（' + (r.vehicle_type || '') + '）</div>';
  h += '<div><b>检查人：</b>' + (r.driver_name || '-') + ' | <b>日期：</b>' + (r.inspection_date || '-') + '</div>';
  h += '<div><b>类型：</b>' + (isMorning ? '☀ 早检' : '🌙 晚检') + '</div>';
  if (isMorning) {
    h += '<div style="margin-top:6px"><b>机油：</b>' + (lm[r.oil_level] || '-') + ' | <b>冷却液：</b>' + (lm[r.coolant_level] || '-') + '</div>';
    h += '<div><b>外观：</b>' + (r.appearance === 'damaged' ? '有损坏' : r.appearance === 'dirty' ? '需清洁' : '正常') + ' | <b>轮胎：</b>' + (r.tire_condition === 'worn' ? '磨损' : r.tire_condition === 'damaged' ? '损坏' : '正常') + '</div>';
    h += '<div><b>随车九样：</b>' + (r.toolkit_check === 'ok' ? '✅ 齐全' : '❌ 缺失') + ' | <b>整体状态：</b>' + (r.overall_status === 'normal' ? '正常' : '异常') + '</div>';
    if (r.engine_hours) h += '<div><b>发动机工时：</b>' + r.engine_hours + ' h</div>';
  } else {
    h += '<div style="margin-top:6px"><b>工时：</b>' + (r.start_hours || 0) + 'h → ' + (r.end_hours || 0) + 'h = ' + ((r.end_hours || 0) - (r.start_hours || 0)).toFixed(1) + 'h</div>';
    if (r.start_km || r.current_km) h += '<div><b>公里：</b>' + (r.start_km || 0) + 'km → ' + (r.current_km || 0) + 'km = ' + ((r.current_km || 0) - (r.start_km || 0)).toFixed(1) + 'km</div>';
    h += '<div><b>加油：</b>' + (r.fuel_amount || 0) + ' L | <b>停车：</b>' + (r.parking_location || '-') + '</div>';
  }
  if (r.notes) h += '<div style="margin-top:6px"><b>备注：</b>' + r.notes + '</div>';
  if (r.abnormal_desc) h += '<div style="margin-top:6px;padding:8px;background:rgba(224,85,85,.1);border-radius:4px"><b>⚠ 异常说明：</b>' + r.abnormal_desc + '</div>';
  // 照片追溯
  var imgs = []; try { imgs = JSON.parse(r.photos || '[]'); } catch(e) {}
  if (imgs.length) {
    h += '<div style="margin-top:10px"><b>📸 现场照片：</b></div><div style="display:flex;gap:4px;flex-wrap:wrap;margin-top:4px">';
    imgs.forEach(function(u, i) {
      h += '<img src="' + u + '" style="width:80px;height:80px;object-fit:cover;border-radius:4px;cursor:pointer;border:1px solid var(--border)" onclick="event.stopPropagation();showFaultPhotos(' + JSON.stringify(imgs) + ',' + i + ')" />';
    });
    h += '</div>';
  } else {
    h += '<div style="margin-top:10px;color:var(--text2);font-size:12px">📷 无现场照片</div>';
  }
  h += '</div>';
  showModal('📋 点检详情', h);
}
