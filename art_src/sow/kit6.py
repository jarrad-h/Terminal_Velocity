"""SOW armed hulls, pass 2: missile launcher styles, narrow spine necks, engine nacelles.
Bigger hulls grow by length, necks and nacelles instead of wider plates."""
import math
import numpy as np
from kit import Paint, deck, collar, grille, lightstrip, rcs, nozzle, emblem, m_bow_bridge, reduce, \
    LIGHT, WHITE, DARK, RED, CYAN, RIB, STEEL, HX0, HX1, CX
from kit2 import aft
from kit3 import aft_cruise
import kit5
from kit5 import seg_armed, booms, fwd_guns, sponson, ring, TUR, _rot

YEL = (214, 172, 52)
TUR['ml'] = dict(r=3.6, off=0, ln=0, w=0)

def _shade(p, m, base, x0, x1, facets=4):
    p.fill(m, np.clip(np.asarray(base, np.float32) * p.facet(x0, x1, facets)[..., None], 0, 255))

def seg_base(p, y0, L=16, flank=('grille', 'light')):
    m = deck(p, y0, y0 + L)
    for side, kind in zip((HX0 + 0.6, HX1 - 3.6), flank):
        if kind == 'grille': grille(p, side, y0 + 2.5, min(7, L - 5))
        elif kind == 'light': lightstrip(p, side + (1.8 if side > CX else 0), y0 + 4, 3.6)
    return m

def missile_nose(p, cx, cy, r=0.9):
    p.fill(p.ell(cx - r, cy - r, cx + r, cy + r), (226, 228, 234)); p.fill(p.ell(cx - r * 0.45, cy - r * 0.45, cx + r * 0.45, cy + r * 0.45), RED)

# ---------------- missile launcher styles ----------------
def vls_red(p, y0):            # VLS-1: the original red-rimmed hatch grid
    kit5.msl(p, y0)

def vls_lids(p, y0):           # VLS-2: armoured rectangular lids, no red, yellow cell numbers
    m = seg_base(p, y0, flank=('grille', 'grille'))
    for r_ in range(2):
        for c_ in range(4):
            x, y = 30.4 + c_ * 5, y0 + 2.4 + r_ * 5.8
            fr = p.rect(x - 0.4, y - 0.4, x + 4.4, y + 5.4); p.fill(fr, (36, 40, 50))
            lid = p.rect(x, y, x + 4, y + 5, r=0.3)
            if (r_, c_) == (0, 2):
                p.fill(lid, (16, 18, 24)); missile_nose(p, x + 2, y + 2.5)
            else:
                _shade(p, lid, (112, 120, 136), 30, 50, 4); p.edges(lid, 0.35, 1.3, 0.55)
                p.fill(p.rect(x + 0.4, y + 0.5, x + 3.6, y + 0.9), (150, 158, 172))
            p.fill(p.rect(x + 3.2, y + 4.1, x + 3.8, y + 4.6), YEL)
    p.wear(m, 6)

def _launcher(p, cx, cy, code, cells):
    if hasattr(p, 'launchers'): p.launchers.append((cx, cy, code, cells))

def vls_round(p, y0):          # VLS-3: round hatches, hex-packed
    _launcher(p, CX, y0 + 8, 'VLS-3', 11)
    m = seg_base(p, y0, flank=('light', 'grille'))
    rows = ((4, 0.0), (3, 2.5), (4, 0.0))
    for ri, (n, off) in enumerate(rows):
        for ci in range(n):
            cx, cy = 32.5 + off + ci * 5, y0 + 3.4 + ri * 4.6
            p.fill(p.ell(cx - 2.1, cy - 2.1, cx + 2.1, cy + 2.1), (34, 38, 48))
            lid = p.ell(cx - 1.6, cy - 1.6, cx + 1.6, cy + 1.6)
            if (ri, ci) == (1, 1):
                p.fill(lid, (16, 18, 24)); missile_nose(p, cx, cy, 0.8)
            else:
                _shade(p, lid, (120, 128, 144), cx - 1.6, cx + 1.6, 3); p.edges(lid, 0.3, 1.3, 0.6)
                p.fill(p.ell(cx - 0.35, cy - 0.35, cx + 0.35, cy + 0.35), (60, 66, 80))
    p.wear(m, 6)

def vls_strip(p, y0):          # VLS-4: one narrow centreline launcher block, hazard-edged
    _launcher(p, CX, y0 + 8, 'VLS-4', 6)
    m = seg_base(p, y0, flank=('grille', 'light'))
    st = p.rect(35.6, y0 + 1.6, 44.4, y0 + 14.4); p.fill(st, (40, 44, 54))
    hz = st * ~(p.rect(36.3, y0 + 2.3, 43.7, y0 + 13.7) > 0.5)
    stripes = (np.floor((p.X + p.Y) / 1.4) % 2) == 0
    p.fill(hz, np.where(stripes[..., None], np.array(YEL, np.float32), np.array([30, 30, 32], np.float32)))
    for r_ in range(3):
        for c_ in range(2):
            x, y = 36.8 + c_ * 3.4, y0 + 2.8 + r_ * 3.6
            d = p.rect(x, y, x + 3, y + 3.2, r=0.2)
            if (r_, c_) == (1, 0): p.fill(d, (16, 18, 24)); missile_nose(p, x + 1.5, y + 1.6, 0.7)
            else: _shade(p, d, (116, 124, 140), 36, 44, 2); p.edges(d, 0.3, 1.3, 0.55)
    p.wear(m, 6)

def vls_well(p, y0):           # VLS-5: open recessed well, missiles visible under a grating
    m = seg_base(p, y0, flank=('light', 'light'))
    well = p.rect(31, y0 + 2, 49, y0 + 14); p.fill(well, (22, 24, 30))
    p.edges(well, 0.6, 0.5, 1.6)                               # inverted bevel: it's a recess
    for r_ in range(2):
        for c_ in range(4):
            missile_nose(p, 33.4 + c_ * 4.4, y0 + 5 + r_ * 6, 1.1)
    for x in np.arange(31.6, 49, 2.2): p.fill(well * p.rect(x, y0 + 2, x + 0.3, y0 + 14), (96, 104, 120), 0.8, solid=False)
    p.wear(m, 6)

def pod_box(p, cx, y0, L=12, w=6, hull_x=None):
    """POD: bolt-on box launcher, 2x3 tubes facing forward."""
    if hull_x is not None:
        x0, x1 = sorted((cx, hull_x))
        for py in (y0 + 3, y0 + L - 4):
            pl = p.rect(x0, py, x1, py + 1.6); p.fill(pl, (50, 56, 70)); p.edges(pl, 0.3)
    b = p.rect(cx - w / 2, y0, cx + w / 2, y0 + L, r=0.5)
    _shade(p, b, (110, 118, 134), cx - w / 2, cx + w / 2, 3); p.edges(b, 0.45)
    face = p.rect(cx - w / 2 + 0.5, y0 + 0.5, cx + w / 2 - 0.5, y0 + 4.2); p.fill(face, (40, 44, 54))
    for r_ in range(2):
        for c_ in range(3):
            tx, ty = cx - w / 2 + 1.3 + c_ * (w - 2.6) / 2, y0 + 1.5 + r_ * 1.7
            p.fill(p.ell(tx - 0.6, ty - 0.6, tx + 0.6, ty + 0.6), (14, 16, 20))
    p.fill(p.rect(cx - w / 2, y0 + L * 0.6, cx + w / 2, y0 + L * 0.6 + 0.8), RED)
    p.rivets(b, y0 + L - 1, cx - w / 2 + 0.8, cx + w / 2, 1.4)

def pod_seg(p, y0):            # POD-1: plain segment with two box launchers on stub pylons
    seg_base(p, y0, flank=('grille', 'grille'))
    pod_box(p, HX0 - 4.2, y0 + 2, 12, 5.6, HX0); pod_box(p, HX1 + 4.2, y0 + 2, 12, 5.6, HX1)

def launcher_turret(p, cx, cy, ang=0.0):
    """ML-1: rotating box launcher on a turret ring (turret sprite kind 'ml')."""
    r = 3.6
    base = p.ell(cx - r, cy - r, cx + r, cy + r); _shade(p, base, (122, 130, 146), cx - r, cx + r); p.edges(base, 0.4)
    box = p.poly(_rot([(cx - 3.2, cy - 5.6), (cx + 3.2, cy - 5.6), (cx + 3.2, cy + 1.4), (cx - 3.2, cy + 1.4)], cx, cy, ang))
    p.fill(box, (104, 112, 128)); p.edges(box, 0.35)
    face = p.poly(_rot([(cx - 2.8, cy - 5.3), (cx + 2.8, cy - 5.3), (cx + 2.8, cy - 2.6), (cx - 2.8, cy - 2.6)], cx, cy, ang))
    p.fill(face, (40, 44, 54))
    for dx in (-1.4, 1.4):
        for dy in (-4.6, -3.3):
            (tx, ty), = _rot([(cx + dx, cy + dy)], cx, cy, ang)
            p.fill(p.ell(tx - 0.5, ty - 0.5, tx + 0.5, ty + 0.5), (14, 16, 20))
    (sx, sy), = _rot([(cx, cy - 0.4)], cx, cy, ang)
    p.fill(p.ell(sx - 0.5, sy - 0.5, sx + 0.5, sy + 0.5), RED)

def ml_seg(p, y0):             # ML-1 on a standard segment
    seg_base(p, y0, flank=('light', 'grille')); ring(p, CX, y0 + 8.5, 'ml')

def int_flank(p, y0):          # INT-1: launch slots built into both flanks
    m = seg_base(p, y0, flank=(None, None))
    for side in (-1, 1):
        xin, xout = (CX - 8.6, HX0 + 0.6) if side < 0 else (CX + 8.6, HX1 - 0.6)
        for k in range(3):
            y = y0 + 2.4 + k * 4.4
            fr = p.poly([(xout, y + 1.0), (xin, y - 0.6), (xin, y + 3.0), (xout, y + 4.6)]); p.fill(fr, (150, 158, 172))
            sl = p.poly([(xout, y + 1.6), (xin, y), (xin, y + 2.4), (xout, y + 4.0)])
            p.fill(sl, (16, 18, 24))
            p.fill(p.poly([(xout, y + 1.0), (xin, y - 0.6), (xin, y - 0.1), (xout, y + 1.5)]), YEL)
    p.wear(m, 6)

def int_bow(p, y0):            # INT-2: four forward tubes in the bow plate either side of the bridge
    m_bow_bridge(p, y0)
    for x in (29.8, 31.9, 48.1, 50.2):
        p.fill(p.ell(x - 1.1, y0 + 12.4, x + 1.1, y0 + 14.6), (200, 60, 54))
        p.fill(p.ell(x - 0.75, y0 + 12.75, x + 0.75, y0 + 14.25), (16, 18, 24))

STYLES = [('vls_red', 'VLS-1', vls_red), ('vls_lids', 'VLS-2', vls_lids), ('vls_round', 'VLS-3', vls_round),
          ('vls_strip', 'VLS-4', vls_strip), ('vls_well', 'VLS-5', vls_well), ('pod_seg', 'POD-1', pod_seg),
          ('ml_seg', 'ML-1', ml_seg), ('int_flank', 'INT-1', int_flank), ('int_bow', 'INT-2', int_bow)]

# ---------------- necks and nacelles ----------------
def neck(p, y0, L, w=12):
    """SPN-N: narrow structural neck between modules (truss, pipe runs, a light)."""
    x0, x1 = CX - w / 2, CX + w / 2
    m = p.rect(x0, y0, x1, y0 + L); _shade(p, m, DARK, x0, x1, 3); p.edges(m, 0.4)
    for y in np.arange(y0 + 0.7, y0 + L - 0.3, 1.4):
        p.fill(m * p.rect(x0, y, x1, y + 0.4), (34, 38, 48), 0.7, solid=False)
    for x in (x0 + 1.4, x1 - 1.9):
        pr = p.rect(x, y0, x + 0.5, y0 + L); p.fill(pr, (150, 158, 172)); p.fill(pr * p.rect(x + 0.25, y0, x + 0.5, y0 + L), (90, 96, 110))
    p.glow(p.rect(CX - 0.4, y0 + L / 2 - 0.8, CX + 0.4, y0 + L / 2 + 0.8))
    collar(p, y0 - 0.6, x0 - 0.8, x1 + 0.8); collar(p, y0 + L - 0.6, x0 - 0.8, x1 + 0.8)

def nacelle(p, cx, y0, L, w, hull_x, pylon_ys, big=False):
    """NAC: engine nacelle on pylons, two-tone faceted drum with an intake and its own nozzle."""
    for py in pylon_ys:
        x0, x1 = sorted((cx, hull_x))
        pl = p.poly([(x0, py - 1.2), (x1, py), (x1, py + 3.6), (x0, py + 4.8)]) if cx < CX else p.poly([(x0, py), (x1, py - 1.2), (x1, py + 4.8), (x0, py + 3.6)])
        _shade(p, pl, (62, 70, 86), x0, x1, 2); p.edges(pl, 0.35)
        for xx in np.arange(x0 + 1, x1 - 0.5, 1.6): p.fill(pl * p.rect(xx, py - 2, xx + 0.4, py + 6), (36, 40, 50), 0.7, solid=False)
    b = p.rect(cx - w / 2, y0, cx + w / 2, y0 + L, r=w * 0.46)
    side = 1 if cx > CX else -1
    two = np.where(((p.X - cx) * side > 0)[..., None], np.asarray(WHITE, np.float32), np.asarray(DARK, np.float32))
    p.fill(b, np.clip(two * p.facet(cx - w / 2, cx + w / 2, 4)[..., None], 0, 255)); p.edges(b, 0.45)
    p.fill(p.ell(cx - w / 2 + 1, y0 + 0.6, cx + w / 2 - 1, y0 + w * 0.5), (30, 34, 44))
    p.fill(p.ell(cx - w / 2 + 2, y0 + 1.4, cx + w / 2 - 2, y0 + w * 0.42), (60, 66, 80))
    for t in (0.42, 0.72): p.fill(b * p.rect(cx - w / 2, y0 + L * t, cx + w / 2, y0 + L * t + 0.45), (28, 32, 42), 0.8, solid=False)
    p.fill(b * p.rect(cx - w / 2, y0 + L * 0.3, cx + w / 2, y0 + L * 0.3 + 0.9), RED)
    p.glow(p.rect(cx + side * (w / 2 - 1.4) - 0.3, y0 + L * 0.5, cx + side * (w / 2 - 1.4) + 0.3, y0 + L * 0.5 + 2.4))
    nozzle(p, cx, y0 + L - 0.5, w * (0.95 if big else 0.85), 5.5 if big else 3.6)

# ---------------- pass-2 hulls (standard width; grow by length, necks and nacelles) ----------------
def k_b(p):   # Escort cutter
    booms(p, 6); m_bow_bridge(p, 6); collar(p, 22)
    seg_armed(p, 23.2, 16, mounts=[(0, 0.5, 't2')], armoured=True); collar(p, 39.2)
    neck(p, 40.4, 7)
    vls_strip(p, 47.4); collar(p, 63.4)
    sponson(p, HX0 - 2, 55, -1); sponson(p, HX1 + 2, 55, 1)
    nacelle(p, 18.5, 60, 17, 8, HX0, (66,)); nacelle(p, 61.5, 60, 17, 8, HX1, (66,))
    aft(p, 64.6, 12, 4)

def r_a(p):   # Gun cruiser
    booms(p, 6); m_bow_bridge(p, 6); fwd_guns(p, 6); collar(p, 22)
    seg_armed(p, 23.2, 16, mounts=[(0, 0.5, 't2')], armoured=True); collar(p, 39.2)
    neck(p, 40.4, 6)
    seg_armed(p, 46.4, 16, mounts=[(0, 0.5, 't2')], armoured=True, flank=('light', 'grille')); collar(p, 62.4)
    sponson(p, HX0 - 2, 54, -1); sponson(p, HX1 + 2, 54, 1)
    seg_armed(p, 63.6, 16, mounts=[(-6.4, 0, 't1'), (6.4, 0, 't1')]); collar(p, 79.6)
    neck(p, 80.8, 8)
    nacelle(p, 15.5, 76, 21, 11, HX0, (84,), big=True); nacelle(p, 64.5, 76, 21, 11, HX1, (84,), big=True)
    aft_cruise(p, 88.8, 12)

def r_b(p):   # Missile cruiser
    booms(p, 6); int_bow(p, 6); collar(p, 22)
    vls_lids(p, 23.2); collar(p, 39.2)
    seg_armed(p, 40.4, 16, mounts=[(0, 0.5, 't2')], armoured=True); collar(p, 56.4)
    neck(p, 57.6, 10)
    pod_box(p, 25, 55, 14, 6, CX - 6); pod_box(p, 55, 55, 14, 6, CX + 6)
    vls_round(p, 67.6); collar(p, 83.6)
    sponson(p, HX0 - 2, 75, -1); sponson(p, HX1 + 2, 75, 1)
    seg_armed(p, 84.8, 16, mounts=[(-6.4, 0, 't1'), (6.4, 0, 't1')], flank=('grille', 'light')); collar(p, 100.8)
    neck(p, 102, 6)
    nacelle(p, 15.5, 94, 22, 11, HX0, (102,), big=True); nacelle(p, 64.5, 94, 22, 11, HX1, (102,), big=True)
    aft_cruise(p, 108, 12)

SHIPS = {'sow_k_b_escort': (k_b, 96), 'sow_r_a_gun_cruiser': (r_a, 112), 'sow_r_b_missile_cruiser': (r_b, 132)}

def fit(p, angles=None):
    for i, (cx, cy, kind) in enumerate(p.mounts):
        a = (angles or {}).get(i, 0.0)
        if kind == 'ml': launcher_turret(p, cx, cy, a)
        else: kit5.turret_sprite(p, cx, cy, kind, a)

def build(fn, h, turrets=True):
    p = Paint(80, h); p.mounts = []; p.mounts_fixed = []
    fn(p)
    if turrets: fit(p)
    return p
