const fs = require('fs');
let js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

// Fix 1: Line 351 - showModal has unescaped quotes in onclick handler
// Broken: onclick="this.closest('.modal-mask').remove()"
// Fixed:  onclick="this.closest(\'.modal-mask\').remove()"
const brokenShowModal = "onclick=\"this.closest('.modal-mask').remove()\">取消</button><button class=\"btn btn-p\" id=\"modalOkBtn\">确认</button>";
const fixedShowModal = "onclick=\"this.closest(\\'.modal-mask\\').remove()\">取消</button><button class=\"btn btn-p\" id=\"modalOkBtn\">确认</button>";
if (js.includes(brokenShowModal)) {
  js = js.replace(brokenShowModal, fixedShowModal);
  console.log('Fixed showModal onclick handler');
} else {
  console.log('showModal pattern not found (may already be fixed or different)');
}

// Fix 2: Check for any other unescaped onclick handlers with single quotes in innerHTML strings
// Pattern: onclick="this.closest('.modal-mask')" - need to escape the inner quotes
// Search for all occurrences
const pattern = /onclick="this\.closest\('\.modal-mask'\)\.remove\(\)"/g;
const matches = js.match(pattern);
if (matches) {
  console.log('Found', matches.length, 'more unescaped onclick handlers');
  js = js.replace(pattern, "onclick=\"this.closest(\\.modal-mask\\)\\.remove\\(\\)\"");
}

// Fix 3: Also check for other broken showModal patterns from add_photo_modal.js
// The script injected photo button HTML with unescaped quotes into showModal
// Look for any remaining broken patterns
const photoBtnPattern = /content\+="<div class="photo-upload-area"/;
if (photoBtnPattern.test(js)) {
  console.log('Found broken photo button injection in showModal');
  // Remove the injection - it's broken
  // The showModal line should end after the modal HTML, not have the photo injection
  // Actually let's just restore the whole showModal function
}

// Test
try {
  new Function(js);
  console.log('SUCCESS: JS is now valid! Size:', js.length);
} catch (e) {
  console.log('Still broken:', e.message);

  // Try to find the error line
  const lineMatch = e.message.match(/at line (\d+)/i) || e.message.match(/position (\d+)/i);
  if (lineMatch) {
    console.log('Error at:', lineMatch[0]);
  }

  // Print lines around common error positions
  const lines = js.split('\n');
  // Try searching for common issues
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    // Check for unescaped single quotes inside single-quoted strings (heuristic)
    if (line.includes("onclick=\"this.closest('")) {
      console.log('Line ' + (i+1) + ' still has unescaped quotes');
    }
  }
}

fs.writeFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', js, 'utf8');
console.log('app.js written');
