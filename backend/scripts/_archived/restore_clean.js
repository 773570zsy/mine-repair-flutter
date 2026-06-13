const fs = require('fs');
// Read the current HTML and identify the broken parts
let h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');
let s = h.indexOf('<script>'), e = h.indexOf('</script>', s + 8);
let js = h.substring(s + 8, e);

// Find and remove camera button HTML patterns
// Pattern 1: '<button class="btn btn-o btn-sm" type="button" onclick="pickPhoto()"...'
let btnPattern = /<button class="btn btn-o btn-sm" type="button" onclick="pickPhoto\(\)"[^>]*>.*?<\/button><div id="photoPreview"[^>]*><\/div>/g;
js = js.replace(btnPattern, '');

// Pattern 2: Remove the modified pickPhoto function
let pickOld = 'function pickPhoto(){window._modalPhotos=[];globalPhotoInput.click();setTimeout(function(){var el=document.getElementById("photoPreview");if(el&&window._modalPhotos){el.innerHTML="";window._modalPhotos.forEach(function(u){var img=document.createElement("img");img.src=u;img.style.cssText="width:50px;height:50px;object-fit:cover;border-radius:4px;margin:3px";el.appendChild(img)})}},500)}';
js = js.replace(pickOld, 'function pickPhoto(){globalPhotoInput.click()}');

// Test
try { new Function(js); console.log('JS OK - size:', js.length); }
catch(e) { console.log('Still broken:', e.message); }

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', js, 'utf8');
