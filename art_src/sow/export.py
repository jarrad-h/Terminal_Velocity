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

TURRET_INFO = {'t1': ('light', 'parts/tur1.png'), 't2': ('heavy', 'parts/tur2.png'), 'pd': ('point-defence', 'parts/pd1.png')}

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
        if k == 'gun': add('gun', 'G', mount='fixed', pos=off(x, y), facing=0, arc=0, note='muzzle point; fires along the heading')
        else: add('beam', 'B', mount='fixed', pos=off(x, y), facing=0, arc=0, note='emitter tip; fires along the heading')
    for x, y, k in sorted(p.mounts, key=lambda m: (m[1], m[0])):
        size, spr = TURRET_INFO[k]
        add('turret', 'T', mount='turret ring', size=size, sprite=spr, pos=off(x, y), facing=0, arc=360,
            note='ring centre = turret pivot; turret sprite barrels point up at rotation 0')
    for x, y, code, cells in sorted(p.launchers, key=lambda m: m[1]):
        add('guided', 'M', mount='vertical launcher', launcher=code, cells=cells, pos=off(x, y), facing=0, arc=360,
            note='launcher centre; vertical launch, missiles can turn onto any bearing')
    eng = [off(x, y) for x, y in sorted(set((round(a, 2), round(b, 2)) for a, b in p.engines))]
    return hps, eng

def summary(name, rec):
    hps = rec['hardpoints']
    if not hps: return 'No weapon hardpoints (unarmed hull).'
    parts = []
    for hp in hps:
        x, y = hp['pos']
        if hp['kind'] == 'gun': parts.append(f"1 fixed gun ({hp['id']}) at ({x}, {y}), firing straight ahead (arc {hp['arc']}°)")
        elif hp['kind'] == 'beam': parts.append(f"1 fixed beam ({hp['id']}) at ({x}, {y}), firing straight ahead (arc {hp['arc']}°)")
        elif hp['kind'] == 'turret': parts.append(f"1 {hp['size']} turret ring ({hp['id']}) at ({x}, {y}) with a {hp['arc']}° firing arc")
        else: parts.append(f"1 missile launcher ({hp['id']}, {hp['launcher']}, {hp['cells']} cells) at ({x}, {y}), {hp['arc']}° launch arc")
    return f"{len(hps)} hardpoint{'s' if len(hps) != 1 else ''}: " + '; '.join(parts) + '.'

def write_hardpoints(folder, records):
    path = os.path.join(folder, 'hardpoints.json')
    data = json.load(open(path)) if os.path.exists(path) else {}
    for name, rec in records.items():
        rec['summary'] = summary(name, rec); data[name] = rec
    data = dict(sorted(data.items()))
    with open(path, 'w') as f: json.dump(data, f, indent=1)
    old = os.path.join(folder, 'mounts.json')
    if os.path.exists(old): os.remove(old)
    return data

def write_doc(all_data):
    lines = ['# Ship hardpoints', '',
             'Generated by `art_src/sow/export.py` from the art itself; do not edit by hand.', '',
             '**Coordinates** are pixels from the sprite centre at 1:1 sprite scale: +x is starboard (right), +y is aft (down), the art faces up. This matches the `hardpoints` convention in `data/README.md` (forward is negative y), so once a sprite scale is chosen, multiply by that scale and copy the points into the ship JSON.', '',
             '**Kinds** match the game: `gun` (fixed, fires along the heading), `turret` (rotating sprite on a ring), `guided` (missile launcher), `beam`. `arc` is a suggested arc in degrees centred on the heading; in the game the actual turret arc comes from the weapon definition. `facing` 0 = forward.', '',
             '**Turrets**: the hull sprite shows an empty ring; the turret is a separate sprite (`parts/tur1.png` light, `tur2.png` heavy, `pd1.png` point defence) whose image centre is the pivot, barrels up at rotation 0. Previews with turrets fitted are in `sow/preview/`.', '',
             '**Engines** are nozzle exit points for an in-engine glow effect.', '']
    for maker, data in all_data:
        lines += [f'## {maker}', '']
        for name, rec in data.items():
            lines += [f"### {name}", '', f"Sprite `{rec['sprite']}`, {rec['size_px'][0]} × {rec['size_px'][1]} px. {rec['summary']}", '']
            if rec['hardpoints']:
                lines += ['| ID | Kind | Mount | Position (x, y) | Facing | Arc | Notes |', '|---|---|---|---|---|---|---|']
                for hp in rec['hardpoints']:
                    extra = hp.get('size') or hp.get('launcher') or ''
                    if hp.get('cells'): extra += f", {hp['cells']} cells"
                    lines.append(f"| {hp['id']} | `{hp['kind']}` | {hp['mount']}{' (' + extra + ')' if extra else ''} | ({hp['pos'][0]}, {hp['pos'][1]}) | {hp['facing']}° | {hp['arc']}° | {hp['note']} |")
                lines.append('')
            if rec.get('engines'):
                lines += ['Engine exits: ' + ', '.join(f'({x}, {y})' for x, y in rec['engines']), '']
    with open(os.path.join(ROOT, 'docs', 'art', 'hardpoints.md'), 'w') as f: f.write('\n'.join(lines))

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
