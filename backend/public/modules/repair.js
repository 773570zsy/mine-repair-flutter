// ==================== 维修模块：报修 / 报价 / 审批 ====================

function showReport(){
  Promise.all([api('/vehicles'), api('/repair/shops')]).then(function(results){
    var vs=results[0], shops=results[1]||[];
    var vOpts=vs.map(function(v){return '<option value="'+v.id+'">'+v.plate_number+'（'+(v.vehicle_type||'')+'）</option>'}).join('');
    var sOpts='<option value="">不限（通知所有修理厂）</option>';
    if(shops.length) sOpts+=shops.map(function(s){return '<option value="'+s.id+'">'+s.name+'</option>'}).join('');
    showModal('故障报修',
      '<div class="form-group"><label>车辆</label><select id="rptVehicle">'+vOpts+'</select></div>'+
      '<div class="form-group"><label>修理厂</label><select id="rptShop">'+sOpts+'</select></div>'+
      '<div class="form-group"><label>故障描述</label><textarea id="rptDesc"></textarea></div>',
    async function(mask){
      var vid=+document.getElementById('rptVehicle').value;
      var sid=+document.getElementById('rptShop').value||null;
      var desc=document.getElementById('rptDesc').value.trim();
      if(!desc){alert('请填写故障描述');return false}
      await api('/repair/report',{method:'POST',data:{vehicle_id:vid,fault_description:desc,repair_shop_id:sid,fault_images:window._rptPhotoUrls||[]}});
      toast('报修成功');mask.remove();renderPage()
    })
  })
}
async function showOrderDetail(id){
  var data=await api('/repair/detail/'+id);if(!data)return;
  var o=data.order,p=data.progress||[];
  var tl=p.map(function(x){return '<div class="tl-item"><div><b>'+actionName(x.action)+'</b> <span style="color:var(--text2);font-size:11px">'+(x.created_at||'').slice(0,16)+'</span></div><div style="font-size:12px">'+(x.content||'')+' — '+(x.user_name||'')+'</div></div>'}).join('');
  var m=document.createElement('div');m.className='modal-mask';
  m.innerHTML='<div class="modal" style="max-width:600px"><div class="flex" style="margin-bottom:12px"><h3>工单详情</h3><button class="btn" onclick="this.closest(\'.modal-mask\').remove()">✕</button></div><div class="flex"><span class="order-no" style="font-size:16px">'+o.order_no+'</span>'+'<span class="tag '+ST_TAG[o.status]+'">'+STATUS_MAP[o.status]+'</span></div><div style="margin-top:10px;font-size:13px"><div><b>车辆：</b>'+o.plate_number+'（'+(o.vehicle_type||'')+'/'+(o.model||'-')+'）</div><div><b>报修部门：</b>'+(o.dept_name||'总调度室')+' | <b>报修人：</b>'+o.driver_name+' '+(o.driver_phone||'')+'</div><div><b>修理厂：</b>'+(o.repair_shop_name||'待接单')+'</div><div><b>故障描述：</b>'+(o.fault_description||'')+'</div>'+'<div class="fault-photos" style="display:flex;gap:4px;flex-wrap:wrap;margin-top:4px"></div>'+'<script>setTimeout(function(){var imgs;try{imgs='+(o.fault_images||'[]')+'}catch(e){imgs=[]};if(imgs.length){var el=document.querySelector(".fault-photos");if(el){imgs.forEach(function(u){var i=document.createElement("img");i.src=u;i.style.cssText="width:60px;height:60px;object-fit:cover;border-radius:4px;margin:2px;cursor:pointer";i.onclick=function(){showFaultPhotos(imgs)};el.appendChild(i)})}}},200)<\/script>'+((o.quote_amount)?'<div style="margin-top:8px;padding:10px;background:rgba(200,160,74,.08);border-radius:6px"><b>报价：</b>¥'+o.quote_amount+'<br>'+(o.quote_detail||'')+'<br>预计'+(o.estimated_days||'?')+'天<br><span style="font-size:12px;color:var(--text2)">配件费: ¥'+(o.parts_cost||0)+' | 人工费: ¥'+(o.labor_cost||0)+' | 工时费: ¥'+(o.hours_cost||0)+'</span>'+'<div class="quote-dmg-photos" style="display:flex;gap:4px;flex-wrap:wrap;margin-top:8px"></div>'+'<script>setTimeout(function(){var imgs;try{imgs='+(o.damage_photos||'[]')+'}catch(e){imgs=[]};if(imgs.length){var el=document.querySelector(".quote-dmg-photos");var lb=document.createElement("div");lb.textContent="🔧 损坏配件";lb.style.cssText="width:100%;font-size:11px;color:var(--text2);margin-bottom:2px";el.before(lb);imgs.forEach(function(u){var i=document.createElement("img");i.src=u;i.style.cssText="width:60px;height:60px;object-fit:cover;border-radius:4px;margin:2px;cursor:pointer;border:1px solid var(--border)";i.onclick=function(){showFaultPhotos(imgs)};el.appendChild(i)})}},200)<\/script>'+'<div class="quote-new-photos" style="display:flex;gap:4px;flex-wrap:wrap;margin-top:4px"></div>'+'<script>setTimeout(function(){var imgs;try{imgs='+(o.new_photos||'[]')+'}catch(e){imgs=[]};if(imgs.length){var el=document.querySelector(".quote-new-photos");var lb=document.createElement("div");lb.textContent="🆕 新配件";lb.style.cssText="width:100%;font-size:11px;color:var(--text2);margin-bottom:2px";el.before(lb);imgs.forEach(function(u){var i=document.createElement("img");i.src=u;i.style.cssText="width:60px;height:60px;object-fit:cover;border-radius:4px;margin:2px;cursor:pointer;border:1px solid var(--border)";i.onclick=function(){showFaultPhotos(imgs)};el.appendChild(i)})}},200)<\/script>'+'</div>':'')+'</div>'+(o.status==='completed'?(USER.role==='driver'?'<div style="margin-top:12px;padding:12px;background:rgba(90,158,95,.1);border:1px solid var(--success);border-radius:8px;text-align:center"><p style="font-size:13px;color:var(--text2);margin-bottom:8px">维修已完工，请确认验收</p><button class="btn btn-s" style="font-size:16px;padding:10px 32px" onclick="acceptCompletedOrder('+o.id+')">✅ 验收通过</button></div>':(USER.role==='repair_shop'?'<div style="margin-top:12px;padding:12px;background:rgba(200,160,74,.08);border:1px solid var(--gold);border-radius:8px;text-align:center"><p style="font-size:13px;color:var(--text2);margin-bottom:8px">等待驾驶员验收</p><button class="btn btn-p btn-sm" onclick="notifyDriverAccept('+o.id+',\''+(o.driver_name||'驾驶员')+'\')">📢 通知驾驶员验收</button></div>':'')):'')+'<div class="card-title">进度</div><div class="timeline">'+(tl||'暂无')+'</div></div>';
  m.onclick=function(e){if(e.target===m)m.remove()};document.body.appendChild(m)
}
async function acceptOrder(id){await api('/repair/accept-order/'+id,{method:'POST'});toast('已接单');renderPage()}
async function showQuote(id,isReQuote){
  // 驳回重报价：先获取旧报价数据回填
  var prevData={};
  if(isReQuote){
    var detail=await api('/repair/detail/'+id);
    if(detail&&detail.order){
      var o=detail.order;
      prevData.partsCost=o.parts_cost||0;
      prevData.laborCost=o.labor_cost||0;
      prevData.hoursCost=o.hours_cost||0;
      prevData.quoteDetail=o.quote_detail||'';
      prevData.estimatedDays=o.estimated_days||'';
      try{prevData.partsList=JSON.parse(o.parts_list||'[]')}catch(e){prevData.partsList=[]}
    }
  }
  var partsRows='';
  var partsInit=prevData.partsList||[];
  if(!partsInit.length)partsInit=[{name:'',qty:'',price:''}];
  partsInit.forEach(function(p,i){
    partsRows+='<div class="flex" style="margin-bottom:4px"><input id="partName'+i+'" placeholder="配件名称" style="flex:2" value="'+(p.name||'')+'" /><input id="partQty'+i+'" placeholder="数量" type="number" style="flex:1;margin:0 4px" value="'+(p.qty||'')+'" /><input id="partPrice'+i+'" placeholder="单价" type="number" style="flex:1" value="'+(p.price||'')+'" /></div>';
  });
  window._partRowCount=partsInit.length;
  showModal((isReQuote?'重新报价':'提交报价'),'<div class="form-group"><label>配件清单</label><div id="partsContainer">'+partsRows+'</div><button class="btn btn-o btn-sm" onclick="addPartRow()" style="margin-top:6px">+ 添加配件</button></div><div class="row2"><div class="form-group"><label>配件总费用</label><input id="quoteParts" type="number" value="'+(prevData.partsCost||0)+'" onchange="updateQuoteTotal()" /></div><div class="form-group"><label>人工费</label><input id="quoteLabor" type="number" value="'+(prevData.laborCost||0)+'" onchange="updateQuoteTotal()" /></div></div><div class="row2"><div class="form-group"><label>工时费</label><input id="quoteHoursCost" type="number" value="'+(prevData.hoursCost||0)+'" onchange="updateQuoteTotal()" /></div><div class="form-group"><label>预计天数</label><input id="quoteDays" type="number" value="'+(prevData.estimatedDays||'')+'" /></div></div><div class="form-group"><label>合计报价</label><input id="quoteAmt" type="number" readonly style="font-size:20px;font-weight:bold;color:var(--danger)" /></div><div class="form-group"><label>报价说明</label><textarea id="quoteDetail">'+(prevData.quoteDetail||'')+'</textarea></div>',async function(mask){
    var parts=[];var j=0;
    while(document.getElementById('partName'+j)){var nm=document.getElementById('partName'+j).value.trim();var qt=+document.getElementById('partQty'+j).value||0;var pr=+document.getElementById('partPrice'+j).value||0;if(nm)parts.push({name:nm,qty:qt,price:pr});j++}
    var pc=+document.getElementById('quoteParts').value||0;var lc=+document.getElementById('quoteLabor').value||0;var hc=+document.getElementById('quoteHoursCost').value||0;var amt=pc+lc+hc;
    if(!amt){alert('请填写费用');return false}
    await api('/repair/submit-quote/'+id,{method:'POST',data:{quote_amount:amt,parts_cost:pc,labor_cost:lc,hours_cost:hc,parts_list:parts,quote_detail:document.getElementById('quoteDetail').value,estimated_days:+document.getElementById('quoteDays').value||null}});
    toast(isReQuote?'重新报价已提交':'报价已提交');mask.remove();renderPage()
  });
  // 初始化合计显示
  setTimeout(function(){updateQuoteTotal()},100)
}
function addPartRow(){var i=window._partRowCount++;var d=document.createElement('div');d.className='flex';d.style.marginBottom='4px';d.innerHTML='<input id="partName'+i+'" placeholder="配件名称" style="flex:2" /><input id="partQty'+i+'" placeholder="数量" type="number" style="flex:1;margin:0 4px" /><input id="partPrice'+i+'" placeholder="单价" type="number" style="flex:1" />';document.getElementById('partsContainer').appendChild(d)}
function updateQuoteTotal(){var p=+document.getElementById('quoteParts').value||0;var l=+document.getElementById('quoteLabor').value||0;var h=+document.getElementById('quoteHoursCost').value||0;document.getElementById('quoteAmt').value=p+l+h}
function updateProgress(id){showModal('更新进度','<div class="form-group"><textarea id="progContent"></textarea></div>',async function(mask){var c=document.getElementById('progContent').value.trim();if(!c){alert('请填写');return false};await api('/repair/update-progress/'+id,{method:'POST',data:{content:c}});toast('已更新');mask.remove();renderPage()})}
async function completeOrder(id){if(!confirm('确认完工？'))return;await api('/repair/complete/'+id,{method:'POST'});toast('已完工');renderPage()}
async function approveOrder(id,approved){await api('/repair/approve/'+id,{method:'POST',data:{approved:approved}});toast(approved?'已通过':'已驳回');renderPage()}
function showReject(id){showModal('驳回原因','<div class="form-group"><textarea id="rejectReason"></textarea></div>',async function(mask){var r=document.getElementById('rejectReason').value.trim();if(!r){alert('请填写');return false};await api('/repair/approve/'+id,{method:'POST',data:{approved:false,reject_reason:r}});toast('已驳回');mask.remove();renderPage()})}
async function markUrgent(id){if(!confirm('标记为加急维修？'))return;await api('/repair/urgent/'+id,{method:'POST'});toast('已标记加急');renderPage()}
async function acceptCompletedOrder(id){if(!confirm('确认验收通过？验收后工单完结。'))return;var r=await api('/repair/accept/'+id,{method:'POST'});if(r)toast('验收完成，工单已完结');renderPage()}
async function notifyDriverAccept(id,name){if(!confirm('将通知'+(name||'驾驶员')+'尽快验收？'))return;await api('/repair/notify-accept/'+id,{method:'POST'});toast('已通知驾驶员验收')}
