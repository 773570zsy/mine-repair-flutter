// Deploy using system SSH client (works with Tencent Cloud QR auth)
// This script displays the QR code and waits for user to scan
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const HOST = 'root@162.14.75.235';
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

// Step 1: Upload each file via scp
async function uploadFile(localPath, remotePath) {
  return new Promise((resolve, reject) => {
    const fullRemote = HOST + ':' + REMOTE_DIR + '/' + remotePath;
    console.log('  Uploading:', remotePath);

    const scp = spawn('scp', [
      '-o', 'StrictHostKeyChecking=no',
      '-o', 'ConnectTimeout=10',
      localPath,
      fullRemote
    ], {
      stdio: ['pipe', 'pipe', 'pipe']
    });

    let stdout = '', stderr = '';

    scp.stdout.on('data', (d) => { stdout += d.toString(); });
    scp.stderr.on('data', (d) => {
      const text = d.toString();
      stderr += text;
      // Show progress/QR codes
      process.stderr.write(text);
    });

    scp.on('close', (code) => {
      if (code === 0) {
        console.log('    OK');
        resolve();
      } else {
        console.log('    Failed (code ' + code + ')');
        reject(new Error('scp exit ' + code + ': ' + stderr.slice(-200)));
      }
    });

    scp.on('error', (err) => {
      reject(err);
    });
  });
}

async function deploy() {
  console.log('========================================');
  console.log('  部署到 162.14.75.235');
  console.log('  如弹出二维码，请用微信扫码');
  console.log('========================================\n');

  // Upload all files
  for (const [local, remote] of files) {
    const localPath = path.join(BASE, local);
    if (!fs.existsSync(localPath)) {
      console.log('  SKIP (not found):', local);
      continue;
    }
    const size = fs.statSync(localPath).size;
    console.log('  [' + remote + '] ' + size + ' bytes');

    try {
      await uploadFile(localPath, remote);
    } catch (e) {
      console.error('  Upload error:', e.message);
      console.log('  Continuing with next file...');
    }
  }

  // Step 2: Restart via SSH
  console.log('\n重启服务...');
  const ssh = spawn('ssh', [
    '-o', 'StrictHostKeyChecking=no',
    '-o', 'ConnectTimeout=10',
    HOST,
    'cd ' + REMOTE_DIR + ' && pm2 restart mine-repair 2>/dev/null || pm2 start app.js --name mine-repair'
  ], {
    stdio: ['pipe', 'pipe', 'pipe']
  });

  ssh.stdout.on('data', (d) => { console.log('PM2:', d.toString().trim()); });
  ssh.stderr.on('data', (d) => { process.stderr.write(d.toString()); });

  ssh.on('close', (code) => {
    if (code === 0) {
      console.log('\n🎉 部署完成！');
      console.log('访问: http://162.14.75.235:3000');
    } else {
      console.log('\nPM2 restart exit code:', code);
      console.log('文件已上传，请手动重启: pm2 restart mine-repair');
    }
  });
}

deploy().catch(e => {
  console.error('Deploy failed:', e.message);
  process.exit(1);
});
