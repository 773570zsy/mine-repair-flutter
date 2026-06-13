const fs = require('fs');
let js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

// 1. Add photo gallery helper function
const oldFn = 'function previewImgs';
if (js.indexOf('function showPhotoGallery') < 0) {
  const galleryFn = 'function showPhotoGallery(urls,title){if(!urls||!urls.length)return;var h=\"<div style=\\\"display:flex;gap:8px;flex-wrap:wrap\\\">\";urls.forEach(function(u){h+=\"<img src=\\\"+u+\"\\\" style=\\\"width:100px;height:100px;object-fit:cover;border-radius:8px;cursor:pointer\\\" onclick=\\\"window.open(\\\\'\\\"+u+\"\\\\')\\n\\\" />\"});h+=\"</div>\";showModal(title||\"照片\",h)}\n';
  js = js.replace('function previewImgs', galleryFn + 'function previewImgs');
  console.log('Gallery function added');
}

// 2. Add photo thumbnails to order detail (after fault description)
// Find: '<div><b>故障描述：</b>'+..., and add photo thumbnails after it
// Actually, the showOrderDetail function builds HTML as a string. Let me find the fault description line.

const faultLine = "<div><b>故障描述：</b>'+o.fault_description+'</div>";
const newFaultLine = "<div><b>故障描述：</b>'+o.fault_description+'</div>'+'<div id=\\\"faultPhotos\\\"></div>'+'<script>setTimeout(function(){var imgs;try{imgs=JSON.parse((\\''+o.fault_images+'\\'||\\'[]\\'))}catch(e){imgs=[]};if(imgs.length){var h=\\\"\\\";imgs.forEach(function(u){h+=\\\"<img src=\\\\'\\\"+u+\\\"\\\\' style=\\\\'\\\\\\\\'width:80px;height:80px;object-fit:cover;border-radius:6px;margin:4px;cursor:pointer\\' onclick=\\\\'\\\"window.open(\\\\\\'\"+u+\"\\\\\\')\\\" />\\\"})\";document.getElementById(\"faultPhotos\").innerHTML=h}},10)</script>';

// That's way too complex with escaping. Let me take a simpler approach.
// Just add photo display as a simple HTML injection after the fault div.

// Actually, let me use a completely different approach. Instead of trying to edit the order detail template,
// I'll make the fault_images field auto-display by modifying how it's rendered.

// For now, let me just add a simple button that shows photos in a modal.
const oldShowDetail = "showModal('工单详情',";
const newShowDetail = oldShowDetail + "'<div class=\\\"flex\\\"><button class=\\\"btn btn-sm btn-o\\\" onclick=\\\"var imgs;try{imgs=JSON.parse(o.fault_images||\\\\'[]\\\\')}catch(e){imgs=[]};if(!imgs.length){alert(\\\\'无照片\\\\');return};showPhotoGallery(imgs,\\\\''故障照片\\\\'')}}>查看故障照片</button></div>'+";
// No, this will have similar escaping issues.

// SIMPLEST approach: Just add photos as clickable thumbnails inside the infoHtml section
// using a separate function call

console.log('Photo viewer: using simpler approach');

// 3. Just update the order detail to show photos after fault line using a safe DOM method
// Replace the infoHtml building to include photos
const oldInfo = "+o.fault_description+''+('</div>'";
// Let me find the exact pattern in the js
const idx = js.indexOf("o.fault_description||''");
if (idx > 0) {
  const ctx = js.substring(idx - 30, idx + 60);
  console.log('Context:', ctx.substring(0, 80));
  // Insert photo display after fault description
  const oldStr = "o.fault_description||''";
  const newStr = "o.fault_description||''+showFaultPhotos(o)";
  js = js.substring(0, idx) + newStr + js.substring(idx + oldStr.length);
  console.log('Photo display injected');
}

// Add showFaultPhotos function
const apiIdx = js.indexOf('async function api(url');
if (apiIdx > 0) {
  const helperFn = 'function showFaultPhotos(o){try{var imgs=JSON.parse(o.fault_images||\"[]\");if(!imgs.length)return\"\";var h=\"<div style=\\\"margin-top:6px;display:flex;gap:6px;flex-wrap:wrap\\\">\";imgs.forEach(function(u){h+=\"<img src=\\\"+u+\"\\\" style=\\\"width:70px;height:70px;object-fit:cover;border-radius:6px;cursor:pointer\\\" onclick=\\\"this.style.position=\\\'fixed\\';this.style.top=\\\'50%\\';this.style.left=\\\'50%\\';this.style.transform=\\\'translate(-50%,-50%)\\\';this.style.width=\\\'auto\\';this.style.height=\\\'80vh\\';this.style.zIndex=\\\'9999\\';this.onclick=function(){this.remove()}\\\" />\"});h+=\"</div>\";return h}catch(e){return\"\"}}\n';
  js = js.substring(0, apiIdx) + helperFn + js.substring(apiIdx);
  console.log('showFaultPhotos function added');
}

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', js, 'utf8');
console.log('Photo viewer integrated');
