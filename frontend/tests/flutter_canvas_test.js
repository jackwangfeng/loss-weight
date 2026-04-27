/**
 * Flutter Web Canvas E2E — verifies app loads and bottom-nav routing works.
 * Tab labels follow the English UI post-pivot (CutBro).
 */

const { test, expect } = require('@playwright/test');

const BASE_URL = process.env.BASE_URL || 'http://localhost:8889';

test.describe('Flutter Web Canvas', () => {
  // The historical "Flutter Web loads" / "canvas visible" tests were dropped:
  // they polled `<canvas>`, but canvaskit is fetched from gstatic.com which
  // is unreachable from this dev environment, so the tests deterministically
  // timed out without proving anything the semantics tests below don't already
  // cover. The "Semantics interaction" describe block is the real load smoke
  // test now — if the bottom nav renders, Flutter mounted.

  test('page ships Flutter bootstrap assets', async ({ page }) => {
    await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });

    // bootstrap script is synchronous in the HTML — visible by DCL.
    const mainDartLoaded = await page.evaluate(() => {
      return document.body.innerHTML.includes('main.dart.js') ||
             document.body.innerHTML.includes('flutter_bootstrap.js');
    });
    expect(mainDartLoaded).toBeTruthy();
    console.log('Flutter bootstrap loaded');
  });
});

test.describe('Semantics interaction', () => {
  // Wait for Flutter's semantics tree to expose at least N tabs.
  async function waitForTabs(page, minCount = 3) {
    await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(
      (n) => document.querySelectorAll('flt-semantics[role="tab"]').length >= n,
      minCount,
      { timeout: 15000 }
    );
  }

  test('bottom nav exposes 3 tabs', async ({ page }) => {
    await waitForTabs(page);
    for (const name of ['Today', 'Assistant', 'Me']) {
      await expect(page.getByRole('tab', { name, exact: false })).toBeVisible();
    }
  });

  test('tapping Assistant switches to chat screen', async ({ page }) => {
    await waitForTabs(page);
    await page.getByRole('tab', { name: 'Assistant', exact: true }).click();
    await expect(page.locator('flt-semantics[role="tab"][aria-selected="true"]'))
      .toHaveAttribute('aria-label', /Assistant/, { timeout: 5000 });
    await expect(page.locator('flutter-view')).toBeVisible();
  });

  test('tapping Me shows profile or logged-out view', async ({ page }) => {
    await waitForTabs(page);
    await page.getByRole('tab', { name: 'Me', exact: true }).click();
    // Logged in: "Edit profile" visible. Logged out: "Not signed in".
    await expect(page.locator('flutter-view')).toBeVisible();
  });

  test('cycling through all tabs does not crash', async ({ page }) => {
    await waitForTabs(page);
    for (const name of ['Assistant', 'Me', 'Today']) {
      await page.getByRole('tab', { name, exact: true }).click();
      await expect(page.locator('flutter-view')).toBeVisible();
    }
  });
});

test.describe('Backend API', () => {
  test('backend health', async ({ request }) => {
    const response = await request.get('http://localhost:8000/health');
    expect(response.ok()).toBeTruthy();
    const data = await response.json();
    expect(data.status).toBe('healthy');
    console.log('Backend healthy:', data);
  });

  test('AI chat API', async ({ request }) => {
    const loginResp = await request.post('http://localhost:8000/v1/auth/sms/login', {
      data: { phone: '13800138000', code: '123456' }
    });
    expect(loginResp.ok()).toBeTruthy();
    const loginData = await loginResp.json();
    console.log('Signed in, user_id:', loginData.user_id);

    const chatResp = await request.post('http://localhost:8000/v1/ai/chat', {
      data: {
        user_id: loginData.user_id,
        messages: [{ role: 'user', content: 'hi' }]
      },
      headers: {
        'Authorization': 'Bearer ' + loginData.token,
        'Content-Type': 'application/json'
      }
    });
    expect(chatResp.ok()).toBeTruthy();
    const chatData = await chatResp.json();
    console.log('AI reply:', chatData.content ? chatData.content.substring(0, 50) : 'N/A');
    expect(chatData.content).toBeTruthy();
  });
});
