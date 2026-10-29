"""Pirate raider concepts: stolen / chop-shopped SOW hulls with wear, painted-over livery, graffiti
and asymmetric guns (2x light laser + 1 mining beam, matching data/ships/pirate_raider.json)."""
import math
import numpy as np
from kit import Paint, deck, collar, nozzle, m_bow_bridge, reduce, LIGHT, WHITE, DARK, RED, RIB, STEEL, HX0, HX1, CX
from kit2 import seg, aft, booster
from kit5 import seg_armed
from kit7 import taper, nacelle, NECK_W
from kit6 import neck

TAG_COLS = [(150, 240, 70), (240, 80, 200), (250, 210, 60), (236, 236, 236)]
RUST = (128, 72, 44)
CHAR = (36, 34, 36)
HOT = (255, 150, 70)

def grime(p, m, n=40, rust=0.5):
    k = m[..., None]                     # weathered: darker, warmer, less SOW-clean
    p.rgb = p.rgb * (1 - k) + (p.rgb * np.array([0.8, 0.76, 0.72], np.float32)) * k
    n = int(n * 1.8)
    for _ in range(n):
        x, y = p.rng.uniform(0, p.uw), p.rng.uniform(0, p.uh); r = p.rng.uniform(0.8, 3.4)
        col = RUST if p.rng.random() < rust else (34, 30, 30)
        p.fill(m * p.ell(x - r, y - r * 0.7, x + r, y + r * 0.7), col, p.rng.uniform(0.25, 0.55), solid=False)
    for _ in range(n // 2):          # streaks running aft
        x, y = p.rng.uniform(0, p.uw), p.rng.uniform(0, p.uh); l = p.rng.uniform(2, 6)
        p.fill(m * p.rect(x, y, x + 0.35, y + l), (40, 34, 30), 0.35, solid=False)

def paint_over(p, m, x0, y0, x1, y1):
    """Crude charcoal over-paint, ragged edges and drips."""
    p.fill(m * p.rect(x0, y0, x1, y1), CHAR, 0.92, solid=False)
    for x in np.arange(x0, x1, 0.9):
        if p.rng.random() < 0.35:
            l = p.rng.uniform(0.6, 2.2); p.fill(m * p.rect(x, y1, x + 0.4, y1 + l), CHAR, 0.85, solid=False)

def tag(p, m, x, y, w, h, col):
    """Spray-paint tag: a looping scrawl with an underline."""
    pts = [(x + w * t, y + h * (0.5 + 0.45 * math.sin(t * 11 + p.rng.uniform(-0.6, 0.6)))) for t in np.linspace(0, 1, 9)]
    p.fill(m * p.line(pts, 0.42), col, 0.95, solid=False)
    p.fill(m * p.line([(x, y + h + 0.6), (x + w * 0.8, y + h + 0.3)], 0.3), col, 0.9, solid=False)

def tally(p, m, x, y, n):
    for i in range(n):
        p.fill(m * p.rect(x + i * 0.75, y, x + i * 0.75 + 0.35, y + 2.2), (236, 236, 236), 0.95, solid=False)
    if n >= 5: p.fill(m * p.line([(x - 0.3, y + 1.8), (x + 3.6, y + 0.4)], 0.3), (236, 236, 236), 0.95, solid=False)

def teeth(p, m, x0, x1, y, h=2.6):
    """Painted mouth: red band with white zigzag teeth."""
    p.fill(m * p.rect(x0, y, x1, y + h), (170, 30, 30), 0.95, solid=False)
    n = int((x1 - x0) / 1.6)
    for i in range(n):
        tx = x0 + i * (x1 - x0) / n
        p.fill(m * p.poly([(tx, y), (tx + (x1 - x0) / n, y), (tx + (x1 - x0) / n / 2, y + h * 0.7)]), (236, 236, 230), solid=False)
        p.fill(m * p.poly([(tx + (x1 - x0) / n / 2, y + h), (tx + (x1 - x0) / n * 1.5, y + h), (tx + (x1 - x0) / n, y + h * 0.35)]), (236, 236, 230), solid=False)

def gun_box(p, x, y, L=7, w=3.2):
    """Bolted-on laser: crude box mount, single barrel, bolts at the corners."""
    b = p.rect(x - w / 2, y, x + w / 2, y + 4, r=0.3); p.fill(b, (82, 74, 70)); p.edges(b, 0.35)
    for bx, by in ((x - w / 2 + 0.5, y + 0.5), (x + w / 2 - 0.5, y + 0.5), (x - w / 2 + 0.5, y + 3.5), (x + w / 2 - 0.5, y + 3.5)):
        p.fill(p.ell(bx - 0.25, by - 0.25, bx + 0.25, by + 0.25), (210, 200, 180))
    br = p.rect(x - 0.55, y - L, x + 0.55, y + 0.4); p.fill(br, STEEL); p.fill(br * p.rect(x, y - L, x + 0.55, y + 0.4), (84, 90, 104))
    p.fill(p.rect(x - 0.8, y - L - 0.6, x + 0.8, y - L + 0.4), (60, 54, 52))
    p.mounts_fixed.append((x, y - L - 0.6, 'gun'))

def beam_strut(p, x, y_from, y_to):
    """Mining beam emitter on a strut: stolen industrial gear."""
    s = p.rect(x - 0.45, y_to, x + 0.45, y_from); p.fill(s, (96, 90, 84))
    p.fill(p.rect(x - 1.2, y_to + 1.2, x + 1.2, y_to + 2.2), (60, 54, 52))
    em = p.poly([(x, y_to - 1.6), (x + 1.4, y_to), (x, y_to + 1.4), (x - 1.4, y_to)]); p.fill(em, (40, 60, 44))
    p.glow(p.poly([(x, y_to - 1), (x + 0.8, y_to), (x, y_to + 0.8), (x - 0.8, y_to)]), (110, 255, 140))
    p.mounts_fixed.append((x, y_to - 1.6, 'beam'))

def scrap_plate(p, pts, col=RUST):
    m = p.poly(pts); p.fill(m, col); p.edges(m, 0.4)
    for x, y in pts:
        cx = sum(q[0] for q in pts) / len(pts); cy = sum(q[1] for q in pts) / len(pts)
        bx, by = x + (cx - x) * 0.2, y + (cy - y) * 0.2
        p.fill(p.ell(bx - 0.25, by - 0.25, bx + 0.25, by + 0.25), (210, 200, 180))
    return m

def hot_nozzles(p, y0, L=12, n=4, x0=HX0, x1=HX1):
    """Re-tint SOW aft nozzles to a hotter, dirtier orange burn."""
    span = x1 - x0 - 5.2
    for i in range(n):
        cx = x0 + 2.6 + span * (i + 0.5) / n
        p.glow(p.poly([(cx - 2.1, y0 + L + 3.1), (cx + 2.1, y0 + L + 3.1), (cx + 2.3, y0 + L + 4), (cx - 2.3, y0 + L + 4)]), HOT)

# ---------------- concepts ----------------
def x1_stolen_picket(p):
    """X-1 Stolen picket: an SOW P-A with the turret pulled, livery blacked out, guns bolted on wherever they fit."""
    m = m_bow_bridge(p, 8); collar(p, 24)
    s = seg_armed(p, 25.2, 16, armoured=True)
    scrap_plate(p, [(29, 30), (36, 29.4), (36.6, 36.8), (29.4, 37.2)], RUST)          # replaced armour plate
    cap = p.ell(CX - 3.4, 29.7, CX + 3.4, 36.5); p.fill(cap, (70, 64, 60)); p.edges(cap, 0.4)   # welded-over turret ring
    collar(p, 41.2)
    a = aft(p, 42.4, 12, 4); hot_nozzles(p, 42.4)
    hull = m + s + a
    paint_over(p, hull, 34.5, 8, 45.5, 8.9)                    # bow cap
    paint_over(p, hull, HX0, 46.8, HX1 - 9, 49.2)              # aft band, half blacked out
    grime(p, hull, 50)
    tag(p, hull, 40, 37.6, 9, 2, TAG_COLS[0]); tag(p, hull, 31, 50.5, 7, 1.6, TAG_COLS[1]); tally(p, hull, 44.5, 27, 6)
    # asymmetric guns: one in a box on the port bow plate, one on a starboard outrigger
    gun_box(p, 30.6, 17.2, 8)
    o = p.rect(HX1 - 0.5, 26.2, HX1 + 5.4, 28.4); p.fill(o, (82, 74, 70)); p.edges(o, 0.3)
    gun_box(p, HX1 + 3.6, 23.4, 9)
    beam_strut(p, 43.2, 9, 3)

def x2_chop_shop(p):
    """X-2 Chop-shop sprinter: middle cut out and replaced with a bare neck; mismatched engines, one big nacelle, one booster pod."""
    m = m_bow_bridge(p, 6); collar(p, 22)
    s = seg(p, 23.2, 16, 'plain', ('grille', None))
    taper(p, 39.2, 5, 26, NECK_W); neck(p, 44.2, 10, NECK_W); taper(p, 54.2, 5, NECK_W, 26)
    a = aft(p, 59.2, 12, 4); hot_nozzles(p, 59.2)
    nacelle(p, 1, 44, 22, 10, big=True)                      # salvaged nacelle, starboard only
    booster(p, HX0 - 4.2, 46, 22, (50, 62), HX0)               # cheaper booster pod, port
    hull = m + s + a
    paint_over(p, hull, 34.5, 6, 45.5, 6.9)
    for i in range(6):                                          # crude checker band where the livery was
        p.fill(hull * p.rect(HX0 + i * 4.4, 26.4, HX0 + i * 4.4 + 2.2, 28.4), (240, 80, 200), 0.9, solid=False)
    paint_over(p, hull, HX0, 63.6, HX1, 65.8)
    grime(p, hull, 45)
    tag(p, hull, 30, 32, 10, 2.2, TAG_COLS[2]); tag(p, hull, 42, 67.4, 8, 1.4, TAG_COLS[3]); tally(p, hull, 45, 33.2, 4)
    # both lasers crammed into one double box on the port bow
    b = p.rect(28.4, 14.2, 34.8, 19, r=0.3); p.fill(b, (82, 74, 70)); p.edges(b, 0.35)
    for x in (30, 33.2):
        br = p.rect(x - 0.55, 7, x + 0.55, 14.6); p.fill(br, STEEL); p.fill(br * p.rect(x, 7, x + 0.55, 14.6), (84, 90, 104))
        p.fill(p.rect(x - 0.8, 6.4, x + 0.8, 7.4), (60, 54, 52)); p.mounts_fixed.append((x, 6.4, 'gun'))
    beam_strut(p, CX, 6, 0.8)

def x3_scrap_dart(p):
    """X-3 Scrap dart: a welded prow of scrap plate with a painted mouth, armour slab down one flank."""
    m = m_bow_bridge(p, 14); collar(p, 30)
    paint_over(p, m, 34.5, 14, 45.5, 14.9)
    s = seg(p, 31.2, 16, 'plain', (None, 'grille')); collar(p, 47.2)
    a = aft(p, 48.4, 12, 4); hot_nozzles(p, 48.4)
    # prow: three mismatched plates welded into a wedge ahead of the bridge
    pr1 = scrap_plate(p, [(HX0 + 1, 21), (CX, 2), (CX, 14.4), (HX0 + 4.4, 21)], (104, 98, 92))
    pr2 = scrap_plate(p, [(HX1 - 1, 21), (CX, 2), (CX, 14.4), (HX1 - 4.4, 21)], (88, 82, 80))
    pr3 = scrap_plate(p, [(CX - 2.2, 5.6), (CX + 2.2, 5.6), (CX + 1.4, 9.6), (CX - 1.4, 9.6)], RUST)
    prow = pr1 + pr2 + pr3
    p.fill(prow * p.line([(HX0 + 2, 20.4), (CX, 2.6), (HX1 - 2, 20.4)], 0.3), (230, 200, 120), 0.6, solid=False)   # weld seam
    teeth(p, prow, CX - 7.5, CX + 7.5, 11.2, 2.4)
    slab = scrap_plate(p, [(HX0 - 2.2, 32), (HX0 + 1.2, 31.4), (HX0 + 1.2, 56), (HX0 - 2.2, 54.6)], (78, 84, 70))   # armour slab, port
    hull = m + s + a + prow + slab
    paint_over(p, hull, HX0, 52.8, CX + 3, 55)
    grime(p, hull, 55)
    tag(p, hull, 32, 36, 12, 2.4, TAG_COLS[1]); tag(p, hull, 43, 56.5, 7, 1.4, TAG_COLS[0]); tally(p, hull, 30, 42, 5)
    # asymmetric guns: one off the prow's port shoulder, one in a starboard flank box
    gun_box(p, 30.4, 15.5, 7)
    sp = p.rect(HX1, 33, HX1 + 3.4, 40, r=0.4); p.fill(sp, (82, 74, 70)); p.edges(sp, 0.35)
    gun_box(p, HX1 + 1.7, 29.4, 6)
    beam_strut(p, CX + 0.6, 4, 1.8)

CONCEPTS = {'pirate_x1_stolen_picket': (x1_stolen_picket, 66), 'pirate_x2_chop_shop': (x2_chop_shop, 80),
            'pirate_x3_scrap_dart': (x3_scrap_dart, 70)}

def build(fn, h):
    p = Paint(80, h, seed=13); p.mounts = []; p.mounts_fixed = []
    fn(p)
    return p
