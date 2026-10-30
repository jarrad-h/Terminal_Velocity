"""Local-space scenery: asteroids (rock, ice, metallic), debris (rock and wreck metal), SOW wreck sections, nav buoys.

Scenery sprites are scaled by the game to each object's random size (largest image side = size), so each
is drawn at the TOP of its data size range: large asteroid 180 px, rock 48 px, small debris 12-16 px,
wreck sections up to 110 px. Every sprite ships albedo, normal and emission maps like the ships; scenery
can opt in to lighting later. Canvases are cropped square with the object centred (it spins about the centre)."""
import math, os
import numpy as np
from PIL import Image, ImageFilter
import skit, kit, lightmaps
from kit import Paint, LIGHT, DARK, RED, RIB, CYAN, STEEL
from natural import fbm, smooth, lerp

_LB = np.array([-0.55, 0.55, 0.63]); _LB /= np.linalg.norm(_LB)
SSA = 4

def _reduce(rgb, a, nrm, colors=64, rim=True):
    """Downsample by SSA, alpha threshold, 64-colour palette and a dark rim pixel (as kit.reduce)."""
    H, W = a.shape[0] // SSA, a.shape[1] // SSA
    def dn(x): return np.asarray(Image.fromarray(x.astype(np.float32), 'F').resize((W, H), Image.BOX), np.float32)
    ad = dn(a)
    col = np.stack([dn(rgb[..., i] * a) for i in range(3)], -1) / np.maximum(ad[..., None], 1e-3)
    n = np.stack([dn(nrm[..., i] * a) for i in range(3)], -1) / np.maximum(ad[..., None], 1e-3)
    n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-4)
    alpha = ad > 0.45
    def q(c):
        im = Image.fromarray(np.clip(c, 0, 255).astype(np.uint8)).quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB')
        out = np.asarray(im, np.float32).copy()
        if rim:
            edge = alpha & ~(np.roll(alpha, 1, 0) & np.roll(alpha, -1, 0) & np.roll(alpha, 1, 1) & np.roll(alpha, -1, 1))
            out[edge] *= 0.6
        return out
    lam = 0.62 + 0.55 * np.clip((n * _LB).sum(-1), 0, None)
    baked = q(col * lam[..., None]); albedo = q(col * 0.86)
    n[~alpha] = (0, 0, 1)
    A = alpha.astype(np.uint8) * 255
    mk = lambda c: Image.fromarray(np.dstack([np.clip(c, 0, 255).astype(np.uint8), A]), 'RGBA')
    return {'sprite': mk(baked), 'albedo': mk(albedo), 'n': mk((n * 0.5 + 0.5) * 255), 'e': mk(np.zeros_like(col)), 'e_ring': None}

KINDS = {
    'rock':  dict(c0=(84, 76, 70), c1=(146, 132, 118), vein=None),
    'ice':   dict(c0=(120, 160, 204), c1=(214, 232, 250), vein=(70, 120, 180)),
    'metal': dict(c0=(52, 56, 64), c1=(118, 122, 130), vein=(150, 96, 60)),
}

def asteroid(px, kind='rock', seed=0, craters=True):
    rng = np.random.default_rng(seed)
    N = px * SSA
    c = (np.arange(N) + 0.5 - N / 2) / (N / 2)
    u, v = np.meshgrid(c, c)
    ang = rng.uniform(0, math.pi); asp = rng.uniform(1.0, 1.45)
    ur = (u * math.cos(ang) + v * math.sin(ang)) / asp * 1.0; vr = (-u * math.sin(ang) + v * math.cos(ang))
    r = np.hypot(ur, vr); th = np.arctan2(vr, ur)
    D = np.stack([np.cos(th), np.sin(th), np.full_like(th, seed * 0.37)])
    edge = 0.60 * (0.82 + 0.36 * fbm(D, 1.3, 5, seed))
    ur, vr = ur * 1.0, vr * 1.0
    m = (r < edge).astype(np.float32)
    rr = np.clip(r / edge, 0, 1)
    P3 = np.stack([u * 2.2, v * 2.2, np.full_like(u, seed * 1.7)])
    h = np.sqrt(np.clip(1 - rr ** 2, 0, 1)) * 0.55 + (fbm(P3, 1.8, 6, seed + 3) - 0.5) * 0.35
    if craters:
        for _ in range(rng.integers(3, 9)):
            cx, cy, cr = rng.uniform(-0.55, 0.55), rng.uniform(-0.55, 0.55), rng.uniform(0.06, 0.22)
            d = np.hypot(u - cx, v - cy) / cr
            h += np.where(d < 1, -(1 - d ** 2) * cr * 0.6, np.where(d < 1.3, (1.3 - d) * cr * 0.45, 0))
    gy, gx = np.gradient(h, 2.0 / N)
    k = 0.28
    nrm = np.stack([-gx * k, gy * k, np.ones_like(h)], -1)
    K = KINDS[kind]
    tone = fbm(P3, 3.0, 5, seed + 9)
    col = lerp(K['c0'], K['c1'], smooth(0.25, 0.8, tone * 0.7 + (h + 0.2) * 0.5))
    if K['vein'] is not None:
        vein = smooth(0.88, 0.95, fbm(P3, 2.5, 5, seed + 11, ridged=True))
        col = lerp(col, K['vein'], vein * 0.8)
    if kind == 'metal':
        spk = (fbm(P3, 22, 2, seed + 13) > 0.66).astype(np.float32)
        col = lerp(col, (214, 216, 222), spk * 0.85)
        plates = smooth(0.48, 0.5, fbm(P3, 1.2, 2, seed + 17))
        col = lerp(col, (88, 92, 102), plates * 0.5)
    return _reduce(col, m, nrm)

# ---------------- wreck sections (SOW parts, broken) ----------------
def _cut(p, y, keep_above, rng, depth=3.0):
    """Tear the hull across at y: jagged edge, scorched rim, everything beyond it removed."""
    xs = np.linspace(20, 60, 18); ys = y + rng.uniform(-depth, depth, xs.size)
    edge = list(zip(xs, ys))
    poly = ([(0, 0), (80, 0)] if keep_above else [(0, p.uh), (80, p.uh)])
    keep = p.poly(edge[::-1] + poly if keep_above else edge + poly[::-1])
    ycut = np.interp(p.X, xs, ys)
    dist = np.abs(p.Y - ycut)
    scorch = np.clip(1 - dist / 4.5, 0, 1) * (p.a > 0.5)
    p.fill(scorch.astype(np.float32), (36, 30, 28), 0.85, solid=False)
    p.a = p.a * keep
    if hasattr(p, 'em'): p.em *= keep[..., None]

def _dead(p):
    if hasattr(p, 'em'): p.em[:] = 0

def wreck_bow(p):
    rng = np.random.default_rng(1)
    kit.m_bow_bridge(p, 6); kit.collar(p, 22); kit.m_segment(p, 23.2, 16, 'hatch'); kit.collar(p, 39.2)
    kit.m_segment(p, 40.4, 16, 'cargo', ('grille', 'grille'))
    _cut(p, 52, True, rng); p.wear(p.a, 40); _dead(p)

def wreck_mid(p):
    rng = np.random.default_rng(2)
    kit.m_segment(p, 4, 16, 'cargo', ('light', 'grille')); kit.collar(p, 20); kit.m_segment(p, 21.2, 16, 'plain'); kit.collar(p, 37.2)
    kit.m_segment(p, 38.4, 16, 'hatch', ('grille', 'light'))
    _cut(p, 8, False, rng); _cut(p, 50, True, rng); p.wear(p.a, 40); _dead(p)

def wreck_aft(p):
    rng = np.random.default_rng(3)
    kit.m_segment(p, 4, 16, 'plain', ('grille', 'light')); kit.collar(p, 20); kit.m_aft_engine(p, 21.2, 12, 4)
    _cut(p, 9, False, rng, 4); p.wear(p.a, 30); _dead(p)

def wreck_split(p):
    """A segment torn lengthwise: one flank, bent."""
    rng = np.random.default_rng(4)
    kit.m_segment(p, 4, 16, 'cargo', ('grille', 'grille')); kit.collar(p, 20); kit.m_segment(p, 21.2, 16, 'plain'); kit.collar(p, 37.2)
    xs = 40 + rng.uniform(-3, 3, 14); ys = np.linspace(2, 40, 14)
    keep = p.poly([(0, 0)] + list(zip(xs, ys)) + [(0, 42)])
    xc = np.interp(p.Y, ys, xs); p.fill((np.clip(1 - np.abs(p.X - xc) / 4, 0, 1) * (p.a > 0.5)).astype(np.float32), (36, 30, 28), 0.85, solid=False)
    p.a = p.a * keep
    if hasattr(p, 'em'): p.em *= keep[..., None]
    _cut(p, 7, False, rng); _cut(p, 35, True, rng); p.wear(p.a, 25); _dead(p)

WRECKS = {'wreck_sow_bow': (wreck_bow, 60), 'wreck_sow_mid': (wreck_mid, 56), 'wreck_sow_aft': (wreck_aft, 38), 'wreck_sow_split': (wreck_split, 42)}

def render_paint(fn, uh, uw=80, crop=True):
    imgs = skit.render(fn, uw, uh, seed=7)
    if crop:
        bb = imgs['sprite'].getbbox(); w, h = bb[2] - bb[0], bb[3] - bb[1]; s = max(w, h) + 2
        cx, cy = (bb[0] + bb[2]) // 2, (bb[1] + bb[3]) // 2
        box = (cx - s // 2, cy - s // 2, cx - s // 2 + s, cy - s // 2 + s)
        for k in ('sprite', 'albedo', 'n', 'e'): imgs[k] = imgs[k].crop(box)
    imgs['e_ring'] = None
    return imgs

# ---------------- metal debris (wreck fragments) ----------------
def metal_bit(seed):
    def fn(p):
        rng = np.random.default_rng(seed)
        cx = cy = 5
        pts = [(cx + math.cos(a) * rng.uniform(2.2, 4.4), cy + math.sin(a) * rng.uniform(2.2, 4.4)) for a in np.sort(rng.uniform(0, 6.28, 6))]
        m = p.poly(pts); nx, ny = rng.uniform(-0.5, 0.5, 2)
        col = LIGHT if seed % 3 == 0 else (DARK if seed % 3 == 1 else (120, 112, 104))
        skit.surf(p, m, col, nx, ny)
        if seed % 2: p.fill(m * p.rect(0, cy - 0.4, 10, cy + 0.6), RED, 0.9, solid=False)
        p.fill(m * p.line([(pts[0][0], pts[0][1]), (pts[3][0], pts[3][1])], 0.3), (30, 30, 34), 0.6, solid=False)
        _dead(p)
    return fn

# ---------------- nav buoys ----------------
def buoy(kind):
    def fn(p):
        C = 10
        body, trim, light = ((150, 158, 172), RED, (255, 179, 71)) if kind == 'authority' else ((218, 210, 194), (186, 144, 80), (206, 192, 255))
        for k in range(3):
            fin = skit.rot([(C - 1.2, C), (C + 1.2, C), (C + 0.6, C - 9), (C - 0.6, C - 9)], C, C, 120 * k)
            skit.surf(p, p.poly(fin), (70, 76, 92) if kind == 'authority' else (52, 54, 62), 0, 0)
            tip = skit.rot([(C, C - 9)], C, C, 120 * k)[0]
            p.fill(p.ell(tip[0] - 1, tip[1] - 1, tip[0] + 1, tip[1] + 1), (34, 34, 40)); p.glow(p.ell(tip[0] - 0.55, tip[1] - 0.55, tip[0] + 0.55, tip[1] + 0.55), light)
        skit.dome(p, C, C, 4.6, body, facets=5)
        skit.torus(p, skit.ann(p, C, C, 4.6, 5.6), C, C, 5.1, 0.5, trim, facets=0)
        p.fill(p.ell(C - 1.6, C - 1.6, C + 1.6, C + 1.6), (30, 30, 36)); p.glow(p.ell(C - 1.0, C - 1.0, C + 1.0, C + 1.0), light)
    return fn
