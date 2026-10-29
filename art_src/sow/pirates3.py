"""Pirate raider, pass 3: R-1 Wedge developed. Red-dominant faceted armour over black, stepped hull,
exposed hot engines; three ways of mounting the asymmetric lasers solidly (no long arms)."""
import numpy as np
from kit import Paint, reduce
from pirates2 import plate, rust, hot_engine, hot_pipes, missile_box, beam, slash, BLACK, OXIDE, IRON, STEELP, HOT1, HOT2

RED2 = (156, 44, 38)        # brighter oxide red, the dominant plate colour
RED3 = (118, 34, 30)        # shadowed red

def barrel(p, x, y_root, y_tip, w=1.0):
    br = p.rect(x - w / 2, y_tip, x + w / 2, y_root); p.fill(br, STEELP); p.fill(br * p.rect(x, y_tip, x + w / 2, y_root), (80, 80, 86))
    p.fill(p.rect(x - w * 0.8, y_tip - 0.6, x + w * 0.8, y_tip + 0.4), (40, 40, 44))
    p.fill(p.rect(x - w * 0.9, (y_root + y_tip) / 2, x + w * 0.9, (y_root + y_tip) / 2 + 0.9), (60, 58, 60))
    p.mounts_fixed.append((x, y_tip - 0.6, 'gun'))

def base_wedge(p, spine=True, deck_tanks=False):
    """Shared R-1 body: stepped arrowhead, red-dominant plates over black, raised spine, open engine bay."""
    hull = p.poly([(40, 5), (50, 24), (53, 28), (55, 58), (52, 66), (50, 75), (30, 75), (28, 66), (25, 58), (27, 28), (30, 24)])
    p.fill(hull, BLACK)
    plates = [
        ([(40, 6), (34.5, 18), (30.5, 25), (36.5, 27), (39.2, 17)], RED2, 1.15),
        ([(40, 6), (40.8, 17), (43.5, 27), (49.5, 25), (45.5, 18)], RED3, 0.95),
        ([(28, 29), (36, 29), (35.4, 41), (26.6, 43)], RED2, 1.12),
        ([(52, 29), (44, 29), (44.6, 41), (53.4, 43)], RED3, 0.9),
        ([(26.4, 44.5), (35.2, 42.6), (35, 52), (25.6, 57)], BLACK, 1.15),
        ([(53.6, 44.5), (44.8, 42.6), (45, 52), (54.4, 57)], BLACK, 0.75),
        ([(26, 58.5), (35, 53.5), (34, 65), (28.6, 67)], RED2, 1.05),
        ([(54, 58.5), (45, 53.5), (46, 65), (51.4, 67)], RED3, 0.85),
    ]
    for pts, col, l in plates: plate(p, pts, col, l, 4, 8)
    # step lines: the hull widens in tiers like the reference
    for y, x0, x1 in ((28.2, 27.2, 52.8), (43.4, 26.2, 53.8), (57.8, 25.2, 54.8)):
        p.fill(hull * p.rect(x0, y, x1, y + 0.55), (24, 22, 24), 0.9, solid=False)
    if spine:
        plate(p, [(37.5, 15), (42.5, 15), (45, 30), (44.4, 52), (35.6, 52), (35, 30)], (66, 62, 66), 1.0, 3, 6)
        plate(p, [(37.5, 15), (40, 15), (40, 52), (35.6, 52), (35, 30)], (66, 62, 66), 1.25, 2, 3)
        p.fill(p.rect(37.4, 20, 42.6, 21.3), (40, 14, 12)); p.glow(p.rect(37.8, 20.3, 42.2, 21), (255, 90, 60))
    if deck_tanks:
        for cx in (37.6, 42.4):
            t = p.rect(cx - 1.9, 34, cx + 1.9, 51, r=1.6)
            n = np.clip((p.X - cx) / 1.9, -0.99, 0.99)
            p.fill(t, np.clip(np.asarray(IRON, np.float32) * (0.5 + 0.7 * np.sqrt(1 - n ** 2) - 0.3 * n)[..., None], 0, 255)); p.edges(t, 0.3)
            for y in (37, 41, 45, 49): p.fill(t * p.rect(cx - 1.9, y, cx + 1.9, y + 0.45), (30, 28, 30), 0.9, solid=False)
        hot_pipes(p, [[(36, 33), (40, 31.5), (44, 33)]])
    # engine bay and stern block
    plate(p, [(33.6, 52), (46.4, 52), (48.5, 70), (31.5, 70)], (44, 42, 44), 1.0, 2, 4)
    hot_pipes(p, [[(36, 54), (35.4, 60), (36.4, 66)], [(40, 53.5), (40, 66)], [(44, 54), (44.6, 60), (43.6, 66)], [(37, 57), (43, 59)]])
    plate(p, [(30, 69), (50, 69), (49, 74.5), (31, 74.5)], RED3, 0.95, 1, 4)
    for cx in (35.2, 40, 44.8): hot_engine(p, cx, 67, 2.0, 7)
    missile_box(p, 22.6, 58, 27.6, 67, RED2); missile_box(p, 52.4, 61, 57.4, 70, BLACK)
    rust(p, hull, 24)
    for x, y in ((30, 48), (47.5, 36)): slash(p, hull, x, y, 3.5, 0.7, -0.9, (190, 180, 170))
    return hull

# ---------------- weapon mounting options ----------------
def a_sponsons(p):
    """A: lasers in armoured sponsons faired into the hull: one forward to port, one aft to starboard."""
    base_wedge(p)
    plate(p, [(31, 21), (27.5, 22.5), (23.4, 27), (23, 37), (27, 38.5)], RED2, 1.12, 3, 6)
    plate(p, [(27.5, 22.5), (25.6, 24.6), (25.6, 35.4), (27, 36)], (64, 60, 64), 1.25, 1, 2)
    barrel(p, 25.2, 24.5, 15.2, 1.1)
    plate(p, [(53, 41), (56.8, 43.5), (57.4, 54), (54.4, 57)], RED3, 0.85, 3, 6)
    barrel(p, 55.6, 44, 36.4, 1.0)
    beam(p, 37.8, 12, 4.4)

def b_shoulder_pods(p):
    """B: pods tight to the hull on short, armoured shoulder pylons, faired in with plates."""
    base_wedge(p)
    # port pod, forward
    plate(p, [(27.5, 26), (30.5, 26.5), (30.5, 38), (27.5, 38.5)], (60, 58, 62), 1.0, 1, 3)
    plate(p, [(20.5, 25), (26, 24), (28, 26), (28, 39.5), (21.5, 40), (20.5, 38)], RED2, 1.12, 3, 6)
    p.fill(p.rect(21.6, 37.2, 22.4, 38), (230, 50, 40)); p.fill(p.rect(23.4, 37.2, 24.2, 38), (230, 50, 40))
    barrel(p, 23.4, 24.6, 15, 1.1)
    # starboard pod, aft
    plate(p, [(52.5, 44), (54.5, 44.5), (54.5, 53.5), (52.5, 54)], (60, 58, 62), 0.8, 1, 3)
    plate(p, [(54, 42.5), (58.5, 43.5), (59.5, 45), (59.5, 55), (54, 56)], RED3, 0.85, 3, 6)
    p.fill(p.rect(56.2, 53.2, 57, 54), (230, 50, 40))
    barrel(p, 56.6, 43.2, 35, 1.0)
    beam(p, 37.8, 12, 4.4)

def c_integrated(p):
    """C: guns built into the hull: one through the port prow plate, one in a dorsal casemate beside the spine;
    deck tanks and pipework mid-ship like the reference."""
    base_wedge(p, spine=False, deck_tanks=True)
    plate(p, [(37.5, 13), (42.5, 13), (44.4, 27), (35.6, 27)], (66, 62, 66), 1.05, 2, 4)
    plate(p, [(37.5, 13), (40, 13), (40, 27), (35.6, 27)], (66, 62, 66), 1.25, 1, 2)
    p.fill(p.rect(37.6, 18.4, 42.4, 19.6), (40, 14, 12)); p.glow(p.rect(38, 18.7, 42, 19.3), (255, 90, 60))
    # port prow gun: barrel exits a reinforced collar in the red prow plate
    p.fill(p.ell(33.2, 18.8, 36.2, 21.8), (44, 40, 42)); p.fill(p.ell(33.9, 19.5, 35.5, 21.1), (24, 22, 24))
    barrel(p, 34.7, 20.2, 9.5, 1.1)
    # starboard dorsal casemate, offset aft
    plate(p, [(45.5, 32), (50.5, 31.5), (51.5, 33), (51.5, 41.5), (45.5, 42)], (62, 58, 62), 0.9, 2, 4)
    p.fill(p.rect(46.6, 32.6, 50.4, 33.4), (230, 50, 40), 0.7, solid=False)
    barrel(p, 48.5, 32, 22.5, 1.1)
    beam(p, 40, 12, 3.6)

CONCEPTS = {'pirate_r1a_sponsons': (a_sponsons, 82), 'pirate_r1b_shoulder_pods': (b_shoulder_pods, 82),
            'pirate_r1c_integrated': (c_integrated, 82)}

def build(fn, h):
    p = Paint(80, h, seed=21); p.mounts = []; p.mounts_fixed = []
    fn(p)
    return p
