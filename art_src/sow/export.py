"""Regenerate every Standard Orbital Works sprite.

Usage (from the repo root):  python art_src/sow/export.py
Needs: Python 3.10+, numpy, Pillow.
Writes:  assets/sprites/ships/sow/ships/*.png   whole hulls, art facing up
         assets/sprites/ships/sow/parts/*.png   individual kit parts
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
    'msl16': (lambda q: k5.msl(q, 2), 20),
    'mslw16': (lambda q: k5.msl(q, 2, 16, 20, 60), 20),
    'arm16_t1': (lambda q: k5.seg_armed(q, 2, 16, mounts=[(0, 0.5, 't1')], armoured=True), 20),
    'armw16_t2': (lambda q: k5.seg_armed(q, 2, 16, 20, 60, mounts=[(0, 0.5, 't2')], armoured=True), 20),
    'dck': (lambda q: k5.docking_bow(q, 10), 20),
    'sen': (lambda q: k5.booms(q, 12), 20),
    'fwd': (lambda q: k5.fwd_guns(q, 4), 18),
    'spn_pd': (lambda q: k5.sponson(q, 40, 6, 1), 12),
    'spn_n': (lambda q: kit6.neck(q, 2, 8), 12),
    'nac': (lambda q: kit6.nacelle(q, 40, 2, 17, 8, 50, (8,)), 26),
    'nac_big': (lambda q: kit6.nacelle(q, 40, 2, 21, 11, 52, (10,), big=True), 30),
    'pod_box': (lambda q: kit6.pod_box(q, 40, 2, 14, 6), 18),
}
for _code, _label, _fn in kit6.STYLES:
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
ARMED.update(kit6.SHIPS)

def turret_part(kind, ring_only=False):
    half = 8 if kind == 'ml' else math.ceil(TUR[kind]['r'] * 0.4 + TUR[kind]['ln'] + 1.5)
    p = Paint(2 * half, 2 * half); p.mounts = []
    if ring_only: ring(p, half, half, kind)
    elif kind == 'ml': kit6.launcher_turret(p, half, half)
    else: turret_sprite(p, half, half, kind)
    return reduce(p)          # not cropped: the image centre is the pivot

import math
if __name__ == '__main__':
    only = set(sys.argv[1:])
    for sub, table in (('ships', SHIPS), ('parts', PARTS)):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
        for name, (fn, h) in table.items():
            if only and name not in only: continue
            im = render(fn, h); im.save(os.path.join(OUT, sub, f'{name}.png'))
            print(f'{sub}/{name}.png', im.size)
    os.makedirs(os.path.join(OUT, 'preview'), exist_ok=True)
    mounts = {}
    for name, (fn, h) in ARMED.items():
        if only and name not in only: continue
        for turrets, sub in ((False, 'ships'), (True, 'preview')):
            p = build(fn, h, turrets=turrets); im = reduce(p); bb = im.getbbox(); im = im.crop(bb)
            im.save(os.path.join(OUT, sub, f'{name}.png'))
        cx, cy = bb[0] + im.width / 2, bb[1] + im.height / 2
        mounts[name] = {
            'size_px': [im.width, im.height],
            'turrets': [{'kind': k, 'pos': [round(x * K - cx, 1), round(y * K - cy, 1)]} for x, y, k in p.mounts],
            'fixed_guns': [[round(x * K - cx, 1), round(y * K - cy, 1)] for x, y in p.mounts_fixed],
        }
        print(f'ships/{name}.png', im.size, len(p.mounts), 'mounts')
    if mounts:
        with open(os.path.join(OUT, 'mounts.json'), 'w') as f: json.dump(mounts, f, indent=1)
    for kind, code in (('t1', 'tur1'), ('t2', 'tur2'), ('pd', 'pd1'), ('ml', 'ml1')):
        if only and code not in only: continue
        turret_part(kind).save(os.path.join(OUT, 'parts', f'{code}.png'))
        turret_part(kind, True).save(os.path.join(OUT, 'parts', f'{code}_ring.png'))
        print(f'parts/{code}.png + ring')
