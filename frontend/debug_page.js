#!/usr/bin/env node
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage();
  
  console.log('访问首页...');
  await page.goto('http://localhost:8888', { waitUntil: 'networkidle', timeout: 30000 });
  
  console.log('获取页面标题...');
  const title = await page.title();
  console.log('页面标题:', title);
  
  console.log('获取页面可见文本...');
  const bodyText = await page.locator('body').textContent();
  console.log('页面文本:', bodyText.substring(0, 500));
  
  console.log('截图...');
  await page.screenshot({ path: 'debug-screenshot.png', fullPage: true });
  console.log('截图已保存：debug-screenshot.png');
  
  await browser.close();
})();
