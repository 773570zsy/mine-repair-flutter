const initSqlJs = require('sql.js');
const fs = require('fs');

(async () => {
  const SQL = await initSqlJs();
  const DB_PATH = 'C:\\Users\\Administrator\\mine_repair_flutter\\backend\\data\\mine_repair.db';
const buf = fs.readFileSync(DB_PATH);
  const db = new SQL.Database(buf);

  const tables = db.exec("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'");
  let total = 0;

  for (const t of tables[0].values) {
    const tname = t[0];
    const cols = db.exec('PRAGMA table_info(' + tname + ')');
    if (!cols[0]) continue;

    for (const c of cols[0].values) {
      const cname = c[1];
      const ctype = c[2];
      if (!ctype.includes('TEXT') && !ctype.includes('CHAR')) continue;

      try {
        // Search for records where the text column contains non-ASCII bytes that aren't valid UTF-8
        // We look for U+FFFD first, then common GBK-in-UTF8 patterns
        const rows = db.exec(
          "SELECT rowid, " + cname + " FROM " + tname +
          " WHERE " + cname + " LIKE '%' || char(0xFFFD) || '%'"
        );
        if (rows[0] && rows[0].values.length > 0) {
          for (const r of rows[0].values) {
            const val = String(r[1]);
            // Only flag if it contains suspicious chars (not clean ASCII or CJK)
            if (/[\x00-\x08\x0B\x0C\x0E-\x1F]/.test(val) || val.includes('�')) {
              console.log('GARBLED:', tname, 'rowid=' + r[0], cname, '=', JSON.stringify(val).slice(0, 80));
              total++;
            }
          }
        }

        // Also check for rows where Chinese text looks garbled (contains Cyrillic chars from GBK mis-encoding)
        const rows2 = db.exec(
          "SELECT rowid, " + cname + " FROM " + tname +
          " WHERE " + cname + " LIKE '%' || char(0x0479) || '%'"  // Cyrillic ѹ (common in GBK→UTF-8 garble)
        );
        if (rows2[0] && rows2[0].values.length > 0) {
          for (const r of rows2[0].values) {
            console.log('GARBLED(GBK):', tname, 'rowid=' + r[0], cname, '=', JSON.stringify(r[1]).slice(0, 80));
            total++;
          }
        }
      } catch(e) {
        // column might not exist
      }
    }
  }
  console.log('Total garbled rows:', total);
})();
