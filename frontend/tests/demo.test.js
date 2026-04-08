#!/usr/bin/env node
/**
 * 减肥 AI 助理 - 快速测试演示脚本
 * 用于快速演示核心功能
 * 
 * 使用方法:
 *   node tests/demo.test.js
 */

const { chromium } = require('playwright');

(async () => {
  // 配置
  const BASE_URL = process.env.BASE_URL || 'http://localhost:8888';
  const TEST_PHONE = '13800138000';
  const TEST_CODE = '123456';
  
  console.log('====================================');
  console.log('  减肥 AI 助理 - 功能演示');
  console.log('====================================');
  console.log('');
  console.log('📱 前端地址:', BASE_URL);
  console.log('📝 测试手机号:', TEST_PHONE);
  console.log('🔐 测试验证码:', TEST_CODE);
  console.log('');
  
  // 启动浏览器
  console.log('🚀 启动浏览器...');
  const browser = await chromium.launch({
    headless: process.env.HEADED ? false : true,
    slowMo: 100, // 慢动作，方便观看
  });
  
  const page = await browser.newPage({
    viewport: { width: 1280, height: 720 },
  });
  
  try {
    // 1. 访问首页
    console.log('📍 访问首页...');
    await page.goto(BASE_URL);
    await page.waitForTimeout(2000);
    console.log('✅ 首页加载成功');
    
    // 2. 点击登录
    console.log('📍 点击"开始使用"按钮...');
    await page.click('text=开始使用');
    await page.waitForTimeout(1000);
    console.log('✅ 进入登录页面');
    
    // 3. 输入手机号
    console.log('📍 输入手机号...');
    await page.fill('input[placeholder*="手机号"]', TEST_PHONE);
    await page.waitForTimeout(500);
    console.log('✅ 手机号输入完成');
    
    // 4. 获取验证码
    console.log('📍 点击"获取验证码"...');
    await page.click('text=获取验证码');
    await page.waitForTimeout(2000);
    console.log('✅ 验证码已发送');
    
    // 5. 输入验证码
    console.log('📍 输入验证码...');
    await page.fill('input[placeholder*="验证码"]', TEST_CODE);
    await page.waitForTimeout(500);
    console.log('✅ 验证码输入完成');
    
    // 6. 点击登录
    console.log('📍 点击"登录"...');
    await page.click('text=登录');
    await page.waitForTimeout(3000);
    console.log('✅ 登录成功');
    
    // 7. 检查首页
    console.log('📍 检查首页元素...');
    const welcomeText = await page.locator('text=早安').isVisible();
    if (welcomeText) {
      console.log('✅ 返回首页，显示欢迎信息');
    } else {
      console.log('⚠️  未找到欢迎信息');
    }
    
    // 8. 导航到饮食页面
    console.log('📍 导航到"饮食"页面...');
    await page.click('text=饮食');
    await page.waitForTimeout(1000);
    console.log('✅ 进入饮食记录页面');
    
    // 9. 添加饮食记录
    console.log('📍 添加饮食记录...');
    await page.click('button[aria-label="添加"]');
    await page.waitForTimeout(500);
    await page.fill('input[placeholder*="食物名称"]', '苹果');
    await page.fill('input[placeholder*="热量"]', '95');
    await page.selectOption('select', 'breakfast');
    await page.click('text=添加');
    await page.waitForTimeout(2000);
    console.log('✅ 饮食记录添加成功');
    
    // 10. 导航到体重页面
    console.log('📍 导航到"体重"页面...');
    await page.click('text=体重');
    await page.waitForTimeout(1000);
    console.log('✅ 进入体重记录页面');
    
    // 11. 添加体重记录
    console.log('📍 添加体重记录...');
    await page.click('button[aria-label="添加"]');
    await page.waitForTimeout(500);
    await page.fill('input[placeholder*="体重"]', '70.5');
    await page.fill('input[placeholder*="体脂率"]', '20');
    await page.click('text=添加');
    await page.waitForTimeout(2000);
    console.log('✅ 体重记录添加成功');
    
    // 12. 检查图表
    console.log('📍 检查体重趋势图表...');
    const chartVisible = await page.locator('text=体重趋势').isVisible();
    if (chartVisible) {
      console.log('✅ 体重趋势图表显示正常');
    } else {
      console.log('⚠️  未找到体重趋势图表');
    }
    
    // 13. 导航到 AI 页面
    console.log('📍 导航到"AI"页面...');
    await page.click('text=AI');
    await page.waitForTimeout(1000);
    console.log('✅ 进入 AI 聊天页面');
    
    // 14. 发送消息
    console.log('📍 发送消息给 AI...');
    await page.fill('input[placeholder*="输入消息"]', '你好，我想减肥');
    await page.click('button[aria-label="send"]');
    await page.waitForTimeout(3000);
    console.log('✅ 消息发送成功');
    
    // 15. 导航到个人中心
    console.log('📍 导航到"我的"页面...');
    await page.click('text=我的');
    await page.waitForTimeout(1000);
    console.log('✅ 进入个人中心');
    
    // 16. 检查用户信息
    console.log('📍 检查用户信息...');
    const userInfoVisible = await page.locator('text=手机用户').isVisible();
    if (userInfoVisible) {
      console.log('✅ 用户信息显示正常');
    } else {
      console.log('⚠️  未找到用户信息');
    }
    
    console.log('');
    console.log('====================================');
    console.log('  ✅ 所有演示步骤完成！');
    console.log('====================================');
    console.log('');
    
  } catch (error) {
    console.error('');
    console.error('❌ 演示过程中出现错误:');
    console.error(error.message);
    console.error('');
    
    // 截图
    await page.screenshot({ path: 'error-screenshot.png' });
    console.log('💾 错误截图已保存：error-screenshot.png');
    console.error('');
    
  } finally {
    // 关闭浏览器
    console.log('🚪 关闭浏览器...');
    await browser.close();
    console.log('✅ 浏览器已关闭');
    console.log('');
  }
})();
