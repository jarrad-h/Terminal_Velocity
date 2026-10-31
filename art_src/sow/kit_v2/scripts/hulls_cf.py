"""Recipes: SOW couriers (C-A/B/C) and freighters (F-A/B/C). Nose up, y grows aft."""
import sys, json
sys.path.insert(0, __import__('os').path.dirname(__file__))
from compose import Hull
OUT = sys.argv[1] if len(sys.argv) > 1 else 'hulls'
only = sys.argv[2:] or None
res = {}

def nose(h, cap, capw):
    """Red cap on the shuttle's upper module (cut from the reference) - the pair always travels together."""
    sc = capw / 320
    h.dy = 0
    h.place('shuttle_upper', 0, (201 + 179) * sc, w=466 * sc, shadow=0.45)
    h.place(cap, 0, 112 * sc, w=capw)
    return (201 + 305) * sc   # y where the next collar's top should sit

def aft_block(h, y, w=400, pods=None, bell='base_28', bell_w=120):
    """Standard SOW aft module (base_20, nozzles built in) with optional engine pods."""
    if pods:
        dx, pw = pods
        ph = 254 * pw / 149
        for yy in (y - 30, y + 70):   # struts tying pods to the aft module
            h.place('trade_21', -dx * 0.62, yy, w=dx * 0.95, shadow=0.35)
            h.place('trade_21', dx * 0.62, yy, w=dx * 0.95, flip=True, shadow=0.35)
        h.pair('base_24', dx, y + 20, pid_right='base_26', w=pw, shadow=0.5)
        h.place(bell, -dx, y + 20 + ph / 2 + bell_w * 0.55, w=bell_w, glow='exit', shadow=0.4)
        h.place(bell, dx, y + 20 + ph / 2 + bell_w * 0.55, w=bell_w, glow='exit', shadow=0.4)
        # re-draw pods over the bell tops
        h.pair('base_24', dx, y + 20, pid_right='base_26', w=pw, shadow=0.0)
    h.place('base_20', 0, y, w=w, glow='exit')

# ---------------- C-A clamp: one container clamped between nose and engines ----------------
def c_a():
    h = Hull('sow_c_a_clamp'); h.dy = 310
    h.place('base_02', 0, 264, w=230)
    h.place('base_03', 0, 828, w=230)
    h.pair('base_19', 158, 544, pid_right='base_21', h=500)
    h.place('trade_00', 0, 544, w=300, rot=90)
    for y in (372, 716):
        h.place('trade_09', -168, y, w=104); h.place('trade_10', 168, y, w=104)
    aft_block(h, 1089, w=400)
    nose(h, 'base_01', 320)
    return h

# ---------------- C-B booster: shuttle-length core with two framed booster tanks ----------------
def c_b():
    h = Hull('sow_c_b_booster'); h.dy = 133
    for y in (520, 900):
        h.pair('trade_21', 215, y, w=210, shadow=0.3)
    for s in (-1, 1):
        h.place('base_31', s * 340, 1100, w=150, glow='exit')
        h.place('trade_05', s * 340, 720, h=700, flip=(s > 0))
    h.place('base_02', 0, 406, w=220)
    h.place('base_03', 0, 860, w=220)
    h.place('base_09', 0, 631, w=320)
    h.pair('base_15', 128, 640, pid_right='base_16', w=90, shadow=0.4)
    aft_block(h, 1110, w=380)
    nose(h, 'base_00', 300)
    return h

# ---------------- C-C longhauler: long courier, fuel sphere, flanks, sensor mast ----------------
def c_c():
    h = Hull('sow_c_c_longhauler'); h.dy = 150
    # under: flanks and rails
    h.place('base_06', -250, 1420, h=520); h.place('base_12', 250, 1420, h=520)
    h.pair('base_19', 178, 642, pid_right='base_21', h=360)
    # collars
    for y, w in ((424, 230), (862, 230), (1172, 230), (1646, 230)):
        h.place('base_02' if y in (424, 1172) else 'base_03', 0, y, w=w)
    h.place('trade_12', 0, 642, w=330)
    h.place('base_17', 0, 1020, w=290)
    h.place('base_09', 0, 1410, w=350)
    h.pair('base_15', 140, 1420, pid_right='base_16', w=96, shadow=0.4)
    aft_block(h, 1907, w=400, pods=(262, 150), bell='base_28', bell_w=112)
    h.place('combat_08', 236, 1180, w=170)          # dish mast on the starboard flank
    nose(h, 'base_01', 320)
    return h

# ---------------- F-A stack: four white containers stacked on a spine ----------------
def f_a():
    h = Hull('sow_f_a_stack'); h.dy = 147
    h.place('base_06', -258, 1900, h=520); h.place('base_12', 258, 1900, h=520)
    # hidden spine (ribbed truss) under the container stack
    for i in range(5):
        h.place('base_03', 0, 600 + i * 240, w=150, h=262, rot=90, shadow=0)
    h.place('base_02', 0, 462, w=240)
    h.place('base_03', 0, 1645, w=240)
    crates = [('trade_01', 659), ('trade_08', 945), ('trade_25', 1211), ('trade_36', 1465)]
    for pid, y in crates:
        h.place(pid, 0, y, w=380)
    for pid, y in crates:
        h.place('trade_13', -196, y, w=78, rot=90); h.place('trade_13', 196, y, w=78, rot=-90)
    h.place('base_09', 0, 1892, w=340)
    h.pair('base_15', 132, 1900, pid_right='base_16', w=92, shadow=0.4)
    aft_block(h, 2280, w=420, pods=(282, 160), bell='base_32', bell_w=130)
    nose(h, 'base_00', 340)
    return h

# ---------------- F-B spine: ribbed truss with containers either side ----------------
def f_b():
    h = Hull('sow_f_b_spine'); h.dy = 151
    for i in range(7):
        h.place('base_03', 0, 640 + i * 262 - 30, w=170, h=289, rot=90, shadow=0)
    cols = ['trade_00', 'trade_24', 'trade_07', 'trade_25', 'trade_35', 'trade_24']
    colsR = ['trade_24', 'trade_07', 'trade_25', 'trade_00', 'trade_24', 'trade_35']
    for i in range(5):
        y = 680 + i * 342
        h.place(cols[i], -202, y, w=232, h=330, rot=90)
        h.place(colsR[i], 202, y, w=232, h=330, rot=-90)
    for i in range(6):
        y = 509 + i * 342
        h.place('trade_16', -92, y, w=70); h.place('trade_16', 92, y, w=70, flip=True)
    h.place('base_02', 0, 442, w=240)
    h.place('base_03', 0, 2268, w=240)
    aft_block(h, 2548, w=420, pods=(282, 160), bell='base_32', bell_w=130)
    nose(h, 'base_01', 330)
    return h

# ---------------- F-C widebody: plated wide hull, big aft engine block ----------------
def f_c():
    h = Hull('sow_f_c_widebody'); h.dy = 334
    for y in (820, 1390):
        h.place('base_06', -378, y, h=600); h.place('base_12', 378, y, h=600)
    for i in range(5):
        h.place('base_03', 0, 470 + i * 262, w=120, h=262, rot=90, shadow=0)
    h.place('base_02', 0, 318, w=280)
    h.place('base_03', 0, 1702, w=280)
    rows = [(545, 'combat_15', 'combat_15', 180), (856, 'combat_31', 'combat_32', 0),
            (1167, 'combat_33', 'combat_34', 0), (1478, 'combat_38', 'combat_31', 0)]
    for y, L, R, rot in rows:
        if rot:
            h.place(L, -152, y, w=300, h=311, rot=rot, flip=True); h.place(R, 152, y, w=300, h=311, rot=rot)
        else:
            h.place(L, -152, y, w=300, h=311); h.place(R, 152, y, w=300, h=311)
    h.place('combat_37', 0, 2140, w=640, rot=-90, glow='exit')
    h.place('base_17', 0, 1850, w=380)
    h.pair('trade_13', 236, 1850, w=90, shadow=0.4)
    nose(h, 'base_00', 360)
    return h

for name, fn in [('c_a', c_a), ('c_b', c_b), ('c_c', c_c), ('f_a', f_a), ('f_b', f_b), ('f_c', f_c)]:
    if only and name not in only: continue
    hh = fn(); res[hh.name] = hh.finish(OUT)
    print(hh.name, res[hh.name])
json.dump(res, open(f'{OUT}/sizes.json', 'w'), indent=1)
