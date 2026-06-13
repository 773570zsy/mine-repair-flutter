import { defineConfig } from 'vitest/config';
import path from 'path';

// 必须在任何测试模块 import 之前设置（db/index.ts 在模块顶层读取 DB_PATH）
process.env.DB_PATH = path.resolve(process.cwd(), 'data/test_mine_repair.db');
process.env.JWT_SECRET = 'test-secret-key';

export default defineConfig({
  test: {
    globals: true,
    environment: 'node',
    include: ['src/__tests__/**/*.test.ts'],
    setupFiles: ['src/__tests__/setup.ts'],
    testTimeout: 15000,
    fileParallelism: false,  // SQLite 不支持并行写
  },
});
