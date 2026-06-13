// Deploy script v2 - try different auth methods
const { Client } = require('ssh2');
const fs = require('fs');
const path = require('path');

const HOST = '162.14.75.235';
const USER = 'root';
const PASS = 'Zsyjw773570!';
const REMOTE_DIR = '/opt/mine-repair-app/backend';

const files = [
  ['public/index.html', 'public/index.html'],
  ['public/modules/hazards.js', 'public/modules/hazards.js'],
  ['public/modules/photos.js', 'public/modules/photos.js'],
  ['public/modules/photo_viewer.js', 'public/modules/photo_viewer.js'],
  ['public/modules/safety_officer.js', 'public/modules/safety_officer.js'],
  ['utils/db.js', 'utils/db.js'],
  ['routes/inspection.js', 'routes/inspection.js'],
  ['routes/repair.js', 'routes/repair.js'],
];

const BASE = 'C:/Users/GIGABYTYE/mine-repair-app/backend';

async function deploy() {
  const conn = new Client();

  return new Promise((resolve, reject) => {
    conn.on('ready', async () => {
      console.log('SSH connected!');

      try {
        // Use exec for SFTP as a batch
        for (const [local, remote] of files) {
          const localPath = path.join(BASE, local);
          const remotePath = REMOTE_DIR + '/' + remote;

          if (!fs.existsSync(localPath)) {
            console.log('SKIP (not found):', local);
            continue;
          }

          const content = fs.readFileSync(localPath);
          console.log('Uploading:', local, '(' + content.length + ' bytes)');

          await new Promise((res, rej) => {
            conn.sftp((err, sftp) => {
              if (err) { rej(err); return; }
              // Ensure remote directory exists
              const remoteDir = path.dirname(remotePath).replace(/\\/g, '/');
              sftp.mkdir(remoteDir, (err) => {
                // ignore "already exists" errors
                sftp.writeFile(remotePath, content, { mode: 0o644 }, (err) => {
                  if (err) {
                    // Try creating parent dirs and retry
                    sftp.writeFile(remotePath, content, { mode: 0o644 }, (err2) => {
                      if (err2) { console.log('  Error writing:', err2.message); }
                      else { console.log('  OK (retry)'); }
                      res();
                    });
                  } else {
                    console.log('  OK');
                    res();
                  }
                });
              });
            });
          });
        }

        // Restart PM2
        console.log('\nRestarting PM2...');
        conn.exec('pm2 restart mine-repair 2>/dev/null || pm2 start ' + REMOTE_DIR + '/app.js --name mine-repair', (err, stream) => {
          if (err) { console.log('Exec error:', err); resolve(); return; }
          let output = '';
          stream.on('data', (data) => { output += data.toString(); });
          stream.stderr.on('data', (data) => { output += data.toString(); });
          stream.on('close', (code) => {
            console.log('PM2 result (code ' + code + '):', output || '(empty)');
            conn.end();
            resolve();
          });
        });

      } catch (e) {
        console.error('Error:', e);
        conn.end();
        reject(e);
      }
    });

    conn.on('error', (err) => {
      console.error('SSH connection error:', err.message);
      reject(err);
    });

    conn.on('keyboard-interactive', (name, instructions, lang, prompts, finish) => {
      // Some servers use keyboard-interactive auth
      console.log('Keyboard-interactive auth requested, responding...');
      finish([PASS]);
    });

    console.log('Connecting to', HOST, '...');
    conn.connect({
      host: HOST,
      port: 22,
      username: USER,
      password: PASS,
      tryKeyboard: true,
      readyTimeout: 15000,
      algorithms: {
        kex: [
          'ecdh-sha2-nistp256',
          'ecdh-sha2-nistp384',
          'ecdh-sha2-nistp521',
          'diffie-hellman-group-exchange-sha256',
          'diffie-hellman-group14-sha256',
          'diffie-hellman-group14-sha1',
        ]
      }
    });
  });
}

deploy().then(() => {
  console.log('\nDeploy complete!');
  process.exit(0);
}).catch((e) => {
  console.error('\nDeploy failed:', e.message);
  process.exit(1);
});
