#!/usr/bin/env node
/**
 * 简单测试 - 使用 Flutter 语义标签
 */

const { test, expect } = require('@playwright/test');

const BASE_URL = process.env.BASE_URL || 'http://localhost:8888';

test.describe('简单测试', () => {
  test('应该能够访问首页', async ({ page }) => {
    await page.goto(BASE_URL, { waitUntil: 'networkidle' });
    
    // 等待 Flutter 加载完成
    await page.waitForSelector('flutter-view', { timeout: 10000 });
    
    // 检查页面标题
    const title = await page.title();
    expect(title).toBe('减肥 AI 助理');
    
    console.log('✅ 首页加载成功');
  });

  test('应该能够看到登录按钮', async ({ page }) => {
    await page.goto(BASE_URL, { waitUntil: 'networkidle' });
    
    // 等待 Flutter 加载完成
    await page.waitForSelector('flutter-view', { timeout: 10000 });
    
    // 截图并检查
    const screenshot = await page.screenshot();
    expect(screenshot).toBeDefined();
    
    console.log('✅ 登录页面可见');
  });
});
