import { defineConfig } from '@playwright/test';
import path from 'node:path';
import repo from '../../playwright.config';

// Its own config, so the repo's e2e run never picks the capture up. testDir resolves relative to this file; so do a
// webServer command and the output folder, so both are pinned back to the repository root: failure snapshots must land
// where the repo already ignores them, never in this folder, which is committed.
const root = path.resolve(__dirname, '../..');
const servers = repo.webServer && (Array.isArray(repo.webServer) ? repo.webServer : [repo.webServer]).map((s) => ({ ...s, cwd: s.cwd ?? root }));

export default defineConfig({
  ...repo,
  testDir: '.',
  testMatch: 'docs-capture.spec.ts',
  workers: 1,
  retries: 1,
  reporter: 'list',
  outputDir: repo.outputDir ? path.resolve(root, repo.outputDir) : path.join(root, 'test-results', 'docs-capture'),
  webServer: servers,
  use: { ...repo.use, baseURL: process.env.DOCS_URL ?? repo.use?.baseURL, trace: 'off', video: 'off', screenshot: 'off' },
});
