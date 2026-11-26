/* Pixel pond: a palette-indexed scene drawn on a 45° diamond lattice.
 *
 * Every cell is one "pixel", a small diamond. Neighbouring cells of one colour merge; wherever
 * two colours meet, a thin ink line runs along the boundary, like a text-mode grid tilted 45°.
 * The still scene is sampled from a Blender render, pushed through hue ramps with horizontal
 * brush-streak noise and ordered dithering; koi, their shadows, ripples and glints are drawn
 * into the same lattice every frame.
 */
(function (root) {
  'use strict';

  // ---------------------------------------------------------------- palette
  const PALETTE = [
    ['ink', '#151a0b'],
    ['moss', '#302e12'],
    ['navy', '#183244'],
    ['cobalt', '#2b5c82'],
    ['steel', '#4a84b0'],
    ['pale', '#8fb6c9'],
    ['white', '#eff1e6'],
    ['sage', '#566a4c'],
    ['dgreen', '#2c4808'],
    ['olive', '#506e0c'],
    ['lime', '#8ca416'],
    ['cream', '#f0e3c3'],
    ['beige', '#c8a46c'],
    ['orange', '#e07b2c'],
    ['red', '#bb3b23'],
    ['pink', '#e6a0b5'],
    ['void', '#000000'], // not part of the art: the island's own black, for fades
  ];
  // Night: the same entries, sunk toward black so the pond reads as part of a black island and
  // only the koi and flowers keep their light.
  const NIGHT = {
    ink: '#030402', moss: '#151409', navy: '#091621', cobalt: '#112b42', steel: '#1f4a6a', pale: '#4e7c98',
    white: '#d9e2db', sage: '#1f291e', dgreen: '#0f1c04', olive: '#203007', lime: '#43560f',
    cream: '#ecdfbf', beige: '#b8955f', orange: '#df7a2b', red: '#bb3a21', pink: '#c98ba0', void: '#000000',
  };
  const C = {};
  PALETTE.forEach(([n], i) => { C[n] = i; });
  const RGB = PALETTE.map(([, h]) => [1, 3, 5].map((o) => parseInt(h.slice(o, o + 2), 16)));
  const pack = ([r, g, b]) => ((255 << 24) | (b << 16) | (g << 8) | r) >>> 0;
  const mix = (p, q, t) => p.map((v, i) => Math.round(v + (q[i] - v) * t));

  // Hue ramps: the entries a material steps through from dark to light, and the tone each sits at.
  const RAMP = {
    water: { idx: [C.ink, C.navy, C.cobalt, C.steel, C.pale, C.white], at: [0.02, 0.2, 0.43, 0.67, 0.88, 1.0] },
    pad: { idx: [C.ink, C.dgreen, C.olive, C.lime], at: [0.0, 0.3, 0.62, 0.95] },
    pink: { idx: [C.red, C.pink, C.white], at: [0.05, 0.5, 0.97] },
    white: { idx: [C.sage, C.pale, C.white], at: [0.1, 0.5, 0.92] },
    gold: { idx: [C.orange, C.beige, C.cream], at: [0.15, 0.55, 0.95] },
  };
  const M = { water: 0, pad: 1, pink: 2, white: 3, gold: 4 };
  const MRAMP = [RAMP.water, RAMP.pad, RAMP.pink, RAMP.white, RAMP.gold];

  // Ordered dithering, 4x4 Bayer, indexed in the lattice's own (a, b) coordinates, so the pattern
  // follows the diamonds.
  const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map((v) => (v + 0.5) / 16);

  // `sharp` > 1 keeps each band's core solid and dithers only near the edges between bands.
  function rampPick(r, t, thr, sharp) {
    const at = r.at, n = at.length;
    if (t <= at[0]) return r.idx[0];
    if (t >= at[n - 1]) return r.idx[n - 1];
    let i = 0;
    while (t > at[i + 1]) i++;
    const f = ((t - at[i]) / (at[i + 1] - at[i]) - 0.5) * sharp + 0.5;
    return f > thr ? r.idx[i + 1] : r.idx[i];
  }

  // ---------------------------------------------------------------- noise
  function hash(x, y, s) {
    let h = Math.imul(x | 0, 0x27d4eb2d) ^ Math.imul(y | 0, 0x165667b1) ^ Math.imul(s | 0, 0x9e3779b1);
    h = Math.imul(h ^ (h >>> 15), 0x85ebca6b);
    h = Math.imul(h ^ (h >>> 13), 0xc2b2ae35);
    return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
  }
  function vnoise(x, y, s) {
    const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
    const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
    const a = hash(xi, yi, s), b = hash(xi + 1, yi, s), c = hash(xi, yi + 1, s), d = hash(xi + 1, yi + 1, s);
    return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
  }
  const fbm = (x, y, s) => 0.62 * vnoise(x, y, s) + 0.38 * vnoise(x * 2.13 + 5.3, y * 2.07 + 1.7, s + 1);
  const clamp = (v, lo, hi) => (v < lo ? lo : v > hi ? hi : v);

  // ---------------------------------------------------------------- pixel font
  // 5 x 8, lowercase; rows 2-6 are the x-height, row 7 the descender.
  const FONT = {
    a: ['', '', ' ### ', '    #', ' ####', '#   #', ' ####', ''],
    b: ['#', '#', '#### ', '#   #', '#   #', '#   #', '#### ', ''],
    c: ['', '', ' ####', '#', '#', '#', ' ####', ''],
    d: ['    #', '    #', ' ####', '#   #', '#   #', '#   #', ' ####', ''],
    e: ['', '', ' ### ', '#   #', '#####', '#', ' ####', ''],
    f: ['  ## ', ' #', '#### ', ' #', ' #', ' #', ' #', ''],
    g: ['', '', ' ####', '#   #', '#   #', ' ####', '    #', ' ### '],
    h: ['#', '#', '#### ', '#   #', '#   #', '#   #', '#   #', ''],
    i: ['  #', '', ' ##', '  #', '  #', '  #', ' ###', ''],
    j: ['   #', '', '  ##', '   #', '   #', '   #', '#  #', ' ## '],
    k: ['#', '#', '#  #', '# #', '##', '# #', '#  #', ''],
    l: [' ##', '  #', '  #', '  #', '  #', '  #', ' ###', ''],
    m: ['', '', '## # ', '# # #', '# # #', '# # #', '#   #', ''],
    n: ['', '', '#### ', '#   #', '#   #', '#   #', '#   #', ''],
    o: ['', '', ' ### ', '#   #', '#   #', '#   #', ' ### ', ''],
    p: ['', '', '#### ', '#   #', '#   #', '#### ', '#', '#'],
    q: ['', '', ' ####', '#   #', '#   #', ' ####', '    #', '    #'],
    r: ['', '', '# ## ', '##  #', '#', '#', '#', ''],
    s: ['', '', ' ####', '#', ' ### ', '    #', '#### ', ''],
    t: [' #', ' #', '#### ', ' #', ' #', ' #  #', '  ## ', ''],
    u: ['', '', '#   #', '#   #', '#   #', '#   #', ' ####', ''],
    v: ['', '', '#   #', '#   #', '#   #', ' # # ', '  #', ''],
    w: ['', '', '#   #', '#   #', '# # #', '# # #', ' # # ', ''],
    x: ['', '', '#   #', ' # # ', '  #', ' # # ', '#   #', ''],
    y: ['', '', '#   #', '#   #', '#   #', ' ####', '    #', ' ### '],
    z: ['', '', '#####', '   #', '  #', ' #', '#####', ''],
    '.': ['', '', '', '', '', '', '  #', ''],
    ',': ['', '', '', '', '', '  #', '  #', ' #'],
    '?': [' ### ', '#   #', '    #', '   #', '  #', '', '  #', ''],
    "'": ['  #', '  #', '', '', '', '', '', ''],
    '-': ['', '', '', '', '#####', '', '', ''],
    '!': ['  #', '  #', '  #', '  #', '  #', '', '  #', ''],
    ' ': ['', '', '', '', '', '', '', ''],
  };

  // ---------------------------------------------------------------- assets
  const Assets = { ready: null };

  function pixels(im, w, h) {
    const c = document.createElement('canvas');
    c.width = w || im.naturalWidth;
    c.height = h || im.naturalHeight;
    const g = c.getContext('2d');
    g.imageSmoothingQuality = 'high';
    g.drawImage(im, 0, 0, c.width, c.height);
    return g.getImageData(0, 0, c.width, c.height).data;
  }

  function load(base) {
    const img = (n) => new Promise((res, rej) => {
      const i = new Image();
      i.onload = () => res(i);
      i.onerror = () => rej(new Error('missing ' + n));
      i.src = base + n;
    });
    Assets.ready = Promise.all([
      img('plate_flora.png'), img('plate_water.png'), img('render.png'),
      img('koi_kohaku.png'), img('koi_showa.png'), img('koi_beni.png'), img('koi_body.png'),
      fetch(base + 'meta.json').then((r) => r.json()),
    ]).then(([flora, water, render, kohaku, showa, beni, body, meta]) => {
      // The water's own light range, so tones are measured against the water, not the pads.
      const wp = pixels(water, 260, 104), lums = [];
      for (let i = 0; i < wp.length; i += 4) lums.push((0.3 * wp[i] + 0.59 * wp[i + 1] + 0.11 * wp[i + 2]) / 255);
      lums.sort((p, q) => p - q);
      const k = meta.koi;
      Object.assign(Assets, {
        flora, water, render,
        waterLo: lums[Math.floor(lums.length * 0.03)], waterHi: lums[Math.floor(lums.length * 0.97)],
        koi: { levels: koiLevels(k, { kohaku, showa, beni }, body) },
      });
      return Assets;
    });
    return Assets.ready;
  }

  // Koi as flat colour regions, the way a pixel artist would draw them: every pixel of a cut-out
  // is read as one of 1 fin, 2 cream, 3 red, 4 orange, 5 black (0 nothing). Shrinking then takes
  // the majority in each block rather than an average, so patches stay pure instead of mixing
  // into beige.
  const KOI_RULE = {
    kohaku: (lum, sat) => (lum < 60 ? 5 : sat < 0.3 ? 2 : 3),
    showa: (lum, sat) => (lum < 85 ? 5 : sat < 0.3 ? 2 : 3),
    beni: (lum, sat) => (sat < 0.25 ? 2 : lum < 105 ? 3 : 4),
  };
  const KOI_WEIGHT = [0, 1, 1, 1.25, 1, 1.5]; // small red and black spots survive shrinking

  // The koi at 256, 128, 64 and 32 px long; each fish samples the size that puts a few sprite
  // pixels in each cell, so small koi don't alias into noise.
  function koiLevels(meta, imgs, bodyImg) {
    const W = meta.width, H = meta.height, n = W * H;
    const bodyPx = pixels(bodyImg), alphaPx = pixels(imgs.kohaku);
    const alpha = new Float32Array(n), body = new Float32Array(n), full = {};
    for (let i = 0; i < n; i++) { alpha[i] = alphaPx[i * 4 + 3] / 255; body[i] = bodyPx[i * 4] / 255; }
    for (const kind in KOI_RULE) {
      const px = pixels(imgs[kind]), cls = new Uint8Array(n);
      for (let i = 0; i < n; i++) {
        const r = px[i * 4], g = px[i * 4 + 1], b = px[i * 4 + 2];
        if (px[i * 4 + 3] < 128) continue;
        if (bodyPx[i * 4] < 128) { cls[i] = 1; continue; }
        const mx = Math.max(r, g, b), mn = Math.min(r, g, b);
        cls[i] = KOI_RULE[kind](0.3 * r + 0.59 * g + 0.11 * b, mx ? (mx - mn) / mx : 0);
      }
      full[kind] = cls;
    }
    const levels = [];
    for (let f = 1; f <= 8; f *= 2) {
      const w = Math.floor(W / f), h = Math.floor(H / f);
      const lv = { w, h, axis: (H / f) / 2, alpha: new Float32Array(w * h), body: new Float32Array(w * h), kinds: {} };
      for (const kind in full) lv.kinds[kind] = new Uint8Array(w * h);
      const cnt = new Float32Array(6);
      for (let y = 0; y < h; y++) {
        for (let x = 0; x < w; x++) {
          const j = y * w + x;
          let a = 0, bo = 0;
          for (let yy = 0; yy < f; yy++) for (let xx = 0; xx < f; xx++) { const i = (y * f + yy) * W + x * f + xx; a += alpha[i]; bo += body[i]; }
          lv.alpha[j] = a / (f * f);
          lv.body[j] = bo / (f * f);
          for (const kind in full) {
            cnt.fill(0);
            const cl = full[kind];
            for (let yy = 0; yy < f; yy++) for (let xx = 0; xx < f; xx++) cnt[cl[(y * f + yy) * W + x * f + xx]] += 1;
            let best = 0, bn = 0;
            for (let c = 1; c < 6; c++) if (cnt[c] * KOI_WEIGHT[c] > bn) { bn = cnt[c] * KOI_WEIGHT[c]; best = c; }
            lv.kinds[kind][j] = best;
          }
        }
      }
      levels.push(lv);
    }
    return levels;
  }

  // ---------------------------------------------------------------- the pond
  const DEFAULTS = {
    width: 800, height: 320,      // canvas, pt
    scene: null,                  // [w, h] of the whole pond, pt (defaults to the canvas)
    view: [0, 0],                 // the scene point at the canvas's top-left, pt
    crop: null,                   // part of the plates [x, y, w, h] (0..1) that fills the scene
    dpr: root.devicePixelRatio || 1,
    cell: 7,                      // diamond width, pt
    line: 1,                      // ink line width, pt
    outline: true,
    streak: 1,                    // brush-streak strength
    glitch: 1,                    // row-segment jitter when sampling the render
    sharp: 2.6,                   // band sharpness: 1 dithers everywhere, higher flattens bands
    smear: 1.4,                   // horizontal brush smear of the render, in cells
    despeckle: 0.7,               // chance a lone cell takes its neighbours' colour
    fat: 1.55,                    // koi drawn this much wider than the render: pixel proportions
    shimmer: 1,
    flat: false,                  // plain water instead of the render (sprite sheets)
    night: false,                 // the dark palette
    toneShift: 0,                 // added to every water tone (night uses about -0.12)
    fade: null,                   // [y0, y1] canvas pt: black above y0, dissolving to the pond by y1
    koi: [],                      // { kind, len, x, y, heading, speed, fixed, phase, depth }
    bounds: null,                 // where koi swim: [x0, y0, x1, y1] in scene pt
    ripples: true,
    glints: true,
    blossoms: true,
    text: null,                   // { lines, x, y, px, gap }
    fps: 12,
    seed: 7,
    animate: true,
  };

  class Pond {
    constructor(canvas, opts) {
      this.canvas = canvas;
      this.ctx = canvas.getContext('2d');
      this.o = Object.assign({}, DEFAULTS, opts);
      if (!this.o.scene) this.o.scene = [this.o.width, this.o.height];
      this.time = 0;
      this.ripples = [];
      this.glints = [];
      this._lattice();
      this._still();
      this.koi = this.o.koi.map((k, i) => this._koi(k, i));
    }

    // ---- lattice: a = floor((X + Y) / d), b = floor((X - Y) / d), X and Y in device px
    _lattice() {
      const o = this.o, dpr = o.dpr;
      const pw = Math.round(o.width * dpr), ph = Math.round(o.height * dpr);
      this.canvas.width = pw;
      this.canvas.height = ph;
      this.canvas.style.width = o.width + 'px';
      this.canvas.style.height = o.height + 'px';
      const d = o.cell * dpr;
      this.d = d;
      const aMin = -1, aMax = Math.floor((pw + ph) / d) + 1;
      const bMin = Math.floor(-ph / d) - 1, bMax = Math.floor(pw / d) + 1;
      const A = aMax - aMin + 1, B = bMax - bMin + 1, N = A * B;
      Object.assign(this, { pw, ph, aMin, aMax, bMin, bMax, A, B, N });
      this.cx = new Float32Array(N); // centres, canvas pt
      this.cy = new Float32Array(N);
      this.ca = new Int32Array(N);
      this.cb = new Int32Array(N);
      this.live = new Uint8Array(N);
      for (let a = aMin; a <= aMax; a++) {
        for (let b = bMin; b <= bMax; b++) {
          const i = (a - aMin) * B + (b - bMin);
          const X = ((a + b + 1) * d) / 2, Y = ((a - b) * d) / 2;
          this.cx[i] = X / dpr;
          this.cy[i] = Y / dpr;
          this.ca[i] = a;
          this.cb[i] = b;
          this.live[i] = X > -d && X < pw + d && Y > -d && Y < ph + d && a > aMin && a < aMax && b > bMin && b < bMax ? 1 : 0;
        }
      }
      // Per device pixel: its cell, and the neighbour across each nearby edge (-1 if not near one).
      const np = pw * ph, inv = 1 / d;
      this.cellOf = new Int32Array(np);
      this.nbA = new Int32Array(np);
      this.nbB = new Int32Array(np);
      const tf = o.outline ? ((o.line * dpr) / 2) * Math.SQRT2 * inv : -1;
      for (let y = 0, p = 0; y < ph; y++) {
        for (let x = 0; x < pw; x++, p++) {
          const sa = (x + y + 1) * inv, sb = (x - y) * inv;
          const a = Math.floor(sa), b = Math.floor(sb), fa = sa - a, fb = sb - b;
          const c = (a - aMin) * B + (b - bMin);
          this.cellOf[p] = c;
          this.nbA[p] = fa < tf ? c - B : fa > 1 - tf ? c + B : -1;
          this.nbB[p] = fb < tf ? c - 1 : fb > 1 - tf ? c + 1 : -1;
        }
      }
      this.idx = new Uint8Array(N);
      this.tone = new Float32Array(N);
      this.img = this.ctx.createImageData(pw, ph);
      this.out = new Uint32Array(this.img.data.buffer);
      const rgb = this.o.night ? PALETTE.map(([n]) => [1, 3, 5].map((q) => parseInt(NIGHT[n].slice(q, q + 2), 16))) : RGB;
      this.COL = rgb.map(pack);
      this.LINE = rgb.map((c) => pack(mix(c, this.o.night ? [0, 0, 0] : RGB[C.ink], 0.8)));
    }

    // ---- the still scene: material, tone and colour of every cell
    _plateSampler(img) {
      const o = this.o, q = o.cell * 0.75; // pt per texel: a little coarser than a cell, so tone is calm
      const sw = Math.ceil(o.scene[0] / q) + 1, sh = Math.ceil(o.scene[1] / q) + 1;
      const iw = img.naturalWidth, ih = img.naturalHeight;
      let cr = o.crop;
      if (!cr) {
        const sa = o.scene[0] / o.scene[1], ia = iw / ih;
        cr = sa > ia ? [0, (1 - ia / sa) / 2, 1, ia / sa] : [(1 - sa / ia) / 2, 0, sa / ia, 1];
      }
      const c = document.createElement('canvas');
      c.width = sw;
      c.height = sh;
      const g = c.getContext('2d');
      g.imageSmoothingQuality = 'high';
      g.drawImage(img, cr[0] * iw, cr[1] * ih, cr[2] * iw, cr[3] * ih, 0, 0, o.scene[0] / q, o.scene[1] / q);
      const px = g.getImageData(0, 0, sw, sh).data;
      return (X, Y, out) => {
        const fx = clamp(X / q - 0.5, 0, sw - 1.001), fy = clamp(Y / q - 0.5, 0, sh - 1.001);
        const x0 = fx | 0, y0 = fy | 0, tx = fx - x0, ty = fy - y0;
        for (let k = 0; k < 3; k++) {
          const p00 = px[(y0 * sw + x0) * 4 + k], p10 = px[(y0 * sw + x0 + 1) * 4 + k];
          const p01 = px[((y0 + 1) * sw + x0) * 4 + k], p11 = px[((y0 + 1) * sw + x0 + 1) * 4 + k];
          out[k] = ((p00 + (p10 - p00) * tx) * (1 - ty) + (p01 + (p11 - p01) * tx) * ty) / 255;
        }
        return out;
      };
    }

    _still() {
      const o = this.o, N = this.N, cell = o.cell, s = o.seed;
      this.mat = new Uint8Array(N);
      this.base = new Float32Array(N); // water tone before shimmer
      this.earth = new Float32Array(N);
      this.still = new Uint8Array(N); // colour of pad and flower cells
      const A = Assets, lo = A.waterLo, hi = A.waterHi;
      const flora = o.flat ? null : this._plateSampler(A.flora);
      const water = o.flat ? null : this._plateSampler(A.water);
      const F = [0, 0, 0], W = [0, 0, 0], W2 = [0, 0, 0];
      for (let i = 0; i < N; i++) {
        if (!this.live[i]) continue;
        const X = this.cx[i] + o.view[0], Y = this.cy[i] + o.view[1];
        // Glitch: some half-row segments sample the render a little to the side.
        const row = Math.floor(Y / (cell / 2));
        const seg = Math.floor((X + hash(row, 0, s) * 400) / (cell * 9));
        const jit = hash(row, seg, s + 1) < 0.3 ? (hash(row, seg, s + 2) - 0.5) * cell * 3.2 * o.glitch : 0;
        const streak = o.streak * 0.36 * (fbm(X / (cell * 10), Y / (cell * 0.75), s + 3) - 0.5);
        this.earth[i] = vnoise(X / (cell * 13), Y / (cell * 2.1), s + 7);
        const thr = BAYER[((this.ca[i] & 3) << 2) | (this.cb[i] & 3)];
        if (o.flat) {
          this.mat[i] = M.water;
          this.base[i] = 0.5 + streak;
          continue;
        }
        flora(X + jit, Y, F);
        water(X + jit, Y, W);
        const diff = Math.abs(F[0] - W[0]) + Math.abs(F[1] - W[1]) + Math.abs(F[2] - W[2]);
        const mx = Math.max(F[0], F[1], F[2]), mn = Math.min(F[0], F[1], F[2]);
        const lum = 0.3 * F[0] + 0.59 * F[1] + 0.11 * F[2];
        // Where the pads shade the bed, the flora plate is darker than the bare water.
        const shade = Math.max(0, 0.3 * W[0] + 0.59 * W[1] + 0.11 * W[2] - lum);
        // Brush smear: the water's light averaged along a short horizontal run.
        if (o.smear > 0) {
          const dx = cell * o.smear;
          for (const sx of [-dx, dx]) {
            water(X + jit + sx, Y, W2);
            for (let ch = 0; ch < 3; ch++) W[ch] += W2[ch];
          }
          for (let ch = 0; ch < 3; ch++) W[ch] /= 3;
        }
        let m = M.water;
        if (diff > 0.24) {
          if (F[0] > 0.6 && F[1] > 0.42 && F[2] < 0.42 && F[0] >= F[1] * 0.95) m = M.gold;
          else if (F[0] > 0.55 && F[0] > F[1] + 0.12 && F[2] > F[1] - 0.08) m = M.pink;
          else if (mn > 0.66 && mx - mn < 0.22) m = M.white;
          else if (F[1] > F[2] + 0.04 && F[1] >= F[0] * 0.85) m = M.pad;
        }
        this.mat[i] = m;
        if (m === M.water) {
          // Bottoms out at navy and moss: the shade under a pad is deep, not a hole.
          const wl = 0.3 * W[0] + 0.59 * W[1] + 0.11 * W[2];
          const t = Math.max(-0.25, (wl - lo) / (hi - lo) - (shade * 2.4) / (hi - lo));
          this.base[i] = 0.3 + 0.58 * t + streak;
        } else {
          const t = m === M.pad ? (lum - 0.22) / 0.5 : m === M.gold ? (lum - 0.45) / 0.45 : (lum - 0.45) / 0.5;
          this.still[i] = rampPick(MRAMP[m], clamp(t + streak * 0.8, 0, 1), thr, o.sharp);
        }
      }
      // Blossoms: little five-cell flowers scattered over the pads.
      this.blossoms = [];
      if (o.blossoms) {
        const B = this.B;
        for (let i = 0; i < N; i++) {
          if (this.mat[i] !== M.pad || hash(this.ca[i], this.cb[i], s + 11) > 0.018) continue;
          const nb = [i - B, i + B, i - 1, i + 1];
          if (nb.some((j) => this.mat[j] !== M.pad)) continue;
          const kind = hash(this.ca[i], this.cb[i], s + 12);
          this.blossoms.push({ i, nb, heart: kind < 0.5 ? C.white : C.pink, petal: kind < 0.5 ? C.pink : C.white, phase: kind * 50 });
        }
      }
    }

    // ---- koi
    _koi(k, n) {
      return Object.assign({
        kind: 'kohaku', len: 120, x: this.o.scene[0] / 2, y: this.o.scene[1] / 2, heading: 0, speed: 16,
        fixed: false, phase: n * 2.1, depth: 0.3, turn: 0, bend: 0, amp: 0.07, fat: this.o.fat, seed: 31 + n * 17, t: n * 40,
      }, k);
    }

    // The sprite size for a koi this long: about three sprite pixels across each cell.
    _level(k) {
      const perCell = (256 / k.len) * this.o.cell;
      return clamp(Math.floor(Math.log2(perCell / 3)), 0, 3);
    }

    _bounds() {
      const o = this.o;
      return o.bounds || [0, 0, o.scene[0], o.scene[1]];
    }

    _stepKoi(k, dt) {
      k.t += dt;
      const [x0, y0, x1, y1] = this._bounds();
      let turn = (vnoise(k.t * 0.13, 0.5, k.seed) - 0.5) * 1.3;
      // Look ahead and steer back inside the bounds.
      const la = k.len * 0.8, ax = k.x + Math.cos(k.heading) * la, ay = k.y + Math.sin(k.heading) * la;
      const m = Math.min(k.len * 0.55, (y1 - y0) * 0.3);
      let fx = 0, fy = 0;
      if (ax < x0 + m) fx += (x0 + m - ax) / m;
      if (ax > x1 - m) fx -= (ax - (x1 - m)) / m;
      if (ay < y0 + m) fy += (y0 + m - ay) / m;
      if (ay > y1 - m) fy -= (ay - (y1 - m)) / m;
      const lure = this.lure;
      if (lure) {
        // Food on the water: every koi turns toward it; the first to reach it takes it.
        const hx = k.x + Math.cos(k.heading) * k.len * 0.45, hy = k.y + Math.sin(k.heading) * k.len * 0.45;
        let da = Math.atan2(lure.y - k.y, lure.x - k.x) - k.heading;
        da = Math.atan2(Math.sin(da), Math.cos(da));
        turn += da * 2.2;
        fx *= 0.3; fy *= 0.3;
        if (Math.hypot(lure.x - hx, lure.y - hy) < k.len * 0.18) {
          this.ripple(lure.x, lure.y, true);
          this.lure = null;
        }
      }
      if (fx || fy) {
        let da = Math.atan2(fy, fx) - k.heading;
        da = Math.atan2(Math.sin(da), Math.cos(da));
        turn += da * Math.min(1.6, Math.hypot(fx, fy)) * 1.4;
      }
      // Give the others room: turn away from any koi close ahead.
      for (const q of this.koi) {
        if (q === k) continue;
        const dx = q.x - k.x, dy = q.y - k.y, dist = Math.hypot(dx, dy), near = (k.len + q.len) * 0.55;
        if (dist > near || dist < 1e-3) continue;
        let da = Math.atan2(dy, dx) - k.heading;
        da = Math.atan2(Math.sin(da), Math.cos(da));
        if (Math.abs(da) < 1.6) turn -= Math.sign(da || 1) * (1 - dist / near) * 1.6;
      }
      turn = clamp(turn, -1.3, 1.3);
      k.turn += (turn - k.turn) * (1 - Math.exp(-dt * 2.2));
      k.heading += k.turn * dt;
      const sp = k.speed * (this.lure ? 1.9 : 0.5 + 0.75 * vnoise(k.t * 0.07, 3.3, k.seed + 9));
      k.x += Math.cos(k.heading) * sp * dt;
      k.y += Math.sin(k.heading) * sp * dt;
      k.phase += dt * (1.5 + (3.4 * sp) / k.speed);
      // The body follows the arc it turns along.
      k.bend = clamp(0.5 * (k.turn / Math.max(sp, 1)) * k.len, -0.3, 0.3);
      k.depth = 0.5 + 0.5 * Math.sin(k.t * 0.045 + k.seed);
      if (this.o.ripples && k.depth < 0.1 && Math.random() < dt * 0.25) {
        this.ripple(k.x + Math.cos(k.heading) * k.len * 0.42, k.y + Math.sin(k.heading) * k.len * 0.42, true);
      }
    }

    // What of koi `k` covers scene point (X, Y): 0 nothing, 1 body (colour in out), 2 fin (alpha in out[3]).
    _koiAt(k, X, Y, out) {
      const dx = X - k.x, dy = Y - k.y, c = Math.cos(k.heading), s = Math.sin(k.heading);
      const u = dx * c + dy * s, v = -dx * s + dy * c;
      const t = 0.5 - u / k.len;
      if (t < 0 || t > 1) return 0;
      const w = k.len * (k.amp * Math.sin(k.phase - 5.5 * t) * (0.12 + 0.88 * t * t) + k.bend * t * t);
      const S = Assets.koi.levels[k.lv], sc = S.w / k.len;
      const px = t * (S.w - 1), py = S.axis - ((v - w) * sc) / k.fat;
      if (py < 0 || py > S.h - 1) return 0;
      const x0 = Math.min(px | 0, S.w - 2), y0 = Math.min(py | 0, S.h - 2), tx = px - x0, ty = py - y0, j = y0 * S.w + x0;
      const bl = (m) => (m[j] * (1 - tx) + m[j + 1] * tx) * (1 - ty) + (m[j + S.w] * (1 - tx) + m[j + S.w + 1] * tx) * ty;
      const a = bl(S.alpha);
      if (a < 0.45) return 0;
      const body = bl(S.body);
      if (body < 0.5) { out[3] = a; return 2; }
      out[0] = S.kinds[k.kind][Math.round(py) * S.w + Math.round(px)];
      out[1] = body;
      return 1;
    }

    // A koi colour region to a palette entry. Cream turns beige at the body's rim, a pixel
    // artist's roundness; a deep fish's cream takes on the water as pale.
    _koiColour(cls, body, depth) {
      const rim = body < 0.72;
      if (cls === 5) return C.ink;
      if (cls === 3) return C.red;
      if (cls === 4) return rim ? C.red : C.orange;
      return depth > 0.75 ? C.pale : rim ? C.beige : C.cream;
    }

    // Drop food at a scene point: a ripple, and the koi come.
    feed(x, y) {
      this.ripple(x, y, false);
      this.lure = { x, y, until: this.time + 9 };
    }

    ripple(x, y, splash) {
      this.ripples.push({ x, y, t0: this.time, speed: 15 + Math.random() * 6, life: 2.4 + Math.random(), seed: (Math.random() * 1e6) | 0, splash: !!splash });
    }

    // Visit the live cells whose centres fall in a rect (canvas pt).
    _cells(x0, y0, x1, y1, fn) {
      const dpr = this.o.dpr, d = this.d;
      const X0 = x0 * dpr, Y0 = y0 * dpr, X1 = x1 * dpr, Y1 = y1 * dpr;
      const a0 = Math.max(this.aMin + 1, Math.floor((X0 + Y0) / d) - 1), a1 = Math.min(this.aMax - 1, Math.ceil((X1 + Y1) / d));
      const b0 = Math.max(this.bMin + 1, Math.floor((X0 - Y1) / d) - 1), b1 = Math.min(this.bMax - 1, Math.ceil((X1 - Y0) / d));
      for (let a = a0; a <= a1; a++) {
        for (let b = b0; b <= b1; b++) {
          const i = (a - this.aMin) * this.B + (b - this.bMin);
          if (!this.live[i]) continue;
          const x = this.cx[i], y = this.cy[i];
          if (x >= x0 && x <= x1 && y >= y0 && y <= y1) fn(i, x, y);
        }
      }
    }

    update(dt) {
      this.time += dt;
      for (const k of this.koi) {
        if (k.drive) k.drive(k, dt, this);
        else if (!k.fixed) this._stepKoi(k, dt);
      }
      if (this.lure && this.time > this.lure.until) this.lure = null;
      const o = this.o;
      if (o.ripples && Math.random() < dt / 7) {
        const [x0, y0, x1, y1] = this._bounds();
        this.ripple(x0 + Math.random() * (x1 - x0), y0 + Math.random() * (y1 - y0), false);
      }
      this.ripples = this.ripples.filter((r) => this.time - r.t0 < r.life);
    }

    // ---- one frame of colour indices
    _frame() {
      const o = this.o, N = this.N, t = this.time, cell = o.cell, s = o.seed;
      const idx = this.idx, tone = this.tone, mat = this.mat, live = this.live, vx = o.view[0], vy = o.view[1];
      const sh = o.animate ? o.shimmer : 0;
      for (let i = 0; i < N; i++) {
        if (!live[i] || mat[i] !== M.water) continue;
        const X = this.cx[i] + vx, Y = this.cy[i] + vy;
        tone[i] = this.base[i] + o.toneShift + sh * (0.1 * (vnoise(X / (cell * 6) - t * 0.35, Y / (cell * 1.1), s + 21) - 0.5) +
          0.07 * (vnoise(X / (cell * 3) + t * 0.22, Y / (cell * 0.8) + t * 0.05, s + 22) - 0.5));
      }
      const white = new Set(), fins = new Map();
      const tmp = [0, 0, 0, 0];
      const koi = this.koi.slice().sort((p, q) => q.depth - p.depth);
      // Shadows on the bed, and fins as lighter, translucent water.
      for (const k of koi) {
        if (k.lv == null) k.lv = this._level(k);
        const off = 1.1 - 0.7 * k.depth, ox = Math.max(k.len * 0.09, cell * 0.8) * off, oy = Math.max(k.len * 0.16, cell * 1.6) * off, r = k.len * 0.62;
        this._cells(k.x - vx - r + ox, k.y - vy - r + oy, k.x - vx + r + ox, k.y - vy + r + oy, (i, x, y) => {
          if (mat[i] !== M.water) return;
          if (this._koiAt(k, x + vx - ox, y + vy - oy, tmp) === 1 && hash(this.ca[i], this.cb[i], 99) > 0.12) tone[i] -= 0.3;
        });
        this._cells(k.x - vx - r, k.y - vy - r, k.x - vx + r, k.y - vy + r, (i, x, y) => {
          if (mat[i] === M.water && this._koiAt(k, x + vx, y + vy, tmp) === 2) fins.set(i, Math.max(fins.get(i) || 0, tmp[3]));
        });
      }
      // Ripples: broken rings of lighter water; a splash of white where a koi broke the surface.
      for (const r of this.ripples) {
        const age = t - r.t0, R = age * r.speed, fade = 1 - age / r.life, band = cell * 0.55;
        this._cells(r.x - vx - R - cell, r.y - vy - R - cell, r.x - vx + R + cell, r.y - vy + R + cell, (i, x, y) => {
          if (mat[i] !== M.water) return;
          const dist = Math.hypot(x + vx - r.x, y + vy - r.y), e = Math.abs(dist - R);
          if (e < band && hash(this.ca[i], this.cb[i], r.seed) > 0.3) {
            tone[i] += 0.42 * fade;
            if (age < 0.6 && e < band * 0.5) white.add(i);
          }
          if (r.splash && age < 0.45 && dist < cell * 2.4 && hash(this.ca[i], this.cb[i], r.seed + ((age * 12) | 0)) > 0.62) white.add(i);
        });
      }
      // Quantize the water.
      const sharp = o.sharp;
      for (let i = 0; i < N; i++) {
        if (!live[i]) continue;
        if (mat[i] !== M.water) { idx[i] = this.still[i]; continue; }
        let k = rampPick(RAMP.water, tone[i], BAYER[((this.ca[i] & 3) << 2) | (this.cb[i] & 3)], sharp);
        const e = this.earth[i];
        if (k === C.navy && e > 0.6) k = C.moss;
        else if (k === C.cobalt && e > 0.72) k = C.sage;
        idx[i] = k;
      }
      // Despeckle: most lone cells take the colour all four of their neighbours share, so the water
      // reads as runs and bands rather than a mesh.
      if (o.despeckle > 0) {
        const B = this.B, src = this.idx2 || (this.idx2 = new Uint8Array(N));
        src.set(idx);
        for (let i = B + 1; i < N - B - 1; i++) {
          if (!live[i] || mat[i] !== M.water) continue;
          const n0 = src[i - 1];
          if (n0 !== src[i] && n0 === src[i + 1] && n0 === src[i - B] && n0 === src[i + B] &&
              hash(this.ca[i], this.cb[i], s + 41) < o.despeckle) idx[i] = n0;
        }
      }
      for (const i of white) idx[i] = C.white;
      // Fins: translucent, so dithered pale over whatever water is under them.
      for (const [i, a] of fins) if (a * 0.8 > BAYER[((this.ca[i] & 3) << 2) | (this.cb[i] & 3)]) idx[i] = C.pale;
      // Koi bodies, deepest first; pads and flowers stay on top of them.
      for (const k of koi) {
        const r = k.len * 0.62;
        this._cells(k.x - vx - r, k.y - vy - r, k.x - vx + r, k.y - vy + r, (i, x, y) => {
          if (mat[i] !== M.water) return;
          if (this._koiAt(k, x + vx, y + vy, tmp) === 1) idx[i] = this._koiColour(tmp[0], tmp[1], k.depth);
        });
      }
      // Glints: a cell of light water flashes white for a frame or two.
      if (o.glints && o.animate) {
        this.glints = this.glints.filter((g) => g.until > t);
        const n = Math.random() < 0.6 ? 1 + ((Math.random() * 2) | 0) : 0;
        for (let j = 0; j < n; j++) {
          const i = (Math.random() * N) | 0;
          if (live[i] && mat[i] === M.water && this.base[i] > 0.62) this.glints.push({ i, until: t + 0.12 + Math.random() * 0.2 });
        }
        for (const g of this.glints) if (idx[g.i] === C.pale || idx[g.i] === C.steel) idx[g.i] = C.white;
      }
      for (const bl of this.blossoms) {
        idx[bl.i] = bl.heart;
        const lit = Math.sin(t * 0.9 + bl.phase) > -0.2;
        for (const j of bl.nb) idx[j] = lit ? bl.petal : C.lime;
      }
      // Dissolve into the island's black, ordered-dithered like everything else.
      if (o.fade) {
        const [f0, f1] = o.fade;
        for (let i = 0; i < N; i++) {
          if (!live[i] || this.cy[i] >= f1) continue;
          if ((this.cy[i] - f0) / (f1 - f0) < BAYER[((this.ca[i] & 3) << 2) | (this.cb[i] & 3)]) idx[i] = C.void;
        }
      }
    }

    draw() {
      this._frame();
      const idx = this.idx, out = this.out, cellOf = this.cellOf, nbA = this.nbA, nbB = this.nbB, COL = this.COL, LINE = this.LINE;
      for (let p = 0, n = out.length; p < n; p++) {
        const k = idx[cellOf[p]];
        let q = nbA[p];
        if (q >= 0 && idx[q] !== k) { out[p] = LINE[k]; continue; }
        q = nbB[p];
        out[p] = q >= 0 && idx[q] !== k ? LINE[k] : COL[k];
      }
      this.ctx.putImageData(this.img, 0, 0);
      this._text();
    }

    _text() {
      const T = this.o.text;
      if (!T || !T.lines || !T.lines.length) return;
      const g = this.ctx, dpr = this.o.dpr, fp = Math.max(1, Math.round(T.px * dpr));
      let y = Math.round(T.y * dpr);
      const x = Math.round(T.x * dpr), padX = 3 * fp, padY = 2 * fp;
      for (const line of T.lines) {
        const w = (line.length * 6 - 1) * fp, h = 8 * fp;
        g.fillStyle = T.box || 'rgba(16, 20, 8, 0.6)';
        g.fillRect(x - padX, y - padY, w + 2 * padX, h + 2 * padY);
        g.fillStyle = T.color || '#f3f2e7';
        [...line.toLowerCase()].forEach((ch, n) => {
          const gl = FONT[ch] || FONT['?'];
          gl.forEach((row, ry) => {
            for (let rx = 0; rx < row.length; rx++) if (row[rx] === '#') g.fillRect(x + (n * 6 + rx) * fp, y + ry * fp, fp, fp);
          });
        });
        y += h + 2 * padY + Math.round((T.gap == null ? 6 : T.gap) * fp);
      }
    }

    start() {
      if (!this.o.animate) { this.draw(); return this; }
      let last = performance.now(), acc = 1;
      const loop = (now) => {
        this.raf = requestAnimationFrame(loop);
        acc += (now - last) / 1000;
        last = now;
        if (acc < 1 / this.o.fps) return;
        this.update(Math.min(acc, 0.25));
        acc = 0;
        this.draw();
      };
      this.raf = requestAnimationFrame(loop);
      return this;
    }

    stop() { cancelAnimationFrame(this.raf); }
  }


  root.Pond = Pond;
  Pond.load = load;
  Pond.assets = Assets;
  Pond.PALETTE = PALETTE;
  Pond.C = C;
})(window);
