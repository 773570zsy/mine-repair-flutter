import fs from 'fs';
import path from 'path';
import Database from 'better-sqlite3';

const TEST_DB = 'C:/Users/Administrator/mine_repair_flutter/backend/data/test_mine_repair.db';

const db = new Database(TEST_DB);
const users = db.prepare("SELECT id, phone, role, length(password) as pw_len FROM users").all();
console.log('Test DB users:', JSON.stringify(users, null, 2));
db.close();
