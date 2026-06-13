const initSqlJs = require('sql.js');
const fs = require('fs');

const DB_PATH = 'C:\\Users\\Administrator\\mine_repair_flutter\\backend\\data\\mine_repair.db';

(async () => {
  const SQL = await initSqlJs();
  const buf = fs.readFileSync(DB_PATH);
  const db = new SQL.Database(buf);

  // Delete all garbled rows
  const deletes = [
    'DELETE FROM repair_orders WHERE rowid=27',
    'DELETE FROM repair_quotes WHERE rowid=24',
    'DELETE FROM external_repair_orders WHERE rowid IN (9,10)',
    'DELETE FROM notifications WHERE rowid BETWEEN 136 AND 160',
    'DELETE FROM driver_attendance WHERE rowid=31',
    'DELETE FROM assessments WHERE rowid IN (9,10,11)',
    'DELETE FROM hazards WHERE rowid=18',
    'DELETE FROM machinery_applications WHERE rowid=23',
  ];

  for (const sql of deletes) {
    db.run(sql);
  }

  const data = db.export();
  fs.writeFileSync(DB_PATH, Buffer.from(data));
  console.log('Cleaned. Verifying...');

  // Verify
  const db2 = new SQL.Database(Buffer.from(data));
  let found = 0;
  const tables = db2.exec("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
  for (const t of tables[0].values) {
    const cols = db2.exec('PRAGMA table_info(' + t[0] + ')');
    if (!cols[0]) continue;
    for (const c of cols[0].values) {
      if (!c[2].includes('TEXT') && !c[2].includes('CHAR')) continue;
      try {
        const rows = db2.exec('SELECT rowid FROM ' + t[0] + ' WHERE ' + c[1] + " LIKE '%' || char(0xFFFD) || '%'");
        if (rows[0]) found += rows[0].values.length;
      } catch(e) {}
    }
  }
  console.log('Garbled remaining:', found);
  console.log('File size:', fs.statSync(DB_PATH).size);
})();
