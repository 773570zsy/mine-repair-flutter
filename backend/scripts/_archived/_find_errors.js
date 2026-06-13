const fs = require('fs');
const js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');
const lines = js.split('\n');

// Find unbalanced quotes
for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  let dq = 0, sq = 0, bt = 0;
  for (let j = 0; j < line.length; j++) {
    const ch = line[j];
    const prev = line[j - 1] || '';
    if (ch === '"' && prev !== '\\') dq++;
    if (ch === "'" && prev !== '\\') sq++;
    if (ch === '`' && prev !== '\\') bt++;
  }
  if (dq % 2 !== 0 || sq % 2 !== 0 || bt % 2 !== 0) {
    console.log('Line ' + (i + 1) + ': DQ=' + dq + ' SQ=' + sq + ' BT=' + bt + ' | ' + line.substring(0, 200));
  }
}

// Also try to find the exact error location
console.log('\n--- Full function test ---');
try {
  new Function(js);
  console.log('JS is VALID!');
} catch (e) {
  console.log('Error:', e.message);
  // Try to find line number from error
  const match = e.message.match(/line (\d+)/);
  if (match) {
    const lineNum = parseInt(match[1]);
    console.log('Error near line:', lineNum);
    // Check context around that line
    for (let k = Math.max(0, lineNum - 3); k < Math.min(lines.length, lineNum + 3); k++) {
      console.log('  ' + (k + 1) + ': ' + lines[k].substring(0, 150));
    }
  }
}
