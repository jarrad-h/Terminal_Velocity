/* Terminal Velocity ship designer: compose a hull from a kit of painted parts, mark hardpoints,
 * engine exhausts, lights and the hit capsule, and save the design file (tv-ship-design/1) that
 * Claude's art pipeline renders. Also writes hull.json (schema 1) and preview PNGs.
 *
 * Coordinates: design space is in kit units. x = 0 is the centre line, +x starboard, +y aft,
 * nose up. A part's (x, y) is its centre; rot is degrees counter-clockwise on screen; transform
 * order is flip, then scale, then rotate about the centre (as compose.py render_design does).
 * Marker conventions, drawing, hull.json output and checks come from ../shared/hull-markers.js.
 */
(() => {
'use strict';
const H = TVHull;
const $ = id => document.getElementById(id);

const FORMAT = 'tv-ship-design/1';
const STORE_KEY = 'tv-ship-designer-v1';
// Render canvas of compose.py render_design (design key "canvas" overrides): parts must fit in it.
const DEFAULT_CANVAS = [2400, 4000];
// compose.py Hull.finish(margin=24): transparent border, in kit units, around the composed sprite.
const SPRITE_MARGIN = 24;
const DEFAULT_SHADOW = 0.55;
const DEFAULT_UNITS = 12.5;
const CENTRE_EPS = 0.5;          // kit units: closer than this to x = 0 counts as on the centre line
const ALPHA_ON = 5;              // composed-alpha threshold for "visible" (compose.py uses a > 0.02)
// Categories the palette knows (a kit's manifest can add more with a "categories" list). Anything
// else is shown under "misc". Order here is palette order.
const KNOWN_CATEGORIES = [
  'nose_cap', 'nose_module', 'collar', 'hull_module', 'hull_module_t', 'small_module', 'flank', 'side_tank',
  'engine_pod', 'engine_bell', 'engine_large', 'aft_module',
  'container_white', 'container_red', 'container_grey', 'container_blue', 'container_green', 'container_yellow', 'container',
  'tank_sphere', 'tank_vertical', 'tank_horizontal', 'clamp', 'pipework', 'strut', 'brace', 'bracket', 'rail', 'robot_arm',
  'turret', 'turret_ring', 'gun', 'missile_rack', 'missile', 'armour_plate', 'sensor_mast', 'canopy', 'hatch', 'greeble'
];
const JSZIP_URL = 'https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js';

const cv = $('cv'), ctx = cv.getContext('2d');
let kit = null;          // { kit, version, units, label, parts: Map(id -> def), cats: [[name, [ids]]] }
let dims = {};           // part id -> { w, h, category, mirror_of, glow }: remembered so parts draw without the kit
let design = null;       // the design being edited (internal: items carry _uid)
let selection = new Set();
let tool = 'select';
let view = { zoom: 0.35, panX: 0, panY: 0 };
let history = [], future = [];
let drag = null, cursor = null, spaceDown = false;
let index = new Map();   // _uid -> { kind, obj }
let uidN = 0;
const uid = () => 'u' + (++uidN).toString(36);
const prefs = { mirror: true, grid: true, snap: true, gridSize: 5, bg: 'dark', markers: true, preview: true, lightColour: '#ff4a3d' };

// ---------- small helpers ----------
const round = H.round;
const num = (v, d) => (typeof v === 'number' && isFinite(v)) ? v : d;
const clamp = (v, a, b) => Math.max(a, Math.min(b, v));
const normRot = r => { r = round(((r % 360) + 540) % 360 - 180); return r === -180 ? 180 : r; };
const norm360 = r => round(((r % 360) + 360) % 360);
const css = H.css;
const clone = o => JSON.parse(JSON.stringify(o));
const typing = () => { const t = document.activeElement; return t && (t.tagName === 'INPUT' || t.tagName === 'SELECT' || t.tagName === 'TEXTAREA'); };
function toast(msg) {
  const t = $('toast'); t.textContent = msg; t.hidden = false;
  clearTimeout(toast._t); toast._t = setTimeout(() => { t.hidden = true; }, 3200);
}
const units = () => num(design.units_per_game_px, DEFAULT_UNITS) || DEFAULT_UNITS;
const snapOn = ev => prefs.snap && !(ev && ev.altKey);
const snap = (v, ev) => { const g = prefs.gridSize; return snapOn(ev) && g > 0 ? round(Math.round(v / g) * g) : round(v); };
const mirrorOn = () => prefs.mirror;

// ---------- design model ----------
function normPart(p) {
  return Object.assign({}, p, {
    _uid: uid(), part: String(p.part || ''), x: num(p.x, 0), y: num(p.y, 0), rot: num(p.rot, 0), scale: num(p.scale, 1) || 1,
    flipX: !!p.flipX, flipY: !!p.flipY, z: num(p.z, 0), shadow: p.shadow == null ? DEFAULT_SHADOW : num(p.shadow, DEFAULT_SHADOW),
    glow: p.glow == null ? null : p.glow, label: p.label == null ? null : p.label, group: p.group == null ? null : p.group,
    mirror_link: p.mirror_link == null ? null : p.mirror_link, hidden: !!p.hidden, locked: !!p.locked
  });
}
function normHp(h) {
  const o = Object.assign({}, h, { _uid: uid(), id: String(h.id || ''), size: H.SIZES.includes(h.size) ? h.size : 'small', mount: H.normaliseMount(h.mount, h.kind), x: num(h.x, 0), y: num(h.y, 0) });
  if (o.facing == null) o.facing = 0;
  return o;
}
function normEng(e) {
  if (Array.isArray(e)) e = { x: e[0], y: e[1] };
  return Object.assign({}, e, { _uid: uid(), x: num(e.x, 0), y: num(e.y, 0), size: num(e.size, 1), dir: num(e.dir, 180) });
}
function normLight(l) { return Object.assign({}, l, { _uid: uid(), x: num(l.x, 0), y: num(l.y, 0), colour: typeof l.colour === 'string' ? l.colour : '#ffffff' }); }
function normHit(h) {
  h = h && typeof h === 'object' ? h : {};
  const size = Array.isArray(h.size) ? [num(h.size[0], 0), num(h.size[1], 0)] : [0, 0];
  const offset = Array.isArray(h.offset) ? [num(h.offset[0], 0), num(h.offset[1], 0)] : [0, 0];
  return Object.assign({}, h, { type: h.type || 'capsule', size, offset });
}
function normaliseDesign(src) {
  const d = Object.assign({}, src);
  d.format = FORMAT;
  d.name = typeof src.name === 'string' ? src.name : '';
  d.kit = typeof src.kit === 'string' ? src.kit : (kit ? kit.kit : '');
  d.units_per_game_px = num(src.units_per_game_px, kit ? kit.units : DEFAULT_UNITS);
  d.parts = (Array.isArray(src.parts) ? src.parts : []).filter(p => p && typeof p === 'object').map(normPart);
  d.hardpoints = (Array.isArray(src.hardpoints) ? src.hardpoints : []).filter(Boolean).map(normHp);
  d.engines = (Array.isArray(src.engines) ? src.engines : []).filter(Boolean).map(normEng);
  d.lights = (Array.isArray(src.lights) ? src.lights : []).filter(Boolean).map(normLight);
  d.hit = normHit(src.hit);
  return d;
}
function blankDesign() {
  return normaliseDesign({ name: '', kit: kit ? kit.kit : '', units_per_game_px: kit ? kit.units : DEFAULT_UNITS, parts: [], hardpoints: [], engines: [], hit: { type: 'capsule', size: [0, 0], offset: [0, 0] }, lights: [] });
}
// Known keys first in a fixed order, then any unknown keys the file carried (the format can grow).
function ordered(obj, known, skip = []) {
  const o = {};
  known.forEach(([k, v]) => { if (v !== undefined) o[k] = v; });
  Object.keys(obj).forEach(k => { if (!(k in o) && k[0] !== '_' && !skip.includes(k)) o[k] = obj[k]; });
  return o;
}
function designOut() {
  const d = design;
  return ordered(d, [
    ['format', FORMAT], ['name', d.name], ['display_name', d.display_name || undefined], ['kit', d.kit], ['units_per_game_px', d.units_per_game_px],
    ['parts', d.parts.map(p => ordered(p, [
      ['part', p.part], ['x', round(p.x)], ['y', round(p.y)], ['rot', round(p.rot)], ['scale', round(p.scale)], ['flipX', p.flipX], ['flipY', p.flipY],
      ['z', p.z], ['shadow', round(p.shadow)], ['glow', p.glow], ['label', p.label], ['group', p.group], ['mirror_link', p.mirror_link],
      ['hidden', p.hidden ? true : undefined], ['locked', p.locked ? true : undefined]
    ], ['hidden', 'locked']))],
    ['hardpoints', d.hardpoints.map(h => ordered(h, [
      ['id', h.id], ['size', h.size], ['mount', h.mount], ['x', round(h.x)], ['y', round(h.y)], ['arc', h.arc], ['facing', h.facing],
      ['traverse', h.traverse], ['role', h.role], ['part', h.part], ['cells', h.cells]
    ]))],
    ['engines', d.engines.map(e => ordered(e, [['x', round(e.x)], ['y', round(e.y)], ['size', round(e.size)], ['dir', round(e.dir)]]))],
    ['hit', ordered(d.hit, [['type', d.hit.type], ['size', d.hit.size.map(round)], ['offset', d.hit.offset.map(round)]])],
    ['lights', d.lights.map(l => ordered(l, [['x', round(l.x)], ['y', round(l.y)], ['colour', l.colour]]))]
  ]);
}
// One item per line inside the parts/marker arrays, so diffs stay readable.
function designText() {
  const o = designOut(), keys = Object.keys(o), one = v => {
    if (v && typeof v === 'object' && !Array.isArray(v)) return '{' + Object.keys(v).map(k => JSON.stringify(k) + ': ' + JSON.stringify(v[k])).join(', ') + '}';
    return JSON.stringify(v);
  };
  const lines = ['{'];
  keys.forEach((k, i) => {
    const v = o[k], comma = i < keys.length - 1 ? ',' : '';
    if (Array.isArray(v) && v.length && v.every(x => x && typeof x === 'object' && !Array.isArray(x))) {
      lines.push(`  ${JSON.stringify(k)}: [`);
      v.forEach((x, j) => lines.push('    ' + one(x) + (j < v.length - 1 ? ',' : '')));
      lines.push('  ]' + comma);
    } else lines.push(`  ${JSON.stringify(k)}: ${one(v)}${comma}`);
  });
  lines.push('}');
  return lines.join('\n') + '\n';
}

function rebuildIndex() {
  index = new Map();
  design.parts.forEach(o => index.set(o._uid, { kind: 'part', obj: o }));
  design.hardpoints.forEach(o => index.set(o._uid, { kind: 'hp', obj: o }));
  design.engines.forEach(o => index.set(o._uid, { kind: 'eng', obj: o }));
  design.lights.forEach(o => index.set(o._uid, { kind: 'light', obj: o }));
  selection = new Set([...selection].filter(u => index.has(u)));
}
const selOf = kind => [...selection].map(u => index.get(u)).filter(x => x && x.kind === kind).map(x => x.obj);
const selParts = () => design.parts.filter(p => selection.has(p._uid));
const listOf = kind => ({ part: design.parts, hp: design.hardpoints, eng: design.engines, light: design.lights })[kind];

// ---------- kit parts ----------
function kitPart(id) {
  if (kit && kit.parts.has(id)) return kit.parts.get(id);
  if (dims[id]) return Object.assign({ id, img: null }, dims[id]);
  return null;
}
function partSize(p) { const k = kitPart(p.part); return k ? [k.w, k.h] : [120, 120]; }
function partLabel(p) { return p.label || p.part || '?'; }
function partner(p) { return p.mirror_link ? design.parts.find(q => q !== p && q.mirror_link === p.mirror_link) || null : null; }
function isEnginePart(p) { const k = kitPart(p.part); return p.glow === 'exit' || (k && (k.glow === 'exit' || /^engine/.test(k.category || ''))); }

// local (native image px from the image centre) <-> design. Flip, then scale, then rotate CCW.
function xf(p) {
  const r = p.rot * Math.PI / 180, c = Math.cos(r), s = Math.sin(r);
  const kx = p.scale * (p.flipX ? -1 : 1), ky = p.scale * (p.flipY ? -1 : 1);
  return {
    toDesign: (lx, ly) => { const fx = lx * kx, fy = ly * ky; return [p.x + fx * c + fy * s, p.y - fx * s + fy * c]; },
    toLocal: (x, y) => { const dx = x - p.x, dy = y - p.y; return [(dx * c - dy * s) / kx, (dx * s + dy * c) / ky]; }
  };
}
function corners(p) { const [w, h] = partSize(p), t = xf(p); return [t.toDesign(-w / 2, -h / 2), t.toDesign(w / 2, -h / 2), t.toDesign(w / 2, h / 2), t.toDesign(-w / 2, h / 2)]; }
function aabb(pts) {
  let a = { minX: Infinity, minY: Infinity, maxX: -Infinity, maxY: -Infinity };
  pts.forEach(([x, y]) => { a.minX = Math.min(a.minX, x); a.maxX = Math.max(a.maxX, x); a.minY = Math.min(a.minY, y); a.maxY = Math.max(a.maxY, y); });
  return a;
}
const partBox = p => aabb(corners(p));
function sortedParts() { return design.parts.map((p, i) => [p, i]).sort((a, b) => a[0].z - b[0].z || a[1] - b[1]).map(x => x[0]); }
function maxZ() { return design.parts.reduce((m, p) => Math.max(m, p.z), 0); }

// Draw a part onto c, with design (x, y) at screen (ox + x*s, oy + y*s).
function drawPart(c, p, ox, oy, s, outline) {
  const k = kitPart(p.part), [w, h] = partSize(p);
  c.save();
  c.translate(ox + p.x * s, oy + p.y * s);
  c.rotate(-p.rot * Math.PI / 180);
  c.scale(s * p.scale * (p.flipX ? -1 : 1), s * p.scale * (p.flipY ? -1 : 1));
  if (k && k.img) {
    c.imageSmoothingEnabled = true; c.imageSmoothingQuality = 'high';
    c.drawImage(k.img, -w / 2, -h / 2, w, h);
  } else if (outline) {
    c.fillStyle = 'rgba(147,160,174,0.12)'; c.fillRect(-w / 2, -h / 2, w, h);
    c.strokeStyle = 'rgba(147,160,174,0.7)'; c.lineWidth = 1 / (s * p.scale); c.strokeRect(-w / 2, -h / 2, w, h);
  }
  c.restore();
  if (outline && !(k && k.img)) {
    c.fillStyle = css('--ink-2'); c.font = `500 11px ${css('--font-mono')}`; c.textAlign = 'center'; c.textBaseline = 'middle';
    c.fillText(p.part, ox + p.x * s, oy + p.y * s);
  }
}
// Alpha (0..255) of a part's own image at native pixel (lx, ly) from its centre; null when unknown.
function partAlpha(k, lx, ly) {
  if (!k || !k.img) return null;
  if (k.alpha === undefined) {
    try {
      const c = document.createElement('canvas'); c.width = k.img.naturalWidth; c.height = k.img.naturalHeight;
      const g = c.getContext('2d'); g.drawImage(k.img, 0, 0);
      const d = g.getImageData(0, 0, c.width, c.height).data, a = new Uint8Array(c.width * c.height);
      for (let i = 0; i < a.length; i++) a[i] = d[i * 4 + 3];
      k.alpha = { a, w: c.width, h: c.height };
    } catch (e) { k.alpha = null; }
  }
  if (!k.alpha) return null;
  const px = Math.floor((lx + k.w / 2) * k.alpha.w / k.w), py = Math.floor((ly + k.h / 2) * k.alpha.h / k.h);
  if (px < 0 || py < 0 || px >= k.alpha.w || py >= k.alpha.h) return 0;
  return k.alpha.a[py * k.alpha.w + px];
}

// ---------- composition (alpha scan, sprite frame, previews) ----------
let heavy = { ver: -1, scan: null };
let ver = 0;
function visibleParts() { return sortedParts().filter(p => !p.hidden); }
function composeScan() {
  if (heavy.ver === ver && heavy.scan !== undefined) return heavy.scan;
  heavy.ver = ver; heavy.scan = null;
  const vis = visibleParts();
  if (!vis.length) return null;
  const b = aabb(vis.flatMap(corners));
  const span = Math.max(b.maxX - b.minX, b.maxY - b.minY, 1);
  const s = Math.min(0.5, 2400 / span);
  const W = Math.max(1, Math.ceil((b.maxX - b.minX) * s) + 4), Hh = Math.max(1, Math.ceil((b.maxY - b.minY) * s) + 4);
  const c = document.createElement('canvas'); c.width = W; c.height = Hh;
  const g = c.getContext('2d');
  const ox = 2 - b.minX * s, oy = 2 - b.minY * s;
  vis.forEach(p => drawPart(g, p, ox, oy, s, false));
  let data = null;
  try { data = g.getImageData(0, 0, W, Hh).data; } catch (e) { data = null; }
  let tight = null;
  if (data) {
    let x0 = Infinity, y0 = Infinity, x1 = -Infinity, y1 = -Infinity;
    for (let y = 0; y < Hh; y++) for (let x = 0; x < W; x++) if (data[(y * W + x) * 4 + 3] > ALPHA_ON) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y; }
    if (x0 !== Infinity) tight = { minX: (x0 - ox) / s, maxX: (x1 + 1 - ox) / s, minY: (y0 - oy) / s, maxY: (y1 + 1 - oy) / s };
    // Parts without images (no kit open) count by their rectangles.
    const blind = vis.filter(p => !(kitPart(p.part) || {}).img);
    if (blind.length) { const r = aabb(blind.flatMap(corners).concat(tight ? [[tight.minX, tight.minY], [tight.maxX, tight.maxY]] : [])); tight = r; }
  } else tight = b;   // no pixel access: fall back to the part rectangles
  heavy.scan = { data, W, H: Hh, ox, oy, s, tight };
  return heavy.scan;
}
function alphaAtDesign(x, y) {
  const sc = composeScan();
  if (!sc) return 0;
  if (!sc.data) return 255;
  const px = Math.floor(sc.ox + x * sc.s), py = Math.floor(sc.oy + y * sc.s);
  if (px < 0 || py < 0 || px >= sc.W || py >= sc.H) return 0;
  return sc.data[(py * sc.W + px) * 4 + 3];
}
// The composed sprite as the renderer crops it: tight alpha bounds plus the margin, widened so the
// centre line stays at x = 0. All in kit units; cy is the sprite centre's design y.
function spriteFrame() {
  const sc = composeScan();
  if (!sc || !sc.tight) return null;
  const t = sc.tight, u = units();
  const half = Math.max(Math.abs(t.minX), Math.abs(t.maxX)) + SPRITE_MARGIN;
  const top = t.minY - SPRITE_MARGIN, bot = t.maxY + SPRITE_MARGIN;
  return { half, top, bot, cy: (top + bot) / 2, sizePx: [Math.max(1, Math.round(2 * half / u)), Math.max(1, Math.round((bot - top) / u))], tight: t, offCentre: Math.abs(t.maxX + t.minX) / 2 };
}
// Composed sprite at `scale` px per kit unit (built big, then halved down for a clean small image).
function composeSprite(scale) {
  const f = spriteFrame();
  if (!f) return null;
  const Wt = Math.max(1, Math.round(2 * f.half * scale)), Ht = Math.max(1, Math.round((f.bot - f.top) * scale));
  const m = Math.max(scale, Math.min(1, 4096 / Math.max(2 * f.half, f.bot - f.top)));
  let c = document.createElement('canvas');
  c.width = Math.max(1, Math.round(2 * f.half * m)); c.height = Math.max(1, Math.round((f.bot - f.top) * m));
  const g = c.getContext('2d');
  visibleParts().forEach(p => drawPart(g, p, f.half * m, -f.top * m, m, false));
  while (c.width / 2 >= Wt && c.height / 2 >= Ht && c.width > 1) {
    const n = document.createElement('canvas'); n.width = Math.max(1, Math.round(c.width / 2)); n.height = Math.max(1, Math.round(c.height / 2));
    const ng = n.getContext('2d'); ng.imageSmoothingQuality = 'high'; ng.drawImage(c, 0, 0, n.width, n.height); c = n;
  }
  const out = document.createElement('canvas'); out.width = Wt; out.height = Ht;
  const og = out.getContext('2d'); og.imageSmoothingQuality = 'high'; og.drawImage(c, 0, 0, Wt, Ht);
  return out;
}

// ---------- hull.json from the design ----------
function hullFromDesign() {
  const f = spriteFrame(), u = units(), cy = f ? f.cy : 0;
  const cvt = (x, y) => [round(x / u), round((y - cy) / u)];
  return {
    id: design.name, name: design.display_name || '', sprite: design.name ? design.name + '.png' : '',
    size_px: f ? f.sizePx : [0, 0], scale: 1,
    hit: { size: [round(design.hit.size[0] / u), round(design.hit.size[1] / u)], offset: cvt(design.hit.offset[0], design.hit.offset[1]) },
    hardpoints: design.hardpoints.map(h => {
      const o = { id: h.id, size: h.size, mount: h.mount, pos: cvt(h.x, h.y) };
      if (h.facing) o.facing = h.facing;
      if (h.arc != null && !(H.aims(h.mount) && h.arc === H.ARC_DEFAULT[h.mount])) o.arc = h.arc;
      if (h.traverse != null) o.traverse = h.traverse;
      if (h.role) o.role = h.role;
      if (h.part) o.part = h.part;
      if (h.cells != null) o.cells = h.cells;
      return o;
    }),
    engines: design.engines.map(e => cvt(e.x, e.y))
  };
}

// ---------- checks ----------
function validate() {
  const f = spriteFrame(), u = units(), hull = hullFromDesign();
  const out = H.validateHull(hull, {
    spriteError: f ? null : 'No visible parts yet: the composed sprite is empty, so positions can\'t be checked.',
    inBounds: (x, y) => Math.abs(x) <= hull.size_px[0] / 2 + 1e-6 && Math.abs(y) <= hull.size_px[1] / 2 + 1e-6,
    alphaAt: (x, y) => alphaAtDesign(x * u, y * u + f.cy),
    offHull: name => `${name} isn't over any part.`,
    target: { hp: i => design.hardpoints[i]._uid, eng: i => design.engines[i]._uid }
  });
  const E = (msg, target) => out.push({ lvl: 'e', msg, target });
  const W = (msg, target) => out.push({ lvl: 'w', msg, target });
  if (!(design.hit.size[0] > 0 && design.hit.size[1] > 0)) W('Press "Fit to composed sprite" under Hit capsule, then trim it.');
  if (!kit) W('No kit open: parts draw as outlines. Open the kit folder or zip to see them.');
  else {
    if (design.kit && kit.kit && design.kit !== kit.kit) W(`This design is for kit "${design.kit}", but kit "${kit.kit}" is open.`);
    if (kit.units && Math.abs(kit.units - units()) > 1e-9) W(`Design uses ${units()} units per game px; the kit says ${kit.units}.`);
    design.parts.forEach(p => { if (!kit.parts.has(p.part)) E(`${partLabel(p)}: part "${p.part}" isn't in the open kit.`, p._uid); });
  }
  const [cw, ch] = Array.isArray(design.canvas) ? design.canvas : DEFAULT_CANVAS;
  design.parts.forEach(p => {
    if (p.hidden) return;
    const b = partBox(p);
    if (b.minX < -cw / 2 || b.maxX > cw / 2 || b.minY < -ch / 2 || b.maxY > ch / 2) E(`${partLabel(p)} reaches off the ${cw} × ${ch} render canvas.`, p._uid);
  });
  design.parts.forEach(p => { if (p.mirror_link && !partner(p)) W(`${partLabel(p)}: its mirror partner is gone. Break the link or add a mirror.`, p._uid); });
  if (design.parts.length && !design.parts.some(p => !p.hidden && isEnginePart(p))) W('No engine parts (engine pods, bells, large engines or glow "exit" parts).');
  // A nose_cap sits on a nose_module: the module is drawn under it and the cap overlaps its top edge.
  design.parts.forEach(cap => {
    const kc = kitPart(cap.part);
    if (cap.hidden || !kc || kc.category !== 'nose_cap') return;
    const cb = partBox(cap);
    const ok = design.parts.some(m => {
      const km = kitPart(m.part);
      if (m === cap || m.hidden || !km || km.category !== 'nose_module' || m.z > cap.z) return false;
      if (m.z === cap.z && design.parts.indexOf(m) > design.parts.indexOf(cap)) return false;
      const mb = partBox(m);
      return cb.maxX > mb.minX && cb.minX < mb.maxX && cb.maxY > mb.minY && cb.maxY < (mb.minY + mb.maxY) / 2 + 1 && cb.minY < mb.minY;
    });
    if (!ok) W(`${partLabel(cap)}: a nose_cap needs a nose_module under it (drawn below, with the cap overlapping its top edge).`, cap._uid);
  });
  if (f && f.offCentre > u) W(`The composed sprite is ${round(f.offCentre / u)} game px off-centre; hull.json widens it so the centre line stays at x = 0.`);
  return out;
}
let lastChecks = [];
function renderChecks() {
  const list = validate(), ul = $('checks'); ul.innerHTML = '';
  lastChecks = list;
  const errs = list.filter(x => x.lvl === 'e').length, warns = list.length - errs;
  if (!list.length) ul.innerHTML = '<li class="ok"><span class="ic">✓</span><span>Ready to hand over.</span></li>';
  list.sort((a, b) => (a.lvl === 'e' ? 0 : 1) - (b.lvl === 'e' ? 0 : 1)).forEach(c => {
    const li = document.createElement('li'); li.className = c.lvl;
    li.innerHTML = `<span class="ic">${c.lvl === 'e' ? '✕' : '!'}</span><span></span>`;
    li.children[1].textContent = c.msg;
    if (c.target) { li.dataset.target = '1'; li.onclick = () => { selection = new Set([c.target]); refresh(false); }; }
    ul.appendChild(li);
  });
  const p = $('chkPill');
  p.className = 'pill ' + (errs ? 'bad' : warns ? 'warn' : 'good');
  p.textContent = errs ? `${errs} error${errs > 1 ? 's' : ''}` : warns ? `${warns} warning${warns > 1 ? 's' : ''}` : 'OK';
  return errs;
}

// ---------- history and autosave ----------
const snapshot = () => JSON.stringify(design);
function commit() { history.push(snapshot()); future = []; updateUndo(); }
function restoreSnap(s) { design = JSON.parse(s); changed(); refresh(); }
function undo() { if (!history.length) return; future.push(snapshot()); restoreSnap(history.pop()); updateUndo(); }
function redo() { if (!future.length) return; history.push(snapshot()); restoreSnap(future.pop()); updateUndo(); }
function updateUndo() { $('bUndo').disabled = !history.length; $('bRedo').disabled = !future.length; }
function persist() {
  try {
    localStorage.setItem(STORE_KEY, JSON.stringify({ design: designOut(), dims, view, prefs, kitLabel: kit ? kit.label : null }));
  } catch (e) { /* storage unavailable or full: the designer still works */ }
}
function restore() {
  try {
    const raw = localStorage.getItem(STORE_KEY);
    if (!raw) return false;
    const p = JSON.parse(raw);
    if (!p || !p.design) return false;
    dims = p.dims && typeof p.dims === 'object' ? p.dims : {};
    if (p.prefs) Object.assign(prefs, p.prefs);
    if (p.view) view = Object.assign(view, p.view);
    design = normaliseDesign(p.design);
    return true;
  } catch (e) { return false; }
}

// ---------- view ----------
function stageSize() { const r = cv.getBoundingClientRect(); return [r.width, r.height]; }
function toScreen(x, y) { const [w, h] = stageSize(); return [w / 2 + view.panX + x * view.zoom, h / 2 + view.panY + y * view.zoom]; }
function toDesign(sx, sy) { const [w, h] = stageSize(); return [(sx - w / 2 - view.panX) / view.zoom, (sy - h / 2 - view.panY) / view.zoom]; }
function resize() {
  const [w, h] = stageSize(), d = window.devicePixelRatio || 1;
  cv.width = Math.max(1, Math.round(w * d)); cv.height = Math.max(1, Math.round(h * d));
  draw();
}
function fitView() {
  const [w, h] = stageSize();
  const pts = design.parts.filter(p => !p.hidden).flatMap(corners);
  [...design.hardpoints, ...design.engines, ...design.lights].forEach(m => pts.push([m.x, m.y]));
  const b = pts.length ? aabb(pts) : { minX: -500, maxX: 500, minY: -900, maxY: 900 };
  const bw = Math.max(200, b.maxX - b.minX, 2 * Math.max(Math.abs(b.minX), Math.abs(b.maxX))), bh = Math.max(200, b.maxY - b.minY);
  view.zoom = clamp(Math.min((w - 100) / bw, (h - 150) / bh), 0.02, 8);
  view.panX = 0; view.panY = -((b.minY + b.maxY) / 2) * view.zoom + 20;
  draw();
}
function zoomAt(f, sx, sy) {
  const [ax, ay] = toDesign(sx, sy);
  view.zoom = clamp(view.zoom * f, 0.02, 8);
  const [nx, ny] = toScreen(ax, ay);
  view.panX += sx - nx; view.panY += sy - ny;
  draw();
}

// ---------- drawing ----------
const BG = { dark: '#0a0807', light: '#e9e6e1' };
function paintBackground(c, w, h) {
  if (prefs.bg === 'checker') {
    c.fillStyle = '#1b1d21'; c.fillRect(0, 0, w, h); c.fillStyle = '#26292e';
    const cell = 12;
    for (let y = 0; y * cell < h; y++) for (let x = 0; x * cell < w; x++) if ((x + y) % 2) c.fillRect(x * cell, y * cell, cell, cell);
  } else { c.fillStyle = BG[prefs.bg] || BG.dark; c.fillRect(0, 0, w, h); }
}
const guideInk = () => prefs.bg === 'light' ? '20,20,24' : '220,226,234';
function selectionBox() {
  const ps = selParts().filter(p => !p.locked);
  if (!ps.length) return null;
  if (ps.length === 1) {
    const p = ps[0], [w, h] = partSize(p), t = xf(p);
    const r = p.rot * Math.PI / 180;
    return { single: p, corners: corners(p), centre: [p.x, p.y], up: [-Math.sin(r), -Math.cos(r)], top: t.toDesign(0, (p.flipY ? 1 : -1) * h / 2), scaleAt: t.toDesign(w / 2 * (p.flipX ? -1 : 1), h / 2 * (p.flipY ? -1 : 1)) };
  }
  const b = aabb(ps.flatMap(corners));
  return { corners: [[b.minX, b.minY], [b.maxX, b.minY], [b.maxX, b.maxY], [b.minX, b.maxY]], centre: [(b.minX + b.maxX) / 2, (b.minY + b.maxY) / 2], up: [0, -1], top: [(b.minX + b.maxX) / 2, b.minY], scaleAt: [b.maxX, b.maxY] };
}
function handles() {
  const sb = selectionBox();
  if (!sb || tool !== 'select') return null;
  const [tx, ty] = toScreen(...sb.top);
  return { rot: [tx + sb.up[0] * 26, ty + sb.up[1] * 26], top: [tx, ty], scale: toScreen(...sb.scaleAt), centre: sb.centre, box: sb };
}
function draw() {
  const d = window.devicePixelRatio || 1;
  ctx.setTransform(d, 0, 0, d, 0, 0);
  const [w, h] = stageSize(), z = view.zoom;
  paintBackground(ctx, w, h);
  const ink = guideInk();
  // render canvas bounds
  const [cw, ch] = Array.isArray(design.canvas) ? design.canvas : DEFAULT_CANVAS;
  const [c0x, c0y] = toScreen(-cw / 2, -ch / 2);
  ctx.strokeStyle = `rgba(${ink},0.18)`; ctx.lineWidth = 1; ctx.setLineDash([8, 6]); ctx.strokeRect(c0x, c0y, cw * z, ch * z); ctx.setLineDash([]);
  // grid
  if (prefs.grid && prefs.gridSize > 0) {
    let step = prefs.gridSize; while (step * z < 8) step *= 5;
    const [x0, y0] = toDesign(0, 0), [x1, y1] = toDesign(w, h);
    ctx.lineWidth = 1;
    for (const major of [false, true]) {
      const st = major ? step * 5 : step;
      ctx.strokeStyle = `rgba(${ink},${major ? 0.13 : 0.06})`; ctx.beginPath();
      for (let x = Math.floor(x0 / st) * st; x <= x1; x += st) { const X = Math.round(toScreen(x, 0)[0]) + 0.5; ctx.moveTo(X, 0); ctx.lineTo(X, h); }
      for (let y = Math.floor(y0 / st) * st; y <= y1; y += st) { const Y = Math.round(toScreen(0, y)[1]) + 0.5; ctx.moveTo(0, Y); ctx.lineTo(w, Y); }
      ctx.stroke();
    }
  }
  // centre line and origin
  const [ox, oy] = toScreen(0, 0);
  ctx.strokeStyle = `rgba(${ink},0.45)`; ctx.setLineDash([6, 5]); ctx.beginPath(); ctx.moveTo(Math.round(ox) + 0.5, 0); ctx.lineTo(Math.round(ox) + 0.5, h); ctx.stroke(); ctx.setLineDash([]);
  ctx.beginPath(); ctx.moveTo(ox - 6, oy); ctx.lineTo(ox + 6, oy); ctx.stroke();
  ctx.fillStyle = `rgba(${ink},0.6)`; ctx.font = `500 11px ${css('--font-ui')}`; ctx.textAlign = 'left'; ctx.textBaseline = 'top';
  ctx.fillText('BOW ▲', ox + 6, Math.max(56, c0y + 4));
  // parts
  sortedParts().forEach(p => { if (!p.hidden) drawPart(ctx, p, w / 2 + view.panX, h / 2 + view.panY, z, true); });
  // selection outlines, mirror partners, locks
  const sel = selParts();
  const outline = (p, col, dash) => {
    const cs = corners(p).map(q => toScreen(...q));
    ctx.beginPath(); cs.forEach((q, i) => i ? ctx.lineTo(...q) : ctx.moveTo(...q)); ctx.closePath();
    ctx.setLineDash(dash || []); ctx.strokeStyle = col; ctx.lineWidth = 1.5; ctx.stroke(); ctx.setLineDash([]);
  };
  sel.forEach(p => {
    outline(p, p.locked ? css('--ink-2') : css('--sel'));
    const q = partner(p); if (q && !selection.has(q._uid)) outline(q, css('--link'), [5, 4]);
    if (p.locked) { const [sx, sy] = toScreen(p.x, p.y); ctx.fillStyle = css('--ink'); ctx.font = `600 13px ${css('--font-ui')}`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle'; ctx.fillText('🔒', sx, sy); }
  });
  const hd = handles();
  if (hd) {
    if (!hd.box.single) { const cs = hd.box.corners.map(q => toScreen(...q)); ctx.setLineDash([4, 4]); ctx.strokeStyle = css('--sel'); ctx.lineWidth = 1; ctx.strokeRect(cs[0][0], cs[0][1], cs[2][0] - cs[0][0], cs[2][1] - cs[0][1]); ctx.setLineDash([]); }
    ctx.strokeStyle = css('--sel'); ctx.lineWidth = 1.5; ctx.beginPath(); ctx.moveTo(...hd.top); ctx.lineTo(...hd.rot); ctx.stroke();
    ctx.fillStyle = css('--bench'); ctx.beginPath(); ctx.arc(hd.rot[0], hd.rot[1], 6, 0, Math.PI * 2); ctx.fill(); ctx.stroke();
    ctx.fillStyle = css('--sel'); ctx.fillRect(hd.scale[0] - 5, hd.scale[1] - 5, 10, 10);
  }
  // markers
  if (prefs.markers) {
    const [hw, hl] = design.hit.size;
    if (hw > 0 && hl > 0) {
      const [hx, hy] = toScreen(design.hit.offset[0], design.hit.offset[1]);
      H.capsulePath(ctx, hx, hy, hw * z, hl * z);
      ctx.setLineDash([6, 4]); ctx.strokeStyle = H.mountColour('hit'); ctx.lineWidth = 1.5; ctx.stroke(); ctx.setLineDash([]);
    }
    design.engines.forEach(e => { const [sx, sy] = toScreen(e.x, e.y); H.drawEngine(ctx, e, sx, sy, selection.has(e._uid), e.size || 1, e.dir); });
    design.lights.forEach(l => drawLight(ctx, l, ...toScreen(l.x, l.y), selection.has(l._uid)));
    design.hardpoints.forEach(hp => { const [sx, sy] = toScreen(hp.x, hp.y); H.drawMarker(ctx, hp, sx, sy, z, selection.has(hp._uid), false); });
  }
  // placement ghost for marker tools
  if (cursor && tool !== 'select' && !drag) {
    const ax = snap(cursor[0], cursor.ev), ay = snap(cursor[1], cursor.ev);
    const ghost = (x, y) => {
      const [sx, sy] = toScreen(x, y);
      if (tool === 'hardpoint') H.drawMarker(ctx, { id: '', mount: $('tMount').value, size: $('tSize').value, facing: 0 }, sx, sy, z, false, false);
      else if (tool === 'engine') H.drawEngine(ctx, null, sx, sy, false, 1, 180);
      else drawLight(ctx, { colour: prefs.lightColour }, sx, sy, false);
    };
    ctx.globalAlpha = 0.45; ghost(ax, ay); if (mirrorOn() && Math.abs(ax) > CENTRE_EPS) ghost(-ax, ay); ctx.globalAlpha = 1;
  }
  if (drag && drag.kind === 'marquee') {
    ctx.fillStyle = 'rgba(240,145,58,0.08)'; ctx.strokeStyle = css('--sel'); ctx.lineWidth = 1; ctx.setLineDash([4, 3]);
    const x = Math.min(drag.sx, drag.cx), y = Math.min(drag.sy, drag.cy), ww = Math.abs(drag.cx - drag.sx), hh = Math.abs(drag.cy - drag.sy);
    ctx.fillRect(x, y, ww, hh); ctx.strokeRect(x + 0.5, y + 0.5, ww, hh); ctx.setLineDash([]);
  }
  if (!design.parts.length) {
    ctx.fillStyle = `rgba(${ink},0.55)`; ctx.font = `500 15px ${css('--font-ui')}`; ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    ctx.fillText(kit ? 'Drag parts from the palette, or click one to add it here' : 'Open the kit folder or zip to start (or drop it here)', w / 2, h / 2);
  }
  $('rZoom').textContent = `zoom ${view.zoom < 1 ? view.zoom.toFixed(3) : view.zoom.toFixed(2)}×`;
}
function drawLight(c, l, sx, sy, selected) {
  c.beginPath(); c.arc(sx, sy, 5, 0, Math.PI * 2); c.fillStyle = l.colour || '#ffffff'; c.fill();
  c.lineWidth = selected ? 2.5 : 1.25; c.strokeStyle = selected ? css('--ink') : H.mountColour('light'); c.stroke();
  c.beginPath(); c.arc(sx, sy, 10, 0, Math.PI * 2); c.globalAlpha *= 0.5; c.strokeStyle = l.colour || '#ffffff'; c.lineWidth = 1; c.stroke(); c.globalAlpha = Math.min(1, c.globalAlpha * 2);
}

// ---------- picking ----------
function pickMarker(sx, sy) {
  if (!prefs.markers) return null;
  let best = null, bd = 14;
  const test = (list, dy = 0) => list.forEach(m => { const [x, y] = toScreen(m.x, m.y); const dd = Math.hypot(x - sx, y + dy - sy); if (dd < bd) { bd = dd; best = m._uid; } });
  test(design.engines, 2); test(design.lights); test(design.hardpoints);
  return best;
}
function pickPart(x, y, includeLocked = false) {
  const ps = sortedParts().reverse();
  for (const p of ps) {
    if (p.hidden || (p.locked && !includeLocked)) continue;
    const [w, h] = partSize(p), [lx, ly] = xf(p).toLocal(x, y);
    if (Math.abs(lx) > w / 2 || Math.abs(ly) > h / 2) continue;
    const a = partAlpha(kitPart(p.part), lx, ly);
    if (a === null || a > 20) return p._uid;
  }
  return null;
}
function hitHandle(sx, sy) {
  const hd = handles();
  if (!hd) return null;
  if (Math.hypot(sx - hd.rot[0], sy - hd.rot[1]) < 9) return { kind: 'rotate', hd };
  if (Math.abs(sx - hd.scale[0]) < 8 && Math.abs(sy - hd.scale[1]) < 8) return { kind: 'scale', hd };
  return null;
}
function groupOf(u) {
  const it = index.get(u);
  if (!it || it.kind !== 'part' || !it.obj.group) return [u];
  return design.parts.filter(p => p.group === it.obj.group).map(p => p._uid);
}

// ---------- mirror links ----------
function newTag(prefix, used) { let n = 1; while (used.has(prefix + n)) n++; return prefix + n; }
function applyMirrorPose(src, dst) {
  dst.x = round(-src.x); dst.y = round(src.y); dst.rot = normRot(-src.rot); dst.scale = src.scale; dst.flipY = src.flipY;
  const ks = kitPart(src.part);
  const usesPartner = dst.part !== src.part && ks && ks.mirror_of === dst.part;
  dst.flipX = usesPartner ? src.flipX : !src.flipX;
  dst.shadow = src.shadow; dst.glow = src.glow; dst.hidden = src.hidden;
}
function makePartner(p) {
  const k = kitPart(p.part);
  const mo = k && k.mirror_of && kitPart(k.mirror_of) ? k.mirror_of : null;
  const q = Object.assign(clone(p), { _uid: uid(), part: mo || p.part, group: null, locked: false });
  if (q.label) q.label = q.label + ' (mirror)';
  const link = p.mirror_link || newTag('m', new Set(design.parts.map(x => x.mirror_link)));
  p.mirror_link = link; q.mirror_link = link;
  applyMirrorPose(p, q);
  design.parts.splice(design.parts.indexOf(p) + 1, 0, q);
  index.set(q._uid, { kind: 'part', obj: q });
  return q;
}
// Bring the partners of `drivers` in step (each pair is set once, by the first of the pair listed).
function syncMirrors(drivers) {
  const done = new Set();
  drivers.forEach(p => {
    if (done.has(p)) return;
    const q = partner(p);
    done.add(p);
    if (q && !done.has(q)) { applyMirrorPose(p, q); done.add(q); }
  });
}
// Selected parts that drive an edit: unlocked, and not the partner of an earlier one.
function drivers(ps = selParts()) {
  const out = [], seen = new Set();
  ps.forEach(p => { if (p.locked || seen.has(p)) return; out.push(p); seen.add(p); const q = partner(p); if (q) seen.add(q); });
  return out;
}
function markerPartner(kind, m) {
  if (!mirrorOn()) return null;
  const list = listOf(kind), i = list.indexOf(m);
  const j = H.mirrorPartner(list, i, o => [o.x, o.y], kind === 'hp' ? H.sameHardpointKind : null, 0.3 * units());
  return j >= 0 ? list[j] : null;
}

// ---------- edits ----------
function changed() { ver++; }
function placePart(id, x, y, ev) {
  const k = kitPart(id);
  if (!k) return;
  commit();
  const p = normPart({ part: id, x: snap(x, ev), y: snap(y, ev), rot: 0, scale: num(k.default_scale, 1) || 1, flipX: false, flipY: false,
    z: maxZ() + 1, shadow: DEFAULT_SHADOW, glow: k.glow || null, label: null, group: null, mirror_link: null });
  design.parts.push(p);
  index.set(p._uid, { kind: 'part', obj: p });
  if (mirrorOn() && Math.abs(p.x) >= CENTRE_EPS) makePartner(p);
  selection = new Set([p._uid]);
  changed(); refresh();
  cv.focus();
}
function placeMarker(x, y) {
  commit();
  let made;
  if (tool === 'hardpoint') {
    const mount = $('tMount').value, size = $('tSize').value;
    const taken = new Set(design.hardpoints.map(h => h.id));
    const hp = normHp({ id: H.nextId(mount, taken), size, mount, x, y, facing: 0 });
    if (H.aims(mount)) hp.arc = H.ARC_DEFAULT[mount];
    if (mount === 'launcher') hp.cells = 4;
    taken.add(hp.id); design.hardpoints.push(hp); made = hp;
    if (mirrorOn() && Math.abs(x) > CENTRE_EPS) { const t = normHp(Object.assign(clone(hp), { id: H.nextId(mount, taken), x: -x, facing: 0 })); design.hardpoints.push(t); }
  } else if (tool === 'engine') {
    const e = normEng({ x, y, size: 1, dir: 180 }); design.engines.push(e); made = e;
    if (mirrorOn() && Math.abs(x) > CENTRE_EPS) design.engines.push(normEng({ x: -x, y, size: 1, dir: 180 }));
  } else {
    const l = normLight({ x, y, colour: prefs.lightColour }); design.lights.push(l); made = l;
    if (mirrorOn() && Math.abs(x) > CENTRE_EPS) design.lights.push(normLight({ x: -x, y, colour: prefs.lightColour }));
  }
  selection = new Set([made._uid]);
  changed(); refresh();
}
// Move every selected thing by (dx, dy); mirror partners follow.
function moveSelection(dx, dy) {
  const ds = drivers();
  ds.forEach(p => { p.x = round(p.x + dx); p.y = round(p.y + dy); });
  syncMirrors(ds);
  ['hp', 'eng', 'light'].forEach(kind => selOf(kind).forEach(m => {
    const q = markerPartner(kind, m);
    m.x = round(m.x + dx); m.y = round(m.y + dy);
    if (q && !selection.has(q._uid)) { q.x = -m.x; q.y = m.y; }
  }));
}
// Rotate the selected parts by `deg` counter-clockwise: one part about its centre, several about their common centre.
function rotateParts(ds, deg, centre, base) {
  const a = deg * Math.PI / 180, c = Math.cos(a), s = Math.sin(a);
  ds.forEach(p => {
    const b = base ? base.get(p) : p;
    const dx = b.x - centre[0], dy = b.y - centre[1];
    p.x = round(centre[0] + dx * c + dy * s); p.y = round(centre[1] - dx * s + dy * c);
    p.rot = normRot(b.rot + deg);
  });
  syncMirrors(ds);
}
function act(name) {
  const ds = drivers();
  const needParts = !['group', 'ungroup', 'unlink', 'lock'].includes(name);
  if (needParts && !ds.length) { if (selParts().length) toast('Those parts are locked.'); return; }
  const centre = () => { const sb = selectionBox(); return sb ? sb.centre : [0, 0]; };
  commit();
  if (name === 'rotL' || name === 'rotR') rotateParts(ds, name === 'rotL' ? 90 : -90, ds.length === 1 ? [ds[0].x, ds[0].y] : centre());
  else if (name === 'flipH' || name === 'flipV') {
    const [cx, cy] = centre();
    ds.forEach(p => {
      if (name === 'flipH') { p.x = round(2 * cx - p.x); p.flipX = !p.flipX; } else { p.y = round(2 * cy - p.y); p.flipY = !p.flipY; }
      p.rot = normRot(-p.rot);
    });
    syncMirrors(ds);
  } else if (name === 'dup') duplicate();
  else if (['front', 'fwd', 'back', 'bottom'].includes(name)) reorder(name);
  else if (name === 'lock') {
    const ps = selParts(), lock = ps.some(p => !p.locked);
    ps.forEach(p => { p.locked = lock; });
    toast(lock ? `Locked ${ps.length} part${ps.length > 1 ? 's' : ''}. Unlock from the layers list.` : 'Unlocked.');
  } else if (name === 'group') {
    const ps = selParts();
    if (ps.length < 2) { history.pop(); updateUndo(); toast('Select two or more parts to group.'); return; }
    const g = newTag('g', new Set(design.parts.map(p => p.group)));
    ps.forEach(p => { p.group = g; });
    toast(`Grouped ${ps.length} parts as ${g}. Alt-click picks one part inside a group.`);
  } else if (name === 'ungroup') selParts().forEach(p => { p.group = null; });
  else if (name === 'unlink') {
    selParts().forEach(p => { const q = partner(p); if (q) q.mirror_link = null; p.mirror_link = null; });
  } else if (name === 'mirror') {
    let n = 0;
    ds.forEach(p => { if (!partner(p) && Math.abs(p.x) >= CENTRE_EPS) { makePartner(p); n++; } });
    if (!n) toast('Mirrors need parts off the centre line without a partner.');
  }
  changed(); refresh();
}
function duplicate() {
  const ps = selParts();
  const map = new Map(), copies = [];
  ps.forEach(p => {
    const q = Object.assign(clone(p), { _uid: uid(), locked: false, z: p.z });
    map.set(p, q); copies.push(q);
  });
  const off = prefs.gridSize > 0 ? prefs.gridSize * 4 : 20;
  const links = new Set(design.parts.map(p => p.mirror_link)), groups = new Map();
  const usedGroups = new Set(design.parts.map(p => p.group));
  copies.forEach((q, i) => {
    const p = ps[i];
    q.y = round(q.y + off);
    if (Math.abs(p.x) >= CENTRE_EPS && !(partner(p) && map.has(partner(p)))) q.x = round(q.x + (p.x > 0 ? off : -off));
    if (p.group) { if (!groups.has(p.group)) { const g = newTag('g', usedGroups); usedGroups.add(g); groups.set(p.group, g); } q.group = groups.get(p.group); }
    q.mirror_link = null;
  });
  ps.forEach(p => {
    const q = partner(p);
    if (q && map.has(q) && !map.get(p).mirror_link) { const l = newTag('m', links); links.add(l); map.get(p).mirror_link = l; map.get(q).mirror_link = l; }
  });
  const top = maxZ();
  sortedParts().filter(p => map.has(p)).forEach((p, i) => { map.get(p).z = top + 1 + i; });
  copies.forEach(q => { design.parts.push(q); index.set(q._uid, { kind: 'part', obj: q }); });
  if (mirrorOn()) copies.forEach(q => { if (!q.mirror_link && Math.abs(q.x) >= CENTRE_EPS) makePartner(q); });
  syncMirrors(drivers(copies));
  selection = new Set(copies.map(q => q._uid));
}
// Re-stack: the selection and its mirror partners move together; z is renumbered 1..n bottom to top.
function reorder(kind) {
  const chosen = new Set();
  selParts().forEach(p => { chosen.add(p); const q = partner(p); if (q) chosen.add(q); });
  let arr = sortedParts();
  const sel = p => chosen.has(p);
  if (kind === 'front') arr = arr.filter(p => !sel(p)).concat(arr.filter(sel));
  else if (kind === 'bottom') arr = arr.filter(sel).concat(arr.filter(p => !sel(p)));
  else if (kind === 'fwd') { for (let i = arr.length - 2; i >= 0; i--) if (sel(arr[i]) && !sel(arr[i + 1])) [arr[i], arr[i + 1]] = [arr[i + 1], arr[i]]; }
  else if (kind === 'back') { for (let i = 1; i < arr.length; i++) if (sel(arr[i]) && !sel(arr[i - 1])) [arr[i], arr[i - 1]] = [arr[i - 1], arr[i]]; }
  arr.forEach((p, i) => { p.z = i + 1; });
}
function deleteSelection() {
  if (!selection.size) return;
  const doomed = new Set();
  selParts().forEach(p => { if (p.locked) return; doomed.add(p); const q = partner(p); if (q && !q.locked) doomed.add(q); });
  const dropped = selParts().length - [...doomed].filter(p => selection.has(p._uid)).length;
  commit();
  design.parts = design.parts.filter(p => !doomed.has(p));
  ['hardpoints', 'engines', 'lights'].forEach(k => { design[k] = design[k].filter(m => !selection.has(m._uid)); });
  selection = new Set();
  if (dropped > 0) toast('Locked parts stay. Unlock them to delete.');
  changed(); refresh();
}
function nudge(dx, dy) {
  commit(); moveSelection(dx, dy); changed(); refresh();
}

// ---------- pointer ----------
const pointers = new Map();
function pinchDist() { const p = [...pointers.values()]; return Math.hypot(p[0].x - p[1].x, p[0].y - p[1].y) || 1; }
cv.addEventListener('pointerdown', ev => {
  cv.focus({ preventScroll: true });
  cv.setPointerCapture(ev.pointerId);
  pointers.set(ev.pointerId, { x: ev.offsetX, y: ev.offsetY });
  if (pointers.size === 2) { drag = { kind: 'pinch', d0: pinchDist(), z0: view.zoom }; return; }
  const sx = ev.offsetX, sy = ev.offsetY;
  if (ev.button === 1 || ev.button === 2 || spaceDown) { drag = { kind: 'pan', sx, sy, px: view.panX, py: view.panY }; return; }
  const [ax, ay] = toDesign(sx, sy);
  if (tool === 'select') {
    const hh = hitHandle(sx, sy);
    if (hh) { startTransform(hh, sx, sy); return; }
  }
  const mk = pickMarker(sx, sy);
  const target = mk || (tool === 'select' ? pickPart(ax, ay) : null);
  if (target) {
    const ids = ev.altKey ? [target] : groupOf(target);
    let reselect = false;
    if (ev.shiftKey) {
      if (selection.has(target)) { ids.forEach(u => selection.delete(u)); refresh(false); drag = null; return; }
      ids.forEach(u => selection.add(u));
    } else if (!selection.has(target)) selection = new Set(ids);
    else reselect = true;
    startMove(ax, ay, sx, sy, reselect ? ids : null);
    refresh(false); return;
  }
  if (tool === 'select') {
    if (!ev.shiftKey) selection = new Set();
    drag = { kind: 'marquee', sx, sy, cx: sx, cy: sy, base: new Set(selection) };
    refresh(false); return;
  }
  placeMarker(snap(ax, ev), snap(ay, ev));
});
function startMove(ax, ay, sx, sy, reselect) {
  const ds = drivers();
  const marks = ['hp', 'eng', 'light'].flatMap(kind => selOf(kind).map(m => ({ m, kind, x: m.x, y: m.y, q: markerPartner(kind, m) })));
  const anchor = ds[0] ? [ds[0].x, ds[0].y] : marks[0] ? [marks[0].x, marks[0].y] : [ax, ay];
  drag = {
    kind: 'move', ax, ay, sx, sy, moved: false, snapshot: snapshot(), reselect, anchor,
    parts: ds.map(p => ({ p, x: p.x, y: p.y, centred: mirrorOn() && !p.mirror_link && Math.abs(p.x) < CENTRE_EPS, auto: null })), marks
  };
}
function startTransform(hh, sx, sy) {
  const ds = drivers();
  const centre = ds.length === 1 ? [ds[0].x, ds[0].y] : hh.hd.centre;
  const [cx, cy] = toScreen(...centre);
  drag = {
    kind: hh.kind, sx, sy, centre, cs: [cx, cy], moved: false, snapshot: snapshot(),
    a0: Math.atan2(sy - cy, sx - cx), d0: Math.max(4, Math.hypot(sx - cx, sy - cy)),
    base: new Map(ds.map(p => [p, { x: p.x, y: p.y, rot: p.rot, scale: p.scale }])), ds
  };
}
function beginEdit() { if (!drag.moved) { history.push(drag.snapshot); future = []; updateUndo(); drag.moved = true; } }
cv.addEventListener('pointermove', ev => {
  if (pointers.has(ev.pointerId)) pointers.set(ev.pointerId, { x: ev.offsetX, y: ev.offsetY });
  const sx = ev.offsetX, sy = ev.offsetY;
  const [ax, ay] = toDesign(sx, sy);
  cursor = [ax, ay]; cursor.ev = { altKey: ev.altKey };
  updateReadout(ax, ay, ev);
  if (!drag) { draw(); updateCursor(sx, sy); return; }
  if (drag.kind === 'pinch' && pointers.size === 2) { view.zoom = clamp(drag.z0 * pinchDist() / drag.d0, 0.02, 8); draw(); return; }
  if (drag.kind === 'pan') { view.panX = drag.px + sx - drag.sx; view.panY = drag.py + sy - drag.sy; draw(); return; }
  if (drag.kind === 'marquee') {
    drag.cx = sx; drag.cy = sy;
    const [x0, y0] = toDesign(Math.min(drag.sx, sx), Math.min(drag.sy, sy)), [x1, y1] = toDesign(Math.max(drag.sx, sx), Math.max(drag.sy, sy));
    const inside = (x, y) => x >= x0 && x <= x1 && y >= y0 && y <= y1;
    const s = new Set(drag.base);
    design.parts.forEach(p => { if (!p.hidden && !p.locked && inside(p.x, p.y)) groupOf(p._uid).forEach(u => s.add(u)); });
    if (prefs.markers) [...design.hardpoints, ...design.engines, ...design.lights].forEach(m => { if (inside(m.x, m.y)) s.add(m._uid); });
    selection = s; draw(); return;
  }
  if (drag.kind === 'move') {
    if (!drag.moved && Math.hypot(sx - drag.sx, sy - drag.sy) < 3) return;
    beginEdit();
    const nx = snap(drag.anchor[0] + ax - drag.ax, ev), ny = snap(drag.anchor[1] + ay - drag.ay, ev);
    const dx = nx - drag.anchor[0], dy = ny - drag.anchor[1];
    drag.parts.forEach(d => { d.p.x = round(d.x + dx); d.p.y = round(d.y + dy); });
    syncMirrors(drag.parts.map(d => d.p));
    // A part dragged off the centre line with mirror on gets a partner; back on the line, it goes.
    drag.parts.forEach(d => {
      if (!d.centred) return;
      if (Math.abs(d.p.x) >= CENTRE_EPS && !d.auto) d.auto = makePartner(d.p);
      else if (Math.abs(d.p.x) < CENTRE_EPS && d.auto) { design.parts = design.parts.filter(p => p !== d.auto); index.delete(d.auto._uid); d.auto = null; d.p.mirror_link = null; }
    });
    drag.marks.forEach(d => {
      d.m.x = round(d.x + dx); d.m.y = round(d.y + dy);
      if (d.q && !selection.has(d.q._uid)) { d.q.x = -d.m.x; d.q.y = d.m.y; }
    });
    changed(); draw(); syncSelection(); scheduleHeavy(160); return;
  }
  if (drag.kind === 'rotate' || drag.kind === 'scale') {
    beginEdit();
    const [cx, cy] = drag.cs;
    if (drag.kind === 'rotate') {
      let deg = -(Math.atan2(sy - cy, sx - cx) - drag.a0) * 180 / Math.PI;
      if (ev.shiftKey) {
        if (drag.ds.length === 1) { const b = drag.base.get(drag.ds[0]); deg = Math.round((b.rot + deg) / 15) * 15 - b.rot; }
        else deg = Math.round(deg / 15) * 15;
      }
      rotateParts(drag.ds, deg, drag.centre, drag.base);
    } else {
      let f = Math.hypot(sx - cx, sy - cy) / drag.d0;
      drag.ds.forEach(p => {
        const b = drag.base.get(p);
        let sc = clamp(b.scale * f, 0.02, 20);
        sc = ev.shiftKey ? Math.round(sc * 20) / 20 : Math.round(sc * 100) / 100;
        if (drag.ds.length === 1) f = sc / b.scale;
        p.scale = sc;
      });
      drag.ds.forEach(p => { const b = drag.base.get(p); p.x = round(drag.centre[0] + (b.x - drag.centre[0]) * f); p.y = round(drag.centre[1] + (b.y - drag.centre[1]) * f); });
      syncMirrors(drag.ds);
    }
    changed(); draw(); syncSelection(); scheduleHeavy(160);
  }
});
function endPointer(ev) {
  pointers.delete(ev.pointerId);
  if (drag && drag.kind === 'move' && !drag.moved && drag.reselect) selection = new Set(drag.reselect);
  const wasEdit = drag && drag.moved, wasMarquee = drag && drag.kind === 'marquee';
  if (pointers.size === 0) drag = null;
  if (wasEdit || wasMarquee) refresh(); else if (!drag) refresh(false);
}
cv.addEventListener('pointerup', endPointer);
cv.addEventListener('pointercancel', endPointer);
cv.addEventListener('pointerleave', () => { cursor = null; if (!drag) draw(); });
cv.addEventListener('contextmenu', ev => ev.preventDefault());
cv.addEventListener('wheel', ev => { ev.preventDefault(); zoomAt(Math.exp(-ev.deltaY * 0.0015), ev.offsetX, ev.offsetY); }, { passive: false });
function updateCursor(sx, sy) {
  if (spaceDown) { cv.style.cursor = 'grab'; return; }
  if (tool !== 'select') { cv.style.cursor = 'crosshair'; return; }
  const hh = hitHandle(sx, sy);
  cv.style.cursor = hh ? (hh.kind === 'rotate' ? 'grab' : 'nwse-resize') : 'default';
}
function updateReadout(ax, ay, ev) {
  const x = snap(ax, ev), y = snap(ay, ev), f = spriteFrame(), u = units();
  $('rCursor').textContent = `x ${x.toFixed(1)}  y ${y.toFixed(1)}`;
  $('rGame').textContent = f ? `game ${(x / u).toFixed(1)}, ${((y - f.cy) / u).toFixed(1)} px` : '';
}

// ---------- keyboard ----------
const KEYS = [
  ['V', 'Select tool'], ['H', 'Hardpoint tool'], ['E', 'Engine exhaust tool'], ['L', 'Light tool'], ['M', 'Mirror mode on/off'],
  ['G', 'Grid on/off'], ['S', 'Snap on/off (hold Alt while dragging to place freely)'], ['B', 'Cycle canvas background'],
  ['Click / Shift-click', 'Select / add or remove (a group selects whole; Alt-click picks one part)'], ['Drag on empty canvas', 'Marquee select (Shift adds)'],
  ['Arrows', 'Nudge one grid step (1 unit without snap); Shift ×10'], ['R / Shift+R', 'Rotate 90° clockwise / counter-clockwise'],
  ['Rotate handle', 'Free rotation; hold Shift to snap to 15°'], ['Scale handle', 'Uniform scale; hold Shift for 0.05 steps'],
  ['F / Shift+F', 'Flip horizontally / vertically'], ['Ctrl+D', 'Duplicate'], [']  /  [', 'Bring forward / send backward'],
  ['Shift+]  /  Shift+[', 'Bring to front / send to back'], ['K', 'Lock or unlock'], ['Ctrl+G / Ctrl+Shift+G', 'Group / ungroup'],
  ['U', 'Break the mirror link'], ['Delete / Backspace', 'Delete (a part takes its mirror partner with it)'], ['Ctrl+A', 'Select all parts'],
  ['Escape', 'Clear the selection'], ['Ctrl+Z / Ctrl+Shift+Z or Ctrl+Y', 'Undo / redo'], ['Ctrl+S / Ctrl+O', 'Save / open design'],
  ['Space-drag, right-drag or middle-drag', 'Pan'], ['Wheel', 'Zoom'], ['0', 'Fit the design in view'], ['?', 'This list']
];
window.addEventListener('keydown', ev => {
  const mod = ev.ctrlKey || ev.metaKey, k = ev.key.toLowerCase();
  if (!$('keysModal').hidden || !$('confirmModal').hidden) { if (k === 'escape') { $('keysModal').hidden = true; $('confirmModal').hidden = true; } return; }
  if (mod && k === 's') { ev.preventDefault(); saveDesign(); return; }
  if (mod && k === 'o') { ev.preventDefault(); $('fDesign').click(); return; }
  if (typing()) return;
  if (mod && k === 'z') { ev.preventDefault(); ev.shiftKey ? redo() : undo(); return; }
  if (mod && k === 'y') { ev.preventDefault(); redo(); return; }
  if (mod && k === 'd') { ev.preventDefault(); act('dup'); return; }
  if (mod && k === 'g') { ev.preventDefault(); act(ev.shiftKey ? 'ungroup' : 'group'); return; }
  if (mod && k === 'a') { ev.preventDefault(); selection = new Set(design.parts.filter(p => !p.hidden && !p.locked).map(p => p._uid)); refresh(false); return; }
  if (mod) return;
  if (ev.key === ' ') { spaceDown = true; cv.style.cursor = 'grab'; ev.preventDefault(); return; }
  if (k === 'v') setTool('select');
  else if (k === 'h') setTool('hardpoint');
  else if (k === 'e') setTool('engine');
  else if (k === 'l') setTool('light');
  else if (k === 'm') togglePref('mirror');
  else if (k === 'g') togglePref('grid');
  else if (k === 's') togglePref('snap');
  else if (k === 'b') { const o = ['dark', 'checker', 'light']; prefs.bg = o[(o.indexOf(prefs.bg) + 1) % o.length]; syncPrefs(); draw(); renderPreview(); persist(); }
  else if (k === '0') fitView();
  else if (ev.key === '?') openKeys();
  else if (k === 'escape') { selection = new Set(); refresh(false); }
  else if (k === 'delete' || k === 'backspace') { ev.preventDefault(); deleteSelection(); }
  else if (k === 'r') act(ev.shiftKey ? 'rotL' : 'rotR');
  else if (k === 'f') act(ev.shiftKey ? 'flipV' : 'flipH');
  else if (k === 'k') act('lock');
  else if (k === 'u') act('unlink');
  else if (ev.key === ']' || ev.key === '}') act(ev.shiftKey ? 'front' : 'fwd');
  else if (ev.key === '[' || ev.key === '{') act(ev.shiftKey ? 'bottom' : 'back');
  else if (selection.size && ev.key.startsWith('Arrow')) {
    ev.preventDefault();
    const step = (prefs.snap && prefs.gridSize > 0 ? prefs.gridSize : 1) * (ev.shiftKey ? 10 : 1);
    nudge(ev.key === 'ArrowLeft' ? -step : ev.key === 'ArrowRight' ? step : 0, ev.key === 'ArrowUp' ? -step : ev.key === 'ArrowDown' ? step : 0);
  }
});
window.addEventListener('keyup', ev => { if (ev.key === ' ') { spaceDown = false; cv.style.cursor = tool === 'select' ? 'default' : 'crosshair'; } });
function setTool(t) {
  tool = t;
  document.querySelectorAll('[data-tool]').forEach(b => b.setAttribute('aria-pressed', String(b.dataset.tool === t)));
  cv.style.cursor = t === 'select' ? 'default' : 'crosshair';
  draw();
}
function togglePref(k) { prefs[k] = !prefs[k]; syncPrefs(); draw(); persist(); }
function syncPrefs() {
  $('tMirror').setAttribute('aria-pressed', String(prefs.mirror));
  $('tGrid').setAttribute('aria-pressed', String(prefs.grid));
  $('tSnap').setAttribute('aria-pressed', String(prefs.snap));
  $('tMarkers').setAttribute('aria-pressed', String(prefs.markers));
  if (document.activeElement !== $('tGridSize')) $('tGridSize').value = prefs.gridSize;
  $('tBg').value = prefs.bg;
  $('preview').classList.toggle('collapsed', !prefs.preview);
  $('pToggle').textContent = prefs.preview ? 'Hide' : 'Show';
  const pb = document.querySelector('.preview .pb');
  pb.style.background = prefs.bg === 'checker' ? 'repeating-conic-gradient(#1b1d21 0% 25%, #26292e 0% 50%) 0 0 / 12px 12px' : (BG[prefs.bg] || BG.dark);
}
function openKeys() {
  const l = $('keysList'); l.innerHTML = '';
  KEYS.forEach(([k, v]) => { const a = document.createElement('kbd'); a.textContent = k; const b = document.createElement('span'); b.textContent = v; l.append(a, b); });
  $('keysModal').hidden = false; $('keysClose').focus();
}

// ---------- inspector ----------
const setVal = (id, v) => { const el = $(id); if (document.activeElement !== el) el.value = v; };
function syncDesignFields() {
  setVal('dName', design.name); setVal('dTitle', design.display_name || ''); setVal('dUnits', design.units_per_game_px);
  $('dKit').value = design.kit || '';
  const f = spriteFrame();
  $('dSize').value = f ? `${f.sizePx[0]} × ${f.sizePx[1]}` : '—';
  $('designTag').textContent = (design.name || 'unsaved design') + (design.display_name ? ' · ' + design.display_name : '') + (kit ? `  ·  kit ${kit.kit} v${kit.version}` : '');
  setVal('hW', round(design.hit.size[0])); setVal('hL', round(design.hit.size[1])); setVal('hOx', round(design.hit.offset[0])); setVal('hOy', round(design.hit.offset[1]));
}
function syncSelection() {
  const items = [...selection].map(u => index.get(u)).filter(Boolean);
  const parts = items.filter(i => i.kind === 'part').map(i => i.obj);
  const one = items.length === 1 ? items[0] : null;
  $('selNone').hidden = items.length > 0;
  $('bDel').hidden = !items.length;
  $('selPart').hidden = !(one && one.kind === 'part');
  $('selMulti').hidden = !(parts.length > 1 || (parts.length && items.length > parts.length));
  $('partActions').hidden = !parts.length;
  $('selHp').hidden = !(one && one.kind === 'hp');
  $('selEng').hidden = !(one && one.kind === 'eng');
  $('selLight').hidden = !(one && one.kind === 'light');
  if (!items.length) { $('selTitle').textContent = 'Selection'; return; }
  if (!one) {
    $('selTitle').textContent = `${items.length} selected`;
    const kinds = { part: 'parts', hp: 'hardpoints', eng: 'engines', light: 'lights' };
    const counts = Object.keys(kinds).map(k => [k, items.filter(i => i.kind === k).length]).filter(x => x[1]).map(([k, n]) => `${n} ${kinds[k]}`);
    $('mInfo').textContent = counts.join(', ') + '. Move, rotate or scale them together; mirror partners follow.';
    if (parts.length) { setVal('mShadow', parts.every(p => p.shadow === parts[0].shadow) ? parts[0].shadow : ''); $('mGlow').value = 'keep'; }
    return;
  }
  const o = one.obj;
  if (one.kind === 'part') {
    $('selTitle').textContent = `Part ${partLabel(o)}`;
    setVal('pLabel', o.label || ''); $('pPart').value = o.part;
    setVal('pX', round(o.x)); setVal('pY', round(o.y)); setVal('pRot', round(o.rot)); setVal('pScale', round(o.scale));
    setVal('pZ', o.z); setVal('pShadow', round(o.shadow)); $('pGlow').value = o.glow || '';
    $('pFlipX').checked = o.flipX; $('pFlipY').checked = o.flipY;
    ['pLabel', 'pX', 'pY', 'pRot', 'pScale', 'pZ', 'pShadow', 'pGlow', 'pFlipX', 'pFlipY'].forEach(id => { $(id).disabled = o.locked && id !== 'pLabel'; });
    const k = kitPart(o.part), q = partner(o), bits = [];
    if (k) bits.push(`${k.category || 'misc'} · ${k.w} × ${k.h} units`);
    if (k && k.note) bits.push(k.note);
    if (q) bits.push(`Mirror-linked to ${partLabel(q)} (${o.mirror_link}).`);
    if (o.group) bits.push(`In group ${o.group}.`);
    if (o.locked) bits.push('Locked: unlock (K) to edit.');
    $('pInfo').textContent = bits.join(' ');
  } else if (one.kind === 'hp') {
    $('selTitle').textContent = `Hardpoint ${o.id || ''}`;
    setVal('sId', o.id); $('sMount').value = o.mount; $('sSize').value = o.size;
    setVal('sX', round(o.x)); setVal('sY', round(o.y)); setVal('sFacing', o.facing || 0);
    const aims = H.aims(o.mount);
    $('sArc').disabled = !aims; $('sTrav').disabled = !aims;
    $('sArc').placeholder = aims ? String(H.ARC_DEFAULT[o.mount]) : 'n/a';
    $('sTrav').placeholder = aims ? String(H.TRAV_DEFAULT[o.mount]) : 'n/a';
    setVal('sArc', o.arc != null ? o.arc : ''); setVal('sTrav', o.traverse != null ? o.traverse : '');
    $('sCells').disabled = o.mount !== 'launcher'; setVal('sCells', o.cells != null ? o.cells : '');
    $('sRole').value = o.role || ''; setVal('sPart', o.part || '');
    $('sHint').textContent = H.HINTS[o.mount];
  } else if (one.kind === 'eng') {
    $('selTitle').textContent = `Engine E${design.engines.indexOf(o) + 1}`;
    setVal('eX', round(o.x)); setVal('eY', round(o.y)); setVal('eDir', o.dir); setVal('eSize', o.size);
  } else {
    $('selTitle').textContent = `Light ${design.lights.indexOf(o) + 1}`;
    setVal('lX', round(o.x)); setVal('lY', round(o.y)); $('lColour').value = /^#[0-9a-f]{6}$/i.test(o.colour) ? o.colour : '#ffffff';
  }
}
let layerDrag = null;
function renderLayers() {
  const el = $('layers'); el.innerHTML = '';
  const arr = sortedParts().reverse();
  $('layerCount').textContent = arr.length;
  if (!arr.length) { el.innerHTML = '<div class="empty">No parts yet.</div>'; return; }
  arr.forEach(p => {
    const k = kitPart(p.part);
    const r = document.createElement('div');
    r.className = 'layer' + (selection.has(p._uid) ? ' sel' : '') + (p.hidden ? ' hiddenpart' : '');
    r.draggable = true; r.tabIndex = 0;
    const eye = document.createElement('button'); eye.type = 'button'; eye.className = 'ic' + (p.hidden ? '' : ' on'); eye.textContent = p.hidden ? '◌' : '●'; eye.title = p.hidden ? 'Show' : 'Hide';
    eye.onclick = e => { e.stopPropagation(); commit(); p.hidden = !p.hidden; syncMirrors([p]); changed(); refresh(); };
    const lock = document.createElement('button'); lock.type = 'button'; lock.className = 'ic' + (p.locked ? ' on' : ''); lock.textContent = p.locked ? '🔒' : '🔓'; lock.title = p.locked ? 'Unlock' : 'Lock';
    lock.onclick = e => { e.stopPropagation(); commit(); p.locked = !p.locked; changed(); refresh(); };
    const im = document.createElement('img'); im.alt = ''; if (k && k.url) im.src = k.url;
    const nm = document.createElement('span'); nm.className = 'nm'; nm.textContent = partLabel(p);
    if (p.label) { const s = document.createElement('small'); s.textContent = p.part; nm.appendChild(s); }
    const meta = document.createElement('span'); meta.className = 'meta';
    meta.textContent = [p.mirror_link ? '⇋' + p.mirror_link : '', p.group || '', 'z' + p.z].filter(Boolean).join(' ');
    r.append(eye, lock, im, nm, meta);
    r.onclick = ev => {
      if (ev.shiftKey) { selection.has(p._uid) ? selection.delete(p._uid) : selection.add(p._uid); }
      else selection = new Set([p._uid]);
      refresh(false);
    };
    nm.ondblclick = ev => {
      ev.stopPropagation();
      const inp = document.createElement('input'); inp.value = p.label || ''; inp.placeholder = p.part;
      nm.replaceWith(inp); inp.focus(); inp.select();
      let done = false;
      const finish = ok => { if (done) return; done = true; if (ok && (inp.value.trim() || null) !== p.label) { commit(); p.label = inp.value.trim() || null; changed(); } refresh(); };
      inp.onkeydown = e => { e.stopPropagation(); if (e.key === 'Enter') finish(true); else if (e.key === 'Escape') finish(false); };
      inp.onblur = () => finish(true);
    };
    r.ondragstart = ev => { layerDrag = p; ev.dataTransfer.effectAllowed = 'move'; ev.dataTransfer.setData('text/plain', 'layer:' + p._uid); };
    r.ondragover = ev => {
      if (!layerDrag) return;
      ev.preventDefault();
      const below = ev.offsetY > r.clientHeight / 2;
      el.querySelectorAll('.dragover').forEach(x => x.classList.remove('dragover', 'below'));
      r.classList.add('dragover'); r.classList.toggle('below', below);
    };
    r.ondragleave = () => r.classList.remove('dragover', 'below');
    r.ondrop = ev => {
      ev.preventDefault(); ev.stopPropagation();
      if (!layerDrag || layerDrag === p) { layerDrag = null; refresh(false); return; }
      const below = ev.offsetY > r.clientHeight / 2;
      commit();
      const list = sortedParts().reverse().filter(x => x !== layerDrag);   // top first
      list.splice(list.indexOf(p) + (below ? 1 : 0), 0, layerDrag);
      list.reverse().forEach((x, i) => { x.z = i + 1; });
      layerDrag = null; changed(); refresh();
    };
    r.ondragend = () => { layerDrag = null; el.querySelectorAll('.dragover').forEach(x => x.classList.remove('dragover', 'below')); };
    el.appendChild(r);
  });
}
function renderMarkerLists() {
  const row = (el, idText, colourVar, desc, pos, u, swatch) => {
    const r = document.createElement('div');
    r.className = 'row' + (selection.has(u) ? ' sel' : ''); r.tabIndex = 0;
    r.innerHTML = '<span class="id"></span><i class="sw"></i><span></span><span class="pos"></span>';
    r.children[0].textContent = idText; r.children[1].style.background = swatch || `var(${colourVar})`;
    r.children[2].textContent = desc; r.children[3].textContent = pos;
    r.onclick = ev => { if (ev.shiftKey) { selection.has(u) ? selection.delete(u) : selection.add(u); } else selection = new Set([u]); refresh(false); };
    r.onkeydown = ev => { if (ev.key === 'Enter') r.onclick(ev); };
    el.appendChild(r);
  };
  const fmt = (x, y) => `${round(x)}, ${round(y)}`;
  const hl = $('hpList'); hl.innerHTML = '';
  if (!design.hardpoints.length) hl.innerHTML = '<div class="empty">No hardpoints. Choose Hardpoint (H) and click the hull.</div>';
  design.hardpoints.forEach(hp => row(hl, hp.id || '?', '--m-' + hp.mount, `${hp.size} ${hp.role === 'point_defence' ? 'PD ' : ''}${hp.mount}`, fmt(hp.x, hp.y), hp._uid));
  const el = $('engList'); el.innerHTML = '';
  if (!design.engines.length) el.innerHTML = '<div class="empty">No engines. Choose Engine (E) and click each exhaust.</div>';
  design.engines.forEach((e, i) => row(el, 'E' + (i + 1), '--m-engine', `exhaust ${e.dir}°${e.size !== 1 ? ' ×' + e.size : ''}`, fmt(e.x, e.y), e._uid));
  const ll = $('lightList'); ll.innerHTML = '';
  if (!design.lights.length) ll.innerHTML = '<div class="empty">No lights (optional). Choose Light (L) to add nav or beacon lights.</div>';
  design.lights.forEach((l, i) => row(ll, 'L' + (i + 1), '--m-light', l.colour, fmt(l.x, l.y), l._uid, l.colour));
  $('hpCount').textContent = design.hardpoints.length; $('engCount').textContent = design.engines.length; $('lightCount').textContent = design.lights.length;
}
function refresh(full = true) {
  rebuildIndex();
  draw(); syncDesignFields(); syncSelection(); renderLayers(); renderMarkerLists();
  scheduleHeavy(full ? 0 : 60);
}
let heavyTimer = null;
function scheduleHeavy(ms) { clearTimeout(heavyTimer); heavyTimer = setTimeout(runHeavy, ms); }
function runHeavy() {
  renderPreview();
  renderChecks();
  $('hullJson').textContent = H.manifestText(hullFromDesign());
  syncDesignFields();
  persist();
}
function renderPreview() {
  const u = units(), c1 = composeSprite(1 / u), c3 = composeSprite(3 / u);
  [['pv1', c1, 'pv1Cap', '1:1 game px'], ['pv3', c3, 'pv3Cap', '3×']].forEach(([id, src, cap, label]) => {
    const c = $(id);
    if (!src) { c.width = 1; c.height = 1; c.style.width = c.style.height = '0px'; $(cap).textContent = label; return; }
    c.width = src.width; c.height = src.height; c.style.width = src.width + 'px'; c.style.height = src.height + 'px';
    const g = c.getContext('2d'); g.clearRect(0, 0, c.width, c.height); g.drawImage(src, 0, 0);
    $(cap).textContent = `${label}  ${src.width} × ${src.height}`;
  });
}

// ---------- inspector wiring ----------
function bind(id, fn, evName = 'change') {
  $(id).addEventListener(evName, () => { const el = $(id); commit(); fn(el.type === 'checkbox' ? el.checked : el.type === 'number' ? (el.value === '' ? null : parseFloat(el.value)) : el.value); changed(); refresh(); });
}
const one = kind => { const it = selection.size === 1 ? index.get([...selection][0]) : null; return it && it.kind === kind ? it.obj : null; };
bind('dName', v => { design.name = v.trim(); });
bind('dTitle', v => { if (v.trim()) design.display_name = v.trim(); else delete design.display_name; });
bind('dUnits', v => { if (v > 0) design.units_per_game_px = v; });
const partEdit = fn => v => { const p = one('part'); if (!p || p.locked) return; fn(p, v); syncMirrors([p]); };
bind('pLabel', v => { const p = one('part'); if (p) p.label = v.trim() || null; });
bind('pX', partEdit((p, v) => { p.x = round(v || 0); }));
bind('pY', partEdit((p, v) => { p.y = round(v || 0); }));
bind('pRot', partEdit((p, v) => { p.rot = normRot(v || 0); }));
bind('pScale', partEdit((p, v) => { if (v > 0) p.scale = round(v); }));
bind('pZ', v => { const p = one('part'); if (p && v != null) p.z = Math.round(v); });
bind('pShadow', partEdit((p, v) => { p.shadow = round(clamp(v == null ? DEFAULT_SHADOW : v, 0, 1)); }));
bind('pGlow', partEdit((p, v) => { p.glow = v || null; }));
bind('pFlipX', partEdit((p, v) => { p.flipX = v; }));
bind('pFlipY', partEdit((p, v) => { p.flipY = v; }));
bind('mShadow', v => { if (v == null) return; const ds = drivers(); ds.forEach(p => { p.shadow = round(clamp(v, 0, 1)); }); syncMirrors(ds); });
bind('mGlow', v => { if (v === 'keep') return; const ds = drivers(); ds.forEach(p => { p.glow = v || null; }); syncMirrors(ds); });
document.querySelectorAll('[data-act]').forEach(b => { b.onclick = () => act(b.dataset.act); });
// hardpoint fields (as tools/hardpoint-editor)
H.MOUNTS.forEach(m => { [$('tMount'), $('sMount')].forEach(s => { const o = document.createElement('option'); o.value = m; o.textContent = m[0].toUpperCase() + m.slice(1); s.appendChild(o); }); });
H.SIZES.forEach(m => { [$('tSize'), $('sSize')].forEach(s => { const o = document.createElement('option'); o.value = m; o.textContent = m[0].toUpperCase() + m.slice(1); s.appendChild(o); }); });
$('tMount').value = 'turret'; $('tSize').value = 'small';
const hpEdit = fn => v => { const h = one('hp'); if (h) fn(h, v); };
bind('sId', hpEdit((h, v) => { h.id = v.trim(); }));
bind('sMount', hpEdit((h, v) => {
  const old = h.mount; h.mount = v;
  if (new RegExp('^' + H.PREFIX[old] + '\\d+$').test(h.id)) h.id = H.nextId(h.mount, new Set(design.hardpoints.filter(x => x !== h).map(x => x.id)));
  if (!H.aims(h.mount)) { delete h.arc; delete h.traverse; } else if (h.arc == null || !H.aims(old)) h.arc = H.ARC_DEFAULT[h.mount];
  if (h.mount !== 'launcher') delete h.cells; else if (h.cells == null) h.cells = 4;
}));
bind('sSize', hpEdit((h, v) => { h.size = v; }));
bind('sRole', hpEdit((h, v) => { if (v) h.role = v; else delete h.role; }));
const hpMove = fn => hpEdit((h, v) => { const q = markerPartner('hp', h); fn(h, v); if (q) { q.x = -h.x; q.y = h.y; } });
bind('sX', hpMove((h, v) => { h.x = round(v || 0); }));
bind('sY', hpMove((h, v) => { h.y = round(v || 0); }));
bind('sFacing', hpEdit((h, v) => { h.facing = v || 0; }));
bind('sArc', hpEdit((h, v) => { if (v == null) delete h.arc; else h.arc = v; }));
bind('sTrav', hpEdit((h, v) => { if (v == null) delete h.traverse; else h.traverse = v; }));
bind('sCells', hpEdit((h, v) => { if (v == null) delete h.cells; else h.cells = Math.round(v); }));
bind('sPart', hpEdit((h, v) => { if (v.trim()) h.part = v.trim(); else delete h.part; }));
$('bMirrorCopy').onclick = () => {
  const h = one('hp'); if (!h) return;
  if (Math.abs(h.x) <= CENTRE_EPS) { toast('This hardpoint is on the centre line; a mirror would sit on top of it.'); return; }
  commit();
  const t = normHp(Object.assign(clone(h), { id: H.nextId(h.mount, new Set(design.hardpoints.map(x => x.id))), x: -h.x, facing: h.facing ? -h.facing : 0 }));
  design.hardpoints.push(t); selection = new Set([t._uid]); changed(); refresh();
};
const engEdit = fn => v => { const e = one('eng'); if (!e) return; const q = markerPartner('eng', e); fn(e, v); if (q) { q.x = -e.x; q.y = e.y; q.size = e.size; q.dir = norm360(360 - e.dir); } };
bind('eX', engEdit((e, v) => { e.x = round(v || 0); }));
bind('eY', engEdit((e, v) => { e.y = round(v || 0); }));
bind('eDir', engEdit((e, v) => { e.dir = norm360(v == null ? 180 : v); }));
bind('eSize', engEdit((e, v) => { if (v > 0) e.size = round(v); }));
const lightEdit = fn => v => { const l = one('light'); if (!l) return; const q = markerPartner('light', l); fn(l, v); if (q) { q.x = -l.x; q.y = l.y; } };
bind('lX', lightEdit((l, v) => { l.x = round(v || 0); }));
bind('lY', lightEdit((l, v) => { l.y = round(v || 0); }));
bind('lColour', lightEdit((l, v) => { l.colour = v; prefs.lightColour = v; }));
const hitEdit = fn => v => { fn(v == null ? 0 : v); };
bind('hW', hitEdit(v => { design.hit.size[0] = round(Math.max(0, v)); }));
bind('hL', hitEdit(v => { design.hit.size[1] = round(Math.max(0, v)); }));
bind('hOx', hitEdit(v => { design.hit.offset[0] = round(v); }));
bind('hOy', hitEdit(v => { design.hit.offset[1] = round(v); }));
$('bFit').onclick = () => {
  const sc = composeScan();
  if (!sc || !sc.tight) { toast('Place some parts first.'); return; }
  const t = sc.tight, bw = t.maxX - t.minX, bh = t.maxY - t.minY;
  commit();
  design.hit.size = [Math.round(Math.min(bw, bh)), Math.round(Math.max(bw, bh))];
  design.hit.offset = [Math.round((t.minX + t.maxX) / 2), Math.round((t.minY + t.maxY) / 2)];
  changed(); refresh();
  toast('Hit capsule fitted to the composed sprite. Trim it if ornaments stick out.');
};
$('bDel').onclick = deleteSelection;
document.querySelectorAll('[data-tool]').forEach(b => { b.onclick = () => setTool(b.dataset.tool); });
$('tMirror').onclick = () => togglePref('mirror');
$('tGrid').onclick = () => togglePref('grid');
$('tSnap').onclick = () => togglePref('snap');
$('tMarkers').onclick = () => togglePref('markers');
$('tGridSize').onchange = () => { const v = parseFloat($('tGridSize').value); if (v > 0) prefs.gridSize = v; syncPrefs(); draw(); persist(); };
$('tBg').onchange = () => { prefs.bg = $('tBg').value; syncPrefs(); draw(); persist(); };
$('tMount').onchange = draw; $('tSize').onchange = draw;
$('pToggle').onclick = () => { prefs.preview = !prefs.preview; syncPrefs(); persist(); };
$('zIn').onclick = () => { const [w, h] = stageSize(); zoomAt(1.25, w / 2, h / 2); };
$('zOut').onclick = () => { const [w, h] = stageSize(); zoomAt(0.8, w / 2, h / 2); };
$('zFit').onclick = fitView;
$('bUndo').onclick = undo; $('bRedo').onclick = redo;
$('bKeys').onclick = openKeys; $('keysClose').onclick = () => { $('keysModal').hidden = true; };
$('bNew').onclick = () => { $('confirmModal').hidden = false; $('confirmOk').focus(); };
$('confirmCancel').onclick = () => { $('confirmModal').hidden = true; };
$('confirmOk').onclick = () => { $('confirmModal').hidden = true; commit(); design = blankDesign(); selection = new Set(); changed(); refresh(); fitView(); };

// ---------- files: designs ----------
function openDesignText(text, filename) {
  let data;
  try { data = JSON.parse(text); } catch (e) { toast('That file isn\'t valid JSON.'); return; }
  if (!data || typeof data !== 'object' || Array.isArray(data)) { toast('That isn\'t a design file.'); return; }
  if (data.schema === 1 && data.hardpoints && !data.parts) { toast('That\'s a hull.json. Open a .design.json (tv-ship-design/1).'); return; }
  if (data.parts && data.parts.length && data.parts[0] && data.parts[0].file && data.kit) { toast('That\'s a kit manifest. Use Open kit folder or zip.'); return; }
  if (typeof data.format === 'string' && !data.format.startsWith('tv-ship-design/')) { toast(`Unknown format "${data.format}".`); return; }
  if (data.format && data.format !== FORMAT) toast(`This file is ${data.format}; the designer writes ${FORMAT}. Unknown fields are kept.`);
  commit();
  design = normaliseDesign(data);
  if (!design.name && filename) design.name = filename.replace(/\.design\.json$|\.json$/i, '');
  selection = new Set(); changed(); refresh(); fitView();
  if (!data.format || data.format === FORMAT) toast(`Opened ${design.name || filename}.`);
}
async function saveDesign() {
  if (typing()) document.activeElement.blur();   // commit a field still being edited
  const name = (design.name || 'untitled') + '.design.json';
  const ok = await H.saveFile(name, designText(), toast);
  if (!ok) copyText(designText(), 'design');
}
async function copyText(text, what) {
  try { await navigator.clipboard.writeText(text); toast(`Copied the ${what} to the clipboard.`); }
  catch (e) { toast('Saving and copying are blocked here.'); }
}
$('bOpen').onclick = () => $('fDesign').click();
$('fDesign').onchange = ev => { const f = ev.target.files[0]; if (f) f.text().then(t => openDesignText(t, f.name)); ev.target.value = ''; };
$('bSave').onclick = saveDesign;
$('bHull').onclick = async () => {
  runHeavy();
  const errs = lastChecks.filter(c => c.lvl === 'e').length;
  if (errs) toast(`Saving with ${errs} error${errs > 1 ? 's' : ''}; the repo check will refuse it until they're fixed.`);
  const text = H.manifestText(hullFromDesign());
  const ok = await H.saveFile('hull.json', text, errs ? null : toast);
  if (!ok) copyText(text, 'hull.json');
};
$('bCopyHull').onclick = () => copyText(H.manifestText(hullFromDesign()), 'hull.json');
$('bPng').onclick = async () => {
  const u = units(), id = design.name || 'design';
  const c1 = composeSprite(1 / u), c3 = composeSprite(3 / u);
  if (!c1) { toast('Nothing to export: place some parts first.'); return; }
  for (const [c, tag] of [[c1, 'game'], [c3, 'x3']]) {
    const blob = await new Promise(res => c.toBlob(res, 'image/png'));
    if (!blob || !await H.saveFile(`${id}_preview_${tag}.png`, blob, toast)) { toast('Saving files is blocked here.'); return; }
    await new Promise(r => setTimeout(r, 350));
  }
};

// ---------- files: the parts kit ----------
// An entry is { path, get() -> Promise<Blob|File> }. Kits come from a folder (picker, folder
// input or drop) or a zip; manifest.json can sit anywhere inside, and part files resolve beside it.
const kitUrls = [];
function baseName(p) { return p.split('/').pop().toLowerCase(); }
async function loadKit(entries, label) {
  const mans = entries.filter(e => baseName(e.path) === 'manifest.json').sort((a, b) => a.path.split('/').length - b.path.split('/').length);
  let man = null, manEntry = null;
  for (const e of mans) {
    try { const m = JSON.parse(await (await e.get()).text()); if (m && Array.isArray(m.parts)) { man = m; manEntry = e; break; } } catch (err) { /* not this one */ }
  }
  if (!man) { toast('No kit manifest.json (with a "parts" list) found there.'); return false; }
  const base = manEntry.path.slice(0, manEntry.path.length - 'manifest.json'.length);
  const byPath = new Map(entries.map(e => [e.path, e])), byName = new Map();
  entries.forEach(e => { const n = baseName(e.path); if (!byName.has(n) || e.path.startsWith(base)) byName.set(n, e); });
  const oldUrls = kitUrls.splice(0);
  const known = new Set(KNOWN_CATEGORIES.concat(Array.isArray(man.categories) ? man.categories : []));
  const parts = new Map(), missing = [];
  toast(`Loading ${man.parts.length} parts…`);
  await Promise.all(man.parts.map(async (raw, i) => {
    if (!raw || !raw.id) return;
    const file = String(raw.file || raw.id + '.png');
    const e = byPath.get(base + file) || byName.get(baseName(file));
    if (!e) { missing.push(raw.id); return; }
    try {
      const blob = await e.get(), url = URL.createObjectURL(blob);
      kitUrls.push(url);
      const img = new Image(); img.src = url; await img.decode();
      parts.set(raw.id, Object.assign({}, raw, { order: i, url, img, w: img.naturalWidth || num(raw.w, 100), h: img.naturalHeight || num(raw.h, 100),
        category: raw.category || 'misc', mirror_of: raw.mirror_of || null, glow: raw.glow || null, alpha: undefined }));
    } catch (err) { missing.push(raw.id); }
  }));
  if (!parts.size) { kitUrls.splice(0).forEach(u => URL.revokeObjectURL(u)); kitUrls.push(...oldUrls); toast('The manifest was found, but none of its part images could be read.'); return false; }
  oldUrls.forEach(u => URL.revokeObjectURL(u));
  const cats = new Map();
  [...parts.values()].sort((a, b) => a.order - b.order).forEach(p => {
    const c = known.has(p.category) ? p.category : 'misc';
    if (!cats.has(c)) cats.set(c, []);
    cats.get(c).push(p.id);
  });
  const order = KNOWN_CATEGORIES.concat(Array.isArray(man.categories) ? man.categories : []);
  const catList = [...cats.entries()].sort((a, b) => (a[0] === 'misc') - (b[0] === 'misc') || order.indexOf(a[0]) - order.indexOf(b[0]));
  kit = { kit: String(man.kit || 'kit'), version: man.version != null ? man.version : '?', units: num(man.units_per_game_px, DEFAULT_UNITS), label, parts, cats: catList, orientation: man.orientation };
  parts.forEach((p, id) => { dims[id] = { w: p.w, h: p.h, category: p.category, mirror_of: p.mirror_of, glow: p.glow }; });
  if (!design.parts.length && !design.kit) { design.kit = kit.kit; design.units_per_game_px = kit.units; }
  $('kitName').textContent = `${kit.kit} v${kit.version} · ${parts.size} parts · ${label}`;
  renderPalette();
  changed(); refresh();
  toast(`Kit ${kit.kit} v${kit.version}: ${parts.size} parts${missing.length ? `; ${missing.length} missing (${missing.slice(0, 4).join(', ')}${missing.length > 4 ? '…' : ''})` : ''}.`);
  return true;
}
function renderPalette() {
  const el = $('cats'); el.innerHTML = '';
  if (!kit) { el.innerHTML = '<div class="empty">Open the kit folder (with <span class="mono">manifest.json</span> and the part PNGs) or a zip of it. You can also drop it on the canvas.</div>'; return; }
  const q = $('search').value.trim().toLowerCase();
  let shown = 0;
  kit.cats.forEach(([cat, ids]) => {
    const hits = ids.filter(id => { const p = kit.parts.get(id); return !q || [id, p.category, p.note || '', cat].join(' ').toLowerCase().includes(q); });
    if (!hits.length) return;
    shown += hits.length;
    const det = document.createElement('details'); det.open = true;
    const sum = document.createElement('summary'); sum.innerHTML = '<span></span> <span class="n"></span>';
    sum.children[0].textContent = cat.replace(/_/g, ' '); sum.children[1].textContent = `(${hits.length})`;
    const tiles = document.createElement('div'); tiles.className = 'tiles';
    hits.forEach(id => {
      const p = kit.parts.get(id);
      const t = document.createElement('div'); t.className = 'tile'; t.draggable = true; t.tabIndex = 0;
      t.title = `${id} · ${p.category} · ${p.w}×${p.h}${p.mirror_of ? ' · mirror of ' + p.mirror_of : ''}${p.glow ? ' · glow ' + p.glow : ''}${p.note ? '\n' + p.note : ''}\nClick to add at the view centre, or drag onto the canvas.`;
      const im = document.createElement('img'); im.src = p.url; im.alt = id;
      const s = document.createElement('span'); s.textContent = id;
      t.append(im, s);
      t.ondragstart = ev => { ev.dataTransfer.setData('application/x-tv-part', id); ev.dataTransfer.setData('text/plain', id); ev.dataTransfer.effectAllowed = 'copy'; };
      const add = () => { const [w, h] = stageSize(); const [x, y] = toDesign(w / 2, h / 2); placePart(id, x, y); };
      t.onclick = add;
      t.onkeydown = ev => { if (ev.key === 'Enter' || ev.key === ' ') { ev.preventDefault(); add(); } };
      tiles.appendChild(t);
    });
    det.append(sum, tiles); el.appendChild(det);
  });
  if (!shown) el.innerHTML = '<div class="empty">No parts match.</div>';
}
$('search').addEventListener('input', renderPalette);

// Folder from the File System Access API (Chrome); the handle is kept so "Reopen kit" works next time.
async function walkHandle(dir, prefix = '', depth = 0, out = []) {
  for await (const [name, h] of dir.entries()) {
    if (name.startsWith('.') || name === 'node_modules') continue;
    if (h.kind === 'file') out.push({ path: prefix + name, get: () => h.getFile() });
    else if (depth < 4) await walkHandle(h, prefix + name + '/', depth + 1, out);
  }
  return out;
}
const idb = {
  open() { return new Promise((res, rej) => { const r = indexedDB.open('tv-ship-designer', 1); r.onupgradeneeded = () => r.result.createObjectStore('kv'); r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); }); },
  async get(k) { const db = await idb.open(); return new Promise((res, rej) => { const t = db.transaction('kv').objectStore('kv').get(k); t.onsuccess = () => res(t.result); t.onerror = () => rej(t.error); }); },
  async set(k, v) { const db = await idb.open(); return new Promise((res, rej) => { const t = db.transaction('kv', 'readwrite').objectStore('kv').put(v, k); t.onsuccess = () => res(); t.onerror = () => rej(t.error); }); }
};
async function openKitHandle(h) {
  try {
    if (h.queryPermission && (await h.queryPermission({ mode: 'read' })) !== 'granted' && (await h.requestPermission({ mode: 'read' })) !== 'granted') { toast('Permission to read the kit folder was refused.'); return; }
    const ok = await loadKit(await walkHandle(h), h.name);
    if (ok) { try { await idb.set('kitHandle', h); } catch (e) { /* no IndexedDB: Reopen won't be offered */ } $('bKitAgain').hidden = true; }
  } catch (e) { toast('That folder could not be read.'); }
}
$('bKitDir').onclick = async () => {
  if (window.showDirectoryPicker) {
    try { await openKitHandle(await window.showDirectoryPicker({ id: 'tv-kit', mode: 'read' })); return; }
    catch (e) { if (e && e.name === 'AbortError') return; /* fall back to the folder input */ }
  }
  $('fKitDir').click();
};
$('fKitDir').onchange = ev => {
  const files = [...ev.target.files];
  if (files.length) {
    const root = (files[0].webkitRelativePath || '').split('/')[0] || 'folder';
    loadKit(files.map(f => ({ path: f.webkitRelativePath || f.name, get: async () => f })), root);
  }
  ev.target.value = '';
};
$('bKitZip').onclick = () => $('fKitZip').click();
$('fKitZip').onchange = ev => { const f = ev.target.files[0]; if (f) openZip(f); ev.target.value = ''; };
$('bKitAgain').onclick = async () => { try { const h = await idb.get('kitHandle'); if (h) await openKitHandle(h); } catch (e) { toast('The last kit folder could not be reopened. Choose it again.'); } };
function loadScript(src) {
  return new Promise((res, rej) => { const s = document.createElement('script'); s.src = src; s.onload = res; s.onerror = () => rej(new Error('load')); document.head.appendChild(s); });
}
async function openZip(file) {
  try {
    if (!window.JSZip) await loadScript(JSZIP_URL);
  } catch (e) { toast('Reading a zip needs JSZip from cdnjs, which didn\'t load (offline?). Unzip it and open the folder instead.'); return; }
  try {
    const zip = await window.JSZip.loadAsync(file);
    const entries = [];
    zip.forEach((path, zf) => { if (!zf.dir && !path.startsWith('__MACOSX/')) entries.push({ path, get: () => zf.async('blob') }); });
    await loadKit(entries, file.name);
  } catch (e) { toast('That zip could not be read.'); }
}
// Drop: a part from the palette, a kit folder or zip, or a design file.
async function walkEntry(entry, prefix, out, depth = 0) {
  if (entry.isFile) { out.push({ path: prefix + entry.name, get: () => new Promise((res, rej) => entry.file(res, rej)) }); return; }
  if (!entry.isDirectory || depth > 5 || entry.name.startsWith('.')) return;
  const reader = entry.createReader();
  for (;;) {
    const batch = await new Promise((res, rej) => reader.readEntries(res, rej));
    if (!batch.length) break;
    for (const e of batch) await walkEntry(e, prefix + entry.name + '/', out, depth + 1);
  }
}
const stage = $('stage');
const isPartDrag = ev => [...(ev.dataTransfer && ev.dataTransfer.types || [])].includes('application/x-tv-part');
stage.addEventListener('dragover', ev => {
  if (layerDrag) return;
  ev.preventDefault();
  if (isPartDrag(ev)) { ev.dataTransfer.dropEffect = 'copy'; return; }
  $('drop').hidden = false;
});
stage.addEventListener('dragleave', ev => { if (ev.target === stage || ev.target === $('drop') || ev.target === cv) $('drop').hidden = true; });
stage.addEventListener('drop', async ev => {
  ev.preventDefault(); $('drop').hidden = true;
  if (isPartDrag(ev)) {
    const id = ev.dataTransfer.getData('application/x-tv-part'), r = cv.getBoundingClientRect();
    const [x, y] = toDesign(ev.clientX - r.left, ev.clientY - r.top);
    placePart(id, x, y, ev); return;
  }
  const items = [...(ev.dataTransfer.items || [])].filter(i => i.kind === 'file');
  const fsEntries = items.map(i => i.webkitGetAsEntry ? i.webkitGetAsEntry() : null);
  const files = [...ev.dataTransfer.files];
  if (fsEntries.some(e => e && e.isDirectory)) {
    const out = [];
    for (const e of fsEntries) if (e) await walkEntry(e, '', out);
    const root = (fsEntries.find(e => e && e.isDirectory) || {}).name || 'folder';
    loadKit(out, root); return;
  }
  const zip = files.find(f => /\.zip$/i.test(f.name));
  if (zip) { openZip(zip); return; }
  const json = files.find(f => /\.json$/i.test(f.name));
  if (json) { openDesignText(await json.text(), json.name); return; }
  toast('Drop a kit folder or zip, or a .design.json.');
});

// ---------- boot ----------
new ResizeObserver(resize).observe(cv);
if (!restore()) design = blankDesign();
rebuildIndex();
syncPrefs(); updateUndo(); renderPalette();
resize();
if (!design.parts.length) fitView();
refresh();
if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => draw());
(async () => {
  try {
    if (!window.showDirectoryPicker) return;
    const h = await idb.get('kitHandle');
    if (h) { $('bKitAgain').hidden = false; $('bKitAgain').textContent = `Reopen kit (${h.name})`; }
  } catch (e) { /* no stored kit */ }
})();
// Test hook: lets an automated check drive the designer (not used by the UI).
window.__designer = { get design() { return design; }, get kit() { return kit; }, composeSprite, units, loadKit, openDesignText, designText, hullFromDesign, validate, placePart, act, refresh, spriteFrame, select: uids => { selection = new Set(uids); refresh(false); }, toScreen, setTool };
})();
