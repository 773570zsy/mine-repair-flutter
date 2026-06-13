# GitHub Actions 部署配置

## 首次设置

### 1. 创建 GitHub 仓库
```bash
# 在 github.com 创建新仓库: mine-repair-flutter
git remote add origin git@github.com:YOUR_USER/mine-repair-flutter.git
git push -u origin main
```

### 2. 添加 Secrets (Settings → Secrets and variables → Actions → New repository secret)

| Secret | 值 |
|--------|-----|
| `SSH_HOST` | `162.14.75.235` |
| `SSH_USER` | `root` |
| `SSH_PRIVATE_KEY` | 复制 `~/.ssh/id_ed25519` 全部内容（含 -----BEGIN/END-----） |

### 3. 推送触发部署
```bash
git push origin main
```
GitHub Actions 自动执行: 安装依赖 → 运行70个测试 → 编译 → 上传服务器 → PM2重启

## 本地部署
```bash
cd backend && bash deploy.sh
```
