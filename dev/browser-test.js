// Drives the widgets from dev/browser-test.R in headless Chromium and checks
// the interaction: drawing, revealing, resetting, facets, axes, touch, Shiny.
//
//   npm install playwright && npx playwright install chromium     (once)
//   Rscript dev/browser-test.R && node dev/browser-test.js
//
// With the Shiny round trip:
//   Rscript dev/browser-test.R shiny &
//   node dev/browser-test.js --shiny

const { chromium } = require('playwright');
const path = require('path');

const out = path.join(__dirname, 'out');
let failures = 0;
const check = (name, ok, detail) => {
  if (!ok) failures++;
  console.log((ok ? 'ok    ' : 'FAIL  ') + name + (ok || detail === undefined ? '' : '  -> ' + JSON.stringify(detail)));
};

async function open(browser, url, options) {
  const context = await browser.newContext(Object.assign({ viewport: { width: 1100, height: 900 } }, options));
  const page = await context.newPage();
  page.errors = [];
  page.on('pageerror', e => page.errors.push(e.message));
  page.on('console', m => { if (m.type() === 'error') page.errors.push(m.text()); });
  await page.goto(url);
  await page.waitForSelector('.ydi-controls', { timeout: 15000 });
  return page;
}
const file = name => 'file://' + path.join(out, name + '.html');

// Where the hidden points of panel k are on screen, and the top of the panel
const points = (page, k = 0) => page.evaluate(k => {
  const svg = document.querySelector('svg.ggiraph-svg');
  const zone = svg.querySelectorAll('[ydi="zone"]')[k];
  const id = zone.getAttribute('ydi_panel');
  const matrix = svg.getScreenCTM();
  const onScreen = (x, y) => {
    const p = svg.createSVGPoint();
    p.x = x; p.y = y;
    const q = p.matrixTransform(matrix);
    return { x: q.x, y: q.y };
  };
  const hidden = Array.from(svg.querySelectorAll(`[ydi="hidden"][ydi_panel="${id}"]`));
  return {
    pts: hidden.map(c => onScreen(+c.getAttribute('cx'), +c.getAttribute('cy'))),
    top: onScreen(0, +zone.getAttribute('y')).y
  };
}, k);

// What the reader sees
const state = page => page.evaluate(() => {
  const svg = document.querySelector('svg.ggiraph-svg');
  const shown = node => node.getAttribute('display') !== 'none';
  const visible = selector => { const node = document.querySelector(selector); return !!node && !node.hidden; };
  return {
    clip: Array.from(svg.querySelectorAll('clipPath[id*="_ydi_"] rect')).map(r => +r.getAttribute('width')),
    dots: Array.from(svg.querySelectorAll('g[pointer-events="none"] > circle')).filter(shown).length,
    texts: Array.from(svg.querySelectorAll('g[pointer-events="none"] > text')).filter(shown).map(t => t.textContent),
    stroke: svg.querySelector('g[pointer-events="none"] > path').getAttribute('stroke'),
    reveal: !visible('.ydi-reveal') ? 'hidden' : document.querySelector('.ydi-reveal').disabled ? 'disabled' : 'enabled',
    revealText: document.querySelector('.ydi-reveal').textContent,
    reset: visible('.ydi-reset'),
    result: visible('.ydi-result') ? document.querySelector('.ydi-result').textContent : null
  };
});

async function drag(page, pts, steps = 6) {
  await page.mouse.move(pts[0].x, pts[0].y);
  await page.mouse.down();
  for (const p of pts.slice(1)) await page.mouse.move(p.x, p.y, { steps });
  if (pts.length === 1) await page.mouse.move(pts[0].x, pts[0].y + 0.5);
  await page.mouse.up();
  await page.mouse.move(3, 3);
}
const reveal = async page => { await page.click('.ydi-reveal'); await page.waitForTimeout(1500); };

(async () => {
  const browser = await chromium.launch({ args: ['--no-proxy-server'] });
  let page, s, g;

  // ---- basic: draw, reveal, lock, reset
  page = await open(browser, file('basic'));
  s = await state(page);
  check('basic: starts hidden, button disabled, hint shown',
    s.clip[0] === 0 && s.reveal === 'disabled' && s.texts.length === 1 && s.dots === 0, s);
  g = await points(page);
  await drag(page, g.pts);
  s = await state(page);
  check('basic: drawing over the real points gives the real last value',
    s.dots === 3 && s.reveal === 'enabled' && s.texts[0] === '15%', s);
  await reveal(page);
  s = await state(page);
  check('basic: reveal opens the clip and shows the result',
    s.clip[0] > 0 && s.reveal === 'hidden' && s.reset && s.result === 'For 2026 you drew 15%. The real number is 15%.', s);
  await drag(page, g.pts.map(p => ({ x: p.x, y: g.top + 10 })));
  check('basic: drawing is locked after the reveal',
    (await state(page)).result === 'For 2026 you drew 15%. The real number is 15%.');
  await page.click('.ydi-reset');
  s = await state(page);
  check('basic: reset starts over', s.clip[0] === 0 && s.dots === 0 && s.reveal === 'disabled' && s.result === null, s);
  await drag(page, [{ x: g.pts[0].x, y: g.top + 120 }, { x: g.pts[2].x, y: g.top + 100 }], 1);
  s = await state(page);
  check('basic: a fast stroke fills the points in between', s.dots === 3, s);
  const lastLabel = s.texts[0];
  await page.mouse.move(g.pts[1].x, g.top + 40);
  s = await state(page);
  check('basic: hovering shows the value at that point, with a decimal comma',
    s.texts[0] !== lastLabel && /^\d+(,\d)?%$/.test(s.texts[0]), [lastLabel, s.texts[0]]);
  check('basic: no browser errors', page.errors.length === 0, page.errors);

  check('basic: the button pulses once the line is complete', await page.evaluate(() => {
    document.querySelector('.ydi-reset').click();
    return !document.querySelector('.ydi-reveal').classList.contains('ydi-ready');
  }));
  await drag(page, g.pts);
  check('basic: ... and pulses again after a redraw',
    await page.evaluate(() => document.querySelector('.ydi-reveal').classList.contains('ydi-ready')));

  // ---- auto: no button, the line reveals itself, controls above the chart
  page = await open(browser, file('auto'));
  s = await state(page);
  check('auto: no reveal button, controls above the chart', s.reveal === 'hidden' &&
    await page.evaluate(() => { const bar = document.querySelector('.ydi-controls');
      return bar.getBoundingClientRect().bottom <= document.querySelector('svg.ggiraph-svg').getBoundingClientRect().top + 1; }), s);
  g = await points(page);
  await drag(page, g.pts.slice(0, 2));
  await page.waitForTimeout(1800);
  check('auto: a partial line does not reveal', (await state(page)).clip[0] === 0);
  await drag(page, g.pts);
  await page.waitForTimeout(1800);
  s = await state(page);
  check('auto: a complete line reveals by itself',
    s.clip[0] > 0 && s.reset && s.result === 'For 2026 you drew 15%. The real number is 15%.', s);
  await page.click('.ydi-reset');
  s = await state(page);
  check('auto: reset starts over', s.clip[0] === 0 && s.dots === 0 && s.reveal === 'hidden', s);
  check('auto: no browser errors', page.errors.length === 0, page.errors);

  // ---- facets: every panel has to be drawn
  page = await open(browser, file('facets'));
  await drag(page, (await points(page, 0)).pts);
  check('facets: button stays disabled until every panel is drawn', (await state(page)).reveal === 'disabled');
  await drag(page, (await points(page, 1)).pts);
  check('facets: button enabled once both are drawn', (await state(page)).reveal === 'enabled');
  await reveal(page);
  s = await state(page);
  check('facets: both panels reveal, without a result sentence',
    s.clip.length === 2 && s.clip.every(w => w > 0) && s.result === null && s.texts.length === 4, s);
  check('facets: no browser errors', page.errors.length === 0, page.errors);

  // ---- log axis: pixels map to values through the lookup table
  page = await open(browser, file('log'));
  await drag(page, (await points(page)).pts);
  s = await state(page);
  check('log: drawing on the real point gives its value within 1%', Math.abs(+s.texts[0] - 3000) < 30, s.texts);

  // ---- reversed axis, fixed decimals, own texts, R colour name
  page = await open(browser, file('reversed'));
  await drag(page, (await points(page)).pts);
  await reveal(page);
  s = await state(page);
  check('reversed: values, digits and the custom result text', s.result === '2026: you 15, real 15', s.result);
  check('reversed: the R colour name arrives as hex', s.stroke === '#68228B', s.stroke);

  // ---- discrete x axis, Dutch texts, touch on a phone-sized screen
  page = await open(browser, file('discrete'), { viewport: { width: 400, height: 800 }, hasTouch: true, isMobile: true });
  g = await points(page);
  const cdp = await page.context().newCDPSession(page);
  const touch = (type, p) => cdp.send('Input.dispatchTouchEvent', { type, touchPoints: p ? [{ x: p.x, y: p.y }] : [] });
  await touch('touchStart', g.pts[0]);
  await touch('touchMove', g.pts[1]);
  await touch('touchEnd');
  s = await state(page);
  check('discrete: touch draws, texts are Dutch', s.dots === 2 && s.revealText === 'Toon de echte cijfers', s);
  await page.tap('.ydi-reveal');
  await page.waitForTimeout(1500);
  s = await state(page);
  check('discrete: category label in the result', s.result === 'Voor Q4 tekende je 160. In werkelijkheid is dat 160.', s.result);
  check('discrete: no sideways scroll on a phone',
    await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth));

  // ---- Shiny: the guesses come back as a data frame, a re-render starts clean
  if (process.argv.includes('--shiny')) {
    page = await open(browser, 'http://127.0.0.1:4750/');
    const table = async () => (await page.textContent('#guess')).replace(/\s+/g, ' ').trim();
    g = await points(page);
    await drag(page, g.pts.slice(0, 2));
    await page.waitForTimeout(700);
    check('shiny: a partial line arrives with NA for the rest', /2026 NA 15\.00 FALSE$/.test(await table()), await table());
    await drag(page, g.pts);
    await reveal(page);
    await page.waitForTimeout(700);
    check('shiny: the full line and the reveal arrive', /2026 15\.00 15\.00 TRUE$/.test(await table()), await table());
    await page.click('#again');
    await page.waitForTimeout(1500);
    s = await state(page);
    check('shiny: a re-render starts clean, with one set of controls',
      s.dots === 0 && s.clip[0] === 0 && (await page.locator('.ydi-controls').count()) === 1, s);
    check('shiny: no browser errors', page.errors.length === 0, page.errors);
  }

  await browser.close();
  console.log(failures ? `\n${failures} check(s) failed` : '\nall checks passed');
  process.exit(failures ? 1 : 0);
})().catch(error => { console.error(error); process.exit(1); });
