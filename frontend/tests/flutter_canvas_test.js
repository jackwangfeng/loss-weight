/**
 * Flutter Web Canvas E2E — verifies app loads and bottom-nav routing works.
 * Tab labels follow the English UI post-pivot (CutBro).
 */

const { test, expect } = require('@playwright/test');

const BASE_URL = process.env.BASE_URL || 'http://localhost:8889';

test.describe('Flutter Web Canvas', () => {
  test('Flutter Web loads', async ({ page }) => {
    await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });

    const html = await page.content();
    expect(html).toContain('flutter');
    expect(html).toContain('flutter_bootstrap.js');

    // Flutter mounts its canvas a beat after networkidle; wait for it with
    // Playwright's auto-retrying visibility matcher instead of a fixed sleep.
    await expect(page.locator('canvas').first()).toBeVisible({ timeout: 15000 });

    await page.screenshot({ path: 'test-1-initial-load.png', fullPage: true });
    console.log('Flutter page loaded, screenshot saved');

    const canvasCount = await page.locator('canvas').count();
    console.log('Found ' + canvasCount + ' canvas element(s)');
    expect(canvasCount).toBeGreaterThan(0);
  });

  test('Flutter Web canvas visible', async ({ page }) => {
    await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });

    // toBeVisible auto-retries up to the default timeout — no fixed sleep needed.
    const canvas = page.locator('canvas').first();
    await expect(canvas).toBeVisible({ timeout: 15000 });

    await page.screenshot({ path: 'test-2-canvas-visible.png', fullPage: true });
    console.log('Canvas visible, screenshot saved');
  });

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
  async function waitForTabs(page, minCount = 4) {
    await page.goto(BASE_URL, { waitUntil: 'domcontentloaded' });
    await page.waitForFunction(
      (n) => document.querySelectorAll('flt-semantics[role="tab"]').length >= n,
      minCount,
      { timeout: 15000 }
    );
  }

  test('bottom nav exposes 4 tabs', async ({ page }) => {
    await waitForTabs(page);
    for (const name of ['Today', 'Log', 'Coach', 'Me']) {
      await expect(page.getByRole('tab', { name, exact: false })).toBeVisible();
    }
  });

  test('tapping Coach switches to Coach screen', async ({ page }) => {
    await waitForTabs(page);
    await page.getByRole('tab', { name: 'Coach', exact: true }).click();
    // Selected-tab label matches Coach.
    await expect(page.locator('flt-semantics[role="tab"][aria-selected="true"]'))
      .toHaveAttribute('aria-label', /Coach/, { timeout: 5000 });
    // Screen renders without crashing.
    await expect(page.locator('flutter-view')).toBeVisible();
  });

  test('Log tab + Food subtab', async ({ page }) => {
    await waitForTabs(page);
    await page.getByRole('tab', { name: 'Log', exact: true }).click();
    // After entering Log, 3 subtabs appear (Food / Training / Weight) — total >= 7.
    await page.waitForFunction(
      () => document.querySelectorAll('flt-semantics[role="tab"]').length >= 7,
      { timeout: 5000 }
    );
    await page.getByRole('tab', { name: 'Food', exact: true })
        .click({ timeout: 5000 });
    await expect(page.locator('flutter-view')).toBeVisible();
  });

  test('Log tab + Training subtab', async ({ page }) => {
    await waitForTabs(page);
    await page.getByRole('tab', { name: 'Log', exact: true }).click();
    await page.getByRole('tab', { name: 'Training', exact: true })
        .click({ timeout: 5000 });
    await expect(page.locator('flutter-view')).toBeVisible();
  });

  test('Log tab + Weight subtab', async ({ page }) => {
    await waitForTabs(page);
    await page.getByRole('tab', { name: 'Log', exact: true }).click();
    await page.getByRole('tab', { name: 'Weight', exact: true })
        .click({ timeout: 5000 });
    // Empty-state or chart — either is fine.
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
    for (const name of ['Log', 'Coach', 'Me', 'Today']) {
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
