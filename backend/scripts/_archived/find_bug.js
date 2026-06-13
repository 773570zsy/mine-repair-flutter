const fs = require('fs');
const h = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');
const s = h.indexOf('<script>'), e = h.lastIndexOf('</script>');
const js = h.substring(s + 8, e);

// Try to find where the error is
let inStr = false, inTpl = false, inComment = false;
let strChar = '';
let lastLine = 0;
const lines = js.split('\n');

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  // Quick check: even number of quotes outside templates?
  let dq = 0, sq = 0, bt = 0;
  for (let j = 0; j < line.length; j++) {
    const ch = line[j];
    if (ch === '"' && (j === 0 || line[j-1] !== '\\')) dq++;
    if (ch === "'" && (j === 0 || line[j-1] !== '\\')) sq++;
    if (ch === '`' && (j === 0 || line[j-1] !== '\\')) bt++;
  }
  if (bt % 2 !== 0) {
    console.log('Line', i+1, 'odd backticks:', line.substring(0, 100));
  }
  // Check for unmatched braces in single lines
  let open = (line.match(/\{/g) || []).length;
  let close = (line.match(/\}/g) || []).length;
  if (Math.abs(open - close) > 2 && line.includes('${')) {
    console.log('Line', i+1, 'brace mismatch:', open, 'open', close, 'close:', line.substring(0, 120));
  }
}

// Try evaluating each line to isolate error
let sofar = '';
for (let i = 0; i < lines.length; i++) {
  sofar += lines[i] + '\n';
  try {
    new Function(sofar);
  } catch (err) {
    if (err.message.includes('Unexpected token')) {
      console.log('\n=== ERROR at line', i+1, '===');
      console.log('Message:', err.message);
      console.log('Line:', lines[i].substring(0, 120));
      console.log('Prev:', (lines[i-1] || '').substring(0, 120));
      break;
    }
  }
}
