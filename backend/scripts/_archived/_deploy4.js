// Deploy v4 - handles both QR and verification code auth
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
    conn.on('banner', (msg) => {
      console.log(msg);
    });

    // Handle keyboard-interactive: QR timeout -> verification code
    conn.on('keyboard-interactive', (name, instructions, lang, prompts, finish) => {
      console.log('\n认证提示:', prompts.map(p => p.prompt).join('\n'));

      // Check if it's asking for verification code
      const fullPrompt = prompts.map(p => p.prompt).join('');
      const codeMatch = fullPrompt.match(/验证码\s*(\d+)/);
      if (codeMatch) {
        console.log('\n请输入验证码: ' + codeMatch[1]);
        finish([codeMatch[1]]);
      } else {
        // Standard password prompt
        finish(prompts.map(() => PASS));
      }
    });

    conn.on('ready', async () => {
      console.log('\n✅ 认证成功！开始部署...\n');

      try {
        for (const [local, remote] of files) {
          const localPath = path.join(BASE, local);
          const remotePath = REMOTE_DIR + '/' + remote;

          if (!fs.existsSync(localPath)) {
            console.log('  SKIP:', local);
            continue;
          }

          const content = fs.readFileSync(localPath);
          process.stdout.write('  ' + local + ' (' + content.length + ' bytes)... ');

          await new Promise((res) => {
            conn.sftp((err, sftp) => {
              if (err) { console.log('SFTP err:', err.message); res(); return; }
              sftp.writeFile(remotePath, content, (err) => {
                console.log(err ? 'ERR: ' + err.message : 'OK');
                res();
              });
            });
          });
        }

        console.log('\n重启 PM2...');
        conn.exec('cd ' + REMOTE_DIR + ' && pm2 restart mine-repair 2>/dev/null || pm2 start app.js --name mine-repair', (err, stream) => {
          if (err) { console.log('Exec err:', err); conn.end(); resolve(); return; }
          let out = '';
          stream.on('data', d => { out += d.toString(); });
          stream.stderr.on('data', d => { out += d.toString(); });
          stream.on('close', () => {
            console.log('PM2:', out.trim() || 'OK');
            console.log('\n🎉 部署完成！访问 http://162.14.75.235:3000');
            conn.end();
            resolve();
          });
        });
      } catch (e) {
        console.error('部署出错:', e.message);
        conn.end();
        reject(e);
      }
    });

    conn.on('error', (err) => {
      console.error('连接错误:', err.message);
      reject(err);
    });

    console.log('正在连接 162.14.75.235:22 ...');
    conn.connect({
      host: HOST,
      port: 22,
      username: USER,
      password: PASS,
      tryKeyboard: true,
      readyTimeout: 60000,
      keepaliveInterval: 5000,
    });
  });
}

deploy().then(() => process.exit(0)).catch(() => process.exit(1));
