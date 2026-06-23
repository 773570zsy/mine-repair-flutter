#!/bin/bash
# ============================================
#  总调度室综合管理系统 — 一键部署脚本
#  用法: cd backend && bash deploy.sh
#  部署内容: 后端源码 + Web前端（不覆盖数据库！）
#  TypeScript 编译在服务器端执行
# ============================================
set -e

HOST="162.14.75.235"
USER="root"
REMOTE_DIR="/opt/mine-repair-app/backend"

echo "========================================"
echo "  总调度室综合管理系统 - 部署脚本"
echo "========================================"

# 1. 上传源码
echo "[1/4] 上传源码到服务器..."
rsync -avz --delete --exclude 'node_modules' --exclude 'data' --exclude 'uploads' --exclude '.git' \
  -e "ssh -o StrictHostKeyChecking=no" \
  src/ package.json package-lock.json tsconfig.json \
  ${USER}@${HOST}:${REMOTE_DIR}/

# 2. 上传前端（如果已构建）
if [ -d "../build/web" ]; then
  echo "[2/4] 上传 Web 前端..."
  ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "mkdir -p ${REMOTE_DIR}/public/app"
  rsync -avz --delete -e "ssh -o StrictHostKeyChecking=no" \
    ../build/web/ ${USER}@${HOST}:${REMOTE_DIR}/public/app/
else
  echo "[2/4] 跳过前端（未构建，请先 flutter build web --debug）"
fi

# 3. 服务器编译 + 安装依赖
echo "[3/4] 服务器编译 TypeScript + 安装依赖..."
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "cd ${REMOTE_DIR} && npm install --omit=dev --no-audit --no-fund && npm install --save-dev typescript && npx tsc && echo 'Build OK'"

# 4. 重启服务
echo "[4/4] 重启服务..."
ssh -o StrictHostKeyChecking=no ${USER}@${HOST} "NODE_ENV=production pm2 restart mine-repair --update-env && pm2 save"

echo ""
echo "========================================"
echo "  ✅ 部署完成!"
echo "  API:  https://jlkydds.cn"
echo "  Web:  https://jlkydds.cn/app"
echo "========================================"
