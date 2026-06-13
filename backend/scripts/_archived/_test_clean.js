// Build a clean HTML without external modules to test core functionality
const fs = require('fs');

// Read build_final.js template (the CSS template)
let html = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index.html', 'utf8');

// Remove the external module script tags
html = html.replace(/<script src="\/modules\/[^"]*"><\/script>/g, '');

// Also check: are there any showSafetyList or showDeptManagement functions?
const js = html.match(/<script>([\s\S]*?)<\/script>/);
if (js) {
  const code = js[1];
  // Check for missing functions referenced in onclick handlers
  const onclickRefs = code.match(/onclick="([^"]+)"/g) || [];
  const funcDefs = code.match(/function (\w+)/g) || [];
  const defNames = new Set(funcDefs.map(f => f.replace('function ', '')));

  console.log('=== Functions defined but referenced ===');
  const refs = onclickRefs.map(r => {
    const match = r.match(/onclick="([^(]+)/);
    return match ? match[1].trim() : null;
  }).filter(Boolean).filter(r => !r.startsWith('this.') && !r.startsWith('document.'));

  const uniqueRefs = [...new Set(refs)];
  uniqueRefs.forEach(r => {
    if (!defNames.has(r)) {
      console.log('MISSING: ' + r + ' - referenced in onclick but not defined!');
    }
  });

  console.log('\nTotal unique onclick refs:', uniqueRefs.length);
  console.log('Total function defs:', defNames.size);

  // Check for backslash issues
  const backslashLines = code.split('\n').filter((l, i) => l.includes("'\\") || l.includes('"\\'));
  console.log('\n=== Lines with potential backslash issues ===');
  backslashLines.forEach(l => {
    // Check for \a \c \s etc in string literals
    if (l.match(/\\[acdefgiklmopqrtuvwxyz]/)) {
      console.log('SUSPICIOUS:', l.substring(0, 120));
    }
  });
}

// Save clean version
fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/index_clean.html', html, 'utf8');
console.log('\nClean HTML written to index_clean.html');
console.log('Test at: http://localhost:3000/index_clean.html');
