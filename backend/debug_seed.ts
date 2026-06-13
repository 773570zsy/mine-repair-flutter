import { initDB, getDB } from './src/db';
import fs from 'fs';
import path from 'path';

process.env.DB_PATH = path.join(process.cwd(), 'data/test_debug.db');
process.env.JWT_SECRET = 'test-secret-key';
try { fs.unlinkSync(process.env.DB_PATH!); } catch {}

initDB();
const db = getDB();

// 模拟 fixtures 的 seed 操作
db.prepare(`INSERT INTO departments (id, name) VALUES (1, '测试部门')`).run();

// 插入修理厂
db.prepare(`INSERT INTO repair_shops (id, name, contact_person, contact_phone, status) VALUES (1, '测试修理厂', '李师傅', '13900001111', 1)`).run();
console.log('1. Repair shop inserted, count:', db.prepare('SELECT count(*) as c FROM repair_shops').get());

// 插入修理厂用户
db.prepare(`INSERT INTO users (id, name, phone, password, role, repair_shop_id, department_id) VALUES (3, '测试修理工', '13800000002', '123456', 'repair_shop', 1, 1)`).run();
console.log('2. Shop user inserted');

// 插入领导
db.prepare(`INSERT INTO users (id, name, phone, password, role, department_id) VALUES (4, '测试领导', '13800000003', '123456', 'leader', 1)`).run();
console.log('3. Leader inserted');

// 验证
const all = db.prepare("SELECT id, phone, role, password FROM users").all();
console.log('All users:', JSON.stringify(all, null, 2));

const shopUser = db.prepare("SELECT * FROM users WHERE phone = '13800000002'").get();
console.log('Shop user found:', shopUser ? 'YES' : 'NO');

const leaderUser = db.prepare("SELECT * FROM users WHERE phone = '13800000003'").get();
console.log('Leader found:', leaderUser ? 'YES' : 'NO');

db.close();
