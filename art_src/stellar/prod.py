"""Production stellars, first detailed pass: Halo gate, authority ring station, trader container yard,
pirate hollowed rock. Hull sprites carry EMPTY turret rings (turrets are separate sprites, as on SOW ships);
mounts are recorded in p.mounts as (x, y, kind) in paint units."""
import math
import numpy as np
from PIL import Image, ImageFilter
import skit, kit, kit2, kit5
from skit import surf, ann, sector, rot, torus, dome, cone, glow_ring, field, polar, quant, heat
from kit import LIGHT, WHITE, DARK, NAVY, RED, CYAN, RIB, STEEL
from gates import IVORY, BONE, GRAPH, GRAPH2, BRASS, FIELD, EMIT, BEACON, BRED, aperture
from stations import (hplate, vdeck, hcollar, strip, beam, heightsurf, YELLOW, SAND, TEAL,
                      ROCK, ROCK2, IRON, OXIDE, HOT1, HOT2, BLACK)

def beacon(p, x, y, col=BEACON, r=1.2, housing=(34, 34, 40)):
    p.fill(p.ell(x - r * 1.8, y - r * 1.8, x + r * 1.8, y + r * 1.8), housing)
    p.glow(p.ell(x - r, y - r, x + r, y + r), col)

def mount(p, kind, x, y):
    if not hasattr(p, 'mounts'): p.mounts = []
    kit5.ring(p, x, y, kind)

def bolt(p, x, y, col=BRASS, r=0.45):
    m = p.ell(x - r, y - r, x + r, y + r); p.fill(m, col); p.fill(p.ell(x - r * 0.5, y - r * 0.5, x + r * 0.3, y + r * 0.3), (250, 236, 200), 0.6, solid=False)

def polar_pt(cx, cy, r, a):
    t = math.radians(a); return cx + r * math.cos(t), cy + r * math.sin(t)

# =====================================================================================================
# Gate A: Halo (600 px)
# =====================================================================================================
GU = skit.units(600); GC = GU / 2
IVORY2 = (206, 197, 180); IVORY3 = (228, 221, 206)

def gate_halo(p):
    C = GC
    # graphite structure ring; its inner lip shows as a dark collar with cooling fins
    torus(p, ann(p, C, C, 115, 161), C, C, 138, 23, GRAPH, facets=5)
    lip = ann(p, C, C, 116.5, 133)
    for a in np.arange(0, 360, 2.5):
        x0, y0 = polar_pt(C, C, 123, a); x1, y1 = polar_pt(C, C, 132, a)
        p.fill(lip * p.line([(x0, y0), (x1, y1)], 0.45), (30, 31, 37), 0.85, solid=False)
    torus(p, ann(p, C, C, 116, 118.6), C, C, 117.3, 1.3, GRAPH2, facets=0)
    glow_ring(p, ann(p, C, C, 119.2, 120.8), (150, 132, 230))
    # ivory armour: 24 panels with raised inset plates; the graphite shows in the seams
    for k in range(24):
        a0, a1 = 15 * k + 0.7, 15 * k + 15 - 0.7
        col = IVORY if k % 2 == 0 else IVORY2
        pm = p.poly(sector(C, C, 134, 162, a0, a1, 16)); torus(p, pm, C, C, 148, 14, col, facets=6)
        im = p.poly(sector(C, C, 139, 157, a0 + 2.0, a1 - 2.0, 14)); torus(p, im, C, C, 148, 9, IVORY3 if k % 2 == 0 else IVORY, facets=6)
        for a in (a0 + 1.0, a1 - 1.0):
            for r in (137, 159): bolt(p, *polar_pt(C, C, r, a))
        if k % 6 == 3:   # consortium glyph: three brass bars
            for i, r in enumerate((142, 146.5, 151)):
                g = p.poly(sector(C, C, r, r + 2.2, a0 + 4.5 + i * 0.6, a1 - 4.5 - i * 0.6, 6)); surf(p, g, BRASS, 0, 0)
        p.wear(pm, 4)
    # brass channel crossing every panel
    torus(p, ann(p, C, C, 146.6, 149.4), C, C, 148, 1.4, BRASS, facets=0, edges=False)
    # emitter housings and prongs at 22.5 + 45k
    for k in range(8):
        a = 22.5 + 45 * k; ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        hm = p.poly(sector(C, C, 126, 156, a - 4.2, a + 4.2, 8)); torus(p, hm, C, C, 141, 15, GRAPH2, facets=4)
        torus(p, p.poly(sector(C, C, 153, 157, a - 4.6, a + 4.6, 8)), C, C, 155, 2, BRASS, facets=0)
        glow_ring(p, p.poly(sector(C, C, 134, 148, a - 0.45, a + 0.45, 4)), EMIT)
        base = rot([(C + 101, C - 4.5), (C + 127, C - 10), (C + 127, C + 10), (C + 101, C + 4.5)], C, C, a)
        cone(p, p.poly(base), C, C, GRAPH, tilt=0.35); p.edges(p.poly(base), 0.4)
        sheath = rot([(C + 107, C - 3.4), (C + 123, C - 6.6), (C + 123, C + 6.6), (C + 107, C + 3.4)], C, C, a)
        X, Y = p.X - C, p.Y - C
        across = quant((-X * sa + Y * ca) / 6.6, 4) * 0.7
        surf(p, p.poly(sheath), IVORY, -sa * across, ca * across)
        glow_ring(p, p.poly(rot([(C + 104, C - 0.5), (C + 121, C - 0.5), (C + 121, C + 0.5), (C + 104, C + 0.5)], C, C, a)), EMIT)
        tip = rot([(C + 98, C - 4.8), (C + 103, C - 5.6), (C + 103, C + 5.6), (C + 98, C + 4.8)], C, C, a)
        surf(p, p.poly(tip), BRASS, -ca * 0.55, -sa * 0.55)
        x, y = polar_pt(C, C, 98.5, a); glow_ring(p, p.ell(x - 2.2, y - 2.2, x + 2.2, y + 2.2), EMIT)
    # control nacelles at the cardinal points, beacons round the rim
    for k in range(4):
        a = 90 * k; ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        nac = rot([(C + 157, C - 13), (C + 165, C - 10), (C + 168, C - 4), (C + 168, C + 4), (C + 165, C + 10), (C + 157, C + 13)], C, C, a)
        nm = p.poly(nac); cone(p, nm, *polar_pt(C, C, 160, a), IVORY2, tilt=0.45); p.edges(nm, 0.45)
        x, y = polar_pt(C, C, 163, a); dome(p, x, y, 4.2, IVORY3, facets=4)
        for d in (-8, 8):
            bx, by = x - sa * d, y + ca * d
            beacon(p, bx, by, BRED if k % 2 else BEACON, 1.0)
    for k in range(16):
        if k % 4 == 0: continue
        x, y = polar_pt(C, C, 159.5, 22.5 * k); beacon(p, x, y, BEACON, 0.8)
    # the field: ripples, eight faint rays from the prong tips, a bright eye at the centre
    aperture(p, 117)
    r, ux, uy, th = polar(p, C, C)
    rays = np.zeros_like(r)
    for k in range(8):
        d = np.angle(np.exp(1j * (th - math.radians(22.5 + 45 * k))))
        rays = np.maximum(rays, np.exp(-(d * r / 3.2) ** 2) * np.clip((r - 20) / 70, 0, 1))
    field(p, rays * (r < 98) * 0.35, EMIT)
    field(p, np.exp(-(r / 10) ** 2) * 0.8, (230, 222, 255))

GATE_JUMP_POINT = (0, 0)

# =====================================================================================================
# Authority ring (480 px)
# =====================================================================================================
SU = skit.units(480); SC = SU / 2

def _ring_band(p, C, R, w, a0, a1, col_mid=LIGHT, col_flank=DARK):
    r, ux, uy, th = polar(p, C, C)
    m = p.poly(sector(C, C, R - w, R + w, a0, a1, 24))
    col = np.where((np.abs(r - R) < w * 0.45)[..., None], np.asarray(col_mid, np.float32), np.asarray(col_flank, np.float32))
    torus(p, m, C, C, R, w, col, facets=5)
    for rr in (R - w * 0.45, R + w * 0.45):
        p.fill(m * ann(p, C, C, rr - 0.12, rr + 0.12), (28, 32, 42), 0.5, solid=False)
    return m

def authority_ring(p):
    C, R, w = SC, 94, 14
    p.mounts = []
    # eight modules between collars at 22.5 + 45k
    for k in range(8):
        a = 45 * k; a0, a1 = a - 22.5 + 1.3, a + 22.5 - 1.3
        m = _ring_band(p, C, R, w, a0, a1)
        kind = {0: 'dock', 4: 'dock', 2: 'spoke', 6: 'spoke'}.get(k, 'hab' if k in (1, 5) else 'cargo')
        if kind == 'hab':
            for side in (-1, 1):
                for aa in np.arange(a0 + 2.2, a1 - 1.5, 2.6):
                    x, y = polar_pt(C, C, R + side * 9.5, aa)
                    p.fill(p.ell(x - 0.95, y - 0.95, x + 0.95, y + 0.95), (24, 28, 36)); p.glow(p.ell(x - 0.55, y - 0.55, x + 0.55, y + 0.55), CYAN if (int(aa * 7) % 5) else (255, 214, 150))
        elif kind == 'cargo':
            kinds = ('rust', 'teal', 'sand', 'grey')
            for i, aa in enumerate(np.arange(a0 + 3.5, a1 - 3, 7.5)):
                c = kit2.CONT[kinds[(i + k) % 4]] if hasattr(kit2, 'CONT') else SAND
                bx = p.poly(sector(C, C, R - 5, R + 5, aa, aa + 6, 6)); torus(p, bx, C, C, R, 5, c, facets=3)
                p.fill(bx * p.poly(sector(C, C, R - 5, R + 5, aa + 5, aa + 6, 3)), (40, 40, 44), 0.5, solid=False)
            for side in (-1, 1):
                for aa in np.arange(a0 + 3, a1 - 2, 5):
                    x, y = polar_pt(C, C, R + side * 10, aa); p.fill(p.ell(x - 0.6, y - 0.6, x + 0.6, y + 0.6), (210, 214, 222), 0.6, solid=False)
        elif kind == 'spoke':
            for side in (-1, 1):
                gm = p.poly(sector(C, C, R + side * 7.5 - 2.2, R + side * 7.5 + 2.2, a - 14, a - 5, 8)); p.fill(gm, (40, 46, 58))
                for aa in np.arange(a - 13.5, a - 5.5, 1.1):
                    p.fill(gm * p.line([polar_pt(C, C, R + side * 7.5 - 2, aa), polar_pt(C, C, R + side * 7.5 + 2, aa)], 0.35), (122, 130, 146))
                gm2 = p.poly(sector(C, C, R + side * 7.5 - 2.2, R + side * 7.5 + 2.2, a + 5, a + 14, 8)); p.fill(gm2, (40, 46, 58))
                for aa in np.arange(a + 5.5, a + 13.5, 1.1):
                    p.fill(gm2 * p.line([polar_pt(C, C, R + side * 7.5 - 2, aa), polar_pt(C, C, R + side * 7.5 + 2, aa)], 0.35), (122, 130, 146))
        elif kind == 'dock':
            kit.emblem(p, *polar_pt(C, C, R, a + 12));
            hx, hy = polar_pt(C, C, R, a - 12); hm = p.rect(hx - 3.6, hy - 3.6, hx + 3.6, hy + 3.6, r=0.5); p.fill(hm, (172, 178, 190)); p.edges(hm, 0.4, 1.25, 0.55)
        p.wear(m, 10)
    # red livery stripe, then the collars on top of it
    torus(p, ann(p, C, C, R + w - 3.1, R + w - 1.7), C, C, R + w - 2.4, 0.7, RED, facets=0, edges=False)
    for k in range(8):
        a = 22.5 + 45 * k
        cm = p.poly(sector(C, C, R - w - 1, R + w + 1, a - 1.4, a + 1.4, 6)); torus(p, cm, C, C, R, w + 1, RIB, facets=4)
        for rr in np.arange(R - w + 0.5, R + w, 2.2):
            x, y = polar_pt(C, C, rr, a); p.fill(p.ell(x - 0.35, y - 0.35, x + 0.35, y + 0.35), (96, 104, 120))
        x, y = polar_pt(C, C, R + w + 0.5, a); beacon(p, x, y, (255, 90, 60) if k % 2 else (255, 214, 150), 0.7)
    # spokes
    for sgn in (-1, 1):
        y0, y1 = (C - R + w - 1, C - 30) if sgn < 0 else (C + 30, C + R - w + 1)
        vdeck(p, C - 8, C + 8, y0, y1)
        for y in np.linspace(y0 + 12, y1 - 12, 3): kit.collar(p, y, C - 8.6, C + 8.6)
        for yy in np.linspace(y0 + 6, y1 - 10, 3):
            strip(p, C - 7.2, yy, C - 6.4, yy + 3.5); strip(p, C + 6.4, yy, C + 7.2, yy + 3.5)
        cy = (y0 + y1) / 2 + sgn * 6; car = p.rect(C - 4.5, cy - 3, C + 4.5, cy + 3, r=0.6); surf(p, car, (176, 182, 194), 0, 0); p.glow(p.rect(C - 3, cy - 0.6, C + 3, cy + 0.6))
    # docking cradles at 3 and 9 o'clock
    for sx in (-1, 1):
        x0 = C + sx * (R + w - 1); x1 = C + sx * (R + w + 15)
        hplate(p, min(x0, x1), max(x0, x1), C - 9, C + 9)
        hcollar(p, C + sx * (R + w + 5) - 0.6, C - 9, C + 9)
        for sy in (-1, 1):
            cl = [(C + sx * (R + w + 6), C + sy * 9), (C + sx * (R + w + 18), C + sy * 13), (C + sx * (R + w + 19), C + sy * 11), (C + sx * (R + w + 8), C + sy * 7)]
            surf(p, p.poly(cl), (70, 76, 92), 0, sy * 0.4)
            beacon(p, C + sx * (R + w + 18), C + sy * 12, (255, 90, 60), 0.6)
        x = C + sx * (R + w + 15)
        torus(p, ann(p, x, C, 4.2, 9.5), x, C, 6.9, 2.7, (66, 72, 88), facets=4)
        p.glow(ann(p, x, C, 4.2, 5.3)); p.fill(p.ell(x - 4.2, C - 4.2, x + 4.2, C + 4.2), (18, 20, 26))
        p.fill(p.rect(min(x0, x1) + 2, C - 1.2, max(x0, x1) - 8, C + 1.2), RED)
    # hub
    hm = p.ell(C - 31, C - 31, C + 31, C + 31); cone(p, hm, C, C, DARK, tilt=0.55); p.edges(hm, 0.5)
    for k in range(8):
        a = 22.5 + 45 * k
        if k in (1, 2, 5, 6): continue
        x, y = polar_pt(C, C, 27, a); g = p.rect(x - 2, y - 2, x + 2, y + 2, r=0.4); p.fill(g, (40, 46, 58))
        p.glow(p.rect(x - 1.2, y - 0.4, x + 1.2, y + 0.4))
    dm = dome(p, C, C, 22, LIGHT, facets=6)
    torus(p, ann(p, C, C, 22, 24.4), C, C, 23.2, 1.2, RED, facets=0, edges=False)
    for k in range(4):
        a = 45 + 90 * k; x, y = polar_pt(C, C, 17, a); p.glow(p.ell(x - 1.1, y - 1.1, x + 1.1, y + 1.1))
    dome(p, C, C, 5.5, WHITE, facets=4)
    p.fill(p.line([(C, C), (C + 9, C - 9)], 0.5), STEEL); beacon(p, C + 9, C - 9, (255, 90, 60), 0.7)
    p.wear(hm, 20)
    # mounts: small turrets on the hab and cargo modules, medium on the hub, PD on the rim
    for a in (45, 135, 225, 315): mount(p, 't1', *polar_pt(C, C, R, a))
    mount(p, 't2', C - 13, C + 1); mount(p, 't2', C + 13, C + 1)
    for a in (67.5, 112.5, 247.5, 292.5): mount(p, 'pd', *polar_pt(C, C, R + 8.5, a))

# =====================================================================================================
# Trader container yard (480 px)
# =====================================================================================================
def hazard(p, m, x0, y0, x1, y1, step=2.0):
    p.fill(m * p.rect(x0, y0, x1, y1), (200, 160, 50))
    for x in np.arange(x0 - (y1 - y0), x1, step * 2):
        p.fill(m * p.rect(x0, y0, x1, y1) * p.poly([(x, y1), (x + step, y1), (x + step + (y1 - y0), y0), (x + (y1 - y0), y0)]), (30, 30, 30))

def trader_yard(p):
    C = SC; U = SU
    p.mounts = []
    kinds = ('rust', 'teal', 'sand', 'grey', 'rust', 'grey')
    rows = np.arange(40, U - 52, 15)
    for side in (-1, 1):
        xa, xb = (C - 48, C - 13) if side < 0 else (C + 13, C + 48)
        for rx0, rx1 in ((xa, xa + 2.5), (xb - 2.5, xb)):
            rm = p.rect(rx0, 34, rx1, U - 40); surf(p, rm, (78, 82, 94), 0, 0); p.edges(rm, 0.3)
        for y in rows:
            br = p.rect(xa, y + 13.6, xb, y + 14.6); p.fill(br, (60, 64, 74))
            p.fill(p.line([(xa + 2, y + 1), (xb - 2, y + 13)], 0.45), (54, 58, 68)); p.fill(p.line([(xb - 2, y + 1), (xa + 2, y + 13)], 0.45), (54, 58, 68))
        for i, y in enumerate(rows):
            for j, cx0 in enumerate((xa + 3, xa + 17.5)):
                roll = p.rng.random()
                if roll < 0.12: continue
                kit2.container(p, cx0, y, cx0 + 13, y + 13.6, kinds[p.rng.integers(len(kinds))])
        for y in (34, U - 40):
            for x in (xa, xb): beacon(p, x + (1.2 if x == xa else -1.2), y, (255, 196, 90), 0.7)
    vdeck(p, C - 12, C + 12, 26, U - 32)
    for y in np.arange(58, U - 44, 40): kit.collar(p, y, C - 12.6, C + 12.6)
    for y in np.arange(64, U - 50, 40):
        kit.grille(p, C - 11.4, y, 7); kit.lightstrip(p, C + 10.4 - 1.2, y + 1.5, 4)
    kit.hatch(p, C, C - 18); kit.hatch(p, C, C + 98)
    # gantry cranes with trolleys carrying a container
    for gi, y in enumerate((C - 50, C + 50)):
        gm = hplate(p, C - 64, C + 64, y - 4, y + 4, centre=YELLOW, flank=(150, 118, 48))
        for xs in ((C - 64, C - 56), (C + 56, C + 64)): hazard(p, gm, xs[0], y - 4, xs[1], y + 4)
        for x in (C - 66, C + 60):
            wb = p.rect(x, y - 7, x + 6, y + 7, r=0.6); surf(p, wb, (60, 64, 74), 0, 0); p.edges(wb, 0.35)
            beacon(p, x + 3, y + 5.6, (255, 196, 90), 0.7)
        tx = C - 30 if gi == 0 else C + 30
        sp = p.rect(tx - 9, y - 9, tx + 9, y + 9, r=0.6); p.fill(sp, (46, 50, 58)); p.edges(sp, 0.35)
        kit2.container(p, tx - 6.5, y - 7, tx + 6.5, y + 7, 'teal' if gi == 0 else 'rust')
        for cx_ in (tx - 8, tx + 8): p.fill(p.rect(cx_ - 0.9, y - 8.5, cx_ + 0.9, y + 8.5), (190, 150, 56))
        cab = p.rect(C + 24, y - 6, C + 36, y + 6, r=0.8); surf(p, cab, (188, 152, 62), 0.25, -0.3); p.edges(cab, 0.35)
        strip(p, C + 25.5, y - 4.4, C + 34.5, y - 3.4, (255, 214, 150))
    # hab dome at the bow
    torus(p, ann(p, C, 28, 21, 26), C, 28, 23.5, 2.5, DARK, facets=4)
    dome(p, C, 28, 21, LIGHT, facets=6)
    torus(p, ann(p, C, 28, 21, 22.6), C, 28, 21.8, 0.8, TEAL, facets=0, edges=False)
    for k in range(14):
        x, y = polar_pt(C, 28, 16, 360 / 14 * k); p.fill(p.ell(x - 1.2, y - 1.2, x + 1.2, y + 1.2), (26, 30, 38)); p.glow(p.ell(x - 0.7, y - 0.7, x + 0.7, y + 0.7), (255, 214, 150))
    dome(p, C, 28, 6, WHITE, facets=4)
    dish = p.ell(C + 8, 14, C + 16, 20); surf(p, dish, (200, 204, 212), -0.3, -0.3); p.fill(p.line([(C + 4, 22), (C + 12, 17)], 0.5), STEEL)
    # fuel tanks at the stern with straps and feed pipes
    for (x, y, r) in ((C - 27, U - 27, 13), (C, U - 20, 13.5), (C + 27, U - 27, 13)):
        dome(p, x, y, r, SAND, facets=5)
        for d in (-r * 0.45, r * 0.45): p.fill(p.ell(x - r, y - r, x + r, y + r) * p.rect(x - r, y + d - 0.6, x + r, y + d + 0.6), (70, 64, 52), 0.85, solid=False)
        p.fill(p.ell(x - 2, y - 2, x + 2, y + 2), (90, 84, 70))
    for x in (C - 18, C + 18): p.fill(p.line([(x, U - 34), (x + (6 if x > C else -6), U - 30)], 1.2), (80, 84, 96))
    # bow docking clamps
    for sx in (-1, 1):
        x = C + sx * 52
        arm = beam(p, C + sx * 22, 30, x, 22, 5, (70, 76, 92))
        dk = p.rect(x - 6, 13, x + 6, 27, r=1.2); surf(p, dk, (84, 90, 106), 0, -0.3); p.edges(dk, 0.4)
        torus(p, ann(p, x, 17, 2.2, 4.8), x, 17, 3.5, 1.3, (66, 72, 88), facets=3); p.glow(ann(p, x, 17, 2.2, 2.9))
        beacon(p, x + sx * 4, 25, (255, 90, 60), 0.7)
    mount(p, 't1', C, 74); mount(p, 't1', C, U - 72)

# =====================================================================================================
# Pirate hollowed rock (480 px)
# =====================================================================================================
def _noise(p, rng, scale, amp):
    h, w = p.X.shape
    n = rng.normal(0, 1, (max(2, int(h / (scale * kit.SS))), max(2, int(w / (scale * kit.SS)))))
    img = Image.fromarray(n.astype(np.float32), 'F').resize((w, h), Image.BICUBIC)
    return np.asarray(img, np.float32) * amp

def pirate_rock(p):
    C = SC; rng = np.random.default_rng(5)
    p.mounts = []
    r, ux, uy, th = polar(p, C, C)
    R = 100
    edge = np.ones_like(th) * R
    for k in range(2, 9): edge += R * 0.18 / k ** 0.8 * np.sin(k * th + rng.uniform(0, 6.28))
    edge += _noise(p, rng, 18, 2.2)
    m = (r < edge).astype(np.float32)
    h = np.sqrt(np.clip(1 - (r / edge) ** 2, 0, 1)) * R * 0.5 + _noise(p, rng, 30, 4) + _noise(p, rng, 9, 1.4) + _noise(p, rng, 3, 0.4)
    craters = []
    for _ in range(18):
        a, d = rng.uniform(0, 6.28), rng.uniform(0, 0.85) * R
        x, y, cr = C + d * math.cos(a), C + d * math.sin(a), rng.uniform(3, 13)
        craters.append((x, y, cr))
        dd = np.hypot(p.X - x, p.Y - y) / cr
        h += np.where(dd < 1, -(1 - dd ** 2) * cr * 0.4, np.where(dd < 1.35, (1.35 - dd) * cr * 0.3, 0))
    tone = np.clip(0.82 + _noise(p, rng, 14, 0.12) + (h - h.mean()) / 80, 0.6, 1.15)
    col = np.asarray(ROCK, np.float32) * tone[..., None]
    heightsurf(p, m, col, h, 0.9)
    for _ in range(9):           # cracks
        x, y = C + rng.uniform(-70, 70), C + rng.uniform(-70, 70); pts = [(x, y)]
        for _ in range(6):
            x += rng.uniform(-9, 9); y += rng.uniform(-9, 9); pts.append((x, y))
        p.fill(m * p.line(pts, 0.5), (28, 24, 24), 0.75, solid=False)
    # hot vents with heat bleeding onto the rock
    for (x, y) in ((C - 30, C + 70), (C + 40, C - 70), (C - 80, C - 30), (C + 64, C + 30)):
        heat(p, m * np.clip(1 - np.hypot(p.X - x, p.Y - y) / 14, 0, 1) ** 1.5, HOT1, 0.45)
        torus(p, ann(p, x, y, 3, 6), x, y, 4.5, 1.5, IRON, facets=3)
        p.fill(p.ell(x - 3, y - 3, x + 3, y + 3), (40, 26, 22)); p.glow(p.ell(x - 2.2, y - 2.2, x + 2.2, y + 2.2), HOT1)
        p.glow(p.ell(x - 0.9, y - 0.9, x + 0.9, y + 0.9), HOT2)
    # docking slip cut into the east flank: dark floor, braced walls, hot guide lamps, cradle at the end
    slip = p.poly([(SU, C - 16), (C + 12, C - 12), (C - 4, C), (C + 12, C + 12), (SU, C + 16)]) * m
    p.fill(slip, (18, 16, 18))
    for x in np.arange(C + 22, C + 104, 11):
        bm = p.rect(x - 1, C - 14, x + 1, C + 14) * slip; surf(p, bm, IRON, -0.3, 0);
    for side in (-1, 1):
        wall = p.poly([(SU, C + side * 16), (C + 12, C + side * 12), (C + 12, C + side * 15.5), (SU, C + side * 19.5)]) * m
        surf(p, wall, (88, 80, 76), 0, side * -0.65)
        for x in np.arange(C + 18, C + 108, 9):
            p.fill(p.ell(x - 1.4, C + side * 13.6 - 1.4, x + 1.4, C + side * 13.6 + 1.4) * m, (40, 30, 28)); p.glow(p.ell(x - 0.8, C + side * 13.6 - 0.8, x + 0.8, C + side * 13.6 + 0.8), HOT2)
    cr_ = p.poly([(C - 4, C), (C + 8, C - 9), (C + 14, C - 9), (C + 14, C + 9), (C + 8, C + 9)]); surf(p, cr_, (70, 62, 60), 0.4, 0)
    p.glow(p.rect(C + 9, C - 1.2, C + 13, C + 1.2), HOT1)
    # grafted SOW hull section, half buried in the rock at the upper left
    gh = beam(p, C - 92, C - 48, C - 48, C - 82, 22, (120, 112, 106), facets=5)
    for t in (0.3, 0.62):
        x, y = C - 92 + 44 * t, C - 48 - 34 * t
        p.fill(gh * p.line([(x - 7, y - 9), (x + 7, y + 9)], 1.0), RIB)
    p.fill(gh * p.rect(C - 80, C - 72, C - 60, C - 60), (130, 74, 44), 0.45, solid=False)
    p.wear(gh, 18)
    # oxide plating bolted to the rock (the turret platforms)
    plates = (((C - 58, C - 72), (C - 16, C - 84), (C - 8, C - 50), (C - 50, C - 40)),
              ((C - 86, C + 8), (C - 50, C + 0), (C - 44, C + 40), (C - 82, C + 46)),
              ((C + 22, C + 44), (C + 66, C + 38), (C + 72, C + 70), (C + 28, C + 80)))
    for pts in plates:
        pm = p.poly(pts)
        ptone = np.clip(0.85 + _noise(p, rng, 6, 0.1), 0.7, 1.05)[..., None]
        surf(p, pm, np.asarray((122, 44, 38), np.float32) * ptone, 0.08, -0.08); p.edges(pm, 0.5)
        p.seam(pm, [((pts[1][0] + pts[2][0]) / 2, (pts[1][1] + pts[2][1]) / 2), ((pts[3][0] + pts[0][0]) / 2, (pts[3][1] + pts[0][1]) / 2)], 0.55)
        cx_, cy_ = np.mean([q[0] for q in pts]), np.mean([q[1] for q in pts])
        p.seam(pm, [((pts[0][0] + pts[1][0]) / 2, (pts[0][1] + pts[1][1]) / 2), ((pts[2][0] + pts[3][0]) / 2, (pts[2][1] + pts[3][1]) / 2)], 0.6)
        for (x, y) in pts:
            x2, y2 = x + (cx_ - x) * 0.1, y + (cy_ - y) * 0.1; p.fill(p.ell(x2 - 0.9, y2 - 0.9, x2 + 0.9, y2 + 0.9), (52, 40, 38))
        p.fill(pm * p.rect(cx_ - 30, cy_ + 2, cx_ + 30, cy_ + 3.2), (220, 196, 140), 0.35, solid=False)
        for _ in range(4):
            x, y = cx_ + rng.uniform(-14, 14), cy_ + rng.uniform(-10, 10)
            p.fill(pm * p.line([(x, y), (x - 2, y + 10)], 1.4), (130, 74, 44), 0.4, solid=False)
        p.wear(pm, 10)
    # antenna masts with dishes
    for (x0, y0, x1, y1) in ((C - 30, C - 68, C - 60, C - 124), (C + 24, C - 40, C + 52, C - 114)):
        p.fill(p.line([(x0, y0), (x1, y1)], 0.9), IRON); p.fill(p.line([(x0 + 2, y0), (x1 + 2, y1)], 0.35), (110, 104, 100))
        dsh = p.ell(x1 - 4, y1 - 3, x1 + 4, y1 + 3); surf(p, dsh, (150, 140, 132), -0.3, -0.3)
        beacon(p, x1, y1 - 3, (255, 70, 50), 0.9)
    mount(p, 't2', C - 33, C - 62); mount(p, 't1', C - 64, C + 24); mount(p, 't1', C + 47, C + 60)
    mount(p, 't1', C + 26, C - 32)

ASSETS = {
    'gate_halo': (gate_halo, GU, 'Hyperspace gate (Halo)'),
    'station_authority_ring': (authority_ring, SU, 'Authority station (Ring)'),
    'station_trader_yard': (trader_yard, SU, 'Trader station (Container yard)'),
    'station_pirate_rock': (pirate_rock, SU, 'Pirate station (Hollowed rock)'),
}
