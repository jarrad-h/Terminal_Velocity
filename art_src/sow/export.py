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
    'tur1': (lambda q: turret(q, 40, 13), 20),
    'hat': (lambda q: hatch(q, 40, 7), 14),
    'grl': (lambda q: grille(q, 38, 2), 11),
    'lgt': (lambda q: lightstrip(q, 39, 2), 8),
    'sol_flat': (lambda q: solar(q, 1, 8, 30), 16),
    'tnk': (lambda q: tank(q, 40, 2, 14.4, 46), 18),
    'rad': (lambda q: radiator(q, 1, 2, 30), 16),
}

def render(fn, h):
    p = Paint(80, h); fn(p); im = reduce(p); return im.crop(im.getbbox())

if __name__ == '__main__':
    only = set(sys.argv[1:])
    for sub, table in (('ships', SHIPS), ('parts', PARTS)):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
        for name, (fn, h) in table.items():
            if only and name not in only: continue
            im = render(fn, h); im.save(os.path.join(OUT, sub, f'{name}.png'))
            print(f'{sub}/{name}.png', im.size)
