const fs = require('fs');
let js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

// Inject photo button into showModal for any form IDs we know about
const oldSM = 'function showModal(title,content,onOk){';

// Simple approach: detect form content and inject a camera button
const photoBtn = '<div class="photo-upload-area" style="margin-top:8px"><button class="btn btn-o btn-sm" type="button" onclick="var i=document.createElement(\'input\');i.type=\'file\';i.accept=\'image/*\';i.multiple=true;i.onchange=function(){if(!i.files.length)return;var p=this.parentNode.querySelector(\'.preview\');var f=i.files[0];var d=new FormData();d.append(\'file\',f);fetch(\'/api/upload/single\',{method:\'POST\',headers:{\'Authorization\':\'Bearer \'+TOKEN},body:d}).then(r=>r.json()).then(j=>{if(j.code===200){var m=document.createElement(\'img\');m.src=j.data.url;m.style.cssText=\'width:50px;height:50px;object-fit:cover;border-radius:4px;margin:3px\';p.appendChild(m);window._modalPhotos=window._modalPhotos||[];window._modalPhotos.push(j.data.url)}})};i.click()">📷 拍照</button><div class="preview" style="display:flex;gap:3px;flex-wrap:wrap;margin-top:4px"></div></div>';

const newSM = 'function showModal(title,content,onOk){' +
  'if(content.indexOf("rptDesc")>0||content.indexOf("inspNotes")>0||content.indexOf("inspParking")>0||content.indexOf("hzDesc")>0||content.indexOf("quoteDetail")>0){' +
  'content+="' + photoBtn + '"}' +
  '';

js = js.replace(oldSM, newSM);
console.log('Photo button injected into showModal');

// Also check if fault_images gets set from the photo URLs
// When form submits, _modalPhotos array has the URLs

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', js, 'utf8');
