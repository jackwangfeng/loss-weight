#!/usr/bin/env node
/**
 * 减肥 AI 助理 - 前端 E2E 测试脚本
 * 使用 Playwright 进行测试
 * 
 * 使用方法:
 *   npm install -D @playwright/test
 *   npx playwright test tests/e2e.test.js
 *   npx playwright test tests/e2e.test.js --headed  # 显示浏览器界面
 *   npx playwright test tests/e2e.test.js --debug  # 调试模式
 */

const { test, expect } = require('@playwright/test');

// 测试配置
const BASE_URL = process.env.BASE_URL || 'http://localhost:8888';
const API_URL = process.env.API_URL || 'http://localhost:8000';

// 测试数据
const TEST_PHONE = '13800138000';
const TEST_CODE = '123456';
const TEST_WEIGHT = 70.5;
const TEST_FOOD = '苹果';
const TEST_FOOD_CALORIES = 95;

test.describe('减肥 AI 助理 - E2E 测试', () => {
  test.beforeEach(async ({ page }) => {
    // 设置视口大小
    await page.setViewportSize({ width: 1280, height: 720 });
  });

  test.describe('登录流程', () => {
    test('应该能够访问首页', async ({ page }) => {
      await page.goto(BASE_URL);
      
      // 检查页面标题
      await expect(page).toHaveTitle(/减肥 AI 助理/);
      
      // 检查是否显示欢迎界面
      await expect(page.locator('text=减肥 AI 助理')).toBeVisible();
      await expect(page.locator('text=轻松减肥，AI 陪你')).toBeVisible();
    });

    test('应该能够通过手机号验证码登录', async ({ page }) => {
      // 访问首页
      await page.goto(BASE_URL);
      
      // 点击"开始使用"按钮
      await page.click('text=开始使用');
      
      // 等待登录页面加载
      await expect(page.locator('text=登录')).toBeVisible();
      
      // 输入手机号
      await page.fill('input[placeholder*="手机号"]', TEST_PHONE);
      
      // 点击获取验证码
      await page.click('text=获取验证码');
      
      // 等待倒计时
      await page.waitForTimeout(1000);
      
      // 输入验证码
      await page.fill('input[placeholder*="验证码"]', TEST_CODE);
      
      // 点击登录按钮
      await page.click('text=登录');
      
      // 等待登录成功提示
      await page.waitForTimeout(2000);
      
      // 检查是否返回首页
      await expect(page.locator('text=减肥 AI 助理')).toBeVisible();
      
      // 检查是否显示用户信息（应该显示欢迎信息）
      const welcomeText = page.locator('text=早安');
      await expect(welcomeText).toBeVisible();
    });
  });

  test.describe('首页功能', () => {
    test.beforeEach(async ({ page }) => {
      // 先登录
      await page.goto(BASE_URL);
      await page.click('text=开始使用');
      await page.fill('input[placeholder*="手机号"]', TEST_PHONE);
      await page.click('text=获取验证码');
      await page.waitForTimeout(1000);
      await page.fill('input[placeholder*="验证码"]', TEST_CODE);
      await page.click('text=登录');
      await page.waitForTimeout(2000);
    });

    test('应该显示用户数据概览', async ({ page }) => {
      // 检查是否显示体重卡片
      await expect(page.locator('text=当前体重')).toBeVisible();
      await expect(page.locator('text=目标体重')).toBeVisible();
      await expect(page.locator('text=BMI')).toBeVisible();
      
      // 检查快捷操作
      await expect(page.locator('text=记录饮食')).toBeVisible();
      await expect(page.locator('text=记录体重')).toBeVisible();
    });

    test('应该能够导航到各个页面', async ({ page }) => {
      // 点击底部导航栏
      await expect(page.locator('text=首页')).toBeVisible();
      await expect(page.locator('text=饮食')).toBeVisible();
      await expect(page.locator('text=体重')).toBeVisible();
      await expect(page.locator('text=AI')).toBeVisible();
      await expect(page.locator('text=我的')).toBeVisible();
      
      // 点击饮食标签
      await page.click('text=饮食');
      await expect(page.locator('text=饮食记录')).toBeVisible();
      
      // 点击体重标签
      await page.click('text=体重');
      await expect(page.locator('text=体重记录')).toBeVisible();
      
      // 点击 AI 标签
      await page.click('text=AI');
      await expect(page.locator('text=AI 助手')).toBeVisible();
      
      // 点击我的标签
      await page.click('text=我的');
      await expect(page.locator('text=我的')).toBeVisible();
    });
  });

  test.describe('饮食记录功能', () => {
    test.beforeEach(async ({ page }) => {
      // 先登录并导航到饮食页面
      await page.goto(BASE_URL);
      await page.click('text=开始使用');
      await page.fill('input[placeholder*="手机号"]', TEST_PHONE);
      await page.click('text=获取验证码');
      await page.waitForTimeout(1000);
      await page.fill('input[placeholder*="验证码"]', TEST_CODE);
      await page.click('text=登录');
      await page.waitForTimeout(2000);
      await page.click('text=饮食');
    });

    test('应该能够添加饮食记录', async ({ page }) => {
      // 点击添加按钮
      await page.click('button[aria-label="添加"]');
      
      // 填写表单
      await page.fill('input[placeholder*="食物名称"]', TEST_FOOD);
      await page.fill('input[placeholder*="热量"]', TEST_FOOD_CALORIES.toString());
      
      // 选择餐次（早餐）
      await page.selectOption('select', 'breakfast');
      
      // 点击添加按钮
      await page.click('text=添加');
      
      // 等待添加成功提示
      await page.waitForTimeout(1000);
      await expect(page.locator('text=添加成功')).toBeVisible();
      
      // 检查列表是否显示新记录
      await expect(page.locator(`text=${TEST_FOOD}`)).toBeVisible();
    });
  });

  test.describe('体重记录功能', () => {
    test.beforeEach(async ({ page }) => {
      // 先登录并导航到体重页面
      await page.goto(BASE_URL);
      await page.click('text=开始使用');
      await page.fill('input[placeholder*="手机号"]', TEST_PHONE);
      await page.click('text=获取验证码');
      await page.waitForTimeout(1000);
      await page.fill('input[placeholder*="验证码"]', TEST_CODE);
      await page.click('text=登录');
      await page.waitForTimeout(2000);
      await page.click('text=体重');
    });

    test('应该能够添加体重记录', async ({ page }) => {
      // 点击添加按钮
      await page.click('button[aria-label="添加"]');
      
      // 填写表单
      await page.fill('input[placeholder*="体重"]', TEST_WEIGHT.toString());
      await page.fill('input[placeholder*="体脂率"]', '20');
      await page.fill('input[placeholder*="肌肉量"]', '50');
      await page.fill('input[placeholder*="水分"]', '60');
      await page.fill('input[placeholder*="备注"]', '晨重');
      
      // 点击添加按钮
      await page.click('text=添加');
      
      // 等待添加成功提示
      await page.waitForTimeout(1000);
      await expect(page.locator('text=添加成功')).toBeVisible();
      
      // 检查列表是否显示新记录
      await expect(page.locator(`text=${TEST_WEIGHT} kg`)).toBeVisible();
    });

    test('应该显示体重趋势图表', async ({ page }) => {
      // 添加第一条记录
      await page.click('button[aria-label="添加"]');
      await page.fill('input[placeholder*="体重"]', '71.0');
      await page.click('text=添加');
      await page.waitForTimeout(1000);
      
      // 添加第二条记录
      await page.click('button[aria-label="添加"]');
      await page.fill('input[placeholder*="体重"]', '70.0');
      await page.click('text=添加');
      await page.waitForTimeout(1000);
      
      // 检查是否显示图表
      await expect(page.locator('text=体重趋势')).toBeVisible();
      
      // 检查统计信息
      await expect(page.locator('text=最低')).toBeVisible();
      await expect(page.locator('text=最高')).toBeVisible();
      await expect(page.locator('text=变化')).toBeVisible();
    });
  });

  test.describe('AI 聊天功能', () => {
    test.beforeEach(async ({ page }) => {
      // 先登录并导航到 AI 页面
      await page.goto(BASE_URL);
      await page.click('text=开始使用');
      await page.fill('input[placeholder*="手机号"]', TEST_PHONE);
      await page.click('text=获取验证码');
      await page.waitForTimeout(1000);
      await page.fill('input[placeholder*="验证码"]', TEST_CODE);
      await page.click('text=登录');
      await page.waitForTimeout(2000);
      await page.click('text=AI');
    });

    test('应该能够发送消息给 AI', async ({ page }) => {
      // 检查输入框是否存在
      const inputField = page.locator('input[placeholder*="输入消息"]');
      await expect(inputField).toBeVisible();
      
      // 输入消息
      await inputField.fill('你好，我想减肥');
      
      // 点击发送按钮
      await page.click('button[aria-label="send"]');
      
      // 等待消息发送（显示 typing 指示器）
      await page.waitForTimeout(3000);
      
      // 检查是否显示用户消息
      await expect(page.locator('text=你好，我想减肥')).toBeVisible();
      
      // 检查是否显示 AI 回复（需要等待后端响应）
      // 注意：如果后端 AI 服务未配置，这里可能会失败
      // 可以添加重试逻辑或跳过此断言
    });

    test('应该能够新建对话', async ({ page }) => {
      // 点击新建对话按钮
      await page.click('button[aria-label="新建对话"]');
      
      // 等待提示
      await page.waitForTimeout(1000);
      await expect(page.locator('text=已创建新对话')).toBeVisible();
    });
  });

  test.describe('个人中心功能', () => {
    test.beforeEach(async ({ page }) => {
      // 先登录并导航到个人中心
      await page.goto(BASE_URL);
      await page.click('text=开始使用');
      await page.fill('input[placeholder*="手机号"]', TEST_PHONE);
      await page.click('text=获取验证码');
      await page.waitForTimeout(1000);
      await page.fill('input[placeholder*="验证码"]', TEST_CODE);
      await page.click('text=登录');
      await page.waitForTimeout(2000);
      await page.click('text=我的');
    });

    test('应该显示用户信息', async ({ page }) => {
      // 检查是否显示用户信息
      await expect(page.locator('text=手机用户')).toBeVisible();
      await expect(page.locator('text=ID:')).toBeVisible();
    });

    test('应该能够退出登录', async ({ page }) => {
      // 点击退出登录按钮
      await page.click('button[aria-label="logout"]');
      
      // 等待退出成功提示
      await page.waitForTimeout(1000);
      await expect(page.locator('text=已退出登录')).toBeVisible();
      
      // 检查是否显示未登录状态
      await expect(page.locator('text=未登录')).toBeVisible();
    });
  });

  test.describe('页面响应式测试', () => {
    test('应该在移动设备尺寸下正常显示', async ({ page }) => {
      // 设置为手机尺寸
      await page.setViewportSize({ width: 375, height: 667 });
      
      await page.goto(BASE_URL);
      
      // 检查基本元素是否可见
      await expect(page.locator('text=减肥 AI 助理')).toBeVisible();
      await expect(page.locator('text=开始使用')).toBeVisible();
    });

    test('应该在平板尺寸下正常显示', async ({ page }) => {
      // 设置为平板尺寸
      await page.setViewportSize({ width: 768, height: 1024 });
      
      await page.goto(BASE_URL);
      
      // 检查基本元素是否可见
      await expect(page.locator('text=减肥 AI 助理')).toBeVisible();
      await expect(page.locator('text=开始使用')).toBeVisible();
    });
  });
});
