"""No-frills maker kit: standard modules on a shared grid, assembled into the block-hull shuttle.
Units: hull is 26 wide (x 27..53), segments are multiples of 4 long, joined by 1.2-unit collars.
Painted at SS px/unit, reduced to K px/unit for the 1:1 sprite."""
import os, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

SS, K = 8, 1.75
LIGHT = (196, 200, 210); WHITE = (216, 220, 228); DARK = (78, 88, 106); NAVY = (54, 62, 80)
RED = (210, 64, 56); CYAN = (90, 224, 255); RIB = (30, 34, 44); STEEL = (150, 158, 172)
HX0, HX1, CX = 27, 53, 40

class Paint:
    def __init__(self, uw, uh, seed=4):
        self.uw, self.uh = uw, uh
        self.rgb = np.zeros((uh * SS, uw * SS, 3), np.float32); self.a = np.zeros((uh * SS, uw * SS), np.float32)
        ys, xs = np.mgrid[0:uh * SS, 0:uw * SS]; self.X = (xs + 0.5) / SS; self.Y = (ys + 0.5) / SS
        self.rng = np.random.default_rng(seed)
    def _m(self, fn):
        im = Image.new('L', (self.uw * SS, self.uh * SS), 0); fn(ImageDraw.Draw(im)); return np.asarray(im, np.float32) / 255
    def poly(self, pts): return self._m(lambda d: d.polygon([(x * SS, y * SS) for x, y in pts], fill=255))
    def rect(self, x0, y0, x1, y1, r=0): return self._m(lambda d: d.rounded_rectangle([x0 * SS, y0 * SS, x1 * SS - 1, y1 * SS - 1], radius=r * SS, fill=255))
    def ell(self, x0, y0, x1, y1): return self._m(lambda d: d.ellipse([x0 * SS, y0 * SS, x1 * SS - 1, y1 * SS - 1], fill=255))
    def line(self, pts, w): return self._m(lambda d: d.line([(x * SS, y * SS) for x, y in pts], fill=255, width=max(1, int(w * SS))))
    def fill(self, m, col, alpha=1.0, solid=True):
        col = np.asarray(col, np.float32)
        if col.ndim == 1: col = np.broadcast_to(col, self.rgb.shape)
        k = (m * alpha)[..., None]; self.rgb = self.rgb * (1 - k) + col * k
        if solid: self.a = np.maximum(self.a, m)
    def shade(self, m, f):
        f = np.asarray(f, np.float32)
        if f.ndim == 0: f = np.full_like(self.X, float(f))
        k = m[..., None]; self.rgb = self.rgb * (1 - k) + np.clip(self.rgb * f[..., None], 0, 255) * k
    def edges(self, m, d=0.55, lit=1.22, dark=0.58):
        s = max(1, int(d * SS))
        lt = (m > 0.5) & ((np.roll(m, s, 1) < 0.5) | (np.roll(m, s, 0) < 0.5))
        dk = (m > 0.5) & ((np.roll(m, -s, 1) < 0.5) | (np.roll(m, -s, 0) < 0.5)) & ~lt
        f = np.ones_like(m); f[lt] = lit; f[dk] = dark; self.shade(m, f)
    def facet(self, x0, x1, facets=5):
        n = np.clip((self.X - (x0 + x1) / 2) / ((x1 - x0) / 2), -0.99, 0.99)
        nf = np.clip((np.floor((n + 1) / 2 * facets) + 0.5) / facets * 2 - 1, -0.99, 0.99)
        return 0.6 + 0.52 * np.clip(0.8 * np.sqrt(1 - nf ** 2) - 0.5 * nf, 0, None)
    def lit(self, f, nx, ny=None, flat=0.86):
        """Hand-written shading factor f for the next fill. Returns f unchanged here; when the light-map
        exporter (lightmaps.py) is active it records the surface direction (nx across, ny down the
        canvas, both -1..1) for the normal map and returns `flat` so the albedo carries no baked light."""
        return f
    def glow(self, m, col=CYAN):
        c = np.asarray(col, np.float32); self.fill(m, c)
        self.fill(m * self.rect(0, 0, self.uw, self.uh), np.clip(c * 1.25 + 30, 0, 255), 0.35, solid=False)
    def seam(self, m, pts, a=0.5):
        self.fill(m * self.line(pts, 0.22), (28, 32, 42), a, solid=False)
        self.fill(m * self.line([(x + 0.3, y + 0.3) for x, y in pts], 0.14), (235, 238, 244), 0.25, solid=False)
    def rivets(self, m, y, x0=HX0 + 1, x1=HX1 - 1, step=1.6):
        for x in np.arange(x0, x1, step):
            self.fill(m * self.ell(x - 0.22, y - 0.22, x + 0.22, y + 0.22), (230, 234, 240), 0.7, solid=False)
            self.fill(m * self.ell(x + 0.05, y + 0.05, x + 0.35, y + 0.35), (40, 44, 52), 0.5, solid=False)
    def wear(self, m, n):
        for _ in range(n):
            x, y = self.rng.uniform(0, self.uw), self.rng.uniform(0, self.uh); r = self.rng.uniform(0.15, 0.4)
            self.fill(m * self.ell(x - r, y - r, x + r, y + r), (46, 50, 58), 0.45, solid=False)
        for _ in range(n // 2):
            x, y = self.rng.uniform(0, self.uw), self.rng.uniform(0, self.uh); l = self.rng.uniform(0.6, 2)
            self.fill(m * self.line([(x, y), (x + l, y + l * 0.4)], 0.12), (240, 244, 250), 0.35, solid=False)

# ---------------- standard parts ----------------
def deck(p, y0, y1, x0=HX0, x1=HX1, ch=0.8):
    """The one hull plate everything shares: white centre deck over slate flanks, 5 facets."""
    m = p.poly([(x0 + ch, y0), (x1 - ch, y0), (x1, y0 + ch), (x1, y1 - ch), (x1 - ch, y1), (x0 + ch, y1), (x0, y1 - ch), (x0, y0 + ch)])
    cw = (x1 - x0) * 0.3
    col = np.where((np.abs(p.X - (x0 + x1) / 2) < cw)[..., None], np.asarray(LIGHT, np.float32), np.asarray(DARK, np.float32))
    p.fill(m, np.clip(col * (p.facet(x0, x1) - 0.06 * (p.Y - y0) / max(y1 - y0, 1))[..., None], 0, 255))
    p.edges(m)
    xc = (x0 + x1) / 2
    for xe in (xc - cw, xc + cw): p.seam(m, [(xe, y0), (xe, y1)], 0.45)
    p.rivets(m, y0 + 0.8, x0 + 1, x1 - 1); p.rivets(m, y1 - 0.8, x0 + 1, x1 - 1)
    return m

def collar(p, y, x0=HX0 - 0.6, x1=HX1 + 0.6):
    m = p.rect(x0, y, x1, y + 1.2)
    n = np.clip((p.X - (x0 + x1) / 2) / ((x1 - x0) / 2), -1, 1)
    p.fill(m, np.clip(np.asarray(RIB, np.float32) * p.lit(1.15 - 0.45 * n, n * 0.8, flat=1.15)[..., None], 0, 255))
    for x in np.arange(x0 + 0.7, x1 - 0.4, 1.3): p.fill(m * p.rect(x, y + 0.25, x + 0.45, y + 0.95), (96, 104, 120), 0.9)
    return m

def grille(p, x0, y0, h=7):
    g = p.rect(x0, y0, x0 + 3, y0 + h); p.fill(g, (40, 46, 58))
    for yy in np.arange(y0 + 0.6, y0 + h - 0.2, 1.2): p.fill(g * p.rect(x0 + 0.3, yy, x0 + 2.7, yy + 0.4), (122, 130, 146))
    p.edges(g, 0.3, 1.3, 0.6)

def lightstrip(p, x0, y0, h=4):
    p.fill(p.rect(x0 - 0.3, y0 - 0.3, x0 + 1.5, y0 + h + 0.3), (30, 34, 44)); p.glow(p.rect(x0, y0, x0 + 1.2, y0 + h, r=0.2))

def rcs(p, x, y):
    m = p.rect(x - 1, y - 1, x + 1, y + 1, r=0.3); p.fill(m, (66, 74, 90)); p.edges(m, 0.3)
    p.fill(p.rect(x - 0.4, y - 0.4, x + 0.4, y + 0.4), (24, 28, 36))

def turret(p, cx, cy):
    p.fill(p.ell(cx - 4.2, cy - 4.2, cx + 4.2, cy + 4.2), (32, 36, 46))
    tm = p.ell(cx - 3.4, cy - 3.4, cx + 3.4, cy + 3.4)
    p.fill(tm, np.clip(np.asarray((120, 128, 144), np.float32) * p.facet(cx - 3.4, cx + 3.4, 4)[..., None], 0, 255)); p.edges(tm, 0.45)
    for x in (cx - 1.4, cx + 1.4):
        b = p.rect(x - 0.45, cy - 10, x + 0.45, cy - 1.5); p.fill(b, STEEL); p.fill(b * p.rect(x, cy - 10, x + 0.45, cy - 1.5), (84, 90, 104))
        p.fill(p.rect(x - 0.6, cy - 10.4, x + 0.6, cy - 9.4), (60, 66, 80))
    p.fill(p.rect(cx - 1.4, cy - 2, cx + 1.4, cy - 0.4), (40, 44, 54))

def hatch(p, cx, cy):
    hm = p.rect(cx - 4.5, cy - 4, cx + 4.5, cy + 4, r=0.5); p.fill(hm, (172, 178, 190)); p.edges(hm, 0.45, 1.25, 0.55)
    p.seam(hm, [(cx - 4.5, cy), (cx + 4.5, cy)], 0.6)
    for x in (cx - 3.6, cx + 2.6): p.fill(p.rect(x, cy - 3.3, x + 1, cy - 2.6), RED)

def nozzle(p, cx, y0, w=5, h=4):
    m = p.poly([(cx - w * 0.38, y0), (cx + w * 0.38, y0), (cx + w / 2, y0 + h), (cx - w / 2, y0 + h)])
    n = np.clip((p.X - cx) / (w / 2), -1, 1)
    p.fill(m, np.clip(np.array([62, 68, 82], np.float32) * p.lit(0.55 + 0.6 * np.sqrt(1 - n ** 2) - 0.3 * n, n, flat=1.0)[..., None], 0, 255)); p.edges(m, 0.4)
    p.glow(p.poly([(cx - w * 0.42, y0 + h - 0.9), (cx + w * 0.42, y0 + h - 0.9), (cx + w / 2 - 0.2, y0 + h), (cx - w / 2 + 0.2, y0 + h)]))

def emblem(p, cx, cy):
    p.fill(p.ell(cx - 1.8, cy - 1.8, cx + 1.8, cy + 1.8), RED); p.fill(p.ell(cx - 0.8, cy - 0.8, cx + 0.8, cy + 0.8), (222, 224, 230))

# ---------------- modules (each is one asset in the pack) ----------------
def m_bow_bridge(p, y0):
    """Bow plate + stepped bridge. 16 long."""
    for x, ya in ((37, y0 - 4), (43.5, y0 - 2)): p.fill(p.line([(x, ya), (x, y0 + 3)], 0.35), STEEL)
    m = p.poly([(31, y0 + 6), (49, y0 + 6), (53, y0 + 11), (53, y0 + 16), (27, y0 + 16), (27, y0 + 11)])
    col = np.where((np.abs(p.X - CX) < 7.8)[..., None], np.asarray(LIGHT, np.float32), np.asarray(DARK, np.float32))
    p.fill(m, np.clip(col * p.facet(HX0, HX1)[..., None], 0, 255)); p.edges(m)
    p.rivets(m, y0 + 15.2)
    s1 = p.poly([(34.5, y0), (45.5, y0), (47, y0 + 1.5), (47, y0 + 13), (33, y0 + 13), (33, y0 + 1.5)])
    p.fill(s1, np.clip(np.asarray(LIGHT, np.float32) * p.facet(33, 47, 4)[..., None], 0, 255)); p.edges(s1)
    s2 = p.rect(35, y0 + 3, 45, y0 + 10.5, r=0.6)
    p.fill(s2, np.clip(np.asarray(WHITE, np.float32) * p.facet(35, 45, 3)[..., None], 0, 255)); p.edges(s2, 0.45)
    for y in (y0 + 4.6, y0 + 7): p.glow(p.rect(36.4, y, 43.6, y + 0.8))
    p.fill(p.rect(34.5, y0, 45.5, y0 + 0.8), RED)
    rcs(p, 29.4, y0 + 13.4); rcs(p, 50.6, y0 + 13.4)
    p.wear(m + s1, 10)
    return m + s1

def m_segment(p, y0, L=16, variant='plain', flank=('grille', 'light')):
    """Standard hull segment: 26 wide, L long. Variants share the plate; fittings bolt on."""
    m = deck(p, y0, y0 + L)
    p.seam(m, [(HX0, y0 + L / 2), (HX1, y0 + L / 2)], 0.35)
    for side, kind in zip((HX0 + 0.6, HX1 - 3.6), flank):
        if kind == 'grille': grille(p, side, y0 + 2.5, min(7, L - 5))
        elif kind == 'light': lightstrip(p, side + (1.8 if side > CX else 0), y0 + 4, 3.6)
    if variant == 'turret': turret(p, CX, y0 + L / 2 + 0.5)
    elif variant == 'hatch': hatch(p, CX, y0 + L / 2)
    elif variant == 'cargo':
        for x in (33.5, 40.5):
            c = p.rect(x, y0 + 2.5, x + 6, y0 + L - 2.5, r=0.4); p.fill(c, (178, 184, 196)); p.edges(c, 0.4)
            p.fill(p.rect(x + 2.4, y0 + L / 2 - 0.4, x + 3.6, y0 + L / 2 + 0.4), (60, 66, 80))
    p.wear(m, 14)
    return m

def m_aft_engine(p, y0, L=12, nozzles=4):
    """Aft block: red maker band, emblem, standard N1 nozzles."""
    m = deck(p, y0, y0 + L)
    p.fill(m * p.rect(HX0, y0 + 4.4, HX1, y0 + 6.6), RED)
    emblem(p, 35.6, y0 + 9)
    p.fill(p.rect(42, y0 + 8, 49, y0 + 9), (40, 44, 54), 0.7, solid=False)
    p.fill(p.rect(42, y0 + 9.6, 47, y0 + 10.3), (40, 44, 54), 0.7, solid=False)
    rcs(p, 29.4, y0 + 2.2); rcs(p, 50.6, y0 + 2.2)
    span = HX1 - HX0 - 5.2
    for i in range(nozzles): nozzle(p, HX0 + 2.6 + span * (i + 0.5) / nozzles, y0 + L)
    p.wear(m, 10)
    return m

# ---------------- reduce to 1:1 ----------------
def reduce(p, colors=64):
    W, H = int(round(p.uw * K)), int(round(p.uh * K))
    pre = p.rgb * p.a[..., None]
    def down(arr): return np.asarray(Image.fromarray(np.clip(np.nan_to_num(arr), 0, 255).astype(np.uint8)).resize((W, H), Image.BOX), np.float32)
    rgb = np.stack([down(pre[..., i]) for i in range(3)], -1); al = down(p.a * 255)
    rgb = rgb / np.maximum(al[..., None] / 255, 1e-3); alpha = (al > 110).astype(np.uint8) * 255
    img = Image.fromarray(np.clip(rgb, 0, 255).astype(np.uint8)).filter(ImageFilter.UnsharpMask(radius=1, percent=80, threshold=2))
    q = np.asarray(img.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert('RGB'), np.float32)
    solid = alpha > 0
    edge = solid & ~(np.roll(solid, 1, 0) & np.roll(solid, -1, 0) & np.roll(solid, 1, 1) & np.roll(solid, -1, 1))
    q[edge] *= 0.6
    return Image.fromarray(np.dstack([q.astype(np.uint8), alpha]), 'RGBA')

def hires(p, scale=5):
    im = Image.fromarray(np.dstack([np.clip(np.nan_to_num(p.rgb), 0, 255).astype(np.uint8), (p.a * 255).astype(np.uint8)]), 'RGBA')
    return im.resize((p.uw * scale, p.uh * scale), Image.LANCZOS)

def build_shuttle(p):
    m_bow_bridge(p, 6); collar(p, 22)
    m_segment(p, 23.2, 16, 'turret', ('grille', 'light')); collar(p, 39.2)
    m_segment(p, 40.4, 16, 'hatch', ('light', 'grille')); collar(p, 56.4)
    m_aft_engine(p, 57.6, 12, 4)

if __name__ == '__main__':
    OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
    p = Paint(80, 80); build_shuttle(p)
    reduce(p).save(f'{OUT}/shuttle.png'); hires(p).save(f'{OUT}/shuttle_paint.png')
    # each module on its own, for the parts strip
    parts = {
        'bow_bridge': (lambda q: m_bow_bridge(q, 6), 24),
        'seg_turret': (lambda q: m_segment(q, 6, 16, 'turret'), 24),
        'seg_hatch': (lambda q: m_segment(q, 2, 16, 'hatch', ('light', 'grille')), 20),
        'seg_cargo': (lambda q: m_segment(q, 2, 16, 'cargo', ('grille', 'grille')), 20),
        'aft_engine': (lambda q: m_aft_engine(q, 2, 12, 4), 20),
        'collar': (lambda q: collar(q, 2), 6),
    }
    for name, (fn, h) in parts.items():
        q = Paint(80, h); fn(q); im = reduce(q); im.crop(im.getbbox()).save(f'{OUT}/part_{name}.png')
    print('ok')
