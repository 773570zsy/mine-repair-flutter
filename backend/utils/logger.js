const { query } = require('./db');

async function log(userId, userName, action, detail = '') {
  try {
    await query('INSERT INTO operation_logs (user_id, user_name, action, detail) VALUES (?,?,?,?)',
      [userId, userName || '', action, detail || '']);
  } catch(e) {}
}

module.exports = { log };
