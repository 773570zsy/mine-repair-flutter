// Simulate browser environment and test app.js execution
const fs = require('fs');

// Simple DOM mock
global.document = {
  getElementById: function(id) {
    console.log('  getElementById(' + id + ')');
    return {
      style: { display: '' },
      textContent: '',
      innerHTML: '',
      value: '',
      closest: function() { return null; },
      querySelector: function() { return null; },
      querySelectorAll: function() { return []; },
      addEventListener: function() {},
      remove: function() {},
      appendChild: function() {},
      removeChild: function() {},
    };
  },
  createElement: function(tag) {
    return {
      className: '',
      style: {},
      textContent: '',
      innerHTML: '',
      id: '',
      type: '',
      accept: '',
      multiple: false,
      onchange: null,
      onclick: null,
      files: [],
      value: '',
      appendChild: function() {},
      remove: function() {},
      addEventListener: function() {},
      querySelector: function() { return null; },
      querySelectorAll: function() { return []; },
      closest: function() { return null; },
      setAttribute: function() {},
      getAttribute: function() { return null; },
    };
  },
  body: {
    appendChild: function() {},
    style: {},
  },
  querySelectorAll: function() { return []; },
  addEventListener: function() {},
};

global.window = {
  _modalPhotos: [],
  location: { href: 'http://localhost:3000/' },
  addEventListener: function() {},
};
global.localStorage = { getItem: function() { return null; }, setItem: function() {}, clear: function() {}, removeItem: function() {} };
global.fetch = function(url) {
  console.log('  fetch(' + url + ')');
  return Promise.resolve({
    json: function() { return Promise.resolve({ code: 401, msg: 'Mock' }); }
  });
};
global.alert = function(m) { console.log('  ALERT: ' + m); };
global.Notification = { permission: 'default', requestPermission: function() {} };
global.MutationObserver = function() { return { observe: function() {}, disconnect: function() {} }; };
global.setTimeout = function(fn, ms) { /* don't execute timeouts */ };
global.setInterval = function() {};
global.FormData = function() { return { append: function() {} }; };
global.Blob = function() {};
global.URL = { createObjectURL: function() {} };
global.navigator = { serviceWorker: { register: function() {} } };
global.XMLHttpRequest = function() {};

const js = fs.readFileSync('C:/Users/GIGABYTYE/mine-repair-app/backend/public/app.js', 'utf8');

console.log('Testing app.js...');
try {
  const fn = new Function(js);
  console.log('Syntax: OK');
  fn();
  console.log('Execution: OK');

  // Test the key functions
  console.log('\n--- Testing doLogin ---');
  // Simulate login elements
  document.getElementById = function(id) {
    return {
      style: { display: '' },
      textContent: '',
      innerHTML: '',
      value: id === 'loginPhone' ? '15129505737' : (id === 'loginPwd' ? 'zsyjw773570' : ''),
      closest: function() { return null; },
      querySelector: function() { return null; },
      querySelectorAll: function() { return []; },
      addEventListener: function() {},
      remove: function() {},
      appendChild: function() {},
      removeChild: function() {},
    };
  };

  try {
    doLogin().then(function() {
      console.log('Login success, USER:', USER ? USER.name : 'NULL');
      console.log('TOKEN:', TOKEN ? 'SET' : 'NULL');
      try {
        renderPage();
        console.log('renderPage() completed');
      } catch(e) {
        console.log('renderPage ERROR:', e.message);
      }
    }).catch(function(e) {
      console.log('Login ERROR:', e.message);
    });
  } catch(e) {
    console.log('doLogin() throw:', e.message);
  }
} catch(e) {
  console.log('Syntax ERROR:', e.message);
  console.log('Line:', e.lineNumber);
}
