#!/usr/bin/env node
/**
 * Flutter Web 交互测试 - 使用坐标点击
 */

const { test, expect } = require('@playwright/test');

const BASE_URL = process.env.BASE_URL || 'http://localhost:8889';

test.describe('Flutter Web 交互测试', () => {

  test('完整流程：登录 -> AI聊天 -> 发送消息', async ({ page }) => {
    // 设置手机视口
    await page.setViewportSize({ width: 390, height: 844 });

    console.log('\n1. 访问首页...');
    await page.goto(BASE_URL, { waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'itest-1-homepage.png' });
    console.log('   截图: itest-1-homepage.png');

    console.log('2. 点击"开始使用"按钮 (195, 450)...');
    await page.mouse.click(195, 450);
    await page.waitForTimeout(2000);
    await page.screenshot({ path: 'itest-2-login-screen.png' });
    console.log('   截图: itest-2-login-screen.png');

    console.log('3. 输入手机号 (195, 200)...');
    await page.mouse.click(195, 200);
    await page.waitForTimeout(300);
    await page.keyboard.type('13800138000');
    await page.waitForTimeout(500);
    await page.screenshot({ path: 'itest-3-phone-typed.png' });
    console.log('   截图: itest-3-phone-typed.png');

    console.log('4. 点击"获取验证码" (195, 280)...');
    await page.mouse.click(195, 280);
    await page.waitForTimeout(2000);

    console.log('5. 输入验证码 (195, 350)...');
    await page.mouse.click(195, 350);
    await page.waitForTimeout(300);
    await page.keyboard.type('123456');
    await page.waitForTimeout(500);
    await page.screenshot({ path: 'itest-4-code-typed.png' });
    console.log('   截图: itest-4-code-typed.png');

    console.log('6. 点击"登录"按钮 (195, 420)...');
    await page.mouse.click(195, 420);
    await page.waitForTimeout(3000);
    await page.screenshot({ path: 'itest-5-after-login.png' });
    console.log('   截图: itest-5-after-login.png');

    console.log('7. 点击"AI" Tab (273, 800)...');
    await page.mouse.click(273, 800);
    await page.waitForTimeout(2000);
    await page.screenshot({ path: 'itest-6-ai-tab.png' });
    console.log('   截图: itest-6-ai-tab.png');

    console.log('8. 输入聊天消息 (195, 700)...');
    await page.mouse.click(195, 700);
    await page.waitForTimeout(300);
    await page.keyboard.type('你好，我想减肥');
    await page.waitForTimeout(500);
    await page.screenshot({ path: 'itest-7-message-typed.png' });
    console.log('   截图: itest-7-message-typed.png');

    console.log('9. 点击发送按钮 (350, 700)...');
    await page.mouse.click(350, 700);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: 'itest-8-after-send.png' });
    console.log('   截图: itest-8-after-send.png');

    console.log('\n✅ 交互测试完成！请查看截图验证结果。');
  });

  test('验证 Flutter Canvas 和元素存在', async ({ page }) => {
    await page.goto(BASE_URL, { waitUntil: 'networkidle' });
    await page.waitForTimeout(3000);

    const canvasCount = await page.locator('canvas').count();
    console.log('Canvas 数量:', canvasCount);
    expect(canvasCount).toBeGreaterThan(0);

    const flutterViewCount = await page.locator('flutter-view').count();
    console.log('Flutter View 数量:', flutterViewCount);
    expect(flutterViewCount).toBeGreaterThan(0);

    await page.screenshot({ path: 'itest-canvas-check.png' });
    console.log('截图: itest-canvas-check.png');
  });
});
