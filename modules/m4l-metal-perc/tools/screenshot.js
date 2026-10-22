const { chromium } = require('playwright');
// Rendert eine HTML-Layout-Vorschau zu PNG: node screenshot.js <layout.html> <out.png> (braucht Playwright)
(async () => {
  const b = await chromium.launch(); const pg = await b.newPage({ deviceScaleFactor: 2, viewport: { width: 1860, height: 210 } });
  await pg.goto('file://' + process.argv[2]); await pg.screenshot({ path: process.argv[3], fullPage: true }); await b.close();
})();
