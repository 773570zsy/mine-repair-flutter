const fs = require('fs');
let js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

// 1. Fix ROLE_MAP - add safety_officer
const oldRM = "external_approver:'外部审批'};";
const newRM = "external_approver:'外部审批',safety_officer:'安全员'};";
if (js.indexOf(oldRM) > 0) {
  js = js.replace(oldRM, newRM);
  console.log('ROLE_MAP fixed');
} else { console.log('ROLE_MAP pattern not found'); }

// 2. Fix renderPage - add safety_officer
const oldRP = "else if(r==='external_approver')renderExternalApprover()";
const newRP = "else if(r==='external_approver')renderExternalApprover();else if(r==='safety_officer')renderSafetyOfficer()";
if (js.indexOf(oldRP) > 0) {
  js = js.replace(oldRP, newRP);
  console.log('renderPage fixed');
} else { console.log('renderPage pattern not found'); }

// 3. Add bulletin loading
const oldAdmin = 'loadSystemAlerts();';
if (js.indexOf('loadSystemAlerts();loadBulletin();') < 0 && js.indexOf(oldAdmin) > 0) {
  js = js.replace(oldAdmin, 'loadSystemAlerts();loadBulletin();');
  console.log('Bulletin added to admin');
}

const oldDrv = 'loadAttendanceCard();';
if (js.indexOf('loadAttendanceCard();loadBulletin();') < 0 && js.indexOf(oldDrv) > 0) {
  // Only replace the FIRST occurrence (driver)
  js = js.replace(oldDrv, 'loadAttendanceCard();loadBulletin();');
  console.log('Bulletin added to driver');
}

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', js, 'utf8');
console.log('Safety officer fixes applied');
