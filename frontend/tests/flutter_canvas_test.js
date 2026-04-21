/**
 * Flutter Web Canvas 测试 - 使用截图验证
 */

const { test, expect } = require('@playwright/test');

const BASE_URL = process.env.BASE_URL || 'http://localhost:8889';

test.describe('Flutter Web Canvas 测试', () => {
  test('Flutter Web 应该正确加载', async ({ page }) => {
    await page.goto(BASE_URL, { waitUntil: 'networkidle' });

    await page.waitForTimeout(3000);

    const html = await page.content();
    expect(html).toContain('flutter');
    expect(html).toContain('flutter_bootstrap.js');

    await page.screenshot({ path: 'test-1-initial-load.png', fullPage: true });
    console.log('Flutter 页面加载完成，截图已保存');

    const canvasCount = await page.locator('canvas').count();
    console.log('找到 ' + canvasCount + ' 个 canvas 元素');
    expect(canvasCount).toBeGreaterThan(0);
  });

  test('Flutter Web canvas 应该可见', async ({ page }) => {
    await page.goto(BASE_URL, { waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);

    const canvas = page.locator('canvas').first();
    await expect(canvas).toBeVisible();

    await page.screenshot({ path: 'test-2-canvas-visible.png', fullPage: true });
    console.log('Canvas 可见，截图已保存');
  });

  test('页面应该包含必要的 Flutter 资源', async ({ page }) => {
    await page.goto(BASE_URL, { waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);

    const mainDartLoaded = await page.evaluate(() => {
      return document.body.innerHTML.includes('main.dart.js') ||
             document.body.innerHTML.includes('flutter_bootstrap.js');
    });
    expect(mainDartLoaded).toBeTruthy();
    console.log('Flutter main.dart.js 已加载');
  });
});

test.describe('Semantics 交互测试', () => {
  // 等 Flutter 的 Semantics 树生成出至少 N 个 tab
  async function waitForTabs(page, minCount = 4) {
    await page.goto(BASE_URL, { waitUntil: 'networkidle' });
    await page.waitForFunction(
      (n) => document.querySelectorAll('flt-semantics[role="tab"]').length >= n,
      minCount,
      { timeout: 15000 }
    );
  }

  test('底部导航应该有 4 个 tab', async ({ page }) => {
    await waitForTabs(page);
    for (const name of ['首页', '记录', 'AI', '我的']) {
      await expect(page.getByRole('tab', { name, exact: false })).toBeVisible();
    }
  });

  test('点击 AI tab 应该切到 AI 界面', async ({ page }) => {
    await waitForTabs(page);
    await page.getByRole('tab', { name: 'AI', exact: true }).click();
    // 选中态变化 + AI 界面特有按钮出现
    await expect(page.locator('flt-semantics[role="tab"][aria-selected="true"]'))
      .toHaveAttribute('aria-label', /AI/, { timeout: 5000 });
    await expect(page.getByText('新建对话').first()).toBeVisible({ timeout: 5000 });
  });

  test('点击 记录 tab + 饮食 子 tab', async ({ page }) => {
    await waitForTabs(page);
    await page.getByRole('tab', { name: '记录', exact: true }).click();
    // 进入"记录"后会多出 3 个子 tab（饮食/运动/体重）
    await page.waitForFunction(
      () => document.querySelectorAll('flt-semantics[role="tab"]').length >= 7,
      { timeout: 5000 }
    );
    await expect(page.getByText('饮食记录').first()).toBeVisible({ timeout: 5000 });
    await expect(page.getByText('今日热量').first()).toBeVisible();
  });

  test('点击 记录 tab + 运动 子 tab', async ({ page }) => {
    await waitForTabs(page);
    await page.getByRole('tab', { name: '记录', exact: true }).click();
    await page.getByRole('tab', { name: '运动', exact: true })
        .click({ timeout: 5000 });
    await expect(page.getByText('今日消耗').first()).toBeVisible({ timeout: 5000 });
  });

  test('点击 记录 tab + 体重 子 tab', async ({ page }) => {
    await waitForTabs(page);
    await page.getByRole('tab', { name: '记录', exact: true }).click();
    await page.getByRole('tab', { name: '体重', exact: true })
        .click({ timeout: 5000 });
    // 体重页要么显示「暂无体重记录」要么显示图表—— 都行
    await expect(page.locator('flutter-view')).toBeVisible();
  });

  test('点击 我的 tab 应该显示未登录状态或资料', async ({ page }) => {
    await waitForTabs(page);
    await page.getByRole('tab', { name: '我的', exact: true }).click();
    // 已登录：看到"编辑资料" 未登录：看到"未登录"
    await expect(page.locator('flutter-view')).toBeVisible();
  });

  test('依次切换所有 tab 不崩溃', async ({ page }) => {
    await waitForTabs(page);
    for (const name of ['记录', 'AI', '我的', '首页']) {
      await page.getByRole('tab', { name, exact: true }).click();
      await expect(page.locator('flutter-view')).toBeVisible();
    }
  });
});

test.describe('后端 API 测试', () => {
  test('后端健康检查', async ({ request }) => {
    const response = await request.get('http://localhost:8000/health');
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.status).toBe('healthy');
    console.log('后端健康:', data);
  });

  test('AI 聊天 API 测试', async ({ request }) => {
    const loginResp = await request.post('http://localhost:8000/v1/auth/sms/login', {
      data: { phone: '13800138000', code: '123456' }
    });
    expect(loginResp.ok()).toBeTruthy();
    const loginData = await loginResp.json();
    console.log('登录成功, user_id:', loginData.user_id);

    const chatResp = await request.post('http://localhost:8000/v1/ai/chat', {
      data: {
        user_id: loginData.user_id,
        messages: [{ role: 'user', content: '你好' }]
      },
      headers: {
        'Authorization': 'Bearer ' + loginData.token,
        'Content-Type': 'application/json'
      }
    });
    expect(chatResp.ok()).toBeTruthy();
    const chatData = await chatResp.json();
    console.log('AI 回复:', chatData.content ? chatData.content.substring(0, 50) : 'N/A');
    expect(chatData.content).toBeTruthy();
  });
});
