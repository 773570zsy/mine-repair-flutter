const fs = require('fs');
let js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

// Find the fault description line in showOrderDetail
const marker = "o.fault_description||";
const funcStart = js.indexOf('function showOrderDetail');
const idx = js.indexOf(marker, funcStart);

if (idx > 0) {
  // Find the end of this HTML string segment
  const endMarker = "</div>'";
  const lineEnd = js.indexOf(endMarker, idx);

  if (lineEnd > idx) {
    // Insert photo display code right after the fault description closing div
    const insertCode =
      "+'<div class=\"fault-photos\" style=\"display:flex;gap:4px;flex-wrap:wrap;margin-top:4px\"></div>'" +
      "+'<script>setTimeout(function(){var imgs;try{imgs=JSON.parse(\"'+o.fault_images.replace(/\"/g,'&quot;')+'\"||\"[]\")}catch(e){imgs=[]};if(imgs.length){var el=document.querySelector(\".fault-photos\");if(el){imgs.forEach(function(u){var i=document.createElement(\"img\");i.src=u;i.style.cssText=\"width:60px;height:60px;object-fit:cover;border-radius:4px;margin:2px;cursor:pointer\";i.onclick=function(){showFaultPhotos(imgs)};el.appendChild(i)})}}},200)<\\/script>'";

    const newJs = js.substring(0, lineEnd + endMarker.length) + insertCode + js.substring(lineEnd + endMarker.length);
    console.log('Photo display added to order detail');
    fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', newJs, 'utf8');
  } else {
    console.log('End marker not found');
  }
} else {
  console.log('Fault description not found in showOrderDetail');
}
