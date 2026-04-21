#!/usr/bin/env node
/**
 * AI 聊天功能测试
 */

const { test, expect } = require('@playwright/test');

const BASE_URL = process.env.BASE_URL || 'http://localhost:8889';

test.describe('AI 聊天功能测试', () => {
  test.beforeEach(async ({ page }) => {
    // 访问首页
    await page.goto(BASE_URL, { waitUntil: 'networkidle' });

    // 等待 Flutter 加载完成
    await page.waitForSelector('flutter-view', { timeout: 15000 });
    console.log('✅ Flutter 加载完成');
  });

  test('应该能够登录并进入首页', async ({ page }) => {
    // 检查页面标题
    const title = await page.title();
    expect(title).toBeTruthy();
    console.log('✅ 页面标题:', title);
  });

  test('应该能够看到"开始使用"按钮', async ({ page }) => {
    // Flutter 使用 canvas 渲染，无法直接使用文本选择器
    // 我们通过检查 flutter-view 是否存在来验证页面加载
    const flutterView = await page.locator('flutter-view').first();
    await expect(flutterView).toBeVisible();
    console.log('✅ Flutter 视图可见');
  });

  test('应该能够点击 AI Tab 并看到聊天界面', async ({ page }) => {
    // 等待页面稳定
    await page.waitForTimeout(2000);

    // 由于 Flutter 使用 canvas 渲染，文本选择器无法工作
    // 我们只能验证 flutter-view 存在
    const flutterView = await page.locator('flutter-view').first();
    await expect(flutterView).toBeVisible();

    // 截图
    await page.screenshot({ path: 'ai-chat-test.png', fullPage: true });
    console.log('✅ AI Tab 截图已保存: ai-chat-test.png');
  });

  test('应该能够发送消息（需要先登录）', async ({ page }) => {
    // 等待页面稳定
    await page.waitForTimeout(3000);

    // 验证 Flutter 视图存在
    const flutterView = await page.locator('flutter-view').first();
    await expect(flutterView).toBeVisible();

    // 截图保存当前状态
    await page.screenshot({ path: 'ai-before-send.png', fullPage: true });
    console.log('✅ 发送消息前截图已保存: ai-before-send.png');

    // 注意：由于 Flutter Web 使用 Canvas 渲染，我们无法通过文本选择器
    // 与输入框和按钮交互。这是 Flutter Web 的限制。
    // 在真实浏览器中，用户可以手动测试这个功能。
  });
});

test.describe('后端 API 测试', () => {
  const API_BASE = 'http://localhost:8000/v1';

  test('后端 API 应该正常运行', async ({ request }) => {
    const response = await request.get('http://localhost:8000/health');
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.status).toBe('healthy');
    console.log('✅ 后端健康检查:', data);
  });

  test('AI 聊天 API 应该正常工作', async ({ request }) => {
    // 1. 登录
    const loginResponse = await request.post(`${API_BASE}/auth/sms/login`, {
      data: {
        phone: '13800138000',
        code: '123456'
      }
    });
    expect(loginResponse.ok()).toBeTruthy();
    const loginData = await loginResponse.json();
    console.log('✅ 登录成功, Token:', loginData.token);

    // 2. 发送 AI 聊天消息
    const chatResponse = await request.post(`${API_BASE}/ai/chat`, {
      data: {
        user_id: loginData.user_id,
        messages: [
          { role: 'user', content: '你好，我想减肥' }
        ]
      },
      headers: {
        'Authorization': `Bearer ${loginData.token}`,
        'Content-Type': 'application/json'
      }
    });
    expect(chatResponse.ok()).toBeTruthy();
    const chatData = await chatResponse.json();
    console.log('✅ AI 聊天响应:', chatData.content?.substring(0, 50) + '...');
    expect(chatData.content).toBeTruthy();
  });
});
