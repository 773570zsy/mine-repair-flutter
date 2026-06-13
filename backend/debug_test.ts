import fs from 'fs';
import path from 'path';

// 必须在任何 db import 之前设置
const TEST_DB_PATH = path.join(process.cwd(), 'data/test_mine_repair.db');
process.env.DB_PATH = TEST_DB_PATH;
process.env.JWT_SECRET = 'test-secret-key';

// 清理旧测试DB
try { fs.unlinkSync(TEST_DB_PATH); } catch {}
try { fs.unlinkSync(TEST_DB_PATH + '-wal'); } catch {}
try { fs.unlinkSync(TEST_DB_PATH + '-shm'); } catch {}

// 现在动态 import
const { initDB, getDB } = await import('./src/db/index.ts');
initDB();

const db = getDB();

// 插入用户（和 fixtures 一样）
db.prepare(`INSERT INTO departments (id, name) VALUES (1, '测试部门')`).run();
db.prepare(`INSERT INTO repair_shops (id, name, status) VALUES (1, '测试修理厂', 1)`).run();
db.prepare(`INSERT INTO users (id, name, phone, password, role, repair_shop_id, department_id) VALUES (3, '测试修理工', '13800000002', '123456', 'repair_shop', 1, 1)`).run();
db.prepare(`INSERT INTO users (id, name, phone, password, role, department_id) VALUES (4, '测试领导', '13800000003', '123456', 'leader', 1)`).run();

// 验证
const u3 = db.prepare("SELECT * FROM users WHERE phone = '13800000002'").get();
console.log('Shop user:', u3 ? 'FOUND' : 'NOT FOUND', u3?.role, u3?.password);

const u4 = db.prepare("SELECT * FROM users WHERE phone = '13800000003'").get();
console.log('Leader:', u4 ? 'FOUND' : 'NOT FOUND', u4?.role, u4?.password);

const all = db.prepare("SELECT id, phone, role, password FROM users").all();
console.log('All users:', all.length);

db.close();
