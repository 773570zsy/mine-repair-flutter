#!/bin/bash
# ============================================
#  总调度室综合管理系统 — 一键部署脚本
#  用法: cd backend && bash deploy.sh
# ============================================
set -e

HOST="162.14.75.235"
USER="root"
REMOTE_DIR="/opt/mine-repair-app/backend"

echo "========================================"
echo "  总调度室综合管理系统 - 部署脚本"
echo "========================================"

# 1. 运行测试
echo "[1/4] 运行测试..."
npm test || { echo "❌ 测试失败，终止部署"; exit 1; }

# 2. 编译
echo "[2/4] 编译 TypeScript..."
npm run build

# 3. 上传文件
echo "[3/4] 上传到服务器..."
scp -o StrictHostKeyChecking=no -r dist/* ${USER}@${HOST}:${REMOTE_DIR}/dist/
scp -o StrictHostKeyChecking=no package.json package-lock.json ${USER}@${HOST}:${REMOTE_DIR}/

# 4. 安装依赖 + 重启
echo "[4/4] 重启服务..."
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "cd ${REMOTE_DIR} && npm install --omit=dev --no-audit --no-fund && NODE_ENV=production pm2 restart mine-repair --update-env && pm2 save"

echo ""
echo "========================================"
echo "  部署完成!"
echo "  API: https://jlkydds.cn"
echo "  查看日志: ssh ${USER}@${HOST} 'pm2 logs mine-repair'"
echo "========================================"
