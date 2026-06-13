const fs = require('fs');
const h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');
const s = h.indexOf('<script>');
const e = h.lastIndexOf('</script>');
const js = h.substring(s + 8, e);

// Find < characters outside of strings/template literals
let inStr = false, inTpl = false, inComment = false;
let strChar = '';
const issues = [];

for (let i = 0; i < js.length; i++) {
  const ch = js[i];
  const prev = js[i - 1] || '';

  if (ch === '\n' && inComment) { inComment = false; continue; }
  if (ch === '/' && prev === '/' && !inStr && !inTpl) { inComment = true; continue; }
  if (inComment) continue;

  if ((ch === "'" || ch === '"') && prev !== '\\' && !inTpl) {
    if (!inStr) { inStr = true; strChar = ch; }
    else if (ch === strChar) { inStr = false; }
  }
  if (ch === '`' && prev !== '\\' && !inStr) { inTpl = !inTpl; }

  if (inStr || inTpl) continue;

  if (ch === '<' && js[i + 1] !== '=' && js[i + 1] !== ' ' && js[i + 1] !== '/') {
    // Possible HTML tag
    const ctx = js.substring(Math.max(0, i - 20), i + 40);
    const lineNum = js.substring(0, i).split('\n').length;
    issues.push({ line: lineNum, pos: i, ctx: ctx });
    if (issues.length >= 5) break;
  }
}

if (issues.length) {
  console.log('Found', issues.length, 'potential HTML tags in JS:');
  issues.forEach(function(x) {
    console.log('  Line', x.line, ':', JSON.stringify(x.ctx));
  });
} else {
  console.log('No HTML tags found outside strings');
}

// Also check for unmatched template literals
let btCount = 0, btOpen = 0;
for (let i = 0; i < js.length; i++) {
  if (js[i] === '`' && js[i - 1] !== '\\') btCount++;
}
console.log('\nBacktick count:', btCount, btCount % 2 === 0 ? '(even)' : '(ODD - BUG!)');
