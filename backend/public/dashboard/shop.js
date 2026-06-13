// ==================== 修理厂仪表盘 ====================

async function renderShop(){
  var el=document.getElementById('mainPage');
  el.innerHTML='<div class="layout"><div class="stats-grid" id="shopStats"></div><div class="row2"><div class="card" style="text-align:center;cursor:pointer" onclick="showVehicleArchiveList()"><h3>📋</h3>在编车辆档案<br><span style="font-size:12px;color:var(--text2)">车辆详细档案查阅</span></div></div><div class="card"><div class="card-title">📋 工单列表</div><div class="tabs" id="shopTabs"></div><div id="shopOrders">加载中...</div></div></div>';
  loadShopData();
}
async function loadShopData(tab){
  tab=tab||'all';
  var [myOrders,pendingAccept]=await Promise.all([api('/repair/shop-orders'+(tab!=='all'?'?status='+tab:'')),api('/repair/pending-accept')]);
  myOrders=myOrders||[];pendingAccept=pendingAccept||[];
  var displayOrders=myOrders.slice();
  if(tab==='all'||tab==='pending_accept'){var myIds={};myOrders.forEach(function(o){myIds[o.id]=true});pendingAccept.forEach(function(o){if(!myIds[o.id])displayOrders.unshift(o)})}
  document.getElementById('shopStats').innerHTML=
    '<div class="stat-item"><div class="stat-num">'+displayOrders.length+'</div><div class="stat-label">全部工单</div></div>'+
    '<div class="stat-item"><div class="stat-num" style="color:var(--danger)">'+pendingAccept.length+'</div><div class="stat-label">待接单</div></div>'+
    '<div class="stat-item"><div class="stat-num" style="color:var(--warning)">'+myOrders.filter(function(o){return o.status==='pending_quote'}).length+'</div><div class="stat-label">待报价</div></div>'+
    '<div class="stat-item"><div class="stat-num" style="color:var(--primary)">'+myOrders.filter(function(o){return['approved','repairing'].indexOf(o.status)>=0}).length+'</div><div class="stat-label">维修中</div></div>';
  var tabs=[{l:'全部',v:'all'},{l:'待接单',v:'pending_accept'},{l:'待报价',v:'pending_quote'},{l:'待审批',v:'pending_approval'},{l:'维修中',v:'repairing'},{l:'已驳回',v:'rejected'},{l:'待验收',v:'completed'},{l:'已完成',v:'accepted'}];
  document.getElementById('shopTabs').innerHTML=tabs.map(function(t){return '<button class="tab '+(tab===t.v?'active':'')+'" onclick="loadShopData(\''+t.v+'\')">'+t.l+'</button>'}).join('');
  document.getElementById('shopOrders').innerHTML=displayOrders.length?'<table><tr><th>工单号</th><th>车辆</th><th>报修人</th><th>故障描述</th><th>状态</th><th>操作</th></tr>'+displayOrders.map(function(o){
    return '<tr><td class="order-no" style="font-size:12px">'+o.order_no+(o.is_urgent?' <span style="background:#ff4d4f;color:#fff;padding:1px 5px;border-radius:3px;font-size:10px">急</span>':'')+'</td><td>'+o.plate_number+'</td><td>'+(o.driver_name||'-')+'</td><td style="max-width:120px;overflow:hidden;white-space:nowrap;text-overflow:ellipsis;font-size:12px">'+(o.fault_description||'-')+'</td><td><span class="tag '+ST_TAG[o.status]+'">'+STATUS_MAP[o.status]+'</span></td><td>'+actionBtns(o)+'</td></tr>'
  }).join('')+'</table>':'<div class="empty">暂无工单</div>';
}
function actionBtns(o){
  var b='<button class="btn btn-sm btn-p" onclick="showOrderDetail('+o.id+')">详情</button>';
  if(o.status==='pending_accept')b+=' <button class="btn btn-sm btn-s" onclick="acceptOrder('+o.id+')">接单</button>';
  if(o.status==='pending_quote'||o.status==='rejected')b+=' <button class="btn btn-sm btn-s" onclick="showQuote('+o.id+','+(o.status==='rejected'?'true':'false')+')">'+(o.status==='rejected'?'重新报价':'报价')+'</button>';
  if(o.status==='approved'||o.status==='repairing'){b+=' <button class="btn btn-sm btn-p" onclick="updateProgress('+o.id+')">进度</button>';b+=' <button class="btn btn-sm btn-s" onclick="completeOrder('+o.id+')">完工</button>'}
  if(o.status==='completed')b+=' <button class="btn btn-sm btn-s" onclick="notifyDriverAccept('+o.id+',\''+(o.driver_name||'驾驶员')+'\')">📢 通知验收</button>';
  return b;
}
