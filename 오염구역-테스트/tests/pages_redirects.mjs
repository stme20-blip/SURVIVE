import {chromium} from '../build/browser-check/node_modules/playwright-core/index.mjs';
import {createServer} from 'node:http';
import {readFileSync, readdirSync} from 'node:fs';
import {fileURLToPath} from 'node:url';
import {join} from 'node:path';
import assert from 'node:assert/strict';

const docs = fileURLToPath(new URL('../docs/', import.meta.url));
const current = readFileSync(join(docs, 'index.html'), 'utf8').match(/url=\.\/(release-v\d+)\//)[1];
const old = readdirSync(docs).filter(name => /^release-v\d+$/.test(name) && name !== current);
const server = createServer((req, res) => {
  const path = new URL(req.url, 'http://localhost').pathname;
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  if (path === `/${current}/`) return res.end('<title>Current release</title>');
  if (path === '/') return res.end(readFileSync(join(docs, 'index.html')));
  if (path === '/recovery.html') return res.end(readFileSync(join(docs, 'recovery.html')));
  const match = path.match(/^\/(release-v\d+)\/(?:index\.html)?$/);
  if (match && old.includes(match[1])) return res.end(readFileSync(join(docs, match[1], 'index.html')));
  res.writeHead(404).end();
});
let browser;
try {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  browser = await chromium.launch({executablePath: 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe', headless: true});
  const page = await browser.newPage();
  const origin = `http://127.0.0.1:${server.address().port}`;
  for (const path of [...old.map(name => `/${name}/`), '/release-v33/index.html', '/recovery.html']) {
    await page.goto(origin + path + '?invite=TEST12#test-fragment');
    await page.waitForURL(origin + `/${current}/?invite=TEST12#test-fragment`);
    assert.equal(await page.title(), 'Current release');
  }
  console.log(`PASS: ${old.length} old release URLs, explicit index and recovery page redirect to ${current}, preserving query and fragment`);
} finally {
  if (browser) await browser.close();
  server.close();
}
