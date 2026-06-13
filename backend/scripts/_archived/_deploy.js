// Deploy script: upload changed files to cloud server and restart
const { Client } = require('ssh2');
const fs = require('fs');
const path = require('path');

const HOST = '162.14.75.235';
const USER = 'root';
const PASS = 'Zsyjw773570!';
const REMOTE_DIR = '/opt/mine-repair-app/backend';

// Files to upload: [local_path, remote_path]
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
      console.log('SSH connected');

      try {
        // Upload each file via SFTP
        for (const [local, remote] of files) {
          const localPath = path.join(BASE, local);
          const remotePath = REMOTE_DIR + '/' + remote;

          if (!fs.existsSync(localPath)) {
            console.log('SKIP (not found):', local);
            continue;
          }

          const content = fs.readFileSync(localPath);
          console.log('Uploading:', local, '->', remotePath, '(' + content.length + ' bytes)');

          await new Promise((res, rej) => {
            conn.sftp((err, sftp) => {
              if (err) { rej(err); return; }
              sftp.writeFile(remotePath, content, (err) => {
                if (err) { rej(err); return; }
                console.log('  OK');
                res();
              });
            });
          });
        }

        // Restart server via PM2
        console.log('Restarting PM2...');
        conn.exec('cd ' + REMOTE_DIR + ' && pm2 restart mine-repair 2>/dev/null || pm2 start app.js --name mine-repair', (err, stream) => {
          if (err) { console.log('PM2 exec error:', err); resolve(); return; }
          stream.on('data', (data) => { console.log('PM2:', data.toString()); });
          stream.stderr.on('data', (data) => { console.log('PM2 stderr:', data.toString()); });
          stream.on('close', () => {
            console.log('Deploy complete');
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
      console.error('SSH error:', err);
      reject(err);
    });

    conn.connect({
      host: HOST,
      port: 22,
      username: USER,
      password: PASS,
      readyTimeout: 10000,
    });
  });
}

deploy().then(() => {
  console.log('Done!');
  process.exit(0);
}).catch((e) => {
  console.error('Failed:', e.message);
  process.exit(1);
});
