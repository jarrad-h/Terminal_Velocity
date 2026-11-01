/* Shared hull-marker code for the browser tools (tools/hardpoint-editor, tools/ship-designer).
 *
 * Hardpoints, engine exhausts and the hit capsule: their conventions, drawing, mirror pairing,
 * hull.json (schema 1) output and the checks that mirror the game's loader rules
 * (scripts/data/ship_def.gd, scripts/data/hardpoint_def.gd). Change the rules here, once, and
 * both tools follow. Plain script (no modules) so it loads from file:// in Chrome and Firefox.
 *
 * Colours come from the page's CSS variables: --m-fixed, --m-pivot, --m-turret, --m-launcher,
 * --m-engine, --m-hit, --ink, --bench, --font-mono.
 */
(function (root) {
'use strict';

// Mount defaults mirror data/game.json "mounts" (arc, traverse). Keep in step with it.
const MOUNTS = ['fixed', 'pivot', 'turret', 'launcher'];
const SIZES = ['small', 'medium', 'large'];
const ARC_DEFAULT = { fixed: 0, pivot: 30, turret: 360, launcher: 360 };
const TRAV_DEFAULT = { pivot: 180, turret: 360 };
const PREFIX = { fixed: 'G', pivot: 'P', turret: 'T', launcher: 'M' };
const SIZE_R = { small: 5, medium: 7, large: 9 };
const HINTS = {
  fixed: 'Fires along the facing. Fixed mounts take no arc or traverse.',
  pivot: 'Tracks the target within a narrow arc centred on the facing.',
  turret: 'Rotates within its arc. The turret sprite pivots on this point; blank part uses the default for its size.',
  launcher: 'Missiles launch here and turn onto any bearing.'
};

const round = v => Math.round(v * 100) / 100;
const css = n => getComputedStyle(document.documentElement).getPropertyValue(n).trim();
const mountColour = m => css('--m-' + m);
const aims = mount => mount === 'pivot' || mount === 'turret';

// ---------- drawing (screen space; markers keep a fixed screen size at any zoom) ----------
function drawMarker(c, hp, sx, sy, z, selected, forSheet) {
  const col = mountColour(hp.mount), r = SIZE_R[hp.size] * (forSheet ? 1.4 : 1);
  const face = ((hp.facing || 0) - 90) * Math.PI / 180;
  // arc wedge
  const arc = hp.arc != null ? hp.arc : ARC_DEFAULT[hp.mount];
  if (hp.mount === 'pivot' || (hp.mount === 'turret' && arc < 360)) {
    const R = Math.max(26, r * 5);
    const a = arc * Math.PI / 180;
    c.beginPath(); c.moveTo(sx, sy); c.arc(sx, sy, R, face - a / 2, face + a / 2); c.closePath();
    c.globalAlpha = 0.18; c.fillStyle = col; c.fill(); c.globalAlpha = 0.7; c.strokeStyle = col; c.lineWidth = 1; c.stroke(); c.globalAlpha = 1;
  } else if (hp.mount === 'turret') {
    c.beginPath(); c.arc(sx, sy, Math.max(16, r * 3), 0, Math.PI * 2);
    c.globalAlpha = 0.45; c.setLineDash([3, 3]); c.strokeStyle = col; c.lineWidth = 1; c.stroke(); c.setLineDash([]); c.globalAlpha = 1;
  }
  // facing line for fixed
  if (hp.mount === 'fixed') {
    c.beginPath(); c.moveTo(sx, sy); c.lineTo(sx + Math.cos(face) * 30, sy + Math.sin(face) * 30);
    c.strokeStyle = col; c.lineWidth = 1.5; c.globalAlpha = 0.85; c.stroke(); c.globalAlpha = 1;
  }
  // marker shape
  c.beginPath();
  if (hp.mount === 'fixed') {
    c.moveTo(sx + Math.cos(face) * r * 1.3, sy + Math.sin(face) * r * 1.3);
    c.lineTo(sx + Math.cos(face + 2.4) * r, sy + Math.sin(face + 2.4) * r);
    c.lineTo(sx + Math.cos(face - 2.4) * r, sy + Math.sin(face - 2.4) * r);
    c.closePath();
  } else if (hp.mount === 'pivot') {
    c.moveTo(sx, sy - r * 1.2); c.lineTo(sx + r * 1.2, sy); c.lineTo(sx, sy + r * 1.2); c.lineTo(sx - r * 1.2, sy); c.closePath();
  } else if (hp.mount === 'turret') {
    c.arc(sx, sy, r, 0, Math.PI * 2);
  } else {
    c.rect(sx - r, sy - r, r * 2, r * 2);
  }
  c.fillStyle = col; c.fill();
  c.lineWidth = selected ? 2.5 : 1.25; c.strokeStyle = selected ? css('--ink') : css('--bench'); c.stroke();
  if (hp.role === 'point_defence') {
    c.beginPath(); c.arc(sx, sy, r * 0.4, 0, Math.PI * 2); c.fillStyle = css('--bench'); c.fill();
  }
  // label
  c.font = `600 ${forSheet ? 15 : 12}px ${css('--font-mono')}`;
  c.textAlign = 'left'; c.textBaseline = 'middle';
  const lx = sx + r + 6, ly = sy - r - 4;
  c.lineWidth = 3; c.strokeStyle = css('--bench'); c.strokeText(hp.id || '?', lx, ly);
  c.fillStyle = selected ? css('--ink') : col; c.fillText(hp.id || '?', lx, ly);
}
// Engine exhaust: a triangle pointing along the exhaust direction (degrees clockwise from the
// nose, 180 = straight aft, the hull.json default). `size` scales the marker.
function drawEngine(c, e, sx, sy, selected, scale = 1, dir = 180) {
  const col = mountColour('engine');
  const a = (dir - 180) * Math.PI / 180, ca = Math.cos(a), sa = Math.sin(a);
  const pt = (x, y) => [sx + (x * ca - y * sa) * scale, sy + (x * sa + y * ca) * scale];
  c.beginPath();
  c.moveTo(...pt(-4, -3)); c.lineTo(...pt(4, -3)); c.lineTo(...pt(0, 9)); c.closePath();
  c.fillStyle = col; c.fill(); c.lineWidth = selected ? 2.5 : 1; c.strokeStyle = selected ? css('--ink') : css('--bench'); c.stroke();
}
function capsulePath(c, cx, cy, wpx, lpx) {
  const r = wpx / 2, half = Math.max(0, lpx / 2 - r);
  c.beginPath();
  c.arc(cx, cy - half, r, Math.PI, 0); c.lineTo(cx + r, cy + half);
  c.arc(cx, cy + half, r, 0, Math.PI); c.closePath();
}

// ---------- ids and mirror pairs ----------
function nextId(mount, taken) {
  const p = PREFIX[mount]; let n = 1;
  while (taken.has(p + n)) n++;
  return p + n;
}
// Index of the marker mirroring list[i] across the centre line (x = -x, same y), or -1.
// posOf(item) -> [x, y]; same(a, b) -> extra match rule; tol in the list's units.
function mirrorPartner(list, i, posOf, same, tol = 0.3) {
  const a = list[i], [ax, ay] = posOf(a);
  if (Math.abs(ax) <= tol / 30) return -1;
  return list.findIndex((b, j) => {
    if (j === i) return false;
    const [bx, by] = posOf(b);
    return Math.abs(bx + ax) < tol && Math.abs(by - ay) < tol && (!same || same(a, b));
  });
}
const sameHardpointKind = (a, b) => a.mount === b.mount && a.size === b.size;

// ---------- import ----------
function normaliseMount(m, kind) {
  if (!m) return kind === 'turret' ? 'turret' : kind === 'guided' ? 'launcher' : 'fixed';
  m = String(m).toLowerCase();
  if (m.includes('turret')) return 'turret';
  if (m.includes('launch')) return 'launcher';
  if (m.includes('pivot')) return 'pivot';
  return MOUNTS.includes(m) ? m : 'fixed';
}
// Any hardpoint-like object (hull.json, art hardpoints.json, prototype ship data) -> schema 1 shape.
function normaliseHardpoint(h) {
  const mount = normaliseMount(h.mount, h.kind);
  const o = { id: h.id || '', size: SIZES.includes(h.size) ? h.size : 'small', mount, pos: [round(h.pos[0]), round(h.pos[1])] };
  if (h.facing) o.facing = h.facing;
  if (h.arc != null && aims(mount) && h.arc !== ARC_DEFAULT[mount]) o.arc = h.arc;
  if (h.traverse != null && aims(mount)) o.traverse = h.traverse;
  if (h.role === 'point_defence' || (typeof h.role === 'string' && h.role.includes('point'))) o.role = 'point_defence';
  if (h.part) o.part = h.part;
  if (h.cells && mount === 'launcher') o.cells = h.cells;
  return o;
}

// ---------- hull.json (schema 1) ----------
function hardpointOut(h) {
  const o = { id: h.id, size: h.size, mount: h.mount, pos: h.pos };
  if (h.facing) o.facing = h.facing;
  if (h.arc != null) o.arc = h.arc;
  if (h.traverse != null) o.traverse = h.traverse;
  if (h.role) o.role = h.role;
  if (h.part) o.part = h.part;
  if (h.cells != null && h.mount === 'launcher') o.cells = h.cells;
  return o;
}
function manifest(s) {
  return {
    schema: 1, id: s.id, name: s.name, sprite: s.sprite, size_px: s.size_px, scale: s.scale,
    hit: { size: s.hit.size, offset: s.hit.offset },
    hardpoints: s.hardpoints.map(hardpointOut),
    engines: s.engines
  };
}
// Compact arrays of two numbers onto one line for readable diffs.
function manifestText(s) {
  return JSON.stringify(manifest(s), null, 2).replace(/\[\s+(-?[\d.]+),\s+(-?[\d.]+)\s+\]/g, '[$1, $2]');
}

// ---------- checks (mirror the loader's rules) ----------
// s: hull in schema 1 shape (positions in art px from the sprite centre).
// env: { spriteError: string|null  (set when positions can't be checked against a sprite),
//        inBounds(x, y) -> bool, alphaAt(x, y) -> 0..255,
//        offHull(name) -> message for a hardpoint over a transparent pixel,
//        target: { hp(i), eng(i) } -> what a check row selects when clicked }
function validateHull(s, env) {
  const out = [];
  const E = (msg, target) => out.push({ lvl: 'e', msg, target });
  const W = (msg, target) => out.push({ lvl: 'w', msg, target });
  const tHp = i => env.target ? env.target.hp(i) : { type: 'hp', i };
  const tEng = i => env.target ? env.target.eng(i) : { type: 'eng', i };
  const checkPos = !env.spriteError;
  if (!s.id) E('Hull ID is empty.');
  else if (!/^[a-z0-9_]+$/.test(s.id)) E('Hull ID must be lowercase snake_case (letters, digits, underscores).');
  if (!s.name) W('Hull has no display name.');
  if (env.spriteError) E(env.spriteError);
  if (!(s.scale > 0)) E('Scale must be above 0.');
  const [hw, hl] = s.hit.size;
  if (!(hw > 0 && hl > 0)) E('Hit capsule needs a width and length above 0.');
  else if (hw > hl) E('Hit capsule width must not exceed its length (the capsule runs along the hull).');
  const seen = new Map();
  s.hardpoints.forEach((hp, i) => {
    const t = tHp(i), name = hp.id || `#${i + 1}`;
    if (!hp.id) E(`Hardpoint #${i + 1} has no ID.`, t);
    else if (!/^[A-Za-z0-9_]+$/.test(hp.id)) E(`${name}: IDs use letters, digits and underscores only.`, t);
    if (hp.id) { if (seen.has(hp.id)) E(`${name} is used twice.`, t); seen.set(hp.id, i); }
    if (checkPos && !env.inBounds(hp.pos[0], hp.pos[1])) E(`${name} sits outside the sprite.`, t);
    else if (checkPos && env.alphaAt(hp.pos[0], hp.pos[1]) < 16) W(env.offHull ? env.offHull(name) : `${name} sits on a transparent pixel. Is it on the hull?`, t);
    if ((hp.mount === 'fixed' || hp.mount === 'launcher') && (hp.arc != null || hp.traverse != null)) E(`${name}: ${hp.mount} mounts can't override arc or traverse (the game refuses it).`, t);
    if (hp.arc != null && !(hp.arc > 0 && hp.arc <= 360)) E(`${name}: arc must be between 1 and 360.`, t);
    if (hp.cells != null && hp.mount !== 'launcher') W(`${name}: cells only apply to launchers.`, t);
    if (hp.role === 'point_defence' && hp.mount !== 'turret') W(`${name}: point defence is meant for turret mounts.`, t);
  });
  s.engines.forEach((e, i) => { if (checkPos && !env.inBounds(e[0], e[1] - 0.01)) W(`Engine E${i + 1} sits outside the sprite.`, tEng(i)); });
  if (!s.engines.length) W('No engine exhausts placed (no engine glow).');
  if (!s.hardpoints.length) W('No hardpoints: this is an unarmed hull.');
  return out;
}

// ---------- files ----------
// Download a file. Inside a claude.ai artifact, use its downloads capability; opened from disk
// (file://), a normal browser download works. Returns false when neither is possible.
async function saveFile(filename, data, toast) {
  const say = toast || (() => {});
  try {
    const dl = root.claude && root.claude.use ? await root.claude.use('downloads') : null;
    if (!dl) {
      if (location.protocol !== 'file:') return false;
      const a = document.createElement('a');
      a.href = URL.createObjectURL(data instanceof Blob ? data : new Blob([data], { type: 'application/json' }));
      a.download = filename; document.body.appendChild(a); a.click(); a.remove();
      setTimeout(() => URL.revokeObjectURL(a.href), 2000);
      say(`Saved ${filename}.`);
      return true;
    }
    await dl.save({ filename, data });
    say(`Saved ${filename}.`);
    return true;
  } catch (e) {
    if (e && e.code === 'declined') { say('Save cancelled.'); return true; }
    return false;
  }
}

root.TVHull = {
  MOUNTS, SIZES, ARC_DEFAULT, TRAV_DEFAULT, PREFIX, SIZE_R, HINTS,
  round, css, mountColour, aims,
  drawMarker, drawEngine, capsulePath,
  nextId, mirrorPartner, sameHardpointKind,
  normaliseMount, normaliseHardpoint,
  hardpointOut, manifest, manifestText, validateHull, saveFile
};
})(window);
