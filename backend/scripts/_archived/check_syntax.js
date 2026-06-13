const fs = require('fs');
const h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

// Check for syntax issues
let lines = h.split('\n');
let issues = [];
let btStack = 0;

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  // Count backticks
  for (const ch of line) {
    if (ch === '\x60') btStack++;
  }
}

console.log('Total backtick count:', btStack, btStack % 2 === 0 ? '(even - OK)' : '(odd - ISSUE!)');

// Check for missing closing braces
let braceStack = 0;
for (const ch of h.substring(h.indexOf('<script>'), h.lastIndexOf('</script>'))) {
  if (ch === '{') braceStack++;
  if (ch === '}') braceStack--;
}
console.log('Brace balance in JS:', braceStack, braceStack === 0 ? '(OK)' : '(ISSUE!)');

// Check for showAttendanceReport
const attIdx = h.indexOf('showAttendanceReport');
if (attIdx > -1) {
  console.log('\nshowAttendanceReport found at index', attIdx);
  // Check surrounding context
  const ctx = h.substring(attIdx, attIdx + 300);
  console.log(ctx.substring(0, 200));
} else {
  console.log('\nshowAttendanceReport NOT FOUND - function missing!');
}

// Check key functions exist
const funcs = ['doLogin', 'renderPage', 'showAdminVehicles', 'showAttendanceReport',
               'showRepairShops', 'delShop', 'delUser', 'doAddUser', 'renderLeader'];
for (const f of funcs) {
  if (h.includes('function ' + f)) {
    console.log('  Found:', f);
  } else {
    console.log('  MISSING:', f);
  }
}

console.log('\nSyntax check complete.');
