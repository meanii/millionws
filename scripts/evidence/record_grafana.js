// Records a video of a live Grafana dashboard and takes screenshots on a schedule.
// Run with Playwright (docker: mcr.microsoft.com/playwright:v1.49.0-noble):
//   node record_grafana.js <host> <dashboard-uid> <slug> <out-dir> <minutes> [shot-every-s]
// The page uses the IST timezone and en-US locale (Grafana throws without a locale).
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const [host, uid, slug, out, minutes, shotEvery] = process.argv.slice(2);
  const ms = parseFloat(minutes) * 60000;
  const every = parseInt(shotEvery || '120', 10) * 1000;
  const b = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await b.newContext({
    viewport: { width: 1440, height: 1000 },
    locale: 'en-US',
    timezoneId: 'Asia/Kolkata',
    recordVideo: { dir: out, size: { width: 1280, height: 890 } },
  });
  const p = await ctx.newPage();
  const from = process.env.FROM_MS || `now-${Math.ceil(parseFloat(minutes)) + 2}m`;
  await p.goto(`http://${host}:3000/d/${uid}/${slug}?orgId=1&from=${from}&to=now&refresh=5s&kiosk`, { waitUntil: 'domcontentloaded', timeout: 60000 });
  const start = Date.now();
  let n = 0;
  while (Date.now() - start < ms) {
    await p.waitForTimeout(Math.min(every, Math.max(1000, ms - (Date.now() - start))));
    n++;
    const t = new Date().toLocaleTimeString('en-GB', { timeZone: 'Asia/Kolkata', hour12: false }).replace(/:/g, '');
    await p.screenshot({ path: path.join(out, `shot-${String(n).padStart(2, '0')}-${t}IST.png`), fullPage: true });
  }
  await ctx.close();
  await b.close();
  console.log('done', n, 'screenshots');
})().catch(e => { console.error('FAIL', e.message); process.exit(1); });
