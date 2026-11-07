# Capturing screenshots for the docs

As of 2026-11. The capture files in `capture/` were run end to end with `@playwright/test` 1.63 on Chromium: whole-screen and clipped scenes, a clip below the fold, highlight and masks, hidden chrome, three roles, a refused host, a missing demo-tenant marker, a missing role mapping, a repo `webServer` started from the right folder, failure output kept out of the tools folder, role and text selectors, an upload replayed inside a scene, and a tools folder two and three levels deep. They need Playwright 1.45 or later for `page.clock`; check the repo's version. They are TypeScript, which `@playwright/test` runs in JavaScript repos too. A Python-only Playwright repo needs the same rules written for `pytest-playwright`; that variant is not tested.

## The files

`docs-init.sh` copies these into `tools/docs-capture/` and never overwrites:

| File | What it does |
| --- | --- |
| `playwright.capture.config.ts` | Imports the repo's own Playwright config (base URL, sign-in, `webServer`) and narrows it to the capture spec, so the repo's e2e run never picks the capture up. Pins each `webServer` and the output folder to the repository root: a server command otherwise runs from this folder, and failure snapshots must land where the repo already ignores them, never in this committed folder. |
| `docs-capture.spec.ts` | Reads `scenes.json`, refuses a host that is not allowed, refuses to capture without the demo-tenant marker on screen, runs each scene as its role, replays its actions and saves the image. |
| `capture-scene.ts` | Takes one screenshot: hides chrome, masks personal data, outlines the control the step acts on, clips to a region with padding, then restores the page. |
| `scenes.json` | The plan: one entry per screenshot a page uses. Written by the skill, kept in git. |

If the repo's Playwright config uses `projects` with a sign-in setup project, keep that setup project and one Chromium project in the capture config, and set `testDir: '.'` and `testMatch: 'docs-capture.spec.ts'` on the Chromium project as well, since a project's own `testDir` wins over the top level. That variant is not covered by the tested files; run the capture once and read its output before trusting it.

## scenes.json

```json
{
  "imageRoot": "../../docs/product/img",
  "tenant": "Demo workspace",
  "allowHosts": ["preview.example.dev"],
  "clock": "2026-03-02T10:00:00Z",
  "viewport": { "width": 1440, "height": 900 },
  "locale": "en-US",
  "timezone": "UTC",
  "roles": { "admin": "../../playwright/.auth/admin.json", "member": "../../playwright/.auth/member.json" },
  "style": {
    "hide": ["[data-env-banner]", "#__next-build-watcher", ".cookie-banner", "#intercom-container"],
    "mask": ["[data-user-menu]", "img.avatar", "input[type=email]"]
  },
  "scenes": [
    {
      "id": "imports-02-upload",
      "module": "imports",
      "page": "imports/import-a-spreadsheet.md",
      "step": 2,
      "as": "member",
      "route": "/imports",
      "actions": [{ "click": "role=button[name=\"New import\"]" }, { "upload": ["input[type=file]", "fixtures/demo-workbook.xlsx"] }],
      "wait": "text=Preview",
      "clip": "[data-panel=new-import]",
      "highlight": "role=button[name=\"Upload\"]",
      "alt": "The New import panel with the Upload button outlined."
    }
  ]
}
```

| Field | Meaning |
| --- | --- |
| `imageRoot` | the published `img/` folder, relative to the tools folder |
| `tenant` | text only the demo tenant shows (its name or badge); required |
| `allowHosts` | hosts besides `localhost` and `127.0.0.1`: the repo's `baseURL` host and each `--allow-host`, nothing else |
| `clock` | a fixed time, so relative dates ("2 days ago") never change between captures |
| `roles` | a scene's `as` to the signed-in state file the repo's auth setup writes; those files are never committed |
| `style.hide` | development and environment chrome, removed from the layout in every scene |
| `style.mask` | every region that can show personal data, masked in every scene |
| `id` | `<module>-<nn>-<slug>`, stable; the image is `imageRoot/<module>/<id>.png` |
| `page`, `step` | where the image is used, so a retake updates the right page |
| `as` | the role the scene runs as; omit for the repo's default sign-in |
| `route` | where the scene starts; each scene runs in a fresh page |
| `actions` | every action from the route to the state: `click`, `fill: [selector, text]`, `select: [selector, value]`, `upload: [selector, fixture]`, `hover`, `press`, `wait` |
| `wait` | what must be on screen before the picture |
| `clip` | crop to this region plus padding; omit for the whole screen |
| `highlight` | the one control the step acts on, outlined |
| `mask` | extra regions to mask for this scene only |
| `fullPage` | the whole scrollable page, for an overview |
| `alt` | the alt text the page uses for this image |

## The screenshot standard

- 1440 by 900 at 2x, light theme, the docs' locale and time zone, a fixed clock, reduced motion, no caret. The same demo tenant and the same users throughout, so every screen looks like one product.
- The first step of a task: the whole screen, so the reader sees where they are. Later steps: clipped to the panel the step is about, with padding. The result: whatever shows it best.
- One highlight per image, on the control the step names. No arrows, numbers or text drawn on the picture: the step's text does that job and survives a translation.
- Demo data is complete and plausible but obviously fictional (no real-looking organisations, no real names). Empty states are captured on purpose, never by accident.
- Each role's task is captured as that role: an admin task as an admin, a member task as a member, so the menus match what the reader has.

## Look at every image

Open each PNG before a page uses it. Retake or list it when any of these fails:
- The screen and state the step describes, after the action, not before it.
- The role the page is about; no admin-only menu in a member's task.
- No development or environment chrome: dev overlays, "staging" or "preview" banners, debug panels, error toasts from unrelated calls, browser extensions.
- No internal names on screen: feature-flag labels, test tenants, placeholder text, internal codenames in menus.
- Personal data masked: the user menu, avatars, email addresses, names in audit logs.
- Text legible at the size the page shows it; the highlight on the right control.
