"""Pirate raider concepts, pass 2: a pirate design language of its own.
Dark faceted armour with oxide-red plates, exposed hot engines, gun pods on arms, spikes, scrap, crude paint.
Loadout per data: 2x light laser + 1x mining beam, mounted asymmetrically."""
import math
import numpy as np
from kit import Paint, reduce

BLACK = (52, 50, 54); OXIDE = (132, 44, 38); RUST = (130, 74, 44); OLIVE = (92, 102, 66)
IRON = (74, 70, 70); AMBER = (214, 150, 60); STEELP = (140, 140, 146)
HOT1, HOT2, HOT3 = (255, 120, 40), (255, 180, 80), (255, 236, 190)

def plate(p, pts, col, light=1.0, scratches=6, chips=10):
    """Armour plate: flat-lit by its facing, bevelled, scratched, chipped at the edges."""
    m = p.poly(pts)
    tex = 1 + (p.rng.random(m.shape).astype(np.float32) - 0.5) * 0.08
    p.fill(m, np.clip(np.asarray(col, np.float32) * light * tex[..., None], 0, 255)); p.edges(m, 0.45, 1.3, 0.5)
    xs = [q[0] for q in pts]; ys = [q[1] for q in pts]
    for _ in range(scratches):
        x, y = p.rng.uniform(min(xs), max(xs)), p.rng.uniform(min(ys), max(ys)); a = p.rng.uniform(-1.2, -0.3); l = p.rng.uniform(1, 3.5)
        p.fill(m * p.line([(x, y), (x + math.cos(a) * l, y + math.sin(a) * l)], 0.16), (200, 196, 190), 0.55, solid=False)
    for _ in range(chips):                                   # worn edges: bright bare-metal chips near the outline
        i = p.rng.integers(len(pts)); j = (i + 1) % len(pts); t = p.rng.random()
        x = pts[i][0] + (pts[j][0] - pts[i][0]) * t; y = pts[i][1] + (pts[j][1] - pts[i][1]) * t
        r = p.rng.uniform(0.2, 0.5); p.fill(m * p.ell(x - r, y - r, x + r, y + r), (176, 170, 164), 0.8, solid=False)
    return m

def rust(p, m, n=20):
    for _ in range(n):
        x, y = p.rng.uniform(0, p.uw), p.rng.uniform(0, p.uh); r = p.rng.uniform(0.6, 2.4)
        p.fill(m * p.ell(x - r, y - r * 0.7, x + r, y + r * 0.7), RUST, p.rng.uniform(0.25, 0.6), solid=False)
    for _ in range(n // 2):
        x, y = p.rng.uniform(0, p.uw), p.rng.uniform(0, p.uh); l = p.rng.uniform(1.5, 5)
        p.fill(m * p.rect(x, y, x + 0.3, y + l), (90, 54, 36), 0.4, solid=False)

def hot_engine(p, cx, y0, r, L):
    """Exposed engine: ribbed casing, glowing combustion ring and core, painted heat bloom on the hull around it."""
    bloom = p.ell(cx - r * 2.2, y0 - r * 0.6, cx + r * 2.2, y0 + L + r * 1.2)
    p.fill(bloom * (p.a > 0.5), HOT1, 0.22, solid=False)
    c = p.rect(cx - r, y0, cx + r, y0 + L, r=r * 0.35)
    n = np.clip((p.X - cx) / r, -0.99, 0.99)
    p.fill(c, np.clip(np.asarray(IRON, np.float32) * (0.55 + 0.6 * np.sqrt(1 - n ** 2) - 0.3 * n)[..., None], 0, 255)); p.edges(c, 0.4)
    for t in np.arange(0.2, 0.9, 0.18): p.fill(c * p.rect(cx - r, y0 + L * t, cx + r, y0 + L * t + 0.4), (30, 28, 30), 0.8, solid=False)
    p.fill(p.ell(cx - r * 1.05, y0 + L - r * 0.5, cx + r * 1.05, y0 + L + r * 0.6), (40, 36, 36))
    p.fill(p.ell(cx - r * 0.9, y0 + L - r * 0.4, cx + r * 0.9, y0 + L + r * 0.5), HOT1)
    p.fill(p.ell(cx - r * 0.6, y0 + L - r * 0.25, cx + r * 0.6, y0 + L + r * 0.35), HOT2)
    p.fill(p.ell(cx - r * 0.3, y0 + L - r * 0.1, cx + r * 0.3, y0 + L + r * 0.2), HOT3)

def hot_pipes(p, pts_list):
    """Exposed glowing pipework (heat exchangers, bypass lines)."""
    for pts in pts_list:
        p.fill(p.line(pts, 0.9), (60, 50, 46))
        p.fill(p.line(pts, 0.45), HOT1); p.fill(p.line(pts, 0.18), HOT2)

def gun_pod(p, x0, y0, x1, y1, barrels, blen, col=BLACK):
    """Laser pod on an arm: armoured box, barrel(s) forward, red sensor dots."""
    b = plate(p, [(x0, y0 + 1), (x0 + 1, y0), (x1 - 1, y0), (x1, y0 + 1), (x1, y1), (x0, y1)], col, 1.0, 2, 4)
    for bx in barrels:
        br = p.rect(bx - 0.5, y0 - blen, bx + 0.5, y0 + 0.5); p.fill(br, STEELP); p.fill(br * p.rect(bx, y0 - blen, bx + 0.5, y0 + 0.5), (80, 80, 86))
        p.fill(p.rect(bx - 0.75, y0 - blen - 0.6, bx + 0.75, y0 - blen + 0.4), (40, 40, 44))
        p.fill(p.rect(bx - 0.9, y0 - blen * 0.45, bx + 0.9, y0 - blen * 0.45 + 0.9), (60, 58, 60))
        p.mounts_fixed.append((bx, y0 - blen - 0.6, 'gun'))
    for dx in (0.35, 0.65): p.fill(p.ell(x0 + (x1 - x0) * dx - 0.35, y1 - 1.4, x0 + (x1 - x0) * dx + 0.35, y1 - 0.7), (230, 50, 40))
    return b

def missile_box(p, x0, y0, x1, y1, col=OXIDE):
    """Rocket box with a 2x2 face of red-capped tubes (visual only)."""
    b = plate(p, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], col, 0.95, 2, 4)
    face = p.rect(x0 + 0.4, y0 + 0.4, x1 - 0.4, y0 + 3.6); p.fill(face, (34, 32, 34))
    for i in range(2):
        for j in range(2):
            tx, ty = x0 + (x1 - x0) * (0.3 + 0.4 * i), y0 + 1.2 + 1.5 * j
            p.fill(p.ell(tx - 0.55, ty - 0.55, tx + 0.55, ty + 0.55), (230, 50, 40))
    return b

def beam(p, x, y_root, y_tip):
    s = p.rect(x - 0.4, y_tip, x + 0.4, y_root); p.fill(s, (96, 92, 90))
    em = p.poly([(x, y_tip - 1.6), (x + 1.3, y_tip), (x, y_tip + 1.3), (x - 1.3, y_tip)]); p.fill(em, (40, 60, 44))
    p.glow(p.poly([(x, y_tip - 1), (x + 0.8, y_tip), (x, y_tip + 0.8), (x - 0.8, y_tip)]), (110, 255, 140))
    p.mounts_fixed.append((x, y_tip - 1.6, 'beam'))

def spike(p, base_a, base_b, tip, col=IRON):
    m = p.poly([base_a, tip, base_b]); p.fill(m, col); p.edges(m, 0.3, 1.4, 0.5)

def slash(p, m, x, y, l, w=0.9, ang=-0.9, col=(176, 30, 28)):
    p.fill(m * p.line([(x, y), (x + math.cos(ang) * l, y + math.sin(ang) * l)], w), col, 0.9, solid=False)

# ---------------- concepts ----------------
def r1_wedge(p):
    """R-1 Wedge: faceted black-and-oxide armour arrowhead, gun pods on unequal arms, exposed engine core."""
    # arms first (under the hull)
    for pts in ([(28, 36), (19, 33.5), (19, 37.5), (28, 40.5)], [(52, 46), (58.5, 45), (58.5, 49), (52, 50.5)]):
        plate(p, pts, (58, 56, 60), 0.9, 1, 3)
    hull = p.poly([(40, 5), (52, 28), (55, 60), (50, 74), (30, 74), (25, 60), (28, 28)])
    p.fill(hull, BLACK)
    plates = [
        ([(40, 6), (34, 20), (30, 29), (36, 31), (39, 19)], OXIDE, 1.15),
        ([(40, 6), (41, 19), (44, 31), (50, 29), (46, 20)], OXIDE, 0.8),
        ([(30, 30), (36, 32), (35, 50), (27, 58), (26, 46)], BLACK, 1.15),
        ([(50, 30), (44, 32), (45, 50), (53, 58), (54, 46)], BLACK, 0.75),
        ([(26.5, 59), (35, 51), (34, 62), (29, 70)], OXIDE, 1.0),
        ([(53.5, 59), (45, 51), (46, 62), (51, 70)], OXIDE, 0.75),
    ]
    for pts, col, l in plates: plate(p, pts, col, l)
    spine = plate(p, [(37.5, 16), (42.5, 16), (45, 32), (44, 52), (36, 52), (35, 32)], (62, 60, 64), 1.0, 4, 6)
    plate(p, [(37.5, 16), (40, 16), (40, 52), (36, 52), (35, 32)], (62, 60, 64), 1.25, 2, 3)
    p.fill(p.rect(38, 21, 42, 22.2), (40, 14, 12)); p.glow(p.rect(38.4, 21.3, 41.6, 21.9), (255, 90, 60))
    for y in (36, 40, 44): p.fill(p.rect(37, y, 43, y + 0.5), (30, 28, 30))
    # engine bay: exposed pipework into three hot nozzles
    bay = plate(p, [(34, 52), (46, 52), (47.5, 70), (32.5, 70)], (44, 42, 44), 1.0, 2, 4)
    hot_pipes(p, [[(36, 54), (35.4, 60), (36.4, 66)], [(40, 53.5), (40, 66)], [(44, 54), (44.6, 60), (43.6, 66)], [(37, 57), (43, 59)]])
    for cx in (35.8, 40, 44.2): hot_engine(p, cx, 66, 1.8, 6)
    missile_box(p, 23.4, 56, 28.4, 66); missile_box(p, 51.6, 60, 56.6, 70, BLACK)
    # asymmetric guns: long port arm with the first laser, short starboard arm further aft with the second
    gun_pod(p, 15.5, 30, 21.5, 41, [18.5], 9, OXIDE)
    gun_pod(p, 56, 42, 61, 51, [58.5], 7)
    beam(p, 37.6, 12, 4.5)
    rust(p, hull, 26)
    for x, y in ((31, 47), (48, 40)): slash(p, hull, x, y, 4)

def r2_hauler(p):
    """R-2 Bubble hauler: long patched olive hull with shoulders and side housings, amber bubble cockpit,
    three huge exposed engines, antenna spikes, a crude painted fang."""
    for x, y, l in ((31, 24, 7), (52, 32, 6), (27, 52, 5), (53, 58, 8), (46, 20, 5)):
        sx = -1 if x < 40 else 1
        p.fill(p.line([(x, y), (x + sx * l, y - l * 0.6)], 0.35), (150, 146, 140)); p.fill(p.ell(x + sx * l - 0.5, y - l * 0.6 - 0.5, x + sx * l + 0.5, y - l * 0.6 + 0.5), (230, 50, 40))
    # side housings (under the hull)
    for x0, x1, l in ((24.5, 31, 1.1), (49, 55.5, 0.75)):
        plate(p, [(x0 + 1.5, 34), (x1, 33), (x1, 61), (x0 + 1.5, 60), (x0, 56), (x0, 38)], OLIVE, l, 3, 8)
        for yy in (40, 47, 54): p.fill(p.rect(x0 + 0.5, yy, x1 - 0.5, yy + 0.5), (40, 40, 34), 0.8, solid=False)
    outline = [(32, 14), (48, 14), (51, 22), (51, 66), (49, 74), (31, 74), (29, 66), (29, 22)]
    hull = p.poly(outline); p.fill(hull, OLIVE)
    rows = [(14, 22, 32, 48), (22, 30, 29, 51), (30.8, 38, 29, 51), (38, 46, 29, 51), (46, 54, 29, 51), (54.8, 62, 29, 51), (62, 68, 29, 51), (68, 74, 31, 49)]
    for ri, (y0, y1, x0, x1) in enumerate(rows):
        cuts = sorted(set([x0, x1] + [round(p.rng.uniform(x0 + 4, x1 - 4), 1) for _ in range(2)]))
        if ri == 0: cuts = [x0, 36, 44, x1]
        for ci in range(len(cuts) - 1):
            a0, a1 = cuts[ci], cuts[ci + 1]
            mid = (a0 + a1) / 2
            l = 1.15 if mid < 37 else (1.0 if mid < 43 else 0.74)
            col = OLIVE if p.rng.random() > 0.25 else (RUST if p.rng.random() > 0.5 else (106, 74, 54))
            plate(p, [(a0 + 0.15, y0 + 0.15), (a1 - 0.15, y0 + 0.15), (a1 - 0.15, y1 - 0.15), (a0 + 0.15, y1 - 0.15)], col, l, 2, 5)
    for yc in (30, 54): 
        c = p.rect(28.4, yc, 51.6, yc + 0.9); p.fill(c, (40, 40, 34))
        for x in np.arange(29, 51, 1.3): p.fill(c * p.rect(x, yc, x + 0.4, yc + 0.9), (96, 100, 80))
    # crude painted fang across the plates
    fang = p.poly([(31, 38), (49, 38), (40, 52)]); p.fill(fang * hull, (190, 50, 36), 0.85, solid=False)
    p.fill(p.poly([(35, 38), (45, 38), (40, 45.5)]) * hull, (214, 204, 188), 0.85, solid=False)
    rust(p, hull, 30)
    # bubble cockpit
    dome = p.ell(32.5, 4, 47.5, 19)
    dx = np.clip((p.X - 40) / 7.5, -1, 1); dy = np.clip((p.Y - 11.5) / 7.5, -1, 1); nz = np.sqrt(np.clip(1 - dx ** 2 - dy ** 2, 0, 1))
    lam = np.clip(-0.45 * dx - 0.45 * dy + 0.77 * nz, 0, 1)
    p.fill(dome, np.clip(np.asarray(AMBER, np.float32) * (0.45 + 0.75 * lam)[..., None], 0, 255))
    for x in (36, 40, 44): p.fill(dome * p.rect(x - 0.25, 4, x + 0.25, 20), (90, 60, 30))
    for yy in (8, 12, 16): p.fill(dome * p.rect(31, yy - 0.25, 49, yy + 0.25), (90, 60, 30))
    p.fill(dome * p.ell(35, 6, 38.5, 9), (255, 236, 180), 0.6, solid=False)
    p.fill(p.ell(32, 17, 48, 21), (40, 40, 34), 1.0); p.fill(p.ell(32.5, 4, 47.5, 19) * (p.Y > 17), (40, 40, 34))
    # side guns on the housings, staggered
    for gx, by in ((26.4, 36), (53.6, 48)):
        br = p.rect(gx - 0.5, by - 8, gx + 0.5, by + 1); p.fill(br, STEELP); p.fill(br * p.rect(gx, by - 8, gx + 0.5, by + 1), (80, 80, 86))
        p.fill(p.rect(gx - 0.8, by - 8.6, gx + 0.8, by - 7.6), (40, 40, 44)); p.mounts_fixed.append((gx, by - 8.6, 'gun'))
    beam(p, 40, 5, 0.8)
    for cx in (33.5, 40, 46.5): hot_engine(p, cx, 72, 3.2, 9)

def r3_scrap_ram(p):
    """R-3 Scrap ram: jagged welded scrap, hooks and spikes, crude red slashes, two unshielded engines running hot."""
    rng = p.rng
    outline = [(40, 8), (45, 14), (47, 22), (52, 26), (49, 32), (53, 44), (51, 56), (55, 64), (49, 70), (46, 76),
               (34, 76), (30, 70), (26, 62), (29, 54), (25, 44), (29, 34), (27, 25), (34, 16)]
    # spikes and hooks around the silhouette (drawn first so the hull overlaps their roots)
    for a, b, t in (((45, 14), (47, 18), (53, 10)), ((52, 26), (51, 30), (60, 24)), ((29, 34), (28, 38), (19, 33)),
                    ((53, 44), (52, 48), (60, 49)), ((26, 62), (27, 58), (19, 64)), ((49, 70), (47, 72), (54, 79))):
        spike(p, a, b, t)
    hook = p.line([(30, 20), (24, 14), (25, 9), (28, 8)], 0.9); p.fill(hook, (90, 84, 80)); p.edges(hook, 0.25)
    hull = p.poly(outline)
    p.fill(hull, IRON)
    # mismatched welded plates
    shards = [([(40, 9), (44, 15), (40, 22), (35, 17)], (88, 82, 80), 1.1), ([(44, 16), (51, 27), (44, 30), (41, 22)], (66, 62, 64), 0.8),
              ([(34, 18), (40, 23), (38, 34), (29, 33), (28, 25)], OXIDE, 1.1), ([(40, 24), (48, 32), (47, 44), (39, 40)], RUST, 0.85),
              ([(29, 35), (38, 36), (37, 50), (27, 46)], (82, 78, 76), 1.15), ([(39, 42), (52, 45), (50, 56), (40, 54)], (70, 66, 66), 0.8),
              ([(29, 54), (39, 52), (37, 64), (28, 62)], OXIDE, 1.0)]
    for pts, col, l in shards: plate(p, pts, col, l, 3, 8)
    for _ in range(14):                                         # weld beads
        x, y = rng.uniform(30, 50), rng.uniform(14, 66)
        p.fill(hull * p.line([(x, y), (x + rng.uniform(-3, 3), y + rng.uniform(1, 4))], 0.3), (210, 170, 110), 0.55, solid=False)
    for x, y, l in ((31, 30, 7), (42, 50, 8), (35, 58, 5)): slash(p, hull, x, y, l, 1.1)
    rust(p, hull, 34)
    # cockpit: a slit cut into a plate
    p.fill(p.rect(37.5, 13.5, 42.5, 14.8), (30, 10, 8)); p.glow(p.rect(38, 13.8, 42, 14.4), (255, 80, 50))
    # unshielded engines: bare cores, exposed coils, heat bleeding onto the hull
    for cx in (35.5, 44.5):
        hot_engine(p, cx, 64, 3.0, 9)
        for t in (0.25, 0.5, 0.75): p.fill(p.ell(cx - 3.4, 64 + 9 * t - 0.4, cx + 3.4, 64 + 9 * t + 0.4), HOT1, 0.85, solid=False)
    hot_pipes(p, [[(35.5, 58), (38, 62), (35.5, 64)], [(44.5, 57), (42, 61), (44.5, 64)]])
    # guns bolted on at odd angles: one high on the starboard shoulder, one low on the port flank; grapple + beam at the prow
    gun_pod(p, 49.5, 30, 54, 37, [51.8], 8, (60, 58, 60))
    gun_pod(p, 22.5, 46, 27, 53, [24.8], 7, OXIDE)
    beam(p, 41.5, 10, 3.2)

CONCEPTS = {'pirate_r1_wedge': (r1_wedge, 82), 'pirate_r2_hauler': (r2_hauler, 88), 'pirate_r3_scrap_ram': (r3_scrap_ram, 84)}

def build(fn, h):
    p = Paint(80, h, seed=21); p.mounts = []; p.mounts_fixed = []
    fn(p)
    return p
