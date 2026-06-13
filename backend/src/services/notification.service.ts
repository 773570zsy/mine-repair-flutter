import { getDB } from '../db';

/**
 * 统一通知服务
 * - sendToRole: 按角色发送给该角色的所有活跃用户
 * - sendToUser: 发送给指定用户
 * - sendToRepairShop: 发送给指定修理厂的所有用户
 */

export interface NotificationData {
  type: string;
  title: string;
  content: string;
  orderId?: number;
}

export function sendToRole(role: string, data: NotificationData): void {
  try {
    const users = getDB().prepare(
      'SELECT id FROM users WHERE role = ? AND status = 1'
    ).all(role) as Array<{ id: number }>;
    const stmt = getDB().prepare(
      'INSERT INTO notifications (user_id, type, title, content, order_id) VALUES (?, ?, ?, ?, ?)'
    );
    for (const u of users) {
      try {
        stmt.run(u.id, data.type, data.title, data.content, data.orderId ?? null);
      } catch { /* skip */ }
    }
  } catch { /* 通知非关键 */ }
}

export function sendToUser(userId: number, data: NotificationData): void {
  try {
    getDB().prepare(
      'INSERT INTO notifications (user_id, type, title, content, order_id) VALUES (?, ?, ?, ?, ?)'
    ).run(userId, data.type, data.title, data.content, data.orderId ?? null);
  } catch { /* 通知非关键 */ }
}

export function sendToRepairShop(repairShopId: number, data: NotificationData): void {
  try {
    const users = getDB().prepare(
      'SELECT id FROM users WHERE role = ? AND repair_shop_id = ? AND status = 1'
    ).all('repair_shop', repairShopId) as Array<{ id: number }>;
    const stmt = getDB().prepare(
      'INSERT INTO notifications (user_id, type, title, content, order_id) VALUES (?, ?, ?, ?, ?)'
    );
    for (const u of users) {
      try {
        stmt.run(u.id, data.type, data.title, data.content, data.orderId ?? null);
      } catch { /* skip */ }
    }
  } catch { /* 通知非关键 */ }
}

/**
 * 快捷通知方法
 */
export const notify = {
  /** 新报修单 → 通知修理厂 + 管理员 */
  newRepairOrder(orderNo: string, vehicle: string, desc: string, orderId: number): void {
    const title = '新报修工单';
    const content = `报修单${orderNo}：${vehicle} ${desc}`;
    sendToRole('repair_shop', { type: 'new_order', title, content, orderId });
    sendToRole('admin', { type: 'new_order', title: `新报修单-${orderNo}`, content, orderId });
    sendToRole('leader', { type: 'new_order', title: `新报修单-${orderNo}`, content, orderId });
  },

  /** 报价待审批 → 通知报修人 + 领导 */
  quotePending(orderNo: string, amount: number, reporterId: number, orderId: number): void {
    const content = `报修单${orderNo}报价¥${amount}，待审批`;
    sendToUser(reporterId, { type: 'quote_pending', title: '报价待审批', content, orderId });
    sendToRole('leader', { type: 'quote_pending', title: `报价待审批-${orderNo}`, content, orderId });
    sendToRole('admin', { type: 'quote_pending', title: `报价待审批-${orderNo}`, content, orderId });
  },

  /** 报价已通过 → 通知修理厂 */
  quoteApproved(orderNo: string, shopId: number, orderId: number): void {
    sendToRepairShop(shopId, {
      type: 'quote_approved', title: '报价已通过',
      content: `报修单${orderNo}报价已审批通过，请开始维修`, orderId,
    });
  },

  /** 报价被驳回 → 通知修理厂 */
  quoteRejected(orderNo: string, reason: string, shopId: number, orderId: number): void {
    sendToRepairShop(shopId, {
      type: 'quote_rejected', title: '报价被驳回',
      content: `报修单${orderNo}报价被驳回：${reason}`, orderId,
    });
  },

  /** 维修完成 → 通知报修人 */
  repairCompleted(orderNo: string, reporterId: number, orderId: number): void {
    sendToUser(reporterId, {
      type: 'repair_completed', title: '车辆维修完成',
      content: `报修单${orderNo}已完工，请验收`, orderId,
    });
  },

  /** 标为加急 */
  markedUrgent(orderNo: string, orderId: number, reporterId?: number, shopId?: number): void {
    const content = `报修单${orderNo}已标记为加急`;
    if (reporterId) sendToUser(reporterId, { type: 'urgent', title: '工单加急', content, orderId });
    if (shopId) sendToRepairShop(shopId, { type: 'urgent', title: '工单加急', content, orderId });
  },

  /** 外部报修：新单 */
  newExternalOrder(orderNo: string, vehicle: string, desc: string, orderId: number): void {
    const content = `外部报修单${orderNo}：${vehicle} ${desc}`;
    sendToRole('repair_shop', { type: 'new_external_order', title: '新外部报修单', content, orderId });
    sendToRole('admin', { type: 'new_external_order', title: `外部报修-${orderNo}`, content, orderId });
    sendToRole('leader', { type: 'new_external_order', title: `外部报修-${orderNo}`, content, orderId });
  },

  /** 隐患上报 → 通知安全员 */
  newHazard(hazardNo: string, location: string, reporterId: number): void {
    sendToRole('safety_officer', {
      type: 'new_hazard', title: '新隐患上报',
      content: `隐患${hazardNo}：${location}`,
    });
  },

  /** 用车申请 → 通知调度员 */
  newMachineryApply(appNo: string, vehicleType: string): void {
    sendToRole('dispatcher', {
      type: 'new_machinery', title: '新用车申请',
      content: `用车申请${appNo}：${vehicleType}`,
    });
    sendToRole('admin', {
      type: 'new_machinery', title: `用车申请-${appNo}`,
      content: `新用车申请${appNo}：${vehicleType}`,
    });
  },
};
