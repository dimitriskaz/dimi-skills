import type { Locator, Page } from '@playwright/test';

export type Scene = { id: string; clip?: string; highlight?: string; mask?: string[]; fullPage?: boolean };
// The same for every scene. hide: development and environment chrome (dev overlays, "staging" banners, cookie
// banners), removed from the layout. mask: every region that can hold personal data, masked in every scene.
export type Style = { hide?: string[]; mask?: string[]; highlight?: string; maskColor?: string; padding?: number };

async function visible(locator: Locator, scene: Scene, selector: string) {
  try { await locator.waitFor({ state: 'visible', timeout: 5000 }); }
  catch { throw new Error(`scene ${scene.id}: ${selector} is not on the screen; fix the selector or the scene's actions`); }
}

export async function captureScene(page: Page, scene: Scene, style: Style, outPath: string) {
  const hide = (style.hide ?? []).map((s) => `${s}{display:none !important}`).join('\n');
  const tag = await page.addStyleTag({ content: `${hide}\n*,*::before,*::after{caret-color:transparent !important}` });
  const target = scene.highlight ? page.locator(scene.highlight).first() : null;
  let previous: [string, string] | null = null;
  try {
    if (target) {
      await visible(target, scene, scene.highlight!);
      await target.scrollIntoViewIfNeeded();
      previous = await target.evaluate((node: HTMLElement, color: string) => {
        const before: [string, string] = [node.style.outline, node.style.outlineOffset];
        node.style.outline = `3px solid ${color}`;
        node.style.outlineOffset = '3px';
        return before;
      }, style.highlight ?? '#d9480f');
    }
    const options = {
      path: outPath,
      animations: 'disabled' as const,
      caret: 'hide' as const,
      mask: [...(style.mask ?? []), ...(scene.mask ?? [])].map((s) => page.locator(s)),
      maskColor: style.maskColor ?? '#8a8f98',
    };
    if (scene.clip) {
      // the region plus padding, in page coordinates, so a region taller than the viewport is captured whole
      const region = page.locator(scene.clip).first();
      await visible(region, scene, scene.clip);
      await region.scrollIntoViewIfNeeded();
      const box = await region.boundingBox();
      if (!box) throw new Error(`scene ${scene.id}: ${scene.clip} has no size`);
      const scroll = await page.evaluate(() => ({ x: window.scrollX, y: window.scrollY }));
      const pad = style.padding ?? 16;
      const x = Math.max(0, box.x + scroll.x - pad);
      const y = Math.max(0, box.y + scroll.y - pad);
      await page.screenshot({ ...options, fullPage: true, clip: { x, y, width: box.width + 2 * pad, height: box.height + 2 * pad } });
    } else {
      if (!target) await page.evaluate(() => window.scrollTo(0, 0));   // a whole-screen shot starts at the top
      await page.screenshot({ ...options, fullPage: !!scene.fullPage });
    }
  } finally {
    if (target && previous) await target.evaluate((node: HTMLElement, before: [string, string]) => { node.style.outline = before[0]; node.style.outlineOffset = before[1]; }, previous);
    await tag.evaluate((node) => node.remove());
  }
}
