const initSqlJs = require('sql.js');
const fs = require('fs');
const crypto = require('crypto');

async function main() {
  const SQL = await initSqlJs();
  const buf = fs.readFileSync('data/mine_repair.db');
  const db = new SQL.Database(buf);

  // Check if user exists
  const r = db.exec("SELECT id, name, phone, role FROM users WHERE phone='13900000111'");
  if (r.length && r[0].values.length) {
    console.log('Already exists:', JSON.stringify(r[0].values));
    db.close();
    return;
  }

  // Insert with hashed password
  const hash = crypto.createHash('sha256').update('123456').digest('hex');
  db.run("INSERT INTO users (name, phone, role, password) VALUES (?, ?, ?, ?)",
    ['安全员', '13900000111', 'safety_officer', hash]);

  console.log('Inserted safety officer, hash:', hash);

  // Save
  const newBuf = db.export();
  fs.writeFileSync('data/mine_repair.db', Buffer.from(newBuf));
  console.log('Database saved');

  // Verify
  const v = db.exec("SELECT id, name, phone, role FROM users WHERE phone='13900000111'");
  console.log('Verify:', JSON.stringify(v[0].values));

  db.close();
}

main().catch(e => console.error(e));
