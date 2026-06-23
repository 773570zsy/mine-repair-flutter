#!/bin/bash
# ============================================
#  总调度室综合管理系统 — 安全部署脚本
#  用法: cd backend && bash deploy.sh
#  部署内容: 后端代码 + Web前端（不覆盖数据库！）
#  DB 结构变更通过 migrations.ts 自动处理
# ============================================
set -e

HOST="162.14.75.235"
USER="root"
REMOTE_DIR="/opt/mine-repair-app/backend"

echo "========================================"
echo "  总调度室综合管理系统 - 部署脚本"
echo "========================================"

# 1. 停服
echo "[1/5] 暂停服务..."
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "pm2 stop mine-repair"

# 2. 编译 TypeScript
echo "[2/5] 编译 TypeScript..."
npm run build

# 3. 上传代码（不上传 DB — 生产数据不能覆盖！）
echo "[3/5] 上传代码到服务器..."
scp -o StrictHostKeyChecking=no -r dist/* ${USER}@${HOST}:${REMOTE_DIR}/dist/
scp -o StrictHostKeyChecking=no package.json package-lock.json ${USER}@${HOST}:${REMOTE_DIR}/
scp -o StrictHostKeyChecking=no -r public/app/* ${USER}@${HOST}:${REMOTE_DIR}/public/app/

# 4. 安装依赖
echo "[4/5] 安装依赖..."
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "cd ${REMOTE_DIR} && npm install --omit=dev --no-audit --no-fund"

# 5. 启动 + 保存 PM2 状态
echo "[5/5] 启动服务..."
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "NODE_ENV=production pm2 start ${REMOTE_DIR}/dist/index.js --name mine-repair && pm2 save"

echo ""
echo "========================================"
echo "  ✅ 部署完成!"
echo "  API:  https://jlkydds.cn"
echo "  Web:  https://jlkydds.cn/app"
echo "========================================"
