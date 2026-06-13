const fs = require('fs');
let js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

// Wire up photo URLs from global array to form submissions
// These are simple fixes - just replace empty arrays with the global photo array

// 1. Repair fault_images
js = js.replace('fault_description:desc,fault_images:[]}', 'fault_description:desc,fault_images:window._modalPhotos||[]}');

// 2. Morning check photos (in submitInspection)
js = js.replace(',photos:window._inspPhotoUrls||[]}', ',photos:window._modalPhotos||[]}');

// 3. Evening check photos
js = js.replace(',photos:window._inspPhotoUrls2||[],videos:[]}', ',photos:window._modalPhotos||[],videos:[]}');

// 4. Hazard photos_before
js = js.replace(',photos_before:window._hzPhotoUrls||[]}', ',photos_before:window._modalPhotos||[]}');

console.log('Photo URLs wired to form submissions');

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', js, 'utf8');
