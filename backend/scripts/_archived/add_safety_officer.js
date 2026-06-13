const fs = require('fs');
let js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

// 1. Add safety_officer to ROLE_MAP
js = js.replace('external_approver:"外部审批"}', 'external_approver:"外部审批",safety_officer:"安全员"}');

// 2. Add to renderPage
js = js.replace('else if(r==="external_approver")renderExternalApprover()', 'else if(r==="external_approver")renderExternalApprover();else if(r==="safety_officer")renderSafetyOfficer()');

// 3. Add bulletin loading to renderAdmin
js = js.replace('loadSystemAlerts();', 'loadSystemAlerts();loadBulletin();');

// 4. Add bulletin loading to renderDriver
js = js.replace('loadAttendanceCard();', 'loadAttendanceCard();loadBulletin();');

console.log('Safety officer role added to frontend');
fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', js, 'utf8');
