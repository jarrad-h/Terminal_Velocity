"""SOW armed hulls, pass 3: hugging splayed nacelles, tapers into necks, two missile styles
(VLS-3 round hatches on large hulls, VLS-4 centre strip on small ones)."""
import math
import numpy as np
from kit import Paint, deck, collar, rcs, nozzle, m_bow_bridge, LIGHT, WHITE, DARK, RED, RIB, STEEL, HX0, HX1, CX
from kit2 import aft
from kit3 import aft_cruise
from kit5 import seg_armed, booms, fwd_guns, sponson
from kit6 import neck, vls_round, vls_strip, fit

NECK_W = 12

def taper(p, y0, L, w_top, w_bot):
    """TPR: tapered transition in standard hull material (white deck over slate), e.g. into or out of a neck."""
    t0, t1, b0, b1 = CX - w_top / 2, CX + w_top / 2, CX - w_bot / 2, CX + w_bot / 2
    m = p.poly([(t0, y0), (t1, y0), (b1, y0 + L), (b0, y0 + L)])
    wide = max(w_top, w_bot)
    half = (w_top + (w_bot - w_top) * np.clip((p.Y - y0) / L, 0, 1)) / 2      # local half-width at this row
    deckw = half * 0.6
    col = np.where((np.abs(p.X - CX) < deckw)[..., None], np.asarray(LIGHT, np.float32), np.asarray(DARK, np.float32))
    n = np.clip((p.X - CX) / np.maximum(half, 0.5), -0.99, 0.99)
    nf = np.clip((np.floor((n + 1) / 2 * 5) + 0.5) / 5 * 2 - 1, -0.99, 0.99)
    f = 0.6 + 0.52 * np.clip(0.8 * np.sqrt(1 - nf ** 2) - 0.5 * nf, 0, None)
    p.fill(m, np.clip(col * f[..., None], 0, 255)); p.edges(m)
    yw = y0 + 0.8 if w_top > w_bot else y0 + L - 0.8
    p.rivets(m, yw, CX - wide / 2 + 1, CX + wide / 2 - 1)
    p.wear(m, 3)

def necked(p, y0, neck_len, taper_len=5):
    """Taper in, neck, taper out. Returns the y where the next full-width module starts."""
    taper(p, y0, taper_len, HX1 - HX0, NECK_W)
    neck(p, y0 + taper_len, neck_len, NECK_W)
    taper(p, y0 + taper_len + neck_len, taper_len, NECK_W, HX1 - HX0)
    return y0 + 2 * taper_len + neck_len

def nacelle(p, side, y0, L, w, ang=8.0, gap=0.5, big=False):
    """NAC: engine nacelle hugging the hull on a stub pylon, splayed outward towards the stern by `ang` degrees."""
    hull_x = HX0 if side < 0 else HX1
    cx = hull_x + side * (gap + w / 2)
    a = math.radians(ang)
    vx, vy = side * math.sin(a), math.cos(a)                     # unit vector from bow to stern of the nacelle
    lx = (p.X - cx) * vy - (p.Y - y0) * vx                         # across the nacelle
    ly = (p.X - cx) * vx + (p.Y - y0) * vy                         # along the nacelle
    def world(x, y): return (cx + x * vy + y * vx, y0 - x * vx + y * vy)
    def rrect(hw, y_a, y_b, r):
        qx = np.abs(lx) - (hw - r); qy = np.abs(ly - (y_a + y_b) / 2) - ((y_b - y_a) / 2 - r)
        d = np.hypot(np.maximum(qx, 0), np.maximum(qy, 0)) + np.minimum(np.maximum(qx, qy), 0) - r
        return np.clip(0.5 - d * 8, 0, 1)
    # stub pylon at the front third
    py = y0 + L * 0.3
    pl = p.rect(min(hull_x, cx - side * w / 2) - 0.3, py, max(hull_x, cx - side * w / 2) + 0.3, py + 3.2)
    p.fill(pl, (56, 62, 76)); p.edges(pl, 0.3)
    body = rrect(w / 2, 0, L, w * 0.46)
    n = np.clip(lx / (w / 2), -0.99, 0.99); nf = np.clip((np.floor((n * side + 1) / 2 * 4) + 0.5) / 4 * 2 - 1, -0.99, 0.99) * side
    f = 0.6 + 0.52 * np.clip(0.8 * np.sqrt(1 - nf ** 2) - 0.5 * nf * side * np.sign(side), 0, None)
    two = np.where((lx * side > 0)[..., None], np.asarray(WHITE, np.float32), np.asarray(DARK, np.float32))
    p.fill(body, np.clip(two * f[..., None], 0, 255)); p.edges(body, 0.45)
    intake = np.clip(0.5 - (np.hypot(lx / (w / 2 - 1), (ly - w * 0.3) / (w * 0.22)) - 1) * 8, 0, 1) * body
    p.fill(intake, (30, 34, 44))
    inner = np.clip(0.5 - (np.hypot(lx / (w / 2 - 2), (ly - w * 0.3) / (w * 0.15)) - 1) * 8, 0, 1) * body
    p.fill(inner, (64, 70, 84))
    for t in (0.45, 0.75): p.fill(body * (np.abs(ly - L * t) < 0.22), (28, 32, 42), 0.85, solid=False)
    p.fill(body * ((ly > L * 0.32) & (ly < L * 0.32 + 0.9)), RED)
    gl = body * (np.abs(lx - side * (w / 2 - 1.4)) < 0.3) * ((ly > L * 0.52) & (ly < L * 0.52 + 2.4))
    p.glow(gl)
    # nozzle on the nacelle's own axis
    nw, nh = w * (0.95 if big else 0.85), (5.5 if big else 3.6)
    noz = p.poly([world(-nw * 0.38, L - 0.6), world(nw * 0.38, L - 0.6), world(nw / 2, L - 0.6 + nh), world(-nw / 2, L - 0.6 + nh)])
    shade = np.clip(0.55 + 0.6 * np.sqrt(np.clip(1 - (lx / (nw / 2)) ** 2, 0, 1)) - 0.3 * lx / (nw / 2), 0.2, 1.3)
    p.fill(noz, np.clip(np.array([62, 68, 82], np.float32) * shade[..., None], 0, 255)); p.edges(noz, 0.4)
    p.glow(p.poly([world(-nw * 0.42, L - 1.5 + nh), world(nw * 0.42, L - 1.5 + nh), world(nw / 2 - 0.2, L - 0.6 + nh), world(-nw / 2 + 0.2, L - 0.6 + nh)]))

# ---------------- hulls ----------------
def p_b(p):   # Patrol: two light turrets, VLS-4 strip
    booms(p, 6); m_bow_bridge(p, 6); collar(p, 22)
    seg_armed(p, 23.2, 16, mounts=[(0, 0.5, 't1')]); collar(p, 39.2)
    vls_strip(p, 40.4); collar(p, 56.4)
    seg_armed(p, 57.6, 16, mounts=[(0, 0.5, 't1')], armoured=True, flank=('light', 'grille')); collar(p, 73.6)
    aft(p, 74.8, 12, 4)

def k_b(p):   # Escort cutter: heavy turret, neck, VLS-4 strip, small nacelles
    booms(p, 6); m_bow_bridge(p, 6); collar(p, 22)
    seg_armed(p, 23.2, 16, mounts=[(0, 0.5, 't2')], armoured=True)
    y = necked(p, 39.2, 6)
    vls_strip(p, y); collar(p, y + 16)
    sponson(p, HX0 - 2, y + 5, -1); sponson(p, HX1 + 2, y + 5, 1)
    nacelle(p, -1, y + 11, 18, 7); nacelle(p, 1, y + 11, 18, 7)
    aft(p, y + 17.2, 12, 4)

def r_a(p):   # Gun cruiser: two heavy turrets around a neck, twin light turrets, big nacelles
    booms(p, 6); m_bow_bridge(p, 6); fwd_guns(p, 6); collar(p, 22)
    seg_armed(p, 23.2, 16, mounts=[(0, 0.5, 't2')], armoured=True)
    y = necked(p, 39.2, 6)
    seg_armed(p, y, 16, mounts=[(0, 0.5, 't2')], armoured=True, flank=('light', 'grille')); collar(p, y + 16)
    sponson(p, HX0 - 2, y + 8, -1); sponson(p, HX1 + 2, y + 8, 1)
    y += 17.2
    seg_armed(p, y, 16, mounts=[(-6.4, 0, 't1'), (6.4, 0, 't1')]); collar(p, y + 16)
    nacelle(p, -1, y + 6, 22, 10, big=True); nacelle(p, 1, y + 6, 22, 10, big=True)
    aft_cruise(p, y + 17.2, 12)

def r_b(p):   # Missile cruiser: two VLS-3 batteries, heavy turret, twin light turrets, big nacelles
    booms(p, 6); m_bow_bridge(p, 6); collar(p, 22)
    vls_round(p, 23.2); collar(p, 39.2)
    seg_armed(p, 40.4, 16, mounts=[(0, 0.5, 't2')], armoured=True)
    y = necked(p, 56.4, 8)
    vls_round(p, y); collar(p, y + 16)
    sponson(p, HX0 - 2, y + 8, -1); sponson(p, HX1 + 2, y + 8, 1)
    y += 17.2
    seg_armed(p, y, 16, mounts=[(-6.4, 0, 't1'), (6.4, 0, 't1')], flank=('grille', 'light')); collar(p, y + 16)
    nacelle(p, -1, y + 6, 24, 10, big=True); nacelle(p, 1, y + 6, 24, 10, big=True)
    aft_cruise(p, y + 17.2, 12)

SHIPS = {'sow_p_b_patrol': (p_b, 94), 'sow_k_b_escort': (k_b, 98),
         'sow_r_a_gun_cruiser': (r_a, 116), 'sow_r_b_missile_cruiser': (r_b, 134)}

def build(fn, h, turrets=True):
    p = Paint(80, h); p.mounts = []; p.mounts_fixed = []
    fn(p)
    if turrets: fit(p)
    return p
