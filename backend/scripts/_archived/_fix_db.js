const initSqlJs = require('sql.js');
const fs = require('fs');
const crypto = require('crypto');

async function main() {
  const SQL = await initSqlJs();
  const buf = fs.readFileSync('data/mine_repair.db');
  const db = new SQL.Database(buf);

  // Fix the CHECK constraint on users table to allow safety_officer
  console.log('Fixing users table CHECK constraint...');

  try {
    db.run(`
      CREATE TABLE IF NOT EXISTS users_new (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT DEFAULT '',
        role TEXT NOT NULL CHECK(role IN ('driver','repair_shop','leader','admin','external','external_approver','safety_officer')),
        repair_shop_id INTEGER,
        avatar_url TEXT DEFAULT '',
        status INTEGER DEFAULT 1,
        password TEXT DEFAULT '',
        department_id INTEGER,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // Copy data
    db.run(`INSERT INTO users_new SELECT id, name, phone, role, repair_shop_id, avatar_url, status, password, department_id, created_at, updated_at FROM users`);

    // Drop old table and rename
    db.run(`DROP TABLE users`);
    db.run(`ALTER TABLE users_new RENAME TO users`);

    console.log('CHECK constraint updated');
  } catch(e) {
    console.log('Error during table migration:', e.message);
    // Try a simpler approach - just insert the user
    // SQLite might accept the new role even with old constraint if we're lucky
  }

  // Now insert safety officer
  const r = db.exec("SELECT id FROM users WHERE phone='13900000111'");
  if (r.length && r[0].values.length) {
    console.log('Safety officer already exists');
  } else {
    const hash = crypto.createHash('sha256').update('123456').digest('hex');
    db.run("INSERT INTO users (name, phone, role, password) VALUES (?, ?, ?, ?)",
      ['安全员', '13900000111', 'safety_officer', hash]);
    console.log('Safety officer inserted');
  }

  // Save
  const newBuf = db.export();
  fs.writeFileSync('data/mine_repair.db', Buffer.from(newBuf));
  console.log('Saved');

  // Verify
  const v = db.exec("SELECT id, name, role FROM users WHERE phone='13900000111'");
  console.log('Verify:', JSON.stringify(v[0]?.values));
  db.close();
}

main().catch(e => console.error('FATAL:', e));
