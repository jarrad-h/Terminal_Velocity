"""Stellar kit: radial painting helpers on top of the SOW painter, plus light maps for stellars.

Stellars (gates, stations, planets, stars, scenery) reuse the SOW painter (`art_src/sow/kit.py`) and its
light-map recorder (`lightmaps.py`), so they share the SOW look: painted at high resolution, reduced to
1:1 with a 64-colour palette and a dark rim pixel. On top of that this module adds:

- radial shapes (rings, tori, domes, sectors) whose surface directions feed the normal map;
- a baked top-left shading factor for the unlit fallback sprite, from the same surface directions;
- a second emission channel, `ring`, so gates can switch their field off while beacons stay lit
  (`<name>_e.png` = always-on lights, `<name>_e_ring.png` = field and ring emitters);
- `field()`: emission with no hull under it (a gate's aperture), drawn only into `_e_ring`.

Stellar canvases are never cropped: the image centre is the stellar's centre, so `jump_point` and
other anchors are plain offsets from the middle of the sprite.
"""
import os, sys, math
import numpy as np
from PIL import Image, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'sow'))
import kit, lightmaps            # noqa: E402
from kit import Paint, CYAN, RED  # noqa: E402,F401

_L = np.array([-0.55, 0.55, 0.63]); _L /= np.linalg.norm(_L)   # baked light: top-left, +Y up the image

def units(px):
    """Canvas size in paint units for a sprite px wide at 1:1."""
    return int(round(px / kit.K))

def baked(nx, ny_down, nz=None):
    """Top-left shading factor for the baked sprite from a surface direction (nx across, ny down)."""
    nx = np.asarray(nx, np.float32); ny = -np.asarray(ny_down, np.float32)
    if nz is None: nz = np.sqrt(np.clip(1 - nx ** 2 - ny ** 2, 0.02, 1))
    return 0.62 + 0.55 * np.clip(nx * _L[0] + ny * _L[1] + nz * _L[2], 0, None)

def quant(t, facets):
    """Stepped profile across -1..1, the painted-pixel facet look."""
    if not facets: return t
    return np.clip((np.floor((np.clip(t, -0.999, 0.999) + 1) / 2 * facets) + 0.5) / facets * 2 - 1, -0.99, 0.99)

def polar(p, cx, cy):
    dx, dy = p.X - cx, p.Y - cy
    r = np.hypot(dx, dy); r1 = np.maximum(r, 1e-4)
    return r, dx / r1, dy / r1, np.arctan2(dy, dx)

def surf(p, m, col, nx=0.0, ny=0.0, edges=True):
    """Fill m with col, shaded as a surface facing (nx, ny-down). Feeds the normal map."""
    nx = np.broadcast_to(np.asarray(nx, np.float32), p.X.shape); ny = np.broadcast_to(np.asarray(ny, np.float32), p.X.shape)
    f = p.lit(baked(nx, ny), nx, ny)
    col = np.asarray(col, np.float32)
    if col.ndim == 1: col = np.broadcast_to(col, p.rgb.shape)
    p.fill(m, np.clip(col * np.asarray(f)[..., None], 0, 255))
    if edges: p.edges(m, 0.4)
    return m

def ann(p, cx, cy, r0, r1):
    return np.clip(p.ell(cx - r1, cy - r1, cx + r1, cy + r1) - (p.ell(cx - r0, cy - r0, cx + r0, cy + r0) if r0 > 0 else 0), 0, 1)

def sector(cx, cy, r0, r1, a0, a1, n=48):
    """Polygon for an annular sector (angles in degrees, 0 = +x, clockwise on screen)."""
    a = np.radians(np.linspace(a0, a1, n))
    outer = [(cx + r1 * math.cos(t), cy + r1 * math.sin(t)) for t in a]
    inner = [(cx + r0 * math.cos(t), cy + r0 * math.sin(t)) for t in a[::-1]]
    return outer + inner

def rot(pts, cx, cy, deg):
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return [(cx + (x - cx) * c - (y - cy) * s, cy + (x - cx) * s + (y - cy) * c) for x, y in pts]

def torus(p, m, cx, cy, R, w, col, facets=6, tilt=0.9, edges=True):
    """A ring of tube half-width w round radius R, inside mask m (pass ann() or a sector)."""
    r, ux, uy, _ = polar(p, cx, cy)
    t = quant((r - R) / w, facets) * tilt
    return surf(p, m, col, ux * t, uy * t, edges)

def dome(p, cx, cy, rad, col, facets=5, tilt=0.9, m=None):
    r, ux, uy, _ = polar(p, cx, cy)
    if m is None: m = p.ell(cx - rad, cy - rad, cx + rad, cy + rad)
    t = quant(np.clip(r / rad, 0, 1) * 2 - 1, facets) * 0.5 + 0.5
    return surf(p, m, col, ux * t * tilt, uy * t * tilt)

def cone(p, m, cx, cy, col, tilt=0.55, facets=0):
    """Surface sloping away from (cx, cy) in every direction (a raised boss or a beveled hub)."""
    _, ux, uy, _ = polar(p, cx, cy)
    return surf(p, m, col, ux * tilt, uy * tilt)

def glow_ring(p, m, col):
    """Emission that belongs to the gate's field and ring (switched off when the gate is closed)."""
    p.glow(m, col)
    if not hasattr(p, 'ringm'): p.ringm = np.zeros_like(p.a)
    p.ringm = np.maximum(p.ringm, m)

def field(p, m, col, k=1.0):
    """Light with no hull under it (a gate's aperture). Only in the light-map pass; never solid."""
    if not hasattr(p, 'em'): return
    if not hasattr(p, 'fld'): p.fld = np.zeros_like(p.rgb)
    p.fld = np.maximum(p.fld, np.asarray(col, np.float32) * (m * k)[..., None])

def lamp(p, x, y, r, col, ring=False, housing=(36, 38, 46)):
    p.fill(p.ell(x - r * 1.7, y - r * 1.7, x + r * 1.7, y + r * 1.7), housing)
    m = p.ell(x - r, y - r, x + r, y + r)
    if ring: glow_ring(p, m, col)
    else: p.glow(m, col)

def _down(p, arr):
    W, H = int(round(p.uw * kit.K)), int(round(p.uh * kit.K))
    return np.asarray(Image.fromarray(arr.astype(np.float32), 'F').resize((W, H), Image.BOX), np.float32)

def maps(p):
    """(albedo, normal, emission, ring emission) at 1:1, full canvas, for a Paint made inside lightmaps.active()."""
    alb, nrm, em = lightmaps.maps(p, (0, 0, int(round(p.uw * kit.K)), int(round(p.uh * kit.K))))
    alpha = np.asarray(alb)[..., 3]
    e = np.asarray(em, np.float32)[..., :3]
    ring = getattr(p, 'ringm', None)
    if ring is not None:
        frac = np.clip(_down(p, ring * p.a) / np.maximum(_down(p, p.a), 1e-3), 0, 1)[..., None]
    else:
        frac = np.zeros(e.shape[:2] + (1,), np.float32)
    e_ring = e * frac; e_beacon = e * (1 - frac)
    fa = np.zeros(alpha.shape, np.uint8)
    if hasattr(p, 'fld'):
        f = np.stack([_down(p, p.fld[..., i]) for i in range(3)], -1)
        e_ring = np.maximum(e_ring, f)
        fa = (f.max(-1) > 2).astype(np.uint8) * 255
    ra = np.maximum(alpha, fa)
    out_e = Image.fromarray(np.dstack([e_beacon.clip(0, 255).astype(np.uint8), alpha]), 'RGBA')
    out_r = Image.fromarray(np.dstack([e_ring.clip(0, 255).astype(np.uint8), ra]), 'RGBA')
    return alb, nrm, out_e, out_r

def render(fn, uw, uh, seed=7):
    """Paint fn twice (baked, then light maps). Returns dict of PIL images: sprite, albedo, n, e, e_ring."""
    p = Paint(uw, uh, seed); fn(p); sprite = kit.reduce(p)
    with lightmaps.active():
        q = Paint(uw, uh, seed); fn(q)
        alb, nrm, em, er = maps(q)
    return {'sprite': sprite, 'albedo': alb, 'n': nrm, 'e': em, 'e_ring': er, 'hps': getattr(p, 'hps', [])}

def save(imgs, folder, name):
    os.makedirs(folder, exist_ok=True)
    imgs['sprite'].save(f'{folder}/{name}.png')
    for k, suf in (('albedo', '_albedo'), ('n', '_n'), ('e', '_e'), ('e_ring', '_e_ring')):
        if imgs.get(k) is not None: imgs[k].save(f'{folder}/{name}{suf}.png')

# ---------------- lit preview (same maths as art_src/sow/preview_lit.py) ----------------
STAR_COL, STAR_EL, STAR_E = (1.0, 0.62, 0.28), 18, 2.2
AMBIENT = np.array([0.6, 0.7, 1.0]) * 0.12

def _lin(a): return np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
def _srgb(a):
    a = np.clip(a, 0, 1); return np.where(a <= 0.0031308, a * 12.92, 1.055 * a ** (1 / 2.4) - 0.055)

def lit(imgs, star_az=90, ring_on=True, bg=(10, 8, 7), glow_px=3):
    """Lit render: star from azimuth star_az (0 = screen top, 90 = screen right)."""
    al = np.asarray(imgs['albedo'], np.float32) / 255; a = al[..., 3:4]
    n = np.asarray(imgs['n'], np.float32)[..., :3] / 255 * 2 - 1
    az, el = math.radians(star_az), math.radians(STAR_EL)
    L = np.array([math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)])
    light = AMBIENT + np.clip((n * L).sum(-1, keepdims=True), 0, 1) * np.array(STAR_COL) * STAR_E
    e = _lin(np.asarray(imgs['e'], np.float32)[..., :3] / 255)
    if ring_on and imgs.get('e_ring') is not None:
        e = e + _lin(np.asarray(imgs['e_ring'], np.float32)[..., :3] / 255)
    rgb = _lin(al[..., :3]) * light * a + e * 1.3
    g = np.asarray(Image.fromarray((np.clip(e, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(glow_px)), np.float32) / 255
    rgb = rgb + g * 0.9
    bgc = _lin(np.asarray(bg, np.float32) / 255)
    out = rgb + bgc * (1 - np.clip(a + g.max(-1, keepdims=True), 0, 1))
    return Image.fromarray((_srgb(out) * 255).astype(np.uint8), 'RGB')
