const { query } = require('./db');

// 发送通知（写入数据库 + 企微推送）
async function sendNotification(roleOrUserId, type, title, content, orderId) {
  let targetUsers;

  if (typeof roleOrUserId === 'number') {
    targetUsers = [{ id: roleOrUserId }];
  } else {
    // 按角色查所有用户
    targetUsers = await query('SELECT id FROM users WHERE role = ? AND status = 1', [roleOrUserId]);
  }

  for (const user of targetUsers) {
    await query(
      'INSERT INTO notifications (user_id, type, title, content, order_id) VALUES (?, ?, ?, ?, ?)',
      [user.id, type, title, content, orderId]
    );
  }

  // TODO: 接入企业微信API推送消息
  // await sendWecomMessage(targetUsers, title, content);
}

module.exports = { sendNotification };
