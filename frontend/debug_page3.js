#!/usr/bin/env node
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage();

  console.log('1. 访问首页...');
  await page.goto('http://localhost:8888', { waitUntil: 'networkidle', timeout: 30000 });

  console.log('2. 检查页面标题...');
  const title = await page.title();
  console.log('页面标题:', title);

  console.log('3. 检查 Flutter 元素...');
  const flutterView = await page.locator('flt-semantics').first();
  const flutterExists = await flutterView.count();
  console.log('Flutter 语义元素数量:', flutterExists);

  console.log('4. 检查 HTML 结构...');
  const html = await page.content();
  console.log('HTML 长度:', html.length);
  console.log('HTML 前 500 字符:', html.substring(0, 500));

  console.log('5. 截图...');
  await page.screenshot({ path: 'debug-full.png', fullPage: true });
  console.log('截图已保存：debug-full.png');

  await browser.close();
})();
