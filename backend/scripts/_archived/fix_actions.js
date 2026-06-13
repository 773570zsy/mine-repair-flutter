const fs = require('fs');
let js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

// Add actionName function before api function
const oldFn = 'async function api(url,opts){';
const newFn = 'function actionName(a){var m={accepted_order:"修理厂接单",quote_submitted:"提交报价",approved:"审批通过",rejected:"驳回",accepted_and_quoted:"接单并报价",department_approved:"部门审批通过",department_rejected:"部门驳回",progress:"维修进度",progress_update:"维修进度",completed:"维修完成",accepted:"验收通过",urgent:"标记加急"};return m[a]||a}\nasync function api(url,opts){';
js = js.replace(oldFn, newFn);

// Find and replace '+x.action+' with '+actionName(x.action)+' in showOrderDetail
const idx = js.indexOf('x.action');
if (idx > 0) {
  console.log('Found x.action at', idx);
  const ctx = js.substring(idx - 20, idx + 30);
  console.log('Context:', ctx);
  // Replace all occurrences of +x.action+ with +actionName(x.action)+
  js = js.replace(/\+x\.action\+/g, '+actionName(x.action)+');
  console.log('Action names translated');
}

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', js, 'utf8');
console.log('App.js updated');
