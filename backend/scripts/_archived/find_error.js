const fs = require('fs');
const js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');
const lines = js.split('\n');

// Try compiling each line individually to find the error
for (let i = 0; i < lines.length; i++) {
  const line = lines[i].trim();
  if (!line) continue;

  // Skip lines that are clearly part of multi-line constructs
  if (line.startsWith('//') || line.startsWith('*')) continue;

  // For single-line constructs, try evaluating
  if (line.endsWith(';') || line.endsWith('{') || line.endsWith('}') ||
      line.includes('function ') || line.includes('var ') || line.includes('let ') || line.includes('const ')) {
    try {
      new Function(line);
    } catch (e) {
      console.log('Line ' + (i + 1) + ' error:', e.message);
      console.log('  ' + line.substring(0, 120));
    }
  }
}

// Also check for balanced quotes on each line
for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  let dq = 0, sq = 0;
  for (let j = 0; j < line.length; j++) {
    const ch = line[j], prev = line[j - 1] || '';
    if (ch === '"' && prev !== '\\') dq++;
    if (ch === "'" && prev !== '\\') sq++;
  }
  if (dq % 2 !== 0 || sq % 2 !== 0) {
    console.log('Line ' + (i + 1) + ' unbalanced quotes (dq=' + dq + ',sq=' + sq + '): ' + line.substring(0, 120));
  }
}
