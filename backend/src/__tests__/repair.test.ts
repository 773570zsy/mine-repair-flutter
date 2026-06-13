import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import app from '../app';
import {
  seedTestAdmin, seedTestVehicle, seedTestDriver,
  seedTestRepairShop, seedTestRepairShopUser, seedTestLeader,
} from './fixtures';
import { getDB } from '../db';

describe('Repair 维修流程', () => {
  let driverToken: string;
  let shopToken: string;
  let leaderToken: string;
  let orderId: number;
  let orderNo: string;

  beforeAll(() => {
    seedTestAdmin();
    seedTestVehicle();
    seedTestDriver();
    const shop = seedTestRepairShop();
    seedTestRepairShopUser(shop.id);
    seedTestLeader();
  });

  // ==================== 认证 ====================

  it('驾驶员登录', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ phone: '13800000001', password: '123456' });
    expect(res.body.code).toBe(200);
    driverToken = res.body.data.token;
  });

  it('修理厂用户登录', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ phone: '13800000002', password: '123456' });
    expect(res.body.code).toBe(200);
    shopToken = res.body.data.token;
  });

  it('领导登录', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ phone: '13800000003', password: '123456' });
    expect(res.body.code).toBe(200);
    leaderToken = res.body.data.token;
  });

  // ==================== 维修全流程（正常路径） ====================

  it('步骤1: 驾驶员报修', async () => {
    const res = await request(app)
      .post('/api/repair/report')
      .set('Authorization', `Bearer ${driverToken}`)
      .send({
        vehicle_id: 1,
        fault_description: '发动机异响，加速无力',
        fault_images: [],
        repair_shop_id: 1,
      });

    expect(res.body.code).toBe(200);
    expect(res.body.msg).toBe('报修成功');
    expect(res.body.data.order_no).toMatch(/^WX/);
    orderNo = res.body.data.order_no;

    // 查数据库验证工单状态
    const order = getDB().prepare('SELECT * FROM repair_orders WHERE order_no = ?').get(orderNo) as any;
    expect(order).toBeTruthy();
    expect(order.status).toBe('pending_accept');
    orderId = order.id;
  });

  it('驾驶员报修 Zod 校验: 空body应返回 400', async () => {
    const res = await request(app)
      .post('/api/repair/report')
      .set('Authorization', `Bearer ${driverToken}`)
      .send({});
    expect(res.status).toBe(400);
    expect(res.body.msg).toContain('参数校验失败');
  });

  it('驾驶员报修 Zod 校验: 缺少 fault_description 应返回 400', async () => {
    const res = await request(app)
      .post('/api/repair/report')
      .set('Authorization', `Bearer ${driverToken}`)
      .send({ vehicle_id: 1 });
    expect(res.status).toBe(400);
  });

  it('非驾驶员不能报修', async () => {
    const res = await request(app)
      .post('/api/repair/report')
      .set('Authorization', `Bearer ${shopToken}`)
      .send({ vehicle_id: 1, fault_description: '测试' });
    expect(res.body.code).toBe(403);
  });

  it('步骤2: 修理厂接单', async () => {
    const res = await request(app)
      .post(`/api/repair/accept-order/${orderId}`)
      .set('Authorization', `Bearer ${shopToken}`);

    expect(res.body.code).toBe(200);
    expect(res.body.msg).toBe('接单成功');

    const order = getDB().prepare('SELECT status FROM repair_orders WHERE id = ?').get(orderId) as any;
    expect(order.status).toBe('pending_quote');
  });

  it('不能重复接单（状态不是 pending_accept）', async () => {
    const res = await request(app)
      .post(`/api/repair/accept-order/${orderId}`)
      .set('Authorization', `Bearer ${shopToken}`);
    expect(res.body.code).toBe(400);
  });

  it('步骤3: 修理厂提交报价', async () => {
    const res = await request(app)
      .post(`/api/repair/submit-quote/${orderId}`)
      .set('Authorization', `Bearer ${shopToken}`)
      .send({
        quote_amount: 3500,
        parts_cost: 2000,
        labor_cost: 1000,
        hours_cost: 500,
        estimated_days: 3,
        quote_detail: '发动机检修，更换活塞环',
      });

    expect(res.body.code).toBe(200);
    expect(res.body.msg).toBe('报价提交成功');

    const order = getDB().prepare('SELECT status FROM repair_orders WHERE id = ?').get(orderId) as any;
    expect(order.status).toBe('pending_approval');

    // 验证报价记录
    const quote = getDB().prepare('SELECT * FROM repair_quotes WHERE order_id = ?').get(orderId) as any;
    expect(quote.quote_amount).toBe(3500);
    expect(quote.parts_cost).toBe(2000);
  });

  it('报价 Zod 校验: 缺少 quote_amount 应返回 400', async () => {
    // 先创建一个新工单到 pending_quote 状态
    const res = await request(app)
      .post(`/api/repair/submit-quote/99999`)
      .set('Authorization', `Bearer ${shopToken}`)
      .send({ estimated_days: 2 });
    expect(res.status).toBe(400);
  });

  it('步骤4: 领导审批通过', async () => {
    const res = await request(app)
      .post(`/api/repair/approve/${orderId}`)
      .set('Authorization', `Bearer ${leaderToken}`)
      .send({ approved: true });

    expect(res.body.code).toBe(200);
    expect(res.body.msg).toBe('审批通过');

    const order = getDB().prepare('SELECT status FROM repair_orders WHERE id = ?').get(orderId) as any;
    expect(order.status).toBe('approved');
  });

  it('审批 Zod 校验: 缺少 approved 字段应返回 400', async () => {
    const res = await request(app)
      .post(`/api/repair/approve/${orderId}`)
      .set('Authorization', `Bearer ${leaderToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('不能重复审批', async () => {
    const res = await request(app)
      .post(`/api/repair/approve/${orderId}`)
      .set('Authorization', `Bearer ${leaderToken}`)
      .send({ approved: true });
    expect(res.body.code).toBe(400);
  });

  it('步骤5: 修理厂更新维修进度', async () => {
    const res = await request(app)
      .post(`/api/repair/update-progress/${orderId}`)
      .set('Authorization', `Bearer ${shopToken}`)
      .send({ content: '已拆解发动机，确认需更换活塞环和缸垫' });

    expect(res.body.code).toBe(200);
    expect(res.body.msg).toBe('进度更新成功');

    const order = getDB().prepare('SELECT status FROM repair_orders WHERE id = ?').get(orderId) as any;
    expect(order.status).toBe('repairing');
  });

  it('更新进度 Zod 校验: 无content也能成功(default "")', async () => {
    const res = await request(app)
      .post(`/api/repair/update-progress/${orderId}`)
      .set('Authorization', `Bearer ${shopToken}`)
      .send({});
    expect(res.body.code).toBe(200); // content 有 default
  });

  it('步骤6: 修理厂完工', async () => {
    const res = await request(app)
      .post(`/api/repair/complete/${orderId}`)
      .set('Authorization', `Bearer ${shopToken}`)
      .send({ new_photos: [] });

    expect(res.body.code).toBe(200);
    expect(res.body.msg).toBe('完工通知已发送');

    const order = getDB().prepare('SELECT status FROM repair_orders WHERE id = ?').get(orderId) as any;
    expect(order.status).toBe('completed');
  });

  it('非修理厂不能完工', async () => {
    const res = await request(app)
      .post(`/api/repair/complete/${orderId}`)
      .set('Authorization', `Bearer ${driverToken}`)
      .send({});
    expect(res.body.code).toBe(403);
  });

  it('步骤7: 驾驶员试车验收', async () => {
    const res = await request(app)
      .post(`/api/repair/accept/${orderId}`)
      .set('Authorization', `Bearer ${driverToken}`)
      .send({ content: '故障已消除，试车正常，同意验收' });

    expect(res.body.code).toBe(200);
    expect(res.body.msg).toBe('验收成功');

    const order = getDB().prepare('SELECT status FROM repair_orders WHERE id = ?').get(orderId) as any;
    expect(order.status).toBe('accepted');
  });

  it('不能对已验收工单再验收', async () => {
    const res = await request(app)
      .post(`/api/repair/accept/${orderId}`)
      .set('Authorization', `Bearer ${driverToken}`)
      .send({});
    expect(res.body.code).toBe(400);
  });

  // ==================== 功能查询 ====================

  it('驾驶员可查看我的报修列表', async () => {
    const res = await request(app)
      .get('/api/repair/my-orders')
      .set('Authorization', `Bearer ${driverToken}`);

    expect(res.body.code).toBe(200);
    expect(res.body.data).toBeInstanceOf(Array);
    expect(res.body.data.length).toBeGreaterThanOrEqual(1);
    expect(res.body.data[0]).toHaveProperty('plate_number');
  });

  it('修理厂可查看待接单列表', async () => {
    const res = await request(app)
      .get('/api/repair/pending-accept')
      .set('Authorization', `Bearer ${shopToken}`);

    expect(res.body.code).toBe(200);
    expect(res.body.data).toBeInstanceOf(Array);
  });

  it('领导可查看全部工单', async () => {
    const res = await request(app)
      .get('/api/repair/all-orders')
      .set('Authorization', `Bearer ${leaderToken}`);

    expect(res.body.code).toBe(200);
    expect(res.body.data).toHaveProperty('list');
    expect(res.body.data.list.length).toBeGreaterThanOrEqual(1);
  });

  it('可查看工单详情（含进度流）', async () => {
    const res = await request(app)
      .get(`/api/repair/detail/${orderId}`)
      .set('Authorization', `Bearer ${driverToken}`);

    expect(res.body.code).toBe(200);
    expect(res.body.data.order).toBeTruthy();
    expect(res.body.data.progress).toBeInstanceOf(Array);
    // 完整流程应有 ≥7 条进度记录
    expect(res.body.data.progress.length).toBeGreaterThanOrEqual(7);
  });

  it('可获取修理厂列表', async () => {
    const res = await request(app)
      .get('/api/repair/shops')
      .set('Authorization', `Bearer ${driverToken}`);

    expect(res.body.code).toBe(200);
    expect(res.body.data).toBeInstanceOf(Array);
    expect(res.body.data.length).toBeGreaterThanOrEqual(1);
  });

  // ==================== 驳回流程 ====================

  it('领导驳回报价：报修-接单-报价-驳回', async () => {
    // 创建第二个工单走驳回流程
    const reportRes = await request(app)
      .post('/api/repair/report')
      .set('Authorization', `Bearer ${driverToken}`)
      .send({ vehicle_id: 1, fault_description: '变速箱漏油', repair_shop_id: 1 });
    const orderId2 = (getDB().prepare('SELECT id FROM repair_orders WHERE order_no = ?').get(reportRes.body.data.order_no) as any).id;

    // 接单
    await request(app).post(`/api/repair/accept-order/${orderId2}`).set('Authorization', `Bearer ${shopToken}`);
    // 报价
    await request(app)
      .post(`/api/repair/submit-quote/${orderId2}`)
      .set('Authorization', `Bearer ${shopToken}`)
      .send({ quote_amount: 8000, estimated_days: 5 });

    // 驳回
    const res = await request(app)
      .post(`/api/repair/approve/${orderId2}`)
      .set('Authorization', `Bearer ${leaderToken}`)
      .send({ approved: false, reject_reason: '报价过高，请重新评估' });

    expect(res.body.code).toBe(200);
    expect(res.body.msg).toBe('已驳回');

    const order = getDB().prepare('SELECT status, reject_reason FROM repair_orders WHERE id = ?').get(orderId2) as any;
    expect(order.status).toBe('rejected');
    expect(order.reject_reason).toBe('报价过高，请重新评估');
  });
});
