"""Station concepts, two per owner: authority (SOW-built), independent traders, pirates.
Canvas 274 units = 480 px at 1:1; centre = sprite centre. Hardpoints are indicative (concept stage):
each station records them in p.hps as (id, size, mount, x_px, y_px) from the sprite centre."""
import math
import numpy as np
import skit, kit, kit2
from skit import surf, ann, sector, rot, torus, dome, cone, polar, quant
from kit import LIGHT, WHITE, DARK, NAVY, RED, CYAN, RIB, STEEL

U = skit.units(480); C = U / 2
YELLOW = (206, 164, 62); SAND = (176, 156, 116); TEAL = (70, 120, 122); RUSTC = (128, 76, 46)
ROCK = (96, 88, 82); ROCK2 = (70, 64, 60)
BLACK = (52, 50, 54); OXIDE = (132, 44, 38); IRON = (74, 70, 70)
HOT1, HOT2 = (255, 120, 40), (255, 180, 80)
SOLAR = (46, 58, 86)

def _hps(p):
    if not hasattr(p, 'hps'): p.hps = []
    return p.hps

def mount(p, size, x, y, mnt='turret', role=None):
    """Turret ring with a turret fitted (concept preview) and a recorded hardpoint."""
    hps = _hps(p); n = sum(1 for h in hps if h[2] == mnt) + 1
    hid = {'turret': 'T', 'launcher': 'M', 'fixed': 'G'}[mnt] + str(n)
    hps.append((hid, size, mnt, round((x - C) * kit.K, 1), round((y - C) * kit.K, 1)))
    if mnt == 'turret':
        s = {'small': 1.0, 'medium': 1.5, 'large': 2.1}[size]
        if role == 'pd':
            p.fill(p.ell(x - 3, y - 3, x + 3, y + 3), (32, 36, 46)); dome(p, x, y, 2.2, (128, 136, 150), facets=3)
            p.fill(p.rect(x - 0.3, y - 5, x + 0.3, y - 1.5), STEEL)
        else:
            turret_scaled(p, x, y, s)
    elif mnt == 'launcher':
        m = p.rect(x - 5, y - 5, x + 5, y + 5, r=0.6); surf(p, m, (64, 70, 84))
        for i in range(3):
            for j in range(3):
                p.fill(p.ell(x - 4 + i * 2.8, y - 4 + j * 2.8, x - 2 + i * 2.8, y - 2 + j * 2.8), (24, 26, 32))

def turret_scaled(p, cx, cy, s):
    p.fill(p.ell(cx - 4.2 * s, cy - 4.2 * s, cx + 4.2 * s, cy + 4.2 * s), (32, 36, 46))
    dome(p, cx, cy, 3.4 * s, (120, 128, 144), facets=4)
    for x in (cx - 1.4 * s, cx + 1.4 * s):
        b = p.rect(x - 0.45 * s, cy - 10 * s, x + 0.45 * s, cy - 1.5 * s)
        surf(p, b, STEEL, 0, 0, edges=False)
        p.fill(p.rect(x - 0.6 * s, cy - 10.4 * s, x + 0.6 * s, cy - 9.4 * s), (60, 66, 80))

def hplate(p, x0, x1, y0, y1, centre=LIGHT, flank=DARK, ch=0.8):
    """SOW hull plate running left-right (kit.deck runs up-down)."""
    m = p.poly([(x0, y0 + ch), (x0 + ch, y0), (x1 - ch, y0), (x1, y0 + ch), (x1, y1 - ch), (x1 - ch, y1), (x0 + ch, y1), (x0, y1 - ch)])
    yc = (y0 + y1) / 2; hw = (y1 - y0) / 2; cw = hw * 0.6
    col = np.where((np.abs(p.Y - yc) < cw)[..., None], np.asarray(centre, np.float32), np.asarray(flank, np.float32))
    t = quant((p.Y - yc) / hw, 5) * 0.85
    surf(p, m, col, 0, t)
    for ye in (yc - cw, yc + cw): p.seam(m, [(x0, ye), (x1, ye)], 0.45)
    return m

def vdeck(p, x0, x1, y0, y1):
    return kit.deck(p, y0, y1, x0, x1)

def hcollar(p, x, y0, y1):
    m = p.rect(x, y0 - 0.6, x + 1.2, y1 + 0.6)
    t = quant((p.Y - (y0 + y1) / 2) / ((y1 - y0) / 2), 4) * 0.8
    surf(p, m, RIB, 0, t, edges=False)
    for y in np.arange(y0 + 0.1, y1 - 0.4, 1.3): p.fill(m * p.rect(x + 0.25, y, x + 0.95, y + 0.45), (96, 104, 120), 0.9)

def strip(p, x0, y0, x1, y1, col=CYAN):
    p.fill(p.rect(x0 - 0.3, y0 - 0.3, x1 + 0.3, y1 + 0.3), (30, 34, 44)); p.glow(p.rect(x0, y0, x1, y1, r=0.2), col)

def beam(p, x0, y0, x1, y1, w, col, facets=4, tilt=0.8):
    """An oriented box from (x0, y0) to (x1, y1), w wide, faceted across its width."""
    ang = math.atan2(y1 - y0, x1 - x0); nx, ny = -math.sin(ang), math.cos(ang)
    pts = [(x0 + nx * w / 2, y0 + ny * w / 2), (x1 + nx * w / 2, y1 + ny * w / 2), (x1 - nx * w / 2, y1 - ny * w / 2), (x0 - nx * w / 2, y0 - ny * w / 2)]
    m = p.poly(pts)
    across = ((p.X - x0) * nx + (p.Y - y0) * ny) / (w / 2)
    q = quant(across, facets) * tilt
    surf(p, m, col, nx * q, ny * q)
    return m

def solar(p, pts, cells=6):
    m = p.poly(pts); surf(p, m, SOLAR, 0.0, 0.0)
    (ax, ay), (bx, by), (cx_, cy_), (dx, dy) = pts
    for i in range(1, cells):
        t = i / cells
        p.fill(m * p.line([(ax + (dx - ax) * t, ay + (dy - ay) * t), (bx + (cx_ - bx) * t, by + (cy_ - by) * t)], 0.35), (120, 140, 170), 0.6, solid=False)
    for i in range(1, 3):
        t = i / 3
        p.fill(m * p.line([(ax + (bx - ax) * t, ay + (by - ay) * t), (dx + (cx_ - dx) * t, dy + (cy_ - dy) * t)], 0.35), (120, 140, 170), 0.6, solid=False)
    return m

def heightsurf(p, m, col, h, k=1.0):
    gy, gx = np.gradient(h, 1.0 / kit.SS)
    nx = np.clip(-gx * k, -0.95, 0.95); ny = np.clip(-gy * k, -0.95, 0.95)
    return surf(p, m, col, nx, ny, edges=False)

def beacon(p, x, y, col=(255, 90, 60), r=1.1):
    p.fill(p.ell(x - r * 1.8, y - r * 1.8, x + r * 1.8, y + r * 1.8), (34, 34, 40)); p.glow(p.ell(x - r, y - r, x + r, y + r), col)

# ---------------- Authority (SOW-built) ----------------
def authority_hub(p):
    """Four SOW docking arms on an octagonal command hub; solar wings on the diagonals."""
    for a in (45, 135, 225, 315):
        pts = rot([(C + 52, C - 14), (C + 118, C - 18), (C + 118, C + 18), (C + 52, C + 14)], C, C, a)
        solar(p, pts, 8)
        x, y = rot([(C + 50, C)], C, C, a)[0]; beam(p, C, C, x, y, 5, NAVY)
    vdeck(p, C - 13, C + 13, 16, C - 30); vdeck(p, C - 13, C + 13, C + 30, U - 16)
    hplate(p, 16, C - 30, C - 13, C + 13); hplate(p, C + 30, U - 16, C - 13, C + 13)
    for y in (46, 76): kit.collar(p, y, C - 13.6, C + 13.6); kit.collar(p, U - y - 1.2, C - 13.6, C + 13.6)
    for x in (46, 76): hcollar(p, x, C - 13, C + 13); hcollar(p, U - x - 1.2, C - 13, C + 13)
    for (x, y) in ((C, 14), (C, U - 14), (14, C), (U - 14, C)):
        torus(p, ann(p, x, y, 6, 14), x, y, 10, 4, (66, 72, 88), facets=4)
        p.glow(ann(p, x, y, 6, 7.2))
        p.fill(p.ell(x - 6, y - 6, x + 6, y + 6), (22, 24, 30))
    for k, (x0, y0, x1, y1) in enumerate(((C - 12, 24, C - 10.8, 40), (C + 10.8, U - 40, C + 12, U - 24))): strip(p, x0, y0, x1, y1)
    oct_ = [(C + 50 * math.cos(math.radians(22.5 + 45 * k)), C + 50 * math.sin(math.radians(22.5 + 45 * k))) for k in range(8)]
    hm = p.poly(oct_); cone(p, hm, C, C, DARK, tilt=0.5); p.edges(hm, 0.5)
    inner = [(C + 38 * math.cos(math.radians(22.5 + 45 * k)), C + 38 * math.sin(math.radians(22.5 + 45 * k))) for k in range(8)]
    cone(p, p.poly(inner), C, C, LIGHT, tilt=0.3)
    torus(p, ann(p, C, C, 38, 41), C, C, 39.5, 1.5, RED, facets=0, edges=False)
    dome(p, C, C, 16, WHITE, facets=5)
    for k in range(8):
        a = math.radians(45 * k); x, y = C + 11 * math.cos(a), C + 11 * math.sin(a)
        p.glow(p.ell(x - 1.4, y - 1.4, x + 1.4, y + 1.4))
    kit.emblem(p, C, C - 64)
    for a in (45, 135, 225, 315):
        x, y = C + 30 * math.cos(math.radians(a)), C + 30 * math.sin(math.radians(a)); mount(p, 'medium', x, y)
    for (x, y) in ((C, 60), (C, U - 60), (60, C), (U - 60, C)): mount(p, 'small', x, y, role='pd')
    p.wear(hm, 30)

def authority_ring(p):
    """A SOW-plated habitat ring on two spokes; docking cradles at 3 and 9 o'clock."""
    R, w = 94, 14
    r, ux, uy, th = polar(p, C, C)
    rm = ann(p, C, C, R - w, R + w)
    col = np.where((np.abs(r - R) < w * 0.45)[..., None], np.asarray(LIGHT, np.float32), np.asarray(DARK, np.float32))
    torus(p, rm, C, C, R, w, col, facets=5)
    for a in range(0, 360, 15):
        t = math.radians(a + 7.5)
        p.seam(rm, [(C + (R - w) * math.cos(t), C + (R - w) * math.sin(t)), (C + (R + w) * math.cos(t), C + (R + w) * math.sin(t))], 0.4)
    for a in range(0, 360, 45):
        cm = p.poly(sector(C, C, R - w - 1, R + w + 1, a - 1.2, a + 1.2, 6)); torus(p, cm, C, C, R, w, RIB, facets=4)
    for a in range(0, 360, 45):
        cm = p.poly(sector(C, C, R - 1.2, R + 1.2, a + 8, a + 37, 12)); p.glow(cm)
    torus(p, ann(p, C, C, R + w - 3, R + w - 1.6), C, C, R + w - 2.3, 1, RED, facets=0, edges=False)
    vdeck(p, C - 9, C + 9, C - R + w - 2, C - 26); vdeck(p, C - 9, C + 9, C + 26, C + R - w + 2)
    for y in (C - 70, C - 50): kit.collar(p, y, C - 9.6, C + 9.6); kit.collar(p, U - y - 1.2, C - 9.6, C + 9.6)
    hm = p.ell(C - 32, C - 32, C + 32, C + 32); cone(p, hm, C, C, DARK, tilt=0.5); p.edges(hm, 0.5)
    dome(p, C, C, 22, LIGHT, facets=6)
    torus(p, ann(p, C, C, 22, 24.5), C, C, 23, 1.2, RED, facets=0, edges=False)
    for sx in (-1, 1):
        x0 = C + sx * (R + w - 2); x1 = C + sx * (R + w + 16)
        hplate(p, min(x0, x1), max(x0, x1), C - 10, C + 10)
        x = C + sx * (R + w + 15); torus(p, ann(p, x, C, 4, 10), x, C, 7, 3, (66, 72, 88), facets=4); p.glow(ann(p, x, C, 4, 5))
    for a in (30, 150, 210, 330):
        t = math.radians(a); mount(p, 'small', C + R * math.cos(t), C + R * math.sin(t))
    mount(p, 'medium', C - 14, C); mount(p, 'medium', C + 14, C)
    for a in (60, 120, 240, 300):
        t = math.radians(a); mount(p, 'small', C + (R + 9) * math.cos(t), C + (R + 9) * math.sin(t), role='pd')
    p.wear(rm, 50)

# ---------------- Independent traders ----------------
def trader_yard(p):
    """A container yard: a long spine with clamp racks either side, gantry cranes, hab and tanks."""
    kinds = ('rust', 'teal', 'sand', 'grey')
    for side in (-1, 1):
        xa, xb = (C - 47, C - 13) if side < 0 else (C + 13, C + 47)
        for rx0, rx1 in ((xa, xa + 2.5), (xb - 2.5, xb)):
            surf(p, p.rect(rx0, 34, rx1, U - 38), (70, 74, 84), 0, 0)
        for y in np.arange(38, U - 50, 15):
            for cx0 in (xa + 3, xa + 3 + 14.5):
                if p.rng.random() < 0.82:
                    kit2.container(p, cx0, y, cx0 + 13, y + 13.5, kinds[p.rng.integers(4)])
    vdeck(p, C - 12, C + 12, 26, U - 30)
    for y in np.arange(56, U - 40, 40): kit.collar(p, y, C - 12.6, C + 12.6)
    for y in (C - 50, C + 50):
        m = hplate(p, C - 62, C + 62, y - 4, y + 4, centre=YELLOW, flank=(150, 118, 48))
        for x in (C - 62, C + 58):
            surf(p, p.rect(x, y - 7, x + 4, y + 7), (60, 64, 74), 0, 0); beacon(p, x + 2, y + 5.5, (255, 196, 90), 0.8)
        cab = p.rect(C + 26, y - 6, C + 36, y + 6, r=0.8); surf(p, cab, (184, 150, 60), 0.3, -0.3)
        strip(p, C + 27.5, y - 4, C + 34.5, y - 3)
    dome(p, C, 28, 22, LIGHT, facets=6)
    torus(p, ann(p, C, 28, 22, 25), C, 28, 23.5, 1.5, TEAL, facets=0, edges=False)
    for k in range(10):
        a = math.radians(36 * k); x, y = C + 15 * math.cos(a), 28 + 15 * math.sin(a); p.glow(p.ell(x - 1.1, y - 1.1, x + 1.1, y + 1.1), (255, 214, 150))
    for (x, y) in ((C - 26, U - 26), (C, U - 20), (C + 26, U - 26)): dome(p, x, y, 13, SAND, facets=5)
    for (x, y) in ((C - 26, U - 26), (C + 26, U - 26)): p.fill(p.rect(x - 7, y - 1, x + 7, y + 1), (60, 60, 64))
    for sx in (-1, 1):
        x = C + sx * 50; surf(p, p.rect(x - 5, 16, x + 5, 30), (66, 72, 88), 0, -0.3)
        p.glow(p.rect(x - 3, 17, x + 3, 18.5)); beacon(p, x, 27, (255, 90, 60), 0.8)
    mount(p, 'small', C, 72); mount(p, 'small', C, U - 70)

def trader_cobble(p):
    """A cobbled-together hub: an old habitat cylinder, tank cluster, a salvaged ring arc, sails and radiators."""
    m_r = p.poly(sector(C, C, 84, 104, 160, 330, 60)); torus(p, m_r, C, C, 94, 10, RUSTC, facets=5)
    for a in range(170, 330, 20):
        t = math.radians(a); p.seam(m_r, [(C + 84 * math.cos(t), C + 84 * math.sin(t)), (C + 104 * math.cos(t), C + 104 * math.sin(t))], 0.5)
    solar(p, rot([(C + 30, C - 104), (C + 104, C - 120), (C + 112, C - 80), (C + 38, C - 64)], C, C, 0), 8)
    beam(p, C + 10, C - 50, C + 40, C - 84, 4, NAVY)
    for k in range(5):
        y = C + 22 + k * 12; beam(p, C + 30, y, C + 96 - k * 6, y + 10, 5, (150, 156, 166), facets=2, tilt=0.4)
    vdeck(p, C - 20, C + 20, C - 72, C + 86)
    for y in (C - 40, C + 6, C + 52): kit.collar(p, y, C - 20.6, C + 20.6)
    mod = p.rect(C - 18, C - 30, C + 18, C - 6, r=1); surf(p, mod, TEAL, 0, 0); p.edges(mod, 0.4)
    mod2 = p.rect(C - 18, C + 60, C + 18, C + 80, r=1); surf(p, mod2, SAND, 0, 0); p.edges(mod2, 0.4)
    for y in (C - 64, C - 56, C + 20, C + 30): strip(p, C - 18.5, y, C - 17.3, y + 5); strip(p, C + 17.3, y, C + 18.5, y + 5)
    for (x, y, r) in ((C - 50, C + 30, 17), (C - 66, C + 4, 14), (C - 44, C - 18, 13), (C - 70, C + 46, 11)):
        dome(p, x, y, r, (196, 184, 160) if r > 12 else SAND, facets=5)
    beam(p, C - 36, C + 10, C - 20, C + 10, 6, (70, 74, 84))
    for (x0, y0, x1, y1) in ((C, C - 72, C, C - 118), (C - 20, C + 70, C - 66, C + 108)):
        beam(p, x0, y0, x1, y1, 12, DARK)
        p.glow(p.ell(x1 - 4, y1 - 4, x1 + 4, y1 + 4)); p.fill(p.ell(x1 - 2.5, y1 - 2.5, x1 + 2.5, y1 + 2.5), (22, 24, 30))
    mount(p, 'small', C, C - 46); mount(p, 'small', C - 92, C - 24); mount(p, 'small', C + 6, C + 96)
    beacon(p, C + 108, C - 98, (255, 196, 90)); beacon(p, C - 104, C + 22)
    p.wear(m_r, 25)

# ---------------- Pirates ----------------
def _rock(p, cx, cy, R, seed, lumps=7, rough=0.18):
    rng = np.random.default_rng(seed)
    r, ux, uy, th = polar(p, cx, cy)
    edge = np.ones_like(th) * R
    for k in range(2, lumps + 2):
        edge += R * rough / k ** 0.8 * np.sin(k * th + rng.uniform(0, 6.28))
    m = (r < edge).astype(np.float32)
    h = np.sqrt(np.clip(1 - (r / edge) ** 2, 0, 1)) * R * 0.5
    for _ in range(26):
        a, d = rng.uniform(0, 6.28), rng.uniform(0, 0.85) * R
        x, y, cr = cx + d * math.cos(a), cy + d * math.sin(a), rng.uniform(4, 14)
        dd = np.hypot(p.X - x, p.Y - y) / cr
        h += np.where(dd < 1, -(1 - dd ** 2) * cr * 0.35, np.where(dd < 1.3, (1.3 - dd) * cr * 0.25, 0))
    return m, h

def pirate_rock(p):
    """A hollowed asteroid: a docking slip cut into the rock, bolted oxide plating, hot vents."""
    m, h = _rock(p, C, C, 100, 5)
    col = np.where((h < h.mean())[..., None], np.asarray(ROCK2, np.float32), np.asarray(ROCK, np.float32))
    heightsurf(p, m, col, h, 0.9)
    slip = p.poly([(U, C - 16), (C + 10, C - 12), (C - 6, C), (C + 10, C + 12), (U, C + 16)]) * m
    p.fill(slip, (20, 18, 20))
    for side in (-1, 1):
        wall = p.poly([(U, C + side * 16), (C + 10, C + side * 12), (C + 10, C + side * 15), (U, C + side * 19)]) * m
        surf(p, wall, IRON, 0, side * -0.6)
        for x in np.arange(C + 18, C + 108, 12): p.glow(p.ell(x - 1, C + side * 13.5 - 1, x + 1, C + side * 13.5 + 1), HOT2)
    for (pts) in (((C - 60, C - 70), (C - 18, C - 82), (C - 10, C - 52), (C - 52, C - 42)),
                  ((C - 84, C + 10), (C - 50, C + 2), (C - 44, C + 40), (C - 80, C + 46)),
                  ((C + 20, C + 46), (C + 64, C + 40), (C + 70, C + 70), (C + 26, C + 80))):
        pm = p.poly(pts); surf(p, pm, (132, 44, 38), 0.1, -0.1); p.edges(pm, 0.5)
        for (x, y) in pts: p.fill(p.ell(x - 1, y - 1, x + 1, y + 1), (40, 36, 36))
        p.wear(pm, 6)
    for (x, y) in ((C - 30, C + 70), (C + 40, C - 70), (C - 80, C - 30), (C + 70, C + 20)):
        p.fill(p.ell(x - 9, y - 9, x + 9, y + 9) * m, HOT1, 0.25, solid=False)
        p.fill(p.ell(x - 4.5, y - 4.5, x + 4.5, y + 4.5), (40, 30, 28)); p.glow(p.ell(x - 3, y - 3, x + 3, y + 3), HOT1)
    for (x0, y0, x1, y1) in ((C - 40, C - 60, C - 70, C - 120), (C + 20, C - 40, C + 50, C - 112)):
        p.fill(p.line([(x0, y0), (x1, y1)], 0.8), IRON); beacon(p, x1, y1)
    mount(p, 'medium', C - 34, C - 62); mount(p, 'small', C - 64, C + 24); mount(p, 'small', C + 46, C + 60)
    mount(p, 'small', C + 30, C - 30)

def pirate_wreck(p):
    """A den welded together from wrecked hulls, scaffolding and hot pipework."""
    hulls = [(C - 6, 20, C + 6, U - 24, 34, BLACK), (C - 96, C + 60, C + 90, C - 40, 28, (88, 70, 64)), (C - 70, C - 90, C + 40, C + 96, 22, IRON)]
    ms = []
    for (x0, y0, x1, y1, w, col) in hulls:
        m = beam(p, x0, y0, x1, y1, w, col, facets=5); ms.append(m)
        ang = math.atan2(y1 - y0, x1 - x0); nx, ny = -math.sin(ang), math.cos(ang)
        L = math.hypot(x1 - x0, y1 - y0)
        for t in np.arange(0.12, 0.95, 0.16):
            cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            p.seam(m, [(cx + nx * w / 2, cy + ny * w / 2), (cx - nx * w / 2, cy - ny * w / 2)], 0.6)
        for t in (0.25, 0.6):
            cx, cy = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
            pl = [(cx + nx * w * 0.4 - (x1 - x0) / L * 9, cy + ny * w * 0.4 - (y1 - y0) / L * 9),
                  (cx + nx * w * 0.4 + (x1 - x0) / L * 9, cy + ny * w * 0.4 + (y1 - y0) / L * 9),
                  (cx - nx * w * 0.1 + (x1 - x0) / L * 7, cy - ny * w * 0.1 + (y1 - y0) / L * 7),
                  (cx - nx * w * 0.1 - (x1 - x0) / L * 7, cy - ny * w * 0.1 - (y1 - y0) / L * 7)]
            pm = p.poly(pl); surf(p, pm, (152, 46, 40), nx * 0.3, ny * 0.3); p.edges(pm, 0.5)
        p.wear(m, 18)
    for (x0, y0, x1, y1) in ((C - 60, C - 20, C - 10, C - 70), (C + 30, C + 20, C + 80, C + 70), (C - 40, C + 40, C + 10, C + 90)):
        for d in (-3, 3): p.fill(p.line([(x0 + d, y0), (x1 + d, y1)], 0.7), IRON)
        for t in np.linspace(0, 1, 6): p.fill(p.line([(x0 - 3 + (x1 - x0) * t, y0 + (y1 - y0) * t), (x0 + 3 + (x1 - x0) * t, y0 + (y1 - y0) * t)], 0.6), IRON)
    for pts in (((C + 10, C - 20), (C + 30, C - 10), (C + 40, C + 20)), ((C - 10, C + 30), (C - 30, C + 50), (C - 60, C + 52))):
        p.fill(p.line(pts, 3.6), (60, 40, 34)); p.glow(p.line(pts, 1.6), HOT1)
    bay = p.rect(C - 9, C - 14, C + 9, C + 14, r=1.2); p.fill(bay, (18, 16, 18))
    for y in (C - 12, C + 12): p.glow(p.rect(C - 7, y - 0.6, C + 7, y + 0.6), HOT2)
    for (x, y) in ((C, 26), (C, U - 30)):
        p.fill(p.ell(x - 6, y - 6, x + 6, y + 6), (40, 30, 28)); p.glow(p.ell(x - 3.5, y - 3.5, x + 3.5, y + 3.5), HOT1)
    mount(p, 'medium', C, C - 60); mount(p, 'small', C - 70, C + 46); mount(p, 'small', C + 60, C - 30)
    mount(p, 'small', C + 4, C + 66, mnt='launcher')
    beacon(p, C - 92, C + 62); beacon(p, C + 86, C - 42)

CONCEPTS = [
    ('station_authority_hub', 'Authority · Hub', authority_hub, 'SOW-built: four standard docking arms on an octagonal command hub, solar wings on the diagonals. 4 medium turrets on the hub, 4 point-defence on the arms.'),
    ('station_authority_ring', 'Authority · Ring', authority_ring, 'SOW-plated habitat ring on two spokes, docking cradles at 3 and 9 o\'clock. 4 small turrets on the ring, 2 medium on the hub, 4 point-defence.'),
    ('station_trader_yard', 'Traders · Container yard', trader_yard, 'A long spine with clamp racks of standard containers, gantry cranes, a hab dome and tanks. Lightly armed: 2 small turrets.'),
    ('station_trader_cobble', 'Traders · Cobbled hub', trader_cobble, 'Patched together from an old hab cylinder, a salvaged ring arc, tanks, sails and radiators. 3 small turrets.'),
    ('station_pirate_rock', 'Pirates · Hollowed rock', pirate_rock, 'An asteroid with a docking slip cut into it, bolted oxide plating, hot vents. 1 medium and 3 small turrets, placed where the rock allowed.'),
    ('station_pirate_wreck', 'Pirates · Wreck den', pirate_wreck, 'Welded together from three wrecked hulls, scaffolding and hot pipework. 1 medium, 2 small turrets and a missile launcher.'),
]
