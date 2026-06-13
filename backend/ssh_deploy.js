// SSH 自动部署脚本
const { spawn } = require('child_process');

const HOST = '162.14.75.235';
const PWD = 'Zsy773570';

console.log('连接到服务器...');
const ssh = spawn('ssh', ['-o', 'StrictHostKeyChecking=no', `root@${HOST}`], {
  stdio: ['pipe', 'pipe', 'pipe']
});

let loggedIn = false;

ssh.stdout.on('data', (data) => {
  const d = data.toString();
  process.stdout.write(d);
  if (!loggedIn && (d.includes('password') || d.includes('Password'))) {
    ssh.stdin.write(PWD + '\n');
    loggedIn = true;
    console.log('(密码已发送，等待登录...)');
    // After login, run deployment commands
    setTimeout(() => {
      console.log('\n=== 开始部署 ===');
      ssh.stdin.write('curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -\n');
      setTimeout(() => { ssh.stdin.write('sudo apt-get install -y nodejs\n'); }, 30000);
      setTimeout(() => { ssh.stdin.write('sudo npm install -g pm2\n'); }, 60000);
      setTimeout(() => { ssh.stdin.write('node -v && echo "✅ Node.js安装成功"\n'); }, 90000);
    }, 2000);
  }
});

ssh.stderr.on('data', (data) => {
  process.stderr.write(data.toString());
});

ssh.on('close', (code) => {
  console.log(`\nSSH连接关闭 (exit code: ${code})`);
});

// Keep alive
setTimeout(() => {
  console.log('\n准备上传项目文件...');
  console.log('请在另一个终端运行:');
  console.log(`scp -r C:\\Users\\GIGABYTYE\\mine-repair-app root@${HOST}:/opt/`);
}, 120000);
