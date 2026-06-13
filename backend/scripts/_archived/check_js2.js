const fs = require('fs');
const h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');
const s = h.indexOf('<script>');
const e = h.lastIndexOf('</script>');
const js = h.substring(s + 8, e);

try {
  new Function(js);
  console.log('JS OK');
} catch (err) {
  console.log('SYNTAX ERROR:', err.message);

  // Find the line by searching for the problematic pattern
  const lines = js.split('\n');
  // Look for common issues
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    // Check for unclosed string literals
    const singles = (line.match(/'/g) || []).length;
    const doubles = (line.match(/"/g) || []).length;
    const bticks = (line.match(/`/g) || []).length;
    if (singles % 2 !== 0 || doubles % 2 !== 0 || bticks % 2 !== 0) {
      console.log('Line ' + (i+1) + ' odd quotes:', line.substring(0, 100));
    }
    // Check for template literal issues
    if (line.includes('${') && !line.includes('}`')) {
      // Might be fine if it spans multiple lines
    }
  }

  // Find the specific error location
  const m = err.stack?.match(/<anonymous>:(\d+):(\d+)/);
  if (m) {
    const line = parseInt(m[1]);
    console.log('\nError around line', line);
    console.log('  ' + (lines[line-2]||'').substring(0, 120));
    console.log('  ' + (lines[line-1]||'').substring(0, 120));
    console.log('  ' + (lines[line]||'').substring(0, 120));
  }
}
