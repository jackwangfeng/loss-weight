#!/usr/bin/env node
/**
 * 体重和聊天 Tab 测试
 */

const { test, expect } = require('@playwright/test');

const BASE_URL = process.env.BASE_URL || 'http://localhost:8888';

test.describe('体重和聊天 Tab 测试', () => {
  test.beforeEach(async ({ page }) => {
    // 先登录
    await page.goto(BASE_URL, { waitUntil: 'networkidle' });
    await page.waitForSelector('flutter-view', { timeout: 10000 });

    // 点击登录
    await page.click('text=开始使用');
    await page.waitForTimeout(2000);

    // 输入手机号
    await page.fill('input[placeholder*="手机号"]', '13800138000');
    await page.waitForTimeout(500);

    // 点击获取验证码
    await page.click('text=获取验证码');
    await page.waitForTimeout(2000);

    // 输入验证码
    await page.fill('input[placeholder*="验证码"]', '123456');
    await page.waitForTimeout(500);

    // 点击登录
    await page.click('text=登录');
    await page.waitForTimeout(3000);
  });

  test('体重 Tab 应该可以正常访问', async ({ page }) => {
    console.log('测试体重 Tab...');

    // 点击体重 tab
    await page.click('text=体重');
    await page.waitForTimeout(3000);

    // 截图保存
    await page.screenshot({ path: 'weight-tab-test.png', fullPage: true });
    console.log('体重 Tab 截图已保存：weight-tab-test.png');

    // 检查是否显示体重记录相关内容
    const bodyText = await page.locator('body').textContent();
    console.log('体重 Tab 页面内容:', bodyText.substring(0, 300));

    // 检查是否有错误信息
    if (bodyText.includes('错误') || bodyText.includes('失败')) {
      throw new Error('体重 Tab 出现错误：' + bodyText.substring(0, 500));
    }
  });

  test('聊天 Tab 应该可以正常访问', async ({ page }) => {
    console.log('测试聊天 Tab...');

    // 点击 AI tab
    await page.click('text=AI');
    await page.waitForTimeout(3000);

    // 截图保存
    await page.screenshot({ path: 'ai-tab-test.png', fullPage: true });
    console.log('聊天 Tab 截图已保存：ai-tab-test.png');

    // 检查是否显示 AI 聊天相关内容
    const bodyText = await page.locator('body').textContent();
    console.log('聊天 Tab 页面内容:', bodyText.substring(0, 300));

    // 检查是否有错误信息
    if (bodyText.includes('错误') || bodyText.includes('失败')) {
      throw new Error('聊天 Tab 出现错误：' + bodyText.substring(0, 500));
    }
  });

  test('应该能够添加体重记录', async ({ page }) => {
    console.log('测试添加体重记录...');

    // 点击体重 tab
    await page.click('text=体重');
    await page.waitForTimeout(2000);

    // 点击添加按钮
    const addButton = page.locator('button[aria-label="添加"]').first();
    if (await addButton.isVisible()) {
      await addButton.click();
      await page.waitForTimeout(1000);
    }

    // 截图
    await page.screenshot({ path: 'add-weight-test.png', fullPage: true });
    console.log('添加体重截图已保存：add-weight-test.png');
  });

  test('应该能够发送聊天消息', async ({ page }) => {
    console.log('测试发送聊天消息...');

    // 点击 AI tab
    await page.click('text=AI');
    await page.waitForTimeout(2000);

    // 检查输入框
    const inputField = page.locator('input[placeholder*="输入消息"]');
    if (await inputField.isVisible()) {
      await inputField.fill('你好');
      await page.waitForTimeout(500);

      // 点击发送
      const sendButton = page.locator('button[aria-label="send"]');
      if (await sendButton.isVisible()) {
        await sendButton.click();
        await page.waitForTimeout(3000);
      }
    }

    // 截图
    await page.screenshot({ path: 'chat-message-test.png', fullPage: true });
    console.log('聊天消息截图已保存：chat-message-test.png');
  });
});
