"""Regenerate every generated ship sprite (Standard Orbital Works + pirates) and their hardpoint data.

Usage (from the repo root):  python art_src/sow/export.py            # everything
                             python art_src/sow/export.py sow_p_b_patrol pirate_raider   # just these
Needs: Python 3.10+, numpy, Pillow.
Writes:  assets/sprites/ships/sow/ships/*.png      hulls (empty turret rings), art facing up
         assets/sprites/ships/sow/preview/*.png    same hulls with turrets fitted (reference only)
         assets/sprites/ships/sow/parts/*.png      kit parts and turret sprites
         assets/sprites/ships/sow/hardpoints.json  every hardpoint per hull (see docs/art/hardpoints.md)
         assets/sprites/ships/pirates/...          same for the pirate raider
         docs/art/hardpoints.md                    readable summary of all hardpoints
"""
import os, sys
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from kit import (Paint, reduce, collar, m_bow_bridge, m_segment, m_aft_engine, build_shuttle, turret, nozzle,
                 grille, lightstrip, rcs, hatch)
from kit2 import seg, aft, adapter, container, clamp, spine_bay, booster, solar, courier_a as booster_courier, \
    courier_b as clamp_courier, freighter_c as wide_freighter
from kit3 import tank, radiator, aft_cruise
import kit5 as k5
import kit6
import kit7
from kit4 import fuel, aft_cruise_w, courier_c as longhaul_courier, freighter_a as stack_freighter, \
    freighter_b as spine_freighter

ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'assets', 'sprites', 'ships', 'sow')

# designation -> (builder, canvas height in units). Letters run small to large within each class.
SHIPS = {
    'sow_s_a_shuttle': (build_shuttle, 80),
    'sow_c_a_clamp': (clamp_courier, 76),
    'sow_c_b_booster': (booster_courier, 76),
    'sow_c_c_longhauler': (longhaul_courier, 98),
    'sow_f_a_stack': (stack_freighter, 124),
    'sow_f_b_spine': (spine_freighter, 136),
    'sow_f_c_widebody': (wide_freighter, 120),
}

# part code -> (builder, canvas height in units)
PARTS = {
    'bow_b': (lambda q: m_bow_bridge(q, 6), 24),
    'seg16_plain': (lambda q: m_segment(q, 2, 16, 'plain'), 20),
    'seg16_turret': (lambda q: m_segment(q, 6, 16, 'turret'), 24),
    'seg16_hatch': (lambda q: m_segment(q, 2, 16, 'hatch', ('light', 'grille')), 20),
    'seg16_cargo': (lambda q: m_segment(q, 2, 16, 'cargo', ('grille', 'grille')), 20),
    'segw16_cargo': (lambda q: seg(q, 2, 16, 'cargo', ('grille', 'light'), 20, 60), 20),
    'fuel16': (lambda q: fuel(q, 2), 20),
    'adp_w': (lambda q: adapter(q, 2, 9, 20, 60), 13),
    'col': (lambda q: collar(q, 2), 6),
    'col_w': (lambda q: collar(q, 2, 19.4, 60.6), 6),
    'spn26': (lambda q: spine_bay(q, 2, 26, ('rust', 'teal'), ('grey', 'sand')), 30),
    'clp24': (lambda q: clamp(q, 2, 24, kinds=('rust',)), 30),
    'aft12': (lambda q: m_aft_engine(q, 2, 12, 4), 20),
    'aft_w': (lambda q: aft(q, 2, 12, 6, 20, 60), 20),
    'aft_c': (lambda q: aft_cruise(q, 2), 24),
    'aft_wc': (lambda q: aft_cruise_w(q, 2), 24),
    'n1': (lambda q: nozzle(q, 40, 2, 5, 4), 8),
    'n2': (lambda q: nozzle(q, 40, 2, 10, 6.5), 10),
    'bst': (lambda q: booster(q, 40, 2, 30, (), 40), 38),
    'rcs': (lambda q: rcs(q, 40, 3), 6),
    'cnt_rust': (lambda q: container(q, 34, 2, 46, 14, 'rust'), 16),
    'cnt_teal': (lambda q: container(q, 34, 2, 46, 14, 'teal'), 16),
    'cnt_sand': (lambda q: container(q, 34, 2, 46, 14, 'sand'), 16),
    'cnt_grey': (lambda q: container(q, 34, 2, 46, 14, 'grey'), 16),
    'hat': (lambda q: hatch(q, 40, 7), 14),
    'grl': (lambda q: grille(q, 38, 2), 11),
    'lgt': (lambda q: lightstrip(q, 39, 2), 8),
    'sol_flat': (lambda q: solar(q, 1, 8, 30), 16),
    'tnk': (lambda q: tank(q, 40, 2, 14.4, 46), 18),
    'rad': (lambda q: radiator(q, 1, 2, 30), 16),
    'arm16_t1': (lambda q: k5.seg_armed(q, 2, 16, mounts=[(0, 0.5, 't1')], armoured=True), 20),
    'armw16_t2': (lambda q: k5.seg_armed(q, 2, 16, 20, 60, mounts=[(0, 0.5, 't2')], armoured=True), 20),
    'dck': (lambda q: k5.docking_bow(q, 10), 20),
    'sen': (lambda q: k5.booms(q, 12), 20),
    'fwd': (lambda q: k5.fwd_guns(q, 4), 18),
    'spn_pd': (lambda q: k5.sponson(q, 40, 6, 1), 12),
    'spn_n': (lambda q: kit6.neck(q, 2, 8), 12),
    'nac': (lambda q: kit7.nacelle(q, 1, 2, 18, 7), 28),
    'nac_big': (lambda q: kit7.nacelle(q, 1, 2, 22, 10, big=True), 32),
    'tpr_in': (lambda q: kit7.taper(q, 2, 5, 26, 12), 9),
    'tpr_out': (lambda q: kit7.taper(q, 2, 5, 12, 26), 9),
}
for _code, _label, _fn in kit6.STYLES:
    if _code not in ('vls_round', 'vls_strip'): continue
    PARTS['msl_' + _code] = ((lambda f: (lambda q: (f(q, 4), kit6.fit(q))))(_fn), 24)

def render(fn, h):
    p = Paint(80, h); p.mounts = []; p.mounts_fixed = []; fn(p); im = reduce(p); return im.crop(im.getbbox())

# ---- armed hulls: hull sprite without turrets + mount positions; turret sprites centred on their pivot ----
import json
from kit import K
from kit5 import SHIPS as _ARMED_V1, ring, turret_sprite, TUR
import kit6
from kit6 import build
# P-A, P-B, K-A from pass 1; K-B, R-A, R-B from pass 2 (standard width, necks, nacelles)
ARMED = {k: v for k, v in _ARMED_V1.items() if k in ('sow_p_a_picket', 'sow_p_b_patrol', 'sow_k_a_boarding')}
import kit7
ARMED = {k: v for k, v in ARMED.items() if k not in kit7.SHIPS}
ARMED.update(kit7.SHIPS)      # pass 3: P-B (VLS-4), K-B, R-A, R-B (tapers, necks, hugging nacelles)
build = kit7.build

def turret_part(kind, ring_only=False):
    half = 8 if kind == 'ml' else math.ceil(TUR[kind]['r'] * 0.4 + TUR[kind]['ln'] + 1.5)
    p = Paint(2 * half, 2 * half); p.mounts = []
    if ring_only: ring(p, half, half, kind)
    elif kind == 'ml': kit6.launcher_turret(p, half, half)
    else: turret_sprite(p, half, half, kind)
    return reduce(p)          # not cropped: the image centre is the pivot


import math, json

# Turret segments draw an empty ring (the turret is a separate sprite) and record the mount.
import kit, kit2
def _ring_turret(p, cx, cy):
    if hasattr(p, 'mounts'): ring(p, cx, cy, 't1')
    else: kit.__dict__['_orig_turret'](p, cx, cy)
kit.__dict__['_orig_turret'] = kit.turret
kit.turret = _ring_turret; kit2.turret = _ring_turret

# Record every nozzle exit (engine glow anchors).
import kit3, kit4
_orig_nozzle = kit.nozzle
def _rec_nozzle(p, cx, y0, w=5, h=4):
    if hasattr(p, 'engines'): p.engines.append((cx, y0 + h))
    _orig_nozzle(p, cx, y0, w, h)
for _m in (kit, kit2, kit3, kit4, k5, kit6, kit7):
    if hasattr(_m, 'nozzle'): _m.nozzle = _rec_nozzle

# Mount size classes (shared by every maker): small / medium / large.
TURRET_INFO = {   # kind -> (size class, role, sprite)
    't1': ('small', 'light twin turret', 'parts/tur1.png'),
    't2': ('medium', 'heavy twin turret', 'parts/tur2.png'),
    'pd': ('small', 'point-defence turret', 'parts/pd1.png'),
}
LAUNCHER_SIZE = {'VLS-4': 'small', 'VLS-3': 'medium'}
NAMES = {
    'sow_s_a_shuttle': 'SOW S-A Shuttle', 'sow_c_a_clamp': 'SOW C-A Clamp courier', 'sow_c_b_booster': 'SOW C-B Booster courier',
    'sow_c_c_longhauler': 'SOW C-C Long-hauler', 'sow_f_a_stack': 'SOW F-A Long-stack freighter', 'sow_f_b_spine': 'SOW F-B Container-spine freighter',
    'sow_f_c_widebody': 'SOW F-C Wide-body freighter', 'sow_p_a_picket': 'SOW P-A Picket corvette', 'sow_p_b_patrol': 'SOW P-B Patrol corvette',
    'sow_k_a_boarding': 'SOW K-A Boarding cutter', 'sow_k_b_escort': 'SOW K-B Escort cutter', 'sow_r_a_gun_cruiser': 'SOW R-A Gun cruiser',
    'sow_r_b_missile_cruiser': 'SOW R-B Missile cruiser', 'pirate_raider': 'Pirate raider (R-1C)',
}

def new_paint(h):
    p = Paint(80, h); p.mounts = []; p.mounts_fixed = []; p.launchers = []; p.engines = []
    return p

def hardpoints(p, bb, w, h):
    """All hardpoints as pixel offsets from the sprite centre (+x starboard/right, +y aft; art faces up)."""
    cx, cy = bb[0] + w / 2, bb[1] + h / 2
    off = lambda x, y: [round(x * K - cx, 1), round(y * K - cy, 1)]
    hps, n = [], {'gun': 0, 'turret': 0, 'guided': 0, 'beam': 0}
    def add(kind, prefix, **kw):
        n[kind] += 1; hps.append(dict(id=f'{prefix}{n[kind]}', kind=kind, **kw))
    for x, y, k in sorted(p.mounts_fixed, key=lambda m: (m[1], m[0])):
        if k == 'gun': add('gun', 'G', mount='fixed', size='small', role='fixed forward gun', pos=off(x, y), facing=0, arc=0,
                           note='muzzle point; fires along the heading')
        else: add('beam', 'B', mount='fixed', size='small', role='fixed beam emitter', pos=off(x, y), facing=0, arc=0,
                  note='emitter tip; fires along the heading')
    for x, y, k in sorted(p.mounts, key=lambda m: (m[1], m[0])):
        size, role, spr = TURRET_INFO[k]
        add('turret', 'T', mount='turret', size=size, role=role, sprite=spr, pos=off(x, y), facing=0, arc=360,
            note='ring centre = turret pivot; turret sprite barrels point up at rotation 0')
    for x, y, code, cells in sorted(p.launchers, key=lambda m: m[1]):
        add('guided', 'M', mount='launcher', size=LAUNCHER_SIZE[code], role=f'{code} vertical missile launcher', launcher=code,
            cells=cells, pos=off(x, y), facing=0, arc=360, note='launcher centre; vertical launch, missiles turn onto any bearing')
    eng = [off(x, y) for x, y in sorted(set((round(a, 2), round(b, 2)) for a, b in p.engines))]
    return hps, eng

def mount_counts(hps):
    """e.g. '2× small fixed gun, 1× small turret, 1× small missile launcher'."""
    order, counts = [], {}
    for hp in hps:
        label = {'gun': 'fixed gun', 'beam': 'fixed beam', 'turret': 'turret', 'guided': 'missile launcher'}[hp['kind']]
        if hp['kind'] == 'turret' and 'point-defence' in hp['role']: label = 'point-defence turret'
        key = f"{hp['size']} {label}"
        if key not in counts: order.append(key); counts[key] = 0
        counts[key] += 1
    return ', '.join(f'{counts[k]}× {k}' for k in order) if order else 'none (unarmed)'

def summary(name, rec):
    hps = rec['hardpoints']
    if not hps: return 'No weapon hardpoints (unarmed hull).'
    parts = []
    for hp in hps:
        x, y = hp['pos']
        if hp['kind'] in ('gun', 'beam'):
            parts.append(f"{hp['id']} {hp['size']} fixed {'gun' if hp['kind'] == 'gun' else 'beam'} at ({x}, {y}), firing straight ahead")
        elif hp['kind'] == 'turret':
            parts.append(f"{hp['id']} {hp['size']} {hp['role']} ring at ({x}, {y}), {hp['arc']}° arc")
        else:
            parts.append(f"{hp['id']} {hp['size']} {hp['launcher']} launcher ({hp['cells']} cells) at ({x}, {y}), {hp['arc']}° launch arc")
    return f"{len(hps)} hardpoint{'s' if len(hps) != 1 else ''}: " + '; '.join(parts) + '.'

def write_hardpoints(folder, records):
    path = os.path.join(folder, 'hardpoints.json')
    data = json.load(open(path)) if os.path.exists(path) else {}
    for name, rec in records.items():
        rec['name'] = NAMES.get(name, name); rec['mounts'] = mount_counts(rec['hardpoints'])
        rec['summary'] = summary(name, rec); data[name] = rec
    data = dict(sorted(data.items()))
    with open(path, 'w') as f: json.dump(data, f, indent=1)
    old = os.path.join(folder, 'mounts.json')
    if os.path.exists(old): os.remove(old)
    return data

# ---- spec sheet image per hull: sprite with labelled hardpoints + a mount list ----
from PIL import Image, ImageDraw, ImageFont
_FONT = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def _font(sz):
    try: return ImageFont.truetype(_FONT, sz)
    except OSError: return ImageFont.load_default()
KIND_COL = {'gun': (255, 176, 64), 'turret': (95, 216, 255), 'guided': (240, 240, 240), 'beam': (110, 255, 140)}

def spec_sheet(name, rec, hull_png, out_png, S=4):
    hull = Image.open(hull_png).convert('RGBA'); w, h = hull.size
    panel = 430; W = max(w * S + 140, 300) + panel; H = max(h * S + 120, 420)
    img = Image.new('RGBA', (W, H), (10, 12, 18, 255)); d = ImageDraw.Draw(img)
    ox = 70; oy = (H - h * S) // 2
    img.alpha_composite(hull.resize((w * S, h * S), Image.NEAREST), (ox, oy))
    f_lab, f_txt, f_head, f_small = _font(14), _font(15), _font(20), _font(12)
    cx0, cy0 = ox + w * S / 2, oy + h * S / 2
    rad = {'small': 7, 'medium': 11, 'large': 15}
    used = {1: [], -1: []}
    for i, hp in enumerate(rec['hardpoints']):
        x, y = cx0 + hp['pos'][0] * S, cy0 + hp['pos'][1] * S; c = KIND_COL[hp['kind']]; r = rad[hp['size']]
        if hp['kind'] == 'turret': d.ellipse([x - r, y - r, x + r, y + r], outline=c, width=3)
        elif hp['kind'] == 'gun': d.rectangle([x - r * 0.6, y - r * 0.6, x + r * 0.6, y + r * 0.6], outline=c, width=3)
        elif hp['kind'] == 'beam': d.polygon([(x, y - r), (x + r, y), (x, y + r), (x - r, y)], outline=c, width=3)
        else: d.polygon([(x, y - r), (x + r, y + r * 0.8), (x - r, y + r * 0.8)], outline=c, width=3)
        side = 1 if hp['pos'][0] >= 0 else -1
        clash = lambda sd, yy: any(abs(yy - u) < 18 for u in used[sd])
        if abs(hp['pos'][0]) < 2: side = 1 if not clash(1, y) else -1
        ly = y
        while clash(side, ly): ly += 18
        used[side].append(ly)
        lx = ox + w * S + 18 if side > 0 else ox - 60
        d.line([(x + side * (r + 2), y), (lx + (0 if side > 0 else 52), ly)], fill=c + (160,), width=1)
        d.text((lx + (4 if side > 0 else 0), ly - 8), hp['id'], font=f_lab, fill=c)
    for ex, ey in rec.get('engines', []):
        x, y = cx0 + ex * S, cy0 + ey * S; d.ellipse([x - 3, y - 3, x + 3, y + 3], fill=(255, 140, 60))
    px = W - panel + 20; y = 24
    d.text((px, y), rec['name'], font=f_head, fill=(230, 236, 244)); y += 30
    d.text((px, y), f"{w} × {h} px · {rec['sprite']}", font=f_small, fill=(140, 150, 166)); y += 26
    d.text((px, y), 'Mounts:', font=f_txt, fill=(140, 150, 166)); y += 20
    for item in rec['mounts'].split(', '):
        d.text((px + 12, y), item, font=f_txt, fill=(230, 236, 244)); y += 19
    y += 12
    for hp in rec['hardpoints']:
        c = KIND_COL[hp['kind']]
        d.text((px, y), hp['id'], font=f_txt, fill=c)
        d.text((px + 40, y), f"{hp['size']} {hp['role']}", font=f_txt, fill=(220, 226, 236)); y += 19
        arc = 'fires along heading' if hp['arc'] == 0 else f"{hp['arc']}° arc"
        d.text((px + 40, y), f"at ({hp['pos'][0]}, {hp['pos'][1]}) · {arc}" + (f" · {hp['cells']} cells" if hp.get('cells') else ''),
               font=f_small, fill=(150, 160, 176)); y += 24
    if not rec['hardpoints']: d.text((px, y), 'No weapon hardpoints.', font=f_txt, fill=(150, 160, 176)); y += 24
    if rec.get('engines'): d.text((px, y + 6), f"● {len(rec['engines'])} engine exits", font=f_small, fill=(255, 140, 60)); y += 26
    d.text((px, H - 54), 'Positions: px from sprite centre,', font=f_small, fill=(110, 120, 136))
    d.text((px, H - 38), '+x right, +y aft (forward = −y), 1:1 scale.', font=f_small, fill=(110, 120, 136))
    img.convert('RGB').save(out_png)

def write_doc(all_data):
    lines = ['# Ship hardpoints and mount specs', '',
             'Generated by `art_src/sow/export.py` from the art itself; do not edit by hand. A labelled spec sheet image for every hull is in `docs/art/specs/`.', '',
             '**Mount types:** `fixed` (gun or beam, fires along the heading), `turret` (rotating sprite on a ring), `launcher` (missile launcher). **Sizes:** `small`, `medium`, `large` — a weapon fits a mount of its size; large is reserved for future capital weapons.', '',
             '| Mount | Size | Used for | Sprite |', '|---|---|---|---|',
             '| fixed gun | small | forward guns (SOW forward gun pair, pirate guns) | part of the hull |',
             '| fixed beam | small | mining beam emitter | part of the hull |',
             '| turret | small | light twin turret (TUR-1), point-defence turret (PD-1) | `parts/tur1.png`, `parts/pd1.png` |',
             '| turret | medium | heavy twin turret (TUR-2) | `parts/tur2.png` |',
             '| launcher | small | VLS-4 centre-strip launcher, 6 cells | part of the hull |',
             '| launcher | medium | VLS-3 round-hatch launcher, 11 cells | part of the hull |', '',
             '**Coordinates** are pixels from the sprite centre at 1:1 sprite scale: +x is starboard (right), +y is aft (down), the art faces up. Same convention as `hardpoints` in `data/README.md` (forward is negative y): once a sprite scale is chosen, multiply by it and copy the points into the ship JSON. `kind` uses the game names (`gun`, `turret`, `guided`, `beam`). `arc` is a suggestion; in the game a turret\'s arc comes from its weapon definition.', '',
             '**Turrets:** hull sprites show an empty ring; the turret sprite\'s image centre is its pivot, barrels up at rotation 0. Previews with turrets fitted are in `sow/preview/`. **Engines** are nozzle exits for the glow effect.', '',
             '## At a glance', '', '| Hull | Size (px) | Mounts |', '|---|---|---|']
    for maker, data in all_data:
        for name, rec in data.items():
            lines.append(f"| {rec['name']} (`{name}`) | {rec['size_px'][0]} × {rec['size_px'][1]} | {rec['mounts']} |")
    lines.append('')
    for maker, data in all_data:
        lines += [f'## {maker}', '']
        for name, rec in data.items():
            lines += [f"### {rec['name']} — `{name}`", '', f"![spec sheet](specs/{name}.png)", '',
                      f"Sprite `{rec['sprite']}`, {rec['size_px'][0]} × {rec['size_px'][1]} px. **Mounts:** {rec['mounts']}.", '']
            if rec['hardpoints']:
                lines += ['| ID | Kind | Mount | Size | Role | Position (x, y) | Arc | Notes |', '|---|---|---|---|---|---|---|---|']
                for hp in rec['hardpoints']:
                    role = hp['role'] + (f", {hp['cells']} cells" if hp.get('cells') else '')
                    arc = 'along heading' if hp['arc'] == 0 else f"{hp['arc']}°"
                    lines.append(f"| {hp['id']} | `{hp['kind']}` | {hp['mount']} | {hp['size']} | {role} | ({hp['pos'][0]}, {hp['pos'][1]}) | {arc} | {hp['note']} |")
                lines.append('')
            if rec.get('engines'):
                lines += ['Engine exits: ' + ', '.join(f'({x}, {y})' for x, y in rec['engines']), '']
    with open(os.path.join(ROOT, 'docs', 'art', 'hardpoints.md'), 'w') as f: f.write('\n'.join(lines))
    specdir = os.path.join(ROOT, 'docs', 'art', 'specs'); os.makedirs(specdir, exist_ok=True)
    for maker, data in all_data:
        for name, rec in data.items():
            spec_sheet(name, rec, os.path.join(ROOT, 'assets', 'sprites', rec['sprite']), os.path.join(specdir, f'{name}.png'))

if __name__ == '__main__':
    only = set(sys.argv[1:])
    os.makedirs(os.path.join(OUT, 'parts'), exist_ok=True)
    for name, (fn, h) in PARTS.items():
        if only and name not in only: continue
        im = render(fn, h); im.save(os.path.join(OUT, 'parts', f'{name}.png')); print(f'parts/{name}.png', im.size)
    for kind, code in (('t1', 'tur1'), ('t2', 'tur2'), ('pd', 'pd1')):
        if only and code not in only: continue
        turret_part(kind).save(os.path.join(OUT, 'parts', f'{code}.png'))
        turret_part(kind, True).save(os.path.join(OUT, 'parts', f'{code}_ring.png'))
        print(f'parts/{code}.png + ring')

    ALL = dict(SHIPS); ALL.update(ARMED)
    records = {}
    for sub in ('ships', 'preview'): os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    for name, (fn, h) in ALL.items():
        if only and name not in only: continue
        p = new_paint(h); fn(p); im = reduce(p); bb = im.getbbox(); im = im.crop(bb)
        im.save(os.path.join(OUT, 'ships', f'{name}.png'))
        hps, eng = hardpoints(p, bb, im.width, im.height)
        if p.mounts:                                   # preview with turrets fitted
            kit7.fit(p); pv = reduce(p).crop(bb); pv.save(os.path.join(OUT, 'preview', f'{name}.png'))
        records[name] = {'sprite': f'ships/sow/ships/{name}.png', 'size_px': [im.width, im.height], 'hardpoints': hps, 'engines': eng}
        print(f'ships/{name}.png', im.size, len(hps), 'hardpoints')
    sow_data = write_hardpoints(OUT, records)

    import pirates3
    PIR = os.path.join(ROOT, 'assets', 'sprites', 'ships', 'pirates')
    os.makedirs(PIR, exist_ok=True)
    precs = {}
    if not only or 'pirate_raider' in only:
        p = Paint(80, 82, seed=21); p.mounts = []; p.mounts_fixed = []; p.launchers = []; p.engines = []
        pirates3.c_integrated(p); im = reduce(p); bb = im.getbbox(); im = im.crop(bb)
        im.save(os.path.join(PIR, 'pirate_raider.png'))
        hps, eng = hardpoints(p, bb, im.width, im.height)
        precs['pirate_raider'] = {'sprite': 'ships/pirates/pirate_raider.png', 'design': 'R-1C Integrated',
                                  'size_px': [im.width, im.height], 'hardpoints': hps, 'engines': eng}
        print('pirates/pirate_raider.png', im.size, len(hps), 'hardpoints')
    pir_data = write_hardpoints(PIR, precs)
    write_doc([('Standard Orbital Works', sow_data), ('Pirates', pir_data)])
