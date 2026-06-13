import { describe, it, expect, beforeAll } from 'vitest';
import request from 'supertest';
import app from '../app';
import { seedTestAdmin } from './fixtures';

describe('Auth 认证模块', () => {
  beforeAll(() => {
    seedTestAdmin();
  });

  it('正确账号密码应登录成功', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ phone: '13800000000', password: '123456' });

    expect(res.status).toBe(200);
    expect(res.body.code).toBe(200);
    expect(res.body.data).toHaveProperty('token');
    expect(res.body.data.user.name).toBe('测试管理员');
    expect(res.body.data.user.role).toBe('admin');
  });

  it('错误密码应返回 401', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ phone: '13800000000', password: 'wrong' });

    expect(res.body.code).toBe(401);
  });

  it('空body应返回 400（Zod校验）', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({});

    expect(res.status).toBe(400);
    expect(res.body.code).toBe(400);
    expect(res.body.msg).toContain('参数校验失败');
  });

  it('缺少password应返回 400', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ phone: '13800000000' });

    expect(res.status).toBe(400);
    expect(res.body.msg).toContain('参数校验失败');
  });

  it('无token访问保护路由应返回 401', async () => {
    const res = await request(app).get('/api/vehicles');
    expect(res.body.code).toBe(401);
  });

  it('无效token应返回 401', async () => {
    const res = await request(app)
      .get('/api/vehicles')
      .set('Authorization', 'Bearer invalid-token');
    expect(res.body.code).toBe(401);
  });

  it('有效token可访问保护路由', async () => {
    const loginRes = await request(app)
      .post('/api/auth/login')
      .send({ phone: '13800000000', password: '123456' });
    const token = loginRes.body.data.token;

    const res = await request(app)
      .get('/api/vehicles')
      .set('Authorization', `Bearer ${token}`);

    expect(res.body.code).toBe(200);
    expect(Array.isArray(res.body.data)).toBe(true);
  });
});
