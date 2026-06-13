// Deploy script v3 - captures QR code, waits for user to scan
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

const conn = new Client();
let bannerShown = false;

conn.on('ready', async () => {
  console.log('\n✅ SSH认证成功！开始部署...\n');

  try {
    for (const [local, remote] of files) {
      const localPath = path.join(BASE, local);
      const remotePath = REMOTE_DIR + '/' + remote;

      if (!fs.existsSync(localPath)) {
        console.log('  SKIP:', local);
        continue;
      }

      const content = fs.readFileSync(localPath);
      process.stdout.write('  Uploading ' + local + ' (' + content.length + ' bytes)... ');

      await new Promise((res, rej) => {
        conn.sftp((err, sftp) => {
          if (err) { console.log('SFTP error:', err.message); res(); return; }
          sftp.writeFile(remotePath, content, (err) => {
            if (err) { console.log('Write error:', err.message); }
            else { console.log('OK'); }
            res();
          });
        });
      });
    }

    console.log('\n重启服务...');
    conn.exec('cd ' + REMOTE_DIR + ' && pm2 restart mine-repair 2>/dev/null || pm2 start app.js --name mine-repair', (err, stream) => {
      if (err) { console.log('PM2 error:', err); conn.end(); return; }
      let out = '';
      stream.on('data', (d) => { out += d.toString(); });
      stream.stderr.on('data', (d) => { out += d.toString(); });
      stream.on('close', () => {
        console.log('PM2:', out.trim() || 'OK');
        console.log('\n🎉 部署完成！http://162.14.75.235:3000');
        conn.end();
      });
    });
  } catch (e) {
    console.error('部署出错:', e.message);
    conn.end();
  }
});

conn.on('error', (err) => {
  console.error('SSH错误:', err.message);
  process.exit(1);
});

// Handle banner - this is where the QR code appears
conn.on('banner', (msg) => {
  if (!bannerShown) {
    bannerShown = true;
    console.log('\n📱 请使用微信扫描以下二维码进行SSH登录认证：\n');
    console.log(msg);
    console.log('\n⏳ 等待扫码认证中...（请用微信扫码后等待连接建立）\n');
  }
});

// Handle keyboard-interactive auth (Tencent Cloud QR + password)
conn.on('keyboard-interactive', (name, instructions, lang, prompts, finish) => {
  console.log('收到认证提示:', prompts);
  // Respond with password for each prompt
  finish(prompts.map(() => PASS));
});

console.log('正在连接 ' + HOST + ':22 ...');
conn.connect({
  host: HOST,
  port: 22,
  username: USER,
  password: PASS,
  tryKeyboard: true,
  readyTimeout: 120000,  // 2 minutes for user to scan QR
  keepaliveInterval: 10000,
  keepaliveCountMax: 12,
});
