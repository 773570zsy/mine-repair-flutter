import { beforeAll, afterAll } from 'vitest';
import fs from 'fs';

// DB_PATH 和 JWT_SECRET 已在 vitest.config.ts 的 env 中设置
// (确保在模块 import 之前已生效，避免缓存到生产DB)
const TEST_DB_PATH = process.env.DB_PATH!;

let initialized = false;

beforeAll(async () => {
  if (initialized) return; // 只初始化一次

  // 删除旧的测试数据库
  try { fs.unlinkSync(TEST_DB_PATH); } catch { /* 不存在 */ }
  try { fs.unlinkSync(TEST_DB_PATH + '-wal'); } catch { /* 不存在 */ }
  try { fs.unlinkSync(TEST_DB_PATH + '-shm'); } catch { /* 不存在 */ }

  const { initDB } = await import('../db');
  initDB();
  initialized = true;
});

afterAll(async () => {
  // 最后清理 — vitest 退出时执行
  try {
    const { getDB } = await import('../db');
    getDB().close();
  } catch { /* 可能已关闭 */ }
  try { fs.unlinkSync(TEST_DB_PATH); } catch { /* 不影响 */ }
  try { fs.unlinkSync(TEST_DB_PATH + '-wal'); } catch { /* 不影响 */ }
  try { fs.unlinkSync(TEST_DB_PATH + '-shm'); } catch { /* 不影响 */ }
});
