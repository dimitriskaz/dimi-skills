import { test, expect, type Page } from '@playwright/test';
import fs from 'node:fs';
import path from 'node:path';
import { captureScene } from './capture-scene';

const plan = JSON.parse(fs.readFileSync(path.join(__dirname, 'scenes.json'), 'utf8'));
const imageRoot = path.resolve(__dirname, plan.imageRoot);              // the published docs' img/ folder
const allowed = new Set(['localhost', '127.0.0.1', ...(plan.allowHosts ?? [])]);

test.describe.configure({ mode: 'serial' });
test.use({
  viewport: plan.viewport ?? { width: 1440, height: 900 },
  deviceScaleFactor: 2,
  reducedMotion: 'reduce',
  colorScheme: 'light',
  locale: plan.locale ?? 'en-US',
  timezoneId: plan.timezone ?? 'UTC',
});

test.beforeEach(async ({ page, baseURL }) => {
  const host = new URL(baseURL ?? 'http://invalid').hostname;
  if (!allowed.has(host)) throw new Error(`docs capture refuses ${host}: add it with --allow-host only if it is a demo environment`);
  if (plan.clock) await page.clock.setFixedTime(new Date(plan.clock));
});

async function act(page: Page, a: Record<string, any>) {
  if (a.click) return page.locator(a.click).first().click();
  if (a.fill) return page.locator(a.fill[0]).first().fill(a.fill[1]);
  if (a.select) return page.locator(a.select[0]).first().selectOption(a.select[1]);
  if (a.upload) return page.locator(a.upload[0]).first().setInputFiles(path.resolve(__dirname, a.upload[1]));
  if (a.hover) return page.locator(a.hover).first().hover();
  if (a.press) return page.keyboard.press(a.press);
  if (a.wait) return page.locator(a.wait).first().waitFor();
  throw new Error(`unknown action ${JSON.stringify(a)}`);
}

// Scenes run as a role when they say "as": the storageState file that role's sign-in setup writes (never committed).
const groups = new Map<string, any[]>();
for (const scene of plan.scenes) groups.set(scene.as ?? '', [...(groups.get(scene.as ?? '') ?? []), scene]);

for (const [role, scenes] of groups) {
  test.describe(role || 'default user', () => {
    if (role) {
      const state = plan.roles?.[role];
      if (!state) throw new Error(`scenes run "as": "${role}" but scenes.json "roles" names no storageState for it`);
      test.use({ storageState: path.resolve(__dirname, state) });
    }
    for (const scene of scenes) {
      test(scene.id, async ({ page }) => {
        await page.goto(scene.route);
        if (!plan.tenant) throw new Error('scenes.json needs "tenant": text that only the demo tenant shows (its name or badge)');
        await expect(page.getByText(plan.tenant).first(), 'docs are captured on the demo tenant only').toBeVisible();
        for (const a of scene.actions ?? []) await act(page, a);
        if (scene.wait) await page.locator(scene.wait).first().waitFor();
        await page.evaluate(() => document.fonts.ready);
        const file = path.join(imageRoot, scene.module, `${scene.id}.png`);
        fs.mkdirSync(path.dirname(file), { recursive: true });
        await captureScene(page, scene, plan.style ?? {}, file);
      });
    }
  });
}
