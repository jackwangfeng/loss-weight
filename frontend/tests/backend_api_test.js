/**
 * 后端 API 端到端测试
 *
 * 串行测试：登录 → 拿 token → 业务操作 → 退出
 * 需要后端在 localhost:8000 运行，SKIP_SMS_VERIFY=true 模式（验证码 123456）
 */

const { test, expect } = require('@playwright/test');

const API = process.env.API_BASE_URL || 'http://localhost:8000';
const PHONE = '13800138000';
const CODE = '123456';

test.describe.serial('后端 API 端到端流程', () => {
  let token = '';
  let userId = 0;

  test('健康检查', async ({ request }) => {
    const r = await request.get(`${API}/health`);
    expect(r.ok()).toBeTruthy();
    const data = await r.json();
    expect(data.status).toBe('healthy');
  });

  test('发送短信验证码', async ({ request }) => {
    const r = await request.post(`${API}/v1/auth/sms/send`, {
      data: { phone: PHONE, purpose: 'login' },
    });
    expect(r.ok()).toBeTruthy();
  });

  test('手机号登录拿 token', async ({ request }) => {
    const r = await request.post(`${API}/v1/auth/sms/login`, {
      data: { phone: PHONE, code: CODE },
    });
    expect(r.ok()).toBeTruthy();
    const data = await r.json();
    token = data.token;
    userId = data.user_id;
    expect(token).toBeTruthy();
    expect(userId).toBeGreaterThan(0);
  });

  test('获取当前用户信息 (/auth/me)', async ({ request }) => {
    const r = await request.get(`${API}/v1/auth/me`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(r.ok()).toBeTruthy();
    const data = await r.json();
    expect(data.account).toBeTruthy();
    expect(data.account.id).toBe(userId);
  });

  test('添加饮食记录', async ({ request }) => {
    const r = await request.post(`${API}/v1/food/record`, {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        user_id: userId,
        food_name: 'E2E 测试餐',
        calories: 500,
        protein: 20,
        carbs: 50,
        fat: 15,
        portion: 200,
        unit: 'g',
        meal_type: 'lunch',
      },
    });
    expect(r.ok()).toBeTruthy();
    const data = await r.json();
    expect(data.food_name).toBe('E2E 测试餐');
  });

  test('获取饮食记录列表', async ({ request }) => {
    const r = await request.get(`${API}/v1/food/records?user_id=${userId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(r.ok()).toBeTruthy();
  });

  test('获取每日营养汇总', async ({ request }) => {
    const r = await request.get(`${API}/v1/food/daily-summary?user_id=${userId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(r.ok()).toBeTruthy();
  });

  test('添加体重记录', async ({ request }) => {
    const r = await request.post(`${API}/v1/weight/record`, {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        user_id: userId,
        weight: 74.5,
        note: 'E2E test',
      },
    });
    expect(r.ok()).toBeTruthy();
  });

  test('获取体重记录列表', async ({ request }) => {
    const r = await request.get(`${API}/v1/weight/records?user_id=${userId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(r.ok()).toBeTruthy();
  });

  test('获取体重趋势', async ({ request }) => {
    const r = await request.get(`${API}/v1/weight/trend?user_id=${userId}&days=30`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(r.ok()).toBeTruthy();
  });

  test('AI 鼓励', async ({ request }) => {
    const r = await request.post(`${API}/v1/ai/encouragement`, {
      headers: { Authorization: `Bearer ${token}` },
      data: {
        user_id: userId,
        current_weight: 74.5,
        target_weight: 65,
        weight_loss: 0.5,
        days_active: 7,
      },
    });
    expect(r.ok()).toBeTruthy();
    const data = await r.json();
    // 响应字段不同实现可能是 message / content / text
    expect(data.message || data.content || data.text).toBeTruthy();
  });

  test('创建 AI 聊天线程', async ({ request }) => {
    const r = await request.post(`${API}/v1/ai/chat/thread?user_id=${userId}`, {
      headers: { Authorization: `Bearer ${token}` },
      data: { title: 'E2E 测试对话' },
    });
    expect(r.ok()).toBeTruthy();
  });

  test('获取用户聊天线程列表', async ({ request }) => {
    const r = await request.get(`${API}/v1/ai/chat/threads?user_id=${userId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(r.ok()).toBeTruthy();
  });

  test('退出登录', async ({ request }) => {
    const r = await request.post(`${API}/v1/auth/logout`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(r.ok()).toBeTruthy();
  });
});
