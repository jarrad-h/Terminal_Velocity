"""SOW armed hulls: patrol corvettes (P), cutters (K), cruisers (R).
Turrets are separate sprites on mount rings; ships record their mounts in p.mounts."""
import math
import numpy as np
from kit import Paint, deck, collar, grille, lightstrip, rcs, hatch, nozzle, emblem, m_bow_bridge, reduce, \
    LIGHT, WHITE, DARK, RED, CYAN, RIB, STEEL, HX0, HX1, CX
from kit2 import seg, aft, adapter
from kit4 import aft_cruise_w

ARMOUR = (88, 96, 112)

def _rot(pts, cx, cy, ang):
    a = math.radians(ang); c, s = math.cos(a), math.sin(a)
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]

TUR = {'t1': dict(r=3.4, off=1.4, ln=8.5, w=0.9), 't2': dict(r=5.0, off=1.9, ln=13, w=1.3), 'pd': dict(r=2.0, off=0, ln=4.2, w=0.6)}

def ring(p, cx, cy, kind):
    """TUR-0: empty mount ring in the hull (what shows when no turret is fitted)."""
    r = TUR[kind]['r'] + 0.9
    p.fill(p.ell(cx - r, cy - r, cx + r, cy + r), (30, 34, 44))
    inner = p.ell(cx - r + 0.7, cy - r + 0.7, cx + r - 0.7, cy + r - 0.7)
    p.fill(inner, (96, 104, 120)); p.edges(inner, 0.35, 1.25, 0.6)
    for a in (45, 135, 225, 315):
        bx, by = cx + math.cos(math.radians(a)) * (r - 1.3), cy + math.sin(math.radians(a)) * (r - 1.3)
        p.fill(p.ell(bx - 0.3, by - 0.3, bx + 0.3, by + 0.3), (40, 44, 54))
    p.mounts.append((cx, cy, kind))

def turret_sprite(p, cx, cy, kind, ang=0.0):
    """TUR-1 (light twin), TUR-2 (heavy twin), PD (point defence). Drawn on top of a ring; ang 0 = forward."""
    t = TUR[kind]; r = t['r']
    base = p.ell(cx - r, cy - r, cx + r, cy + r)
    p.fill(base, np.clip(np.asarray((122, 130, 146), np.float32) * p.facet(cx - r, cx + r, 4)[..., None], 0, 255)); p.edges(base, 0.4)
    if kind == 't2':
        for sx in (-1, 1):
            cheek = p.poly(_rot([(cx + sx * 2.4, cy - 3.2), (cx + sx * 4.2, cy - 2.2), (cx + sx * 4.2, cy + 2.6), (cx + sx * 2.4, cy + 3.4)], cx, cy, ang))
            p.fill(cheek, (84, 92, 108)); p.edges(cheek, 0.3)
    offs = (-t['off'], t['off']) if t['off'] else (0,)
    for ox in offs:
        x = cx + ox; w = t['w'] / 2
        bar = p.poly(_rot([(x - w, cy - r * 0.4), (x + w, cy - r * 0.4), (x + w, cy - r * 0.4 - t['ln']), (x - w, cy - r * 0.4 - t['ln'])], cx, cy, ang))
        p.fill(bar, STEEL)
        sh = p.poly(_rot([(x, cy - r * 0.4), (x + w, cy - r * 0.4), (x + w, cy - r * 0.4 - t['ln']), (x, cy - r * 0.4 - t['ln'])], cx, cy, ang))
        p.fill(sh, (84, 90, 104))
        tip = p.poly(_rot([(x - w - 0.2, cy - r * 0.4 - t['ln']), (x + w + 0.2, cy - r * 0.4 - t['ln']), (x + w + 0.2, cy - r * 0.4 - t['ln'] + 1), (x - w - 0.2, cy - r * 0.4 - t['ln'] + 1)], cx, cy, ang))
        p.fill(tip, (56, 62, 76))
    p.fill(p.poly(_rot([(cx - 1.2, cy - r * 0.6), (cx + 1.2, cy - r * 0.6), (cx + 1.2, cy - r * 0.6 + 1), (cx - 1.2, cy - r * 0.6 + 1)], cx, cy, ang)), (40, 44, 54))
    p.fill(p.ell(cx - 0.5, cy + r * 0.3 - 0.5, cx + 0.5, cy + r * 0.3 + 0.5), RED)

def fit_turrets(p, angles=None):
    for i, (cx, cy, kind) in enumerate(p.mounts):
        turret_sprite(p, cx, cy, kind, (angles or {}).get(i, 0.0))

def armour(p, y0, L, x0, x1):
    """ARM overlay: heavy darker plates bolted over the standard deck."""
    cx = (x0 + x1) / 2
    for a0, a1 in ((x0 + 0.8, cx - 0.4), (cx + 0.4, x1 - 0.8)):
        m = p.rect(a0, y0 + 1.6, a1, y0 + L - 1.6, r=0.4)
        p.fill(m, np.clip(np.asarray(ARMOUR, np.float32) * p.facet(x0, x1, 5)[..., None], 0, 255)); p.edges(m, 0.5, 1.3, 0.5)
        for bx in (a0 + 1, a1 - 1):
            for by in (y0 + 2.6, y0 + L - 2.6):
                p.fill(p.ell(bx - 0.35, by - 0.35, bx + 0.35, by + 0.35), (200, 206, 216))

def seg_armed(p, y0, L=16, x0=HX0, x1=HX1, mounts=(), armoured=False, flank=('grille', 'light')):
    """Combat segment: standard (or armour-plated) deck with turret rings. mounts = [(dx, dy, kind)] from segment centre."""
    m = deck(p, y0, y0 + L, x0, x1); cx = (x0 + x1) / 2
    if armoured: armour(p, y0, L, x0, x1)
    else: p.seam(m, [(x0, y0 + L / 2), (x1, y0 + L / 2)], 0.35)
    for side, kind in zip((x0 + 0.6, x1 - 3.6), flank):
        if kind == 'grille': grille(p, side, y0 + 2.5, min(7, L - 5))
        elif kind == 'light': lightstrip(p, side + (1.8 if side > cx else 0), y0 + 4, 3.6)
    for dx, dy, kind in mounts: ring(p, cx + dx, y0 + L / 2 + dy, kind)
    p.wear(m, 10)
    return m

def msl(p, y0, L=16, x0=HX0, x1=HX1, cols=None):
    """MSL-16: missile segment, grid of hatches with one open tube."""
    m = deck(p, y0, y0 + L, x0, x1); cx = (x0 + x1) / 2
    cols = cols or max(2, int((x1 - x0 - 8) // 4.5))
    w = (x1 - x0 - 8) / cols
    for r_ in range(2):
        for c_ in range(cols):
            hx, hy = x0 + 4 + c_ * w + 0.4, y0 + 2.5 + r_ * 6
            h = p.rect(hx, hy, hx + w - 0.8, hy + 5, r=0.3)
            p.fill(h, (60, 66, 80)); p.edges(h, 0.3, 1.3, 0.55)
            p.fill(p.rect(hx, hy, hx + w - 0.8, hy + 0.6), (200, 60, 54))
            if r_ == 0 and c_ == 1:
                p.fill(p.rect(hx + 0.6, hy + 1, hx + w - 1.4, hy + 4.4), (20, 22, 28))
                p.fill(p.poly([(hx + (w - 0.8) / 2, hy + 1.3), (hx + w - 1.8, hy + 3), (hx + 1, hy + 3)]), (220, 222, 230))
    p.wear(m, 8)
    return m

def booms(p, y0):
    """SEN: two forward sensor booms of different sizes, offset (port long and thin, starboard short with a dish)."""
    for x, y_top, w, col in ((32.6, y0 - 9, 0.5, STEEL), (46.8, y0 - 4, 0.9, (130, 138, 152))):
        b = p.rect(x - w / 2, y_top, x + w / 2, y0 + 6.5); p.fill(b, col)
    p.fill(p.rect(31.9, y0 - 10.4, 33.3, y0 - 8.6), (60, 66, 80)); p.glow(p.rect(32.3, y0 - 10.2, 32.9, y0 - 9.6))
    p.fill(p.poly([(44.6, y0 - 4.2), (49, y0 - 4.2), (48, y0 - 5.6), (45.6, y0 - 5.6)]), (176, 182, 194))
    p.fill(p.rect(46.5, y0 - 7, 47.1, y0 - 5.4), (60, 66, 80))

def fwd_guns(p, y0):
    """FWD: fixed forward gun pair in blisters on the bow plate."""
    for x in (31.4, 48.6):
        bl = p.rect(x - 1.9, y0 + 6.5, x + 1.9, y0 + 12, r=0.7); p.fill(bl, (70, 78, 94)); p.edges(bl, 0.35)
        b = p.rect(x - 0.65, y0 - 1, x + 0.65, y0 + 7); p.fill(b, STEEL); p.fill(b * p.rect(x, y0 - 1, x + 0.65, y0 + 7), (84, 90, 104))
        p.fill(p.rect(x - 0.9, y0 - 1.4, x + 0.9, y0 - 0.4), (56, 62, 76))
    p.mounts_fixed = [(31.4, y0 - 1.4), (48.6, y0 - 1.4)]

def docking_bow(p, y0):
    """DCK: docking collar and clamp arms ahead of the bow."""
    for sx in (-1, 1):
        x = CX + sx * 6.5
        arm = p.poly([(x - 0.9, y0 + 8), (x + 0.9, y0 + 8), (x + 0.9 - sx * 1.4, y0 - 6), (x - 0.9 - sx * 1.4, y0 - 6)])
        p.fill(arm, (84, 92, 108)); p.edges(arm, 0.35)
        claw = p.poly([(x - sx * 1.4 - 1, y0 - 6), (x - sx * 1.4 + 1, y0 - 6), (x - sx * 3.4, y0 - 8.4), (x - sx * 3.8, y0 - 7.4)])
        p.fill(claw, (60, 66, 80))
        p.fill(p.rect(x - 0.9, y0 - 1, x + 0.9, y0 + 1), (214, 172, 52))
    col = p.ell(CX - 4, y0 - 3.5, CX + 4, y0 + 4.5); p.fill(col, (52, 58, 72)); p.edges(col, 0.4)
    hz = col * (np.abs(np.hypot(p.X - CX, p.Y - (y0 + 0.5)) - 3.4) < 0.55)
    stripes = (np.floor((np.arctan2(p.Y - (y0 + 0.5), p.X - CX) + math.pi) / (math.pi / 6)) % 2) == 0
    p.fill(hz, np.where(stripes[..., None], np.array([214, 172, 52], np.float32), np.array([30, 30, 32], np.float32)))
    p.fill(p.ell(CX - 2.2, y0 - 1.7, CX + 2.2, y0 + 2.7), (24, 26, 32))

def sponson(p, cx, cy, side):
    """SPN-PD: small hull-side blister carrying a point-defence ring."""
    m = p.ell(cx - 3.2, cy - 3.6, cx + 3.2, cy + 3.6)
    p.fill(m, np.clip(np.asarray(DARK, np.float32) * p.facet(cx - 3.2, cx + 3.2, 3)[..., None], 0, 255)); p.edges(m, 0.4)
    ring(p, cx, cy, 'pd')

# ---------------- ships (y grows towards the stern) ----------------
W0, W1 = 20, 60      # wide plate
X0, X1 = 15, 65      # extra-wide (cruiser) plate

def p_a(p):   # Picket: booms, forward guns, armoured turret segment
    booms(p, 6); m_bow_bridge(p, 6); fwd_guns(p, 6); collar(p, 22)
    seg_armed(p, 23.2, 16, mounts=[(0, 0.5, 't1')], armoured=True); collar(p, 39.2)
    aft(p, 40.4, 12, 4)

def p_b(p):   # Patrol: two turrets and a missile segment
    booms(p, 6); m_bow_bridge(p, 6); collar(p, 22)
    seg_armed(p, 23.2, 16, mounts=[(0, 0.5, 't1')]); collar(p, 39.2)
    msl(p, 40.4); collar(p, 56.4)
    seg_armed(p, 57.6, 16, mounts=[(0, 0.5, 't1')], armoured=True, flank=('light', 'grille')); collar(p, 73.6)
    aft(p, 74.8, 12, 4)

def k_a(p):   # Boarding cutter: docking collar and clamps, crew segment, armoured turret
    docking_bow(p, 6); m_bow_bridge(p, 14); collar(p, 30)
    seg(p, 31.2, 16, 'hatch', ('light', 'grille')); collar(p, 47.2)
    seg_armed(p, 48.4, 16, mounts=[(0, 0.5, 't1')], armoured=True); collar(p, 64.4)
    aft(p, 65.6, 12, 4)

def k_b(p):   # Escort cutter: wide hull, heavy turret, missiles, PD
    booms(p, 6); m_bow_bridge(p, 6); collar(p, 22)
    adapter(p, 23.2, 9, W0, W1); collar(p, 32.2, W0 - 0.6, W1 + 0.6)
    seg_armed(p, 33.4, 16, W0, W1, mounts=[(0, 0.5, 't2')], armoured=True); collar(p, 49.4, W0 - 0.6, W1 + 0.6)
    msl(p, 50.6, 16, W0, W1); collar(p, 66.6, W0 - 0.6, W1 + 0.6)
    sponson(p, W0 - 2, 76, -1); sponson(p, W1 + 2, 76, 1)
    seg_armed(p, 67.8, 16, W0, W1, mounts=[]); collar(p, 83.8, W0 - 0.6, W1 + 0.6)
    aft(p, 85, 12, 6, W0, W1)

def r_a(p):   # Gun cruiser: extra-wide, three heavy turrets, PD sponsons
    booms(p, 6); m_bow_bridge(p, 6); fwd_guns(p, 6); collar(p, 22)
    adapter(p, 23.2, 7, W0, W1); collar(p, 30.2, W0 - 0.6, W1 + 0.6)
    adapter(p, 31.4, 5, X0, X1, W0, W1); collar(p, 36.4, X0 - 0.6, X1 + 0.6)
    y = 37.6
    for mounts, arm in (([(0, 0.5, 't2')], True), ([(-12, 0, 't1'), (12, 0, 't1')], False), ([(0, 0.5, 't2')], True), ([(0, 0.5, 't2')], True)):
        seg_armed(p, y, 16, X0, X1, mounts=mounts, armoured=arm); collar(p, y + 16, X0 - 0.6, X1 + 0.6); y += 17.2
    for yy in (46, 80): sponson(p, X0 - 2, yy, -1); sponson(p, X1 + 2, yy, 1)
    aft(p, y, 12, 6, X0, X1)

def r_b(p):   # Missile cruiser: longest hull, missile batteries, heavy turret, PD, cruise drive
    booms(p, 6); m_bow_bridge(p, 6); collar(p, 22)
    adapter(p, 23.2, 7, W0, W1); collar(p, 30.2, W0 - 0.6, W1 + 0.6)
    adapter(p, 31.4, 5, X0, X1, W0, W1); collar(p, 36.4, X0 - 0.6, X1 + 0.6)
    y = 37.6
    plan = (('arm', [(0, 0.5, 't2')]), ('msl', None), ('msl', None), ('arm', [(-12, 0, 't1'), (12, 0, 't1')]), ('msl', None))
    for kind, mounts in plan:
        if kind == 'msl': msl(p, y, 16, X0, X1)
        else: seg_armed(p, y, 16, X0, X1, mounts=mounts, armoured=True)
        collar(p, y + 16, X0 - 0.6, X1 + 0.6); y += 17.2
    for yy in (63, 98): sponson(p, X0 - 2, yy, -1); sponson(p, X1 + 2, yy, 1)
    aft_cruise_w(p, y, 12, X0, X1, 2)

SHIPS = {'sow_p_a_picket': (p_a, 64), 'sow_p_b_patrol': (p_b, 98),
         'sow_k_a_boarding': (k_a, 90), 'sow_k_b_escort': (k_b, 110),
         'sow_r_a_gun_cruiser': (r_a, 128), 'sow_r_b_missile_cruiser': (r_b, 140)}

def build(fn, h, turrets=True, angles=None):
    p = Paint(80, h); p.mounts = []; p.mounts_fixed = []
    fn(p)
    if turrets: fit_turrets(p, angles)
    return p
