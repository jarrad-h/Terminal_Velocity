"""Hyperspace gate concepts. Built by an advanced consortium, not a shipyard: ivory ceramic armour over
graphite structure, brass trim, a violet-white field. Beacons (always on) and the ring/field (off when
the gate is closed) go to separate emission maps. Canvas 343 units = 600 px at 1:1; centre = sprite centre."""
import math
import numpy as np
import skit
from skit import surf, ann, sector, rot, torus, dome, cone, glow_ring, field, polar, quant

IVORY = (218, 210, 194); BONE = (176, 168, 154); GRAPH = (52, 54, 62); GRAPH2 = (82, 84, 96)
BRASS = (186, 144, 80); FIELD = (168, 148, 255); EMIT = (206, 192, 255)
BEACON = (255, 212, 150); BRED = (255, 92, 60)
U = skit.units(600); C = U / 2

def radial_seams(p, m, r0, r1, step, off=0):
    for a in np.arange(off, 360 + off, step):
        t = math.radians(a)
        p.seam(m, [(C + r0 * math.cos(t), C + r0 * math.sin(t)), (C + r1 * math.cos(t), C + r1 * math.sin(t))], 0.4)

def aperture(p, r, k=1.0, ripple=0.22, spiral=0.0):
    rr, ux, uy, th = polar(p, C, C)
    t = np.clip(rr / r, 0, 1)
    wave = 0.5 + 0.5 * np.cos(rr * ripple + th * spiral * 3)
    inten = (0.18 + 0.55 * t ** 3 + 0.12 * wave) * (rr < r)
    edge = np.clip((r - rr) / 2.5, 0, 1)
    field(p, inten * edge, FIELD, k * 0.55)

def beacon(p, x, y, col=BEACON, r=1.3):
    p.fill(p.ell(x - r * 1.8, y - r * 1.8, x + r * 1.8, y + r * 1.8), (34, 34, 40))
    p.glow(p.ell(x - r, y - r, x + r, y + r), col)

# ---------------- A: Halo ----------------
def gate_halo(p):
    """One great ceramic torus, eight inward emitter prongs, four beacon pods."""
    torus(p, ann(p, C, C, 118, 160), C, C, 139, 21, GRAPH, facets=5)
    m = torus(p, ann(p, C, C, 134, 162), C, C, 148, 14, IVORY, facets=6)
    radial_seams(p, m, 134, 162, 10, 5)
    torus(p, ann(p, C, C, 145.5, 148.5), C, C, 147, 1.5, BRASS, facets=0, edges=False)
    for k in range(8):
        a = 22.5 + 45 * k
        pts = rot([(C + 100, C - 4), (C + 128, C - 9), (C + 128, C + 9), (C + 100, C + 4)], C, C, a)
        pm = p.poly(pts); cone(p, pm, C, C, GRAPH2, tilt=0.35)
        tip = rot([(C + 99, C - 4.5), (C + 105, C - 6), (C + 105, C + 6), (C + 99, C + 4.5)], C, C, a)
        surf(p, p.poly(tip), BRASS, *(-0.5 * math.cos(math.radians(a)), -0.5 * math.sin(math.radians(a))))
        x, y = C + 99.5 * math.cos(math.radians(a)), C + 99.5 * math.sin(math.radians(a))
        glow_ring(p, p.ell(x - 2, y - 2, x + 2, y + 2), EMIT)
    glow_ring(p, ann(p, C, C, 119, 121), (150, 132, 230))
    for k in range(4):
        a = 45 + 90 * k; ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        pod = rot([(C + 156, C - 12), (C + 168, C - 8), (C + 168, C + 8), (C + 156, C + 12)], C, C, a)
        pm = p.poly(pod); surf(p, pm, BONE, ca * 0.4, sa * 0.4)
        beacon(p, C + 164 * ca, C + 164 * sa, BRED if k % 2 else BEACON)
    for k in range(16):
        a = math.radians(11.25 * (2 * k + 1))
        if k % 2: beacon(p, C + 155 * math.cos(a), C + 155 * math.sin(a), BEACON, 0.9)
    p.wear(m, 60)
    aperture(p, 118)

# ---------------- B: Crown ----------------
def gate_crown(p):
    """Six floating arc segments held in formation by the field; keystone nodes in the gaps."""
    for k in range(6):
        a0 = 60 * k - 90 + 4; a1 = 60 * k - 90 + 56
        base = p.poly(sector(C, C, 110, 150, a0, a1)); torus(p, base, C, C, 130, 20, GRAPH, facets=5)
        top = p.poly(sector(C, C, 117, 146, a0 + 2.5, a1 - 2.5)); torus(p, top, C, C, 131, 15, IVORY, facets=6)
        mid = (a0 + a1) / 2
        for da in (-14, 0, 14):
            t = math.radians(mid + da)
            p.seam(top, [(C + 117 * math.cos(t), C + 117 * math.sin(t)), (C + 146 * math.cos(t), C + 146 * math.sin(t))], 0.45)
        for ae in (a0 + 1.2, a1 - 1.2):
            cap = p.poly(sector(C, C, 112, 148, ae - 1.2, ae + 1.2, 6)); torus(p, cap, C, C, 130, 18, BRASS, facets=4)
        glow_ring(p, p.poly(sector(C, C, 110, 113, a0 + 3, a1 - 3)), EMIT)
        t = math.radians(mid); ox, oy = math.cos(t), math.sin(t)
        hub = rot([(C + 141, C - 7), (C + 156, C - 5), (C + 156, C + 5), (C + 141, C + 7)], C, C, mid)
        surf(p, p.poly(hub), BONE, ox * 0.45, oy * 0.45)
        beacon(p, C + 152 * ox, C + 152 * oy, BEACON)
        p.wear(top, 12)
        # keystone in the gap after this segment
        g = math.radians(a1 + 4); gx, gy = C + 130 * math.cos(g), C + 130 * math.sin(g)
        ks = rot([(gx, gy - 7), (gx + 4, gy), (gx, gy + 7), (gx - 4, gy)], gx, gy, a1 + 4)
        cone(p, p.poly(ks), gx, gy, GRAPH2, tilt=0.5)
        glow_ring(p, p.ell(gx - 1.6, gy - 1.6, gx + 1.6, gy + 1.6), EMIT)
    for k in range(6):
        t = math.radians(60 * k)
        x, y = C + 165 * math.cos(t), C + 165 * math.sin(t)
        dm = p.ell(x - 3.2, y - 3.2, x + 3.2, y + 3.2); dome(p, x, y, 3.2, BONE, m=dm)
        beacon(p, x, y, BRED, 0.9)
    aperture(p, 109, ripple=0.3)

# ---------------- C: Caliper ----------------
def _arm(p, side, plates=True):
    """One curved arm of the caliper; side -1 left, +1 right."""
    ys = np.linspace(C + 96, C - 150, 40)
    def xc(y):
        s = (C + 96 - y) / 246                       # 0 at the root, 1 at the tip
        return C + side * (58 + 26 * math.sin(s * math.pi * 0.9) - 6 * s)
    def hw(y):
        s = (C + 96 - y) / 246; return 15 - 6 * s
    outer = [(xc(y) + side * hw(y), y) for y in ys]; inner = [(xc(y) - side * hw(y), y) for y in ys[::-1]]
    m = p.poly(outer + inner)
    X, Y = p.X, p.Y
    s = np.clip((C + 96 - Y) / 246, 0, 1)
    xcy = C + side * (58 + 26 * np.sin(s * np.pi * 0.9) - 6 * s); hwy = 15 - 6 * s
    t = quant((X - xcy) / hwy, 5) * 0.85
    surf(p, m, GRAPH, t, 0)
    # armour plates
    for i in range(10):
        y0 = C + 86 - i * 23.5; y1 = y0 - 19
        if y1 < C - 146: break
        pl = [(xc(y) + side * (hw(y) - 1.5), y) for y in np.linspace(y0, y1, 6)] + \
             [(xc(y) - side * (hw(y) - 5), y) for y in np.linspace(y1, y0, 6)]
        pm = p.poly(pl); surf(p, pm, IVORY, np.where(m > 0, t * 0.9, 0), -0.12)
        if i % 3 == 1:
            yb = (y0 + y1) / 2; beacon(p, xc(yb) + side * (hw(yb) - 4), yb, BEACON, 0.9)
    # emitter strip on the inner face
    em = [(xc(y) - side * hw(y), y) for y in np.linspace(C + 70, C - 136, 30)]
    em_in = [(x - side * 2.6, y) for x, y in em[::-1]]
    glow_ring(p, p.poly(em + em_in), EMIT)
    # tip pylon
    yt = C - 150; tp = [(xc(yt) - 7, yt + 4), (xc(yt) + 7, yt + 4), (xc(yt) + 4, yt - 8), (xc(yt) - 4, yt - 8)]
    surf(p, p.poly(tp), BRASS, 0, -0.5)
    beacon(p, xc(yt), yt - 4, BRED, 1.2)
    return m

def gate_caliper(p):
    """Two great curved arms rising from a control hub; ships pass between the arms."""
    _arm(p, -1); _arm(p, 1)
    # field between the arms, strongest along the centre line
    X, Y = p.X, p.Y
    s = np.clip((C + 96 - Y) / 246, 0, 1)
    half = 58 + 26 * np.sin(s * np.pi * 0.9) - 6 * s - (15 - 6 * s) - 2
    inside = (np.abs(X - C) < half) & (Y < C + 72) & (Y > C - 140)
    xn = np.abs(X - C) / np.maximum(half, 1)
    wave = 0.5 + 0.5 * np.cos((Y - C) * 0.35 - xn * 3)
    inten = inside * (0.2 + 0.45 * xn ** 4 + 0.15 * wave) * np.clip((C + 72 - Y) / 14, 0, 1) * np.clip((Y - (C - 140)) / 14, 0, 1)
    field(p, inten, FIELD)
    # hub
    hb = p.poly([(C - 74, C + 84), (C + 74, C + 84), (C + 60, C + 128), (C + 30, C + 150), (C - 30, C + 150), (C - 60, C + 128)])
    cone(p, hb, C, C + 112, GRAPH2, tilt=0.45)
    dome(p, C, C + 114, 30, IVORY, facets=6)
    torus(p, ann(p, C, C + 114, 30, 34), C, C + 114, 32, 2, BRASS, facets=0)
    for k in range(6):
        a = math.radians(30 + 60 * k); x, y = C + 22 * math.cos(a), C + 114 + 22 * math.sin(a)
        p.fill(p.ell(x - 2.2, y - 2.2, x + 2.2, y + 2.2), (40, 42, 50)); p.glow(p.ell(x - 1.2, y - 1.2, x + 1.2, y + 1.2), BEACON)
    glow_ring(p, p.ell(C - 7, C + 107, C + 7, C + 121), EMIT)
    for sx in (-1, 1):
        dk = p.rect(C + sx * 64 - 6, C + 130, C + sx * 64 + 6, C + 146, r=1.5); surf(p, dk, BONE, sx * 0.3, 0.3)
        beacon(p, C + sx * 64, C + 143, BRED, 0.9)
    p.wear(hb, 30)

JUMP_POINTS = {'gate_halo': (0, 0), 'gate_crown': (0, 0), 'gate_caliper': (0, -30), 'gate_orrery': (0, 0)}

# ---------------- D: Orrery ----------------
def gate_orrery(p):
    """Concentric outer and inner rings on three spokes; control pod on the outer ring."""
    m_out = torus(p, ann(p, C, C, 142, 162), C, C, 152, 10, GRAPH2, facets=4)
    torus(p, ann(p, C, C, 150.5, 153.5), C, C, 152, 1.5, BRASS, facets=0, edges=False)
    for k in range(3):
        a = 90 + 120 * k
        sp = rot([(C + 100, C - 8), (C + 146, C - 6), (C + 146, C + 6), (C + 100, C + 8)], C, C, a)
        sm = p.poly(sp); t = math.radians(a)
        X, Y = p.X - C, p.Y - C
        across = (-X * math.sin(t) + Y * math.cos(t)) / 8
        q = quant(across, 4) * 0.8
        surf(p, sm, GRAPH, -math.sin(t) * q, math.cos(t) * q)
        pl = rot([(C + 106, C - 5), (C + 140, C - 4), (C + 140, C + 4), (C + 106, C + 5)], C, C, a)
        surf(p, p.poly(pl), IVORY, -math.sin(t) * q * 0.8, math.cos(t) * q * 0.8)
        cd = rot([(C + 104, C - 0.9), (C + 148, C - 0.9), (C + 148, C + 0.9), (C + 104, C + 0.9)], C, C, a)
        glow_ring(p, p.poly(cd), EMIT)
    m_in = torus(p, ann(p, C, C, 82, 110), C, C, 96, 14, IVORY, facets=6)
    radial_seams(p, m_in, 84, 109, 15, 7.5)
    torus(p, ann(p, C, C, 80, 86), C, C, 83, 3, GRAPH, facets=3)
    glow_ring(p, ann(p, C, C, 80.5, 82.5), EMIT)
    for k in range(12):
        a = math.radians(30 * k + 15); beacon(p, C + 152 * math.cos(a), C + 152 * math.sin(a), BRED if k % 3 == 0 else BEACON, 1.0)
    for k in range(6):
        a = math.radians(60 * k + 30); x, y = C + 96 * math.cos(a), C + 96 * math.sin(a)
        dome(p, x, y, 5, BONE, facets=4); glow_ring(p, p.ell(x - 1.6, y - 1.6, x + 1.6, y + 1.6), EMIT)
    pod = p.rect(C - 18, C - 170, C + 18, C - 146, r=4); surf(p, pod, BONE, 0, -0.35)
    dome(p, C, C - 158, 9, IVORY, facets=5)
    for sx in (-12, 12): beacon(p, C + sx, C - 152, BEACON, 1.0)
    p.wear(m_in, 30); p.wear(m_out, 20)
    aperture(p, 80, ripple=0.15, spiral=1.0)

CONCEPTS = [
    ('gate_halo', 'A · Halo', gate_halo, 'One great ceramic torus with eight inward emitter prongs and four beacon pods. Classic and readable at any zoom.'),
    ('gate_crown', 'B · Crown', gate_crown, 'Six floating arc segments held in formation by the field itself, with glowing keystones in the gaps and an outer ring of drone beacons.'),
    ('gate_caliper', 'C · Caliper', gate_caliper, 'Two great curved arms rising from a control hub; ships fly between them. Has a front and a back, so gates can point along their lanes.'),
    ('gate_orrery', 'D · Orrery', gate_orrery, 'Concentric rings on three spokes, a spiral field and a control pod on the rim. The most "machine" of the four.'),
]
