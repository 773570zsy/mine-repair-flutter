const fs = require('fs');
let js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

// 1. Add uploadFiles helper
const toastFn = 'function toast(m,t)';
const uploadFn = 'async function uploadFiles(files){if(!files||!files.length)return[];var urls=[];for(var i=0;i<files.length;i++){var f=new FormData();f.append("file",files[i]);try{var r=await fetch("/api/upload/single",{method:"POST",headers:{"Authorization":"Bearer "+TOKEN},body:f});var d=await r.json();if(d.code===200)urls.push(d.data.url)}catch(e){}}return urls}\nfunction toast(m,t)';
js = js.replace(toastFn, uploadFn);

// 2. Add previewImgs before api function
const apiFn = 'async function api(url,opts){';
const preFn = 'function previewImgs(inp,pid){var el=document.getElementById(pid);if(!el)return;el.innerHTML="";for(var i=0;i<inp.files.length;i++){(function(i){var reader=new FileReader();reader.onload=function(e){var img=document.createElement("img");img.src=e.target.result;img.style.cssText="width:60px;height:60px;object-fit:cover;border-radius:6px";el.appendChild(img)};reader.readAsDataURL(inp.files[i])})(i)}}\n';
js = js.replace(apiFn, preFn + apiFn);

// 3. Add photo input to repair report
const oldRpt = '<textarea id="rptDesc"></textarea></div>';
const newRpt = '<textarea id="rptDesc"></textarea></div><div class="form-group"><label>故障照片(可选)</label><input type="file" id="rptPhotos" accept="image/*" multiple style="padding:8px" onchange="previewImgs(this,\'rptPreview\')" /><div id="rptPreview" style="display:flex;gap:6px;flex-wrap:wrap;margin-top:6px"></div></div>';
js = js.replace(oldRpt, newRpt);

// 4. Update repair submit to use uploadFiles
const oldRptSub = 'fault_description:desc,fault_images:[]}';
const newRptSub = 'fault_description:desc,fault_images:await uploadFiles(document.getElementById("rptPhotos")?.files)}';
js = js.replace(oldRptSub, newRptSub);

// 5. Add photo input to morning inspection
const oldMorn = '<label>备注</label><textarea id="inspNotes"></textarea></div>';
const newMorn = '<label>备注</label><textarea id="inspNotes"></textarea></div><div class="form-group"><label>检查照片</label><input type="file" id="inspPhotos" accept="image/*" multiple style="padding:8px" /></div>';
js = js.replace(oldMorn, newMorn);

// 6. Update morning submit
const oldMornSub = 'overall_status:document.getElementById("inspStatus").value,notes:document.getElementById("inspNotes")?.value?.trim()||""}';
const newMornSub = 'overall_status:document.getElementById("inspStatus").value,notes:document.getElementById("inspNotes")?.value?.trim()||"",photos:await uploadFiles(document.getElementById("inspPhotos")?.files)}';
js = js.replace(oldMornSub, newMornSub);

// 7. Add photo input to evening inspection
const oldEven = '<input id="inspParking" /></div>';
const newEven = '<input id="inspParking" /></div><div class="form-group"><label>检查照片</label><input type="file" id="inspPhotos2" accept="image/*" multiple style="padding:8px" /></div>';
js = js.replace(oldEven, newEven);

// 8. Update evening submit
const oldEvenSub = 'parking_location:document.getElementById("inspParking")?.value?.trim()||""}';
const newEvenSub = 'parking_location:document.getElementById("inspParking")?.value?.trim()||"",photos:await uploadFiles(document.getElementById("inspPhotos2")?.files)}';
js = js.replace(oldEvenSub, newEvenSub);

try { new Function(js); console.log('JS OK'); } catch(e) { console.log('JS ERROR:', e.message); }
fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', js, 'utf8');
console.log('Photo upload added');
