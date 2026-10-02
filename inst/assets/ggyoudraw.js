/* ggyoudraw: the 'you draw it' interaction on a ggiraph SVG.
 *
 * geom_you_draw_line() tags its SVG elements with `ydi` attributes (see
 * R/geom-you-draw-line.R). This script finds them, hides the part of the line
 * the reader has to draw, lets the reader drag to draw it, and reveals the
 * real line on request.
 *
 * you_draw_it() calls window.ggyoudraw(el, settings) after girafe has rendered:
 *   el        the widget's element
 *   settings  { unit, digits, decimal_mark, auto_reveal, controls, labels }
 */
window.ggyoudraw = function (el, settings) {
  const svg = el.querySelector('svg');
  const zones = svg ? Array.from(svg.querySelectorAll('[ydi="zone"]')) : [];
  if (!zones.length) return;

  const NS = 'http://www.w3.org/2000/svg';
  const MINUS = String.fromCharCode(8722);
  const L = settings.labels;
  const root = svg.querySelector('.ggiraph-svg-rootg') || svg;
  const defs = svg.querySelector('defs') || svg.insertBefore(document.createElementNS(NS, 'defs'), svg.firstChild);
  const viewWidth = svg.viewBox.baseVal.width;
  let phase = 'draw';                            // 'draw' -> 'revealing' -> 'revealed'

  // take the typeface, size and colour of the text in the plot
  const axisText = svg.querySelector('text');
  const font = (axisText && axisText.getAttribute('font-family')) || 'sans-serif';
  const fontSize = (axisText && parseFloat(axisText.getAttribute('font-size'))) || 6.6;
  const ink = (axisText && axisText.getAttribute('fill')) || '#4d4d4d';
  const lineHeight = fontSize * 1.33;            // text height in SVG units

  const make = (name, attrs, parent) => {
    const node = document.createElementNS(NS, name);
    Object.keys(attrs).forEach(key => node.setAttribute(key, attrs[key]));
    if (parent) parent.appendChild(node);
    return node;
  };
  const num = (node, attr) => parseFloat(node.getAttribute(attr));
  const decimals = v => {
    const s = String(v), i = s.indexOf('.');
    return i < 0 ? 0 : Math.min(4, s.length - i - 1);
  };
  const fmt = (v, digits) => (v < 0 ? MINUS : '') +
    String(+Math.abs(v).toFixed(digits)).replace('.', settings.decimal_mark) + settings.unit;

  /* ---------- per panel ---------- */

  const panels = zones.map((zone, k) => {
    const id = zone.getAttribute('ydi_panel');
    const within = role => Array.from(svg.querySelectorAll(`[ydi="${role}"][ydi_panel="${id}"]`));
    // px, py: position in the SVG. gy, guess: the height and value the reader drew.
    const point = c => ({ px: num(c, 'cx'), py: num(c, 'cy'), label: c.getAttribute('ydi_x'),
      value: +c.getAttribute('ydi_y'), gy: null, guess: null });

    const top = num(zone, 'y'), height = num(zone, 'height'), right = num(zone, 'x') + num(zone, 'width');
    const lut = zone.getAttribute('ydi_lut').split(' ').map(Number);   // value per height, bottom -> top
    const colour = zone.getAttribute('ydi_colour');
    const line = within('truth')[0], dots = within('hidden');
    const anchor = point(within('anchor')[0]), pts = dots.map(point);
    const last = pts.length - 1;

    // decimals: what the reader draws follows the range of the axis,
    // the real values show the decimals they have
    const span = Math.abs(lut[lut.length - 1] - lut[0]);
    const auto = Math.max(0, Math.min(4, Math.ceil(-Math.log10(span / 100))));
    const dGuess = settings.digits != null ? settings.digits : auto;
    const dTruth = settings.digits != null ? settings.digits : Math.max(auto, ...pts.map(p => decimals(p.value)));

    const valueAt = py => {
      const t = (top + height - py) / height * (lut.length - 1);
      const i = Math.max(0, Math.min(lut.length - 2, Math.floor(t)));
      return lut[i] + (t - i) * (lut[i + 1] - lut[i]);
    };

    // the real line and its points go behind a clip path that slides open on reveal
    const clipId = `${svg.id}_ydi_${k}`;
    const clip = make('rect', { x: anchor.px, y: top, width: 0, height: height },
      make('clipPath', { id: clipId }, defs));
    const truth = make('g', { 'clip-path': `url(#${clipId})` });
    line.parentNode.insertBefore(truth, line);
    [line].concat(dots).forEach(node => truth.appendChild(node));

    // the reader's line, in the same panel as the real line
    const layer = make('g', { 'pointer-events': 'none' }, truth.parentNode);
    const path = make('path', { fill: 'none', stroke: colour, 'stroke-dasharray': '5 4', 'stroke-linejoin': 'round',
      'stroke-width': line.getAttribute('stroke-width') }, layer);
    const guessDots = pts.map(p => make('circle', { cx: p.px, r: dots[0].getAttribute('r'), fill: colour,
      stroke: colour, 'stroke-width': dots[0].getAttribute('stroke-width'), display: 'none' }, layer));

    // texts and the drag surface: on top of everything, outside the panel's clip
    const texts = make('g', { 'pointer-events': 'none', 'font-family': font, 'text-anchor': 'middle' }, root);
    const text = (size, attrs) =>
      make('text', Object.assign({ 'font-size': size + 'pt', display: 'none' }, attrs), texts);
    const halo = { 'font-weight': 'bold', fill: '#12161d', stroke: '#fff', 'stroke-width': 2.5,
      'stroke-opacity': 0.85, 'paint-order': 'stroke', 'stroke-linejoin': 'round' };
    const guessLabel = text(fontSize, halo), truthLabel = text(fontSize, halo);
    // the invitation sits in the half of the zone where the last known point is not
    const hint = text(fontSize * 1.25, { fill: ink, x: (anchor.px + right) / 2,
      y: anchor.py > top + height / 2 ? top + height * 0.25 : top + height * 0.78 });
    hint.textContent = L.hint;
    hint.setAttribute('display', 'inline');
    const hintFits = hint.getComputedTextLength() <= right - anchor.px - 8;

    // The drag surface covers only the drawing zone, so a phone can still be
    // scrolled elsewhere. pointer-events is set through style: ggiraph's
    // stylesheet turns it off for elements without an id.
    const x0 = (anchor.px + pts[0].px) / 2;
    const overlay = make('rect', { x: x0, y: top, width: right - x0, height: height,
      fill: 'transparent', style: 'pointer-events:all;touch-action:none' }, root);

    let active = null, prev = null, dragging = false;

    const place = (label, p, py, textValue, above) => {
      label.textContent = textValue;
      label.setAttribute('display', 'inline');
      const half = label.getComputedTextLength() / 2;
      label.setAttribute('x', Math.max(half + 2, Math.min(viewWidth - half - 2, p.px)));
      label.setAttribute('y', above ? py - 7 : py + 7 + lineHeight);
    };

    const paint = () => {
      // the reader's line starts at the last known point and stops where nothing is drawn yet
      let d = '', open = false;
      [{ px: anchor.px, gy: anchor.py }].concat(pts).forEach(p => {
        if (p.gy == null) { open = false; return; }
        d += (open ? 'L' : 'M') + p.px + ',' + p.gy;
        open = true;
      });
      path.setAttribute('d', d);
      pts.forEach((p, i) => {
        guessDots[i].setAttribute('display', p.gy == null ? 'none' : 'inline');
        if (p.gy != null) guessDots[i].setAttribute('cy', p.gy);
      });

      // show the value at the point under the pointer, otherwise at the last point
      const p = pts[active != null ? active : last];
      const mine = p.gy != null, real = phase === 'revealed';
      guessLabel.setAttribute('display', 'none');
      truthLabel.setAttribute('display', 'none');
      if (mine) place(guessLabel, p, p.gy, fmt(p.guess, dGuess), real ? p.gy <= p.py : p.gy - top > 18);
      if (real) place(truthLabel, p, p.py, fmt(p.value, dTruth), mine ? p.py < p.gy : p.py - top > 18);
      // keep the labels inside the picture and off each other
      [guessLabel, truthLabel].filter(t => t.getAttribute('display') !== 'none')
        .sort((a, b) => a.getAttribute('y') - b.getAttribute('y'))
        .forEach((t, i, shown) => t.setAttribute('y', Math.max(+t.getAttribute('y'),
          i ? +shown[i - 1].getAttribute('y') + lineHeight + 1 : lineHeight + 2)));

      const started = pts.some(q => q.gy != null);
      hint.setAttribute('display', hintFits && !started && phase === 'draw' ? 'inline' : 'none');
      overlay.style.cursor = phase === 'draw' ? 'crosshair' : 'default';
    };

    const local = e => {
      const pt = svg.createSVGPoint();
      pt.x = e.clientX; pt.y = e.clientY;
      return pt.matrixTransform(overlay.getScreenCTM().inverse());
    };
    const nearest = x =>
      pts.reduce((best, p, i) => Math.abs(p.px - x) < Math.abs(pts[best].px - x) ? i : best, 0);

    // Drawing: the nearest point takes the height of the pointer.
    const draw = e => {
      const at = local(e);
      const cur = { i: nearest(at.x), py: Math.max(top, Math.min(top + height, at.y)) };
      // Also fill the points between the previous and the current position,
      // so a fast stroke leaves no gaps.
      const from = prev && prev.i !== cur.i ? prev : null;
      pts.forEach((p, i) => {
        const t = from ? (p.px - pts[from.i].px) / (pts[cur.i].px - pts[from.i].px) : +(i === cur.i);
        if (t > 0 && t <= 1) {
          p.gy = from ? from.py + t * (cur.py - from.py) : cur.py;
          p.guess = +valueAt(p.gy).toFixed(dGuess);
        }
      });
      prev = cur; active = cur.i;
      update();
    };
    const stop = () => {
      if (!dragging) return;
      dragging = false;
      send();
      if (settings.auto_reveal) autoReveal();
    };

    overlay.addEventListener('pointerdown', e => {
      if (phase !== 'draw' || e.button) return;
      e.preventDefault();
      overlay.setPointerCapture(e.pointerId);
      dragging = true; prev = null;
      draw(e);
    });
    overlay.addEventListener('pointermove', e => {
      if (dragging) draw(e);
      else { active = nearest(local(e).x); paint(); }
    });
    overlay.addEventListener('pointerup', stop);
    overlay.addEventListener('pointercancel', stop);
    overlay.addEventListener('pointerleave', () => { if (!dragging) { active = null; paint(); } });

    return {
      id: id, pts: pts, paint: paint, dGuess: dGuess, dTruth: dTruth,
      open: share => clip.setAttribute('width', share * (right - anchor.px)),
      clear: () => {
        pts.forEach(p => { p.gy = null; p.guess = null; });
        active = null;
        clip.setAttribute('width', 0);
      }
    };
  });

  /* ---------- buttons and result, under or above the chart ---------- */

  el.querySelectorAll('.ydi-controls').forEach(node => node.remove());   // on a re-render in Shiny
  const bar = document.createElement('div');
  bar.className = 'ydi-controls';
  bar.innerHTML = '<button type="button" class="ydi-reveal"></button>' +
    '<button type="button" class="ydi-reset"></button>' +
    '<span class="ydi-help"></span><p class="ydi-result" aria-live="polite"></p>';
  if (settings.controls === 'top') {
    bar.classList.add('ydi-top');
    el.insertBefore(bar, el.firstChild);
  } else {
    el.appendChild(bar);
  }
  const reveal = bar.children[0], reset = bar.children[1], help = bar.children[2], result = bar.children[3];
  reveal.textContent = L.reveal;
  reset.textContent = L.reset;

  const complete = () => panels.every(P => P.pts.every(p => p.gy != null));

  function update() {
    const done = complete();
    panels.forEach(P => P.paint());
    // the button draws attention to itself the moment it can be used
    const ready = done && phase === 'draw' && reveal.disabled;
    reveal.hidden = phase === 'revealed' || settings.auto_reveal;
    reveal.disabled = !done || phase !== 'draw';
    if (ready && !reveal.hidden) {
      reveal.classList.remove('ydi-ready');
      void reveal.offsetWidth;                   // restart the animation
      reveal.classList.add('ydi-ready');
    }
    if (reveal.disabled) reveal.classList.remove('ydi-ready');
    reset.hidden = phase !== 'revealed';
    help.hidden = phase !== 'draw' || (settings.auto_reveal && done);
    help.textContent = done ? L.adjust : L.todo;
    // The sentence under the chart is about the last point. With several
    // panels the labels in the chart show the values instead.
    result.hidden = phase !== 'revealed' || panels.length > 1;
    if (!result.hidden) {
      const P = panels[0], p = P.pts[P.pts.length - 1];
      result.textContent = L.result.replace('{x}', p.label)
        .replace('{guess}', fmt(p.guess, P.dGuess)).replace('{truth}', fmt(p.value, P.dTruth));
    }
  }

  // Shiny: what the reader drew comes back as input$<outputId>_guess
  function send() {
    if (!window.Shiny || !Shiny.setInputValue || !el.id) return;
    const rows = [].concat(...panels.map(P => P.pts.map(p => ({ panel: P.id, point: p }))));
    Shiny.setInputValue(el.id + '_guess:ggyoudraw.guess', {
      panel: rows.map(r => r.panel),
      x: rows.map(r => r.point.label),
      guess: rows.map(r => r.point.guess),
      truth: rows.map(r => r.point.value),
      revealed: phase === 'revealed'
    }, { priority: 'event' });
  }

  // With auto_reveal: once the last stroke completes the line, wait a moment
  // so the reader sees their line, then reveal.
  let pending = null;
  function autoReveal() {
    if (phase !== 'draw' || !complete() || pending) return;
    pending = setTimeout(() => {
      pending = null;
      if (phase === 'draw' && complete()) start();
    }, 300);
  }

  function start() {
    const ms = matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : 1200;
    const start = performance.now();
    phase = 'revealing';
    update();
    const step = now => {
      const t = ms ? Math.min(1, (now - start) / ms) : 1;
      const eased = t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2;
      panels.forEach(P => P.open(eased));
      if (t < 1) return requestAnimationFrame(step);
      phase = 'revealed';
      update();
      send();
    };
    requestAnimationFrame(step);
  }
  reveal.addEventListener('click', start);
  reset.addEventListener('click', () => {
    panels.forEach(P => P.clear());
    phase = 'draw';
    update();
    send();
  });

  update();
};
