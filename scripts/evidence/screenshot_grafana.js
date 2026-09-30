// Full-page screenshots of Grafana dashboards for a fixed time range, in IST.
//   node screenshot_grafana.js <host> <out-dir> <from-ms> <to-ms> <uid>:<slug> [<uid>:<slug> ...]
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const [host, out, from, to, ...dashes] = process.argv.slice(2);
  const b = await chromium.launch({ args: ['--no-sandbox'] });
  const ctx = await b.newContext({ viewport: { width: 1800, height: 1400 }, locale: 'en-US', timezoneId: 'Asia/Kolkata' });
  for (const d of dashes) {
    const [uid, slug] = d.split(':');
    const p = await ctx.newPage();
    await p.goto(`http://${host}:3000/d/${uid}/${slug}?orgId=1&from=${from}&to=${to}&kiosk`, { waitUntil: 'domcontentloaded', timeout: 60000 });
    await p.waitForTimeout(25000);
    await p.screenshot({ path: path.join(out, `${slug}.png`), fullPage: true });
    console.log('saved', slug);
    await p.close();
  }
  await b.close();
})().catch(e => { console.error('FAIL', e.message); process.exit(1); });
