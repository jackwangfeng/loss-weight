#!/usr/bin/env node
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage();

  console.log('1. 访问首页...');
  await page.goto('http://localhost:8888', { waitUntil: 'networkidle', timeout: 30000 });

  console.log('2. 等待 Flutter 加载...');
  await page.waitForSelector('flutter-view', { timeout: 10000 });

  console.log('3. 截图...');
  await page.screenshot({ path: 'debug-homepage.png', fullPage: true });

  console.log('4. 获取页面内容...');
  const bodyText = await page.locator('body').textContent();
  console.log('页面内容:', bodyText.substring(0, 500));

  console.log('5. 尝试查找"开始使用"按钮...');
  const startButton = await page.locator('text=开始使用').first();
  const isVisible = await startButton.isVisible().catch(() => false);
  console.log('"开始使用"按钮可见:', isVisible);

  if (!isVisible) {
    console.log('6. 尝试查找其他登录相关文本...');
    const loginText = await page.locator('text=登录').first();
    const loginVisible = await loginText.isVisible().catch(() => false);
    console.log('"登录"文本可见:', loginVisible);

    const fitnessText = await page.locator('text=减肥').first();
    const fitnessVisible = await fitnessText.isVisible().catch(() => false);
    console.log('"减肥"文本可见:', fitnessVisible);
  }

  await browser.close();
})();
