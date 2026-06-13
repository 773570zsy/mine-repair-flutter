const fs = require('fs');
const h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');
const s = h.indexOf('<script>');
const e = h.lastIndexOf('</script>');
const js = h.substring(s + 8, e);

// Try to compile
try {
  new Function(js);
  console.log('JS OK');
} catch (err) {
  console.log('SYNTAX ERROR:', err.message);
  // Find the line
  const m = err.stack.match(/at new Function.*<anonymous>:(\d+):(\d+)/);
  if (m) {
    const line = parseInt(m[1]);
    const lines = js.split('\n');
    console.log('Line ' + line + ': ' + (lines[line - 1] || '').substring(0, 120));
    console.log('Before: ' + (lines[line - 2] || '').substring(0, 120));
    console.log('After: ' + (lines[line] || '').substring(0, 120));
  }
}
