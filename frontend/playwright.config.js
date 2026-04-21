/**
 * Playwright 配置文件
 * 用于减肥 AI 助理前端 E2E 测试
 */

module.exports = {
  // 测试超时时间（毫秒）
  timeout: 60000,
  
  // 每个测试的超时时间
  expect: {
    timeout: 10000
  },
  
  // 测试文件匹配规则（同时支持 foo.test.js 和 foo_test.js）
  testMatch: /.*(_test|\.test|\.spec)\.[cm]?[jt]sx?$/,

  // 测试失败后重试次数
  retries: 0,
  
  // 并行执行的 worker 数量
  workers: 1,
  
  // 报告器
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['list'],
  ],
  
  // 共享配置
  use: {
    // 基础 URL
    baseURL: process.env.BASE_URL || 'http://localhost:8888',
    
    // 浏览器选项
    headless: process.env.HEADED ? false : true,
    
    // 截图选项
    screenshot: 'only-on-failure',
    
    // 视频选项
    video: 'retain-on-failure',
    
    // 跟踪选项（用于调试）
    trace: 'on-first-retry',
    
    // 浏览器视口
    viewport: { width: 1280, height: 720 },
    
    // 用户代理
    userAgent: 'LossWeight-App-Test-Bot'
  },
  
  // 项目配置（多浏览器测试）
  projects: [
    {
      name: 'chromium',
      use: { 
        // 使用 Chromium 浏览器
      },
    },
    {
      name: 'chrome',
      use: { 
        // 使用系统已安装的 Chrome
        channel: 'chrome',
      },
    },
  ],
};
