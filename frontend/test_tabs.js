#!/usr/bin/env node
/**
 * Tab 功能简单测试
 */

const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({ channel: 'chrome', headless: true });
  const page = await browser.newPage();

  try {
    console.log('1. 访问首页...');
    await page.goto('http://localhost:8888', { waitUntil: 'networkidle', timeout: 30000 });
    console.log('✅ 页面加载完成');

    console.log('2. 等待 Flutter 渲染...');
    await page.waitForTimeout(5000);
    console.log('✅ Flutter 渲染完成');

    console.log('3. 截图保存...');
    await page.screenshot({ path: 'tab-test-1-homepage.png', fullPage: true });
    console.log('✅ 首页截图已保存：tab-test-1-homepage.png');

    console.log('4. 检查页面标题...');
    const title = await page.title();
    console.log('页面标题:', title);

    console.log('5. 查找 Tab 元素...');
    const tabs = await page.locator('flt-semantics[label]').count();
    console.log('Flutter 语义标签数量:', tabs);

    if (tabs > 0) {
      console.log('6. 获取 Tab 标签...');
      const labels = await page.locator('flt-semantics[label]').evaluateAll(
        elements => elements.map(e => e.getAttribute('label'))
      );
      console.log('标签列表:', labels.slice(0, 10));
    }

    console.log('');
    console.log('========================================');
    console.log('  测试完成！请查看截图检查界面是否正常');
    console.log('========================================');

  } catch (error) {
    console.error('❌ 测试失败:', error.message);
    await page.screenshot({ path: 'tab-test-error.png', fullPage: true });
  } finally {
    await browser.close();
  }
})();
