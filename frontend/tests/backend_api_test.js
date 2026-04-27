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
  let threadId = 0;
  let lastMsgId = 0;

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
    const data = await r.json();
    threadId = data.id;
    expect(threadId).toBeGreaterThan(0);
  });

  test('获取用户聊天线程列表', async ({ request }) => {
    const r = await request.get(`${API}/v1/ai/chat/threads?user_id=${userId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(r.ok()).toBeTruthy();
  });

  test('发两条聊天消息 (给 since_id 测试做种)', async ({ request }) => {
    for (const content of ['since_id seed A', 'since_id seed B']) {
      const r = await request.post(`${API}/v1/ai/chat`, {
        headers: { Authorization: `Bearer ${token}` },
        data: {
          user_id: userId,
          thread_id: String(threadId),
          messages: [{ role: 'user', content }],
          locale: 'en',
        },
      });
      expect(r.ok()).toBeTruthy();
      const data = await r.json();
      // Assistant message_id comes back on every chat completion; we want the
      // *highest* real id at the end so the since_id tests below can assert
      // "nothing newer than this" returns empty.
      if (data.message_id) lastMsgId = data.message_id;
    }
    expect(lastMsgId).toBeGreaterThan(0);
  });

  test('增量拉取 (since_id 过滤)', async ({ request }) => {
    // Full fetch — should contain both user + assistant messages we seeded.
    const full = await request.get(
      `${API}/v1/ai/chat/history?user_id=${userId}&thread_id=${threadId}&since_id=0`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    expect(full.ok()).toBeTruthy();
    const fullData = await full.json();
    expect(fullData.count).toBeGreaterThanOrEqual(2);

    // since_id = highest known id → server should return 0 messages.
    const empty = await request.get(
      `${API}/v1/ai/chat/history?user_id=${userId}&thread_id=${threadId}&since_id=${lastMsgId}`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    expect(empty.ok()).toBeTruthy();
    expect((await empty.json()).count).toBe(0);

    // Absurdly large cursor → also 0. Guards against off-by-one.
    const huge = await request.get(
      `${API}/v1/ai/chat/history?user_id=${userId}&thread_id=${threadId}&since_id=99999999`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    expect(huge.ok()).toBeTruthy();
    expect((await huge.json()).count).toBe(0);

    // Malformed since_id → 400, not silently ignored.
    const bad = await request.get(
      `${API}/v1/ai/chat/history?user_id=${userId}&thread_id=${threadId}&since_id=abc`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    expect(bad.status()).toBe(400);
  });

  // ----- AI tool calling — log_weight -----
  // Coach 自己识别"我今天体重 X 公斤"调 log_weight 工具：
  //   1. SSE 里推 action 帧（前端渲染卡片用）
  //   2. WeightRecord 真落库
  //   3. assistant 消息带 action_kind/action_payload 持久化（reload 还能渲染）
  //   4. DELETE /weight/record/:id 模拟撤销
  let toolThreadId = 0;
  let toolRecordId = 0;
  let toolAssistantMsgId = 0;

  test('AI 工具 — 起一个干净 thread', async ({ request }) => {
    const r = await request.post(`${API}/v1/ai/chat/thread?user_id=${userId}`, {
      headers: { Authorization: `Bearer ${token}` },
      data: { title: 'log_weight tool e2e' },
    });
    expect(r.ok()).toBeTruthy();
    toolThreadId = (await r.json()).id;
    expect(toolThreadId).toBeGreaterThan(0);
  });

  test('AI 工具 — 流式聊天触发 log_weight，SSE 含 action 帧', async ({ request }) => {
    const r = await request.post(`${API}/v1/ai/chat/stream`, {
      headers: {
        Authorization: `Bearer ${token}`,
        Accept: 'text/event-stream',
      },
      data: {
        user_id: userId,
        thread_id: String(toolThreadId),
        locale: 'zh',
        messages: [{ role: 'user', content: '我今天早上体重 75 公斤' }],
      },
      timeout: 30000,
    });
    expect(r.ok()).toBeTruthy();

    // SSE: 多个 "data: {json}\n\n" 帧。一次性读完，挨个 JSON.parse。
    const text = await r.text();
    const frames = text
      .split('\n')
      .filter((l) => l.startsWith('data: '))
      .map((l) => l.slice(6))
      .filter(Boolean)
      .map((s) => {
        try { return JSON.parse(s); } catch { return null; }
      })
      .filter(Boolean);

    const action = frames.find((f) => f.action === 'log_weight');
    expect(action, 'expected an action:log_weight frame in SSE').toBeTruthy();
    expect(action.action_payload).toBeTruthy();

    const payload = JSON.parse(action.action_payload);
    expect(payload.weight_kg).toBeCloseTo(75, 0);
    expect(payload.record_id).toBeGreaterThan(0);
    toolRecordId = payload.record_id;

    // done 帧应该带最终 assistant message_id（用来在 history 里拉持久化字段）
    const done = frames.find((f) => f.done === true);
    expect(done, 'expected a done frame').toBeTruthy();
    if (done.message_id) toolAssistantMsgId = done.message_id;
  });

  test('AI 工具 — WeightRecord 真落库', async ({ request }) => {
    const r = await request.get(`${API}/v1/weight/records?user_id=${userId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(r.ok()).toBeTruthy();
    const records = (await r.json()).records || [];
    const hit = records.find((rec) => rec.id === toolRecordId);
    expect(hit, `record ${toolRecordId} should exist`).toBeTruthy();
    expect(hit.weight).toBeCloseTo(75, 0);
  });

  test('AI 工具 — assistant 消息持久化 action_kind / action_payload', async ({ request }) => {
    const r = await request.get(
      `${API}/v1/ai/chat/history?user_id=${userId}&thread_id=${toolThreadId}&since_id=0`,
      { headers: { Authorization: `Bearer ${token}` } },
    );
    expect(r.ok()).toBeTruthy();
    const messages = (await r.json()).messages || [];
    const tagged = messages.find(
      (m) => m.role === 'assistant' && m.action_kind === 'log_weight',
    );
    expect(tagged, 'reload 后应该还能在历史里看到 action_kind').toBeTruthy();
    expect(tagged.action_payload).toContain('"record_id"');

    // 解出来的 record_id 应该和 SSE 里那个一致
    const parsed = JSON.parse(tagged.action_payload);
    expect(parsed.record_id).toBe(toolRecordId);
  });

  test('AI 工具 — 撤销：DELETE 后 record 消失', async ({ request }) => {
    const del = await request.delete(`${API}/v1/weight/record/${toolRecordId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(del.ok()).toBeTruthy();

    const list = await request.get(`${API}/v1/weight/records?user_id=${userId}`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(list.ok()).toBeTruthy();
    const records = (await list.json()).records || [];
    expect(records.find((rec) => rec.id === toolRecordId)).toBeUndefined();
  });

  test('退出登录', async ({ request }) => {
    const r = await request.post(`${API}/v1/auth/logout`, {
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(r.ok()).toBeTruthy();
  });
});
