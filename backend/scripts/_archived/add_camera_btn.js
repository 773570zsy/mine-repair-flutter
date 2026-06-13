const fs = require('fs');
let js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

const cameraHTML = '<button class="btn btn-o btn-sm" type="button" onclick="pickPhoto()" style="margin-bottom:8px">📷 拍照上传</button><div id="photoPreview" style="display:flex;gap:4px;flex-wrap:wrap;margin-bottom:8px"></div>';

// Add to repair form - after fault description textarea
const oldRepair = '<textarea id="rptDesc"></textarea></div>';
const newRepair = '<textarea id="rptDesc"></textarea></div>' + cameraHTML;
js = js.replace(oldRepair, newRepair);

// Add to morning inspection form - after notes textarea
const oldMorn = '<textarea id="inspNotes"></textarea></div>';
const newMorn = '<textarea id="inspNotes"></textarea></div>' + cameraHTML;
const countMorn = (js.match(new RegExp(oldMorn.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'), 'g')) || []).length;
console.log('Morning form occurrences:', countMorn);
js = js.replace(oldMorn, newMorn);

// Add to hazard form - after description textarea
const oldHaz = '<textarea id="hzDesc" placeholder="请详细描述隐患..."></textarea></div>';
const newHaz = '<textarea id="hzDesc" placeholder="请详细描述隐患..."></textarea></div>' + cameraHTML;
js = js.replace(oldHaz, newHaz);

console.log('Camera buttons added to forms');

// Also update pickPhoto to show preview
const oldPick = 'function pickPhoto(){globalPhotoInput.click()}';
const newPick = 'function pickPhoto(){window._modalPhotos=[];globalPhotoInput.click();setTimeout(function(){var el=document.getElementById("photoPreview");if(el&&window._modalPhotos){el.innerHTML="";window._modalPhotos.forEach(function(u){var img=document.createElement("img");img.src=u;img.style.cssText="width:50px;height:50px;object-fit:cover;border-radius:4px;margin:3px";el.appendChild(img)})}},500)}';
js = js.replace(oldPick, newPick);

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', js, 'utf8');
console.log('Camera button and preview done');
