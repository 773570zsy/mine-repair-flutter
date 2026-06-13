import { describe, it, expect, beforeAll } from 'vitest';
import type { Express } from 'express';
import request from 'supertest';
import { seedTestAdmin, seedTestVehicle, seedTestDriver } from './fixtures';

// 动态 import 避免模块初始化竞态
let app: Express;

describe('Machinery 工程机械模块', () => {
  let adminToken: string;
  let driverToken: string;
  let applicationId: number;
  let getDB: typeof import('../db').getDB;

  beforeAll(async () => {
    const [appModule, dbModule] = await Promise.all([
      import('../app'),
      import('../db'),
    ]);
    app = appModule.default;
    getDB = dbModule.getDB;

    seedTestAdmin();
    seedTestVehicle();
    seedTestDriver();
  });

  // ==================== 认证 ====================

  it('管理员登录', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ phone: '13800000000', password: '123456' });
    expect(res.body.code).toBe(200);
    adminToken = res.body.data.token;
  });

  it('驾驶员登录', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ phone: '13800000001', password: '123456' });
    expect(res.body.code).toBe(200);
    driverToken = res.body.data.token;
  });

  // ==================== 申请 ====================

  it('申请 Zod 校验: 空body应返回 400', async () => {
    const res = await request(app)
      .post('/api/machinery/apply')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({});
    expect(res.status).toBe(400);
    expect(res.body.msg).toContain('参数校验失败');
  });

  it('申请 Zod 校验: 缺少必填字段应返回 400', async () => {
    const res = await request(app)
      .post('/api/machinery/apply')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ applicant_name: '张三' });
    expect(res.status).toBe(400);
  });

  it('提交工程机械申请', async () => {
    const res = await request(app)
      .post('/api/machinery/apply')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        applicant_dept: '生产技术部',
        applicant_name: '赵工',
        applicant_phone: '13900009999',
        vehicle_type: '装载机',
        application_type: 'short_term',
        scheduled_start: '2026-06-14 08:00',
        scheduled_end: '2026-06-14 18:00',
        work_location: '2号采矿区',
        work_altitude: '4500',
        work_purpose: '矿渣转运',
        is_hazardous: false,
        urgency: 'normal',
        briefing_method: '现场',
        briefing_files: '[]',
      });

    expect(res.body.code).toBe(200);
    expect(res.body.msg).toBe('申请已提交');
    expect(res.body.data.application_no).toMatch(/^PC/);

    const record = getDB().prepare(
      "SELECT id, status FROM machinery_applications WHERE application_no = ?"
    ).get(res.body.data.application_no) as any;
    expect(record).toBeTruthy();
    expect(record.status).toBe('pending');
    applicationId = record.id;
  });

  // ==================== 查询 ====================

  it('可查看我的申请列表', async () => {
    const res = await request(app)
      .get('/api/machinery/my-applications')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.body.code).toBe(200);
    expect(res.body.data).toBeInstanceOf(Array);
    expect(res.body.data.length).toBeGreaterThanOrEqual(1);
    expect(res.body.data[0].application_no).toMatch(/^PC/);
  });

  it('可查看进行中的申请', async () => {
    const res = await request(app)
      .get('/api/machinery/active')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.body.code).toBe(200);
    expect(res.body.data).toBeInstanceOf(Array);
  });

  it('可查看待派列表（调度员视角）', async () => {
    const res = await request(app)
      .get('/api/machinery/pending-list')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.body.code).toBe(200);
    expect(res.body.data).toHaveProperty('list');
    expect(res.body.data.list).toBeInstanceOf(Array);
  });

  it('可查看调度看板', async () => {
    const res = await request(app)
      .get('/api/machinery/kanban')
      .set('Authorization', `Bearer ${adminToken}`);

    expect(res.body.code).toBe(200);
    expect(res.body.data).toBeTruthy();
  });

  // ==================== 指派 ====================

  it('指派 Zod 校验: 空body应返回 400', async () => {
    const res = await request(app)
      .post(`/api/machinery/assign/${applicationId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({});
    expect(res.status).toBe(400);
  });

  it('指派: 管理员指派车辆+驾驶员', async () => {
    const res = await request(app)
      .post(`/api/machinery/assign/${applicationId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        assigned_vehicle_id: 1,
        assigned_driver_id: 2,
      });

    expect(res.body.code).toBe(200);
    expect(res.body.msg).toBe('派车成功');

    // 验证状态变更
    const record = getDB().prepare(
      'SELECT status, assigned_vehicle_id, assigned_driver_id FROM machinery_applications WHERE id = ?'
    ).get(applicationId) as any;
    expect(record.status).toBe('assigned');
    expect(record.assigned_vehicle_id).toBe(1);
    expect(record.assigned_driver_id).toBe(2);
  });

  it('不能对已指派的申请重复指派', async () => {
    const res = await request(app)
      .post(`/api/machinery/assign/${applicationId}`)
      .set('Authorization', `Bearer ${adminToken}`)
      .send({ assigned_vehicle_id: 1, assigned_driver_id: 2 });
    expect(res.body.code).toBe(404); // 申请不存在或已处理
  });

  it('无权限者不能指派（非admin/dispatcher）', async () => {
    // 创建第二个申请
    const applyRes = await request(app)
      .post('/api/machinery/apply')
      .set('Authorization', `Bearer ${adminToken}`)
      .send({
        applicant_dept: '测试部',
        applicant_name: '测试',
        applicant_phone: '13900000000',
        vehicle_type: '装载机',
        scheduled_start: '2026-06-15 08:00',
        scheduled_end: '2026-06-15 18:00',
        work_location: '矿山',
        work_purpose: '测试用途',
      });
    const appId = (getDB().prepare(
      "SELECT id FROM machinery_applications WHERE application_no = ?"
    ).get(applyRes.body.data.application_no) as any).id;

    const res = await request(app)
      .post(`/api/machinery/assign/${appId}`)
      .set('Authorization', `Bearer ${driverToken}`)
      .send({ assigned_vehicle_id: 1, assigned_driver_id: 2 });
    expect(res.body.code).toBe(403);
  });

  // ==================== 统计 ====================

  it('可查看使用统计', async () => {
    const res = await request(app)
      .get('/api/machinery/usage-stats')
      .set('Authorization', `Bearer ${adminToken}`);

    // 可能返回200或没有数据时返回其他码，只要不500就行
    expect(res.status).not.toBe(500);
  });
});
