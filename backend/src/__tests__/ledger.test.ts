import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import app from '../app';
import { seedTestAdmin, seedTestVehicle, seedTestDriver, seedTestInspection, bindDriverToVehicle, seedAttendance } from './fixtures';
import { getDB } from '../db';

describe('Ledger 单车核算模块', () => {
  let token: string;

  beforeAll(() => {
    const admin = seedTestAdmin();
    const vehicle = seedTestVehicle();
    const driver = seedTestDriver();

    // 绑定驾驶员到车辆
    bindDriverToVehicle(driver.id, vehicle.id);

    // 插入点检数据（6月份的4天出勤+加油）
    seedTestInspection(vehicle.id, driver.id, '2026-06-01', 50, 8);
    seedTestInspection(vehicle.id, driver.id, '2026-06-02', 45, 7.5);
    seedTestInspection(vehicle.id, driver.id, '2026-06-03', 55, 8.5);
    seedTestInspection(vehicle.id, driver.id, '2026-06-04', 40, 7);

    // 考勤记录
    seedAttendance(driver.id, '2026-06-01');
    seedAttendance(driver.id, '2026-06-02');
    seedAttendance(driver.id, '2026-06-03');
    seedAttendance(driver.id, '2026-06-04');
  });

  it('应成功登录并获取token', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ phone: '13800000000', password: '123456' });

    expect(res.body.code).toBe(200);
    token = res.body.data.token;
    expect(token).toBeTruthy();
  });

  it('Zod校验: 空body生成月度清单应返回 400', async () => {
    const res = await request(app)
      .post('/api/ledger/monthly/generate')
      .set('Authorization', `Bearer ${token}`)
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.msg).toContain('参数校验失败');
  });

  it('Zod校验: 错误年月格式应返回 400', async () => {
    const res = await request(app)
      .post('/api/ledger/monthly/generate')
      .set('Authorization', `Bearer ${token}`)
      .send({ year_month: 'abc' });

    expect(res.status).toBe(400);
  });

  it('应成功生成 2026-06 月度清单', async () => {
    const res = await request(app)
      .post('/api/ledger/monthly/generate')
      .set('Authorization', `Bearer ${token}`)
      .send({ year_month: '2026-06' });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(200);
    expect(res.body.data).toBeInstanceOf(Array);
    expect(res.body.data.length).toBeGreaterThanOrEqual(1);

    const ledger = res.body.data[0];
    expect(ledger).toHaveProperty('fuel_cost');
    expect(ledger).toHaveProperty('repair_cost');
    expect(ledger).toHaveProperty('parts_cost');
    expect(ledger).toHaveProperty('work_days');
    expect(ledger).toHaveProperty('total_hours');

    // 燃油费用: (50+45+55+40) * 8.5 = 1615
    expect(ledger.fuel_cost).toBeGreaterThan(0);
    // 工作天数: 4天
    expect(ledger.work_days).toBe(4);
    // 工时: 8+7.5+8.5+7 = 31
    expect(ledger.total_hours).toBe(31);
  });

  it('仪表盘汇总应反映清单数据', async () => {
    const res = await request(app)
      .get('/api/ledger/summary?month=2026-06')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.data).toHaveProperty('fuelCost');
    expect(res.body.data).toHaveProperty('totalCost');
    // 汇总应从 monthly_ledger 读取
    expect(res.body.data.fuelCost).toBeGreaterThan(0);
  });

  it('KPI计算: 未审批清单时应返回 400', async () => {
    const res = await request(app)
      .post('/api/ledger/kpi/calculate')
      .set('Authorization', `Bearer ${token}`)
      .send({ year_month: '2026-06' });

    expect(res.body.code).toBe(400);
    expect(res.body.msg).toContain('已审批');
  });

  it('审批清单后应成功计算KPI', async () => {
    // 提交+审批所有清单
    const db = getDB();
    db.prepare("UPDATE monthly_ledger SET status = 'approved' WHERE year_month = '2026-06'").run();

    const res = await request(app)
      .post('/api/ledger/kpi/calculate')
      .set('Authorization', `Bearer ${token}`)
      .send({ year_month: '2026-06' });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(200);
    expect(res.body.data).toBeInstanceOf(Array);
    expect(res.body.data[0]).toHaveProperty('total_score');
    expect(res.body.data[0]).toHaveProperty('rank');
  });
});
