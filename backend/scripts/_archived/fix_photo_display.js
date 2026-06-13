const fs = require('fs');
let js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

// 在订单详情里加照片显示 - 替换故障描述那一行后面
// 找到: +o.fault_description+''+('</div>'
// 或者找 exact pattern

// Strategy: 找到 showOrderDetail 函数中的 infoHtml 构建位置
// 在故障描述 div 后面插入照片缩略图

const pattern1 = "+o.fault_description||''+'+('</div>'";
if (js.indexOf(pattern1) > 0) {
  // 已被之前的修改更改了 - skip
  console.log('Pattern1 found - already modified');
}

// 找实际的故障描述行
const searchFor = "o.fault_description||";
const idx = js.indexOf(searchFor, js.indexOf('function showOrderDetail'));
if (idx > 0) {
  // 找到这行代码的结尾 - 下一个 '</div>' 字符串
  const lineEnd = js.indexOf("</div>'", idx);
  if (lineEnd > idx) {
    // 在这行后面插入照片代码
    const before = js.substring(0, lineEnd + 7); // +7 to include </div>'
    const after = js.substring(lineEnd + 7);
    const photoCode = "+'<div class=\\\"flex\\\" style=\\\"margin-top:4px\\\"><button class=\\\"btn btn-sm btn-o\\\" onclick=\\\"event.stopPropagation();var x=document.getElementById(\\'\\\\'faultImg'+Math.random()+'\\');var imgs;try{imgs=JSON.parse(\\''+o.fault_images+'\\''||\\'[]\\')}catch(e){imgs=[]};if(!imgs.length)return;var h=\\\"\\\";imgs.forEach(function(u){h+=\\\"<img src=\\\"+u+\\\" style=\\\'\\\\'width:70px;height:70px;object-fit:cover;border-radius:4px;margin:2px;cursor:pointer\\'\\\\' onclick=\\\"\\\\'this.style.cssText=\\\\\\\\\\\\\"\\\\\\'position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);max-width:90vw;max-height:90vh;z-index:9999\\\\\\\\\\\\"\\\\\\';this.onclick=function(){this.remove()}\\\" /></div>\\\"')\\">📷 查看故障照片</button></div>'";
    js = before + photoCode + after;
    console.log('Photo display added to order detail');
  }
}

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', js, 'utf8');
console.log('Photo display fix applied');
