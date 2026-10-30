"""Planets and the star: procedural spheres painted straight into albedo, normal and emission maps.

Planets are drawn on a 1024 px canvas with the disc 900 px across (room round it for the atmosphere);
the game scales each planet to its data radius: sprite_scale = radius * 2 / 900. Surfaces carry no baked
light: the normal map is the sphere (plus surface relief), so the lit side always faces the system's star.
Layers, all pixel-aligned with the planet canvas (except rings, which have their own larger canvas):
  <name>_albedo / _n / _e      the surface (emission = city lights or lava)
  <name>_clouds / _clouds_n    clouds, lit like the surface; the game can turn this layer slowly
  <name>_atmo / _atmo_n        the atmosphere rim, drawn additive and lit
  <name>_rings / _rings_n      gas giant rings, drawn under the planet
  <name>.png                   baked fallback (everything composited, light from the top-left)
The star is emission only, greyscale so the game tints it with the star's data colour."""
import math
import numpy as np
from PIL import Image, ImageFilter

# ---------------- 3D value noise (seamless on a sphere) ----------------
_TAB = np.random.default_rng(1234).random(1 << 16).astype(np.float32)

def _hash(ix, iy, iz, seed):
    h = (ix * 73856093) ^ (iy * 19349663) ^ (iz * 83492791) ^ (seed * 2654435761)
    return _TAB[h & 0xFFFF]

def vnoise(x, y, z, seed=0):
    ix, iy, iz = np.floor(x).astype(np.int64), np.floor(y).astype(np.int64), np.floor(z).astype(np.int64)
    fx, fy, fz = x - ix, y - iy, z - iz
    fx, fy, fz = fx * fx * (3 - 2 * fx), fy * fy * (3 - 2 * fy), fz * fz * (3 - 2 * fz)
    out = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                w = (fx if dx else 1 - fx) * (fy if dy else 1 - fy) * (fz if dz else 1 - fz)
                out = out + w * _hash(ix + dx, iy + dy, iz + dz, seed)
    return out

def fbm(P, freq, octaves=6, seed=0, gain=0.5, ridged=False):
    x, y, z = P
    tot, amp, norm = 0, 1.0, 0
    for o in range(octaves):
        n = vnoise(x * freq + 31.7 * o, y * freq - 17.3 * o, z * freq + 5.1 * o, seed + o)
        if ridged: n = 1 - np.abs(n * 2 - 1)
        tot = tot + n * amp; norm += amp; amp *= gain; freq *= 2
    return tot / norm

def smooth(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1); return t * t * (3 - 2 * t)

def lerp(c0, c1, t):
    c0, c1 = np.asarray(c0, np.float32), np.asarray(c1, np.float32)
    return c0 + (c1 - c0) * np.asarray(t, np.float32)[..., None]

def rotm(a, b, c):
    a, b, c = math.radians(a), math.radians(b), math.radians(c)
    Rx = np.array([[1, 0, 0], [0, math.cos(a), -math.sin(a)], [0, math.sin(a), math.cos(a)]])
    Ry = np.array([[math.cos(b), 0, math.sin(b)], [0, 1, 0], [-math.sin(b), 0, math.cos(b)]])
    Rz = np.array([[math.cos(c), -math.sin(c), 0], [math.sin(c), math.cos(c), 0], [0, 0, 1]])
    return Rz @ Ry @ Rx

# ---------------- sphere setup ----------------
CANVAS, DISC = 1024, 900
SS = 2

class Sphere:
    def __init__(self, canvas=CANVAS, disc=DISC, ss=SS, tilt=(18, 30, 12)):
        N = canvas * ss; self.N, self.canvas, self.ss = N, canvas, ss
        c = (np.arange(N) + 0.5 - N / 2) / (disc * ss / 2)
        self.u, self.v = np.meshgrid(c, c)                 # u right, v down, 1 = disc edge
        self.r = np.hypot(self.u, self.v)
        self.inside = self.r < 1
        self.z = np.sqrt(np.clip(1 - self.r ** 2, 0, 1))
        P = np.stack([self.u, -self.v, self.z]).reshape(3, -1)
        self.P = (rotm(*tilt) @ P).reshape(3, N, N)       # texture space: tilted so poles aren't straight up
        self.lat = np.arcsin(np.clip(self.P[1], -1, 1))   # -pi/2..pi/2 along the tilted axis

def craters(S, n, seed, rmin=0.03, rmax=0.18, depth=1.0):
    rng = np.random.default_rng(seed); h = np.zeros(S.u.shape, np.float32)
    for _ in range(n):
        d = rng.normal(size=3); d /= np.linalg.norm(d); cr = rng.uniform(rmin, rmax) ** 1.0
        ang = np.arccos(np.clip(S.P[0] * d[0] + S.P[1] * d[1] + S.P[2] * d[2], -1, 1)) / cr
        h += np.where(ang < 1, -(1 - ang ** 2) * cr * depth, np.where(ang < 1.3, (1.3 - ang) * cr * depth * 0.8, 0))
    return h

# ---------------- planet types ----------------
OCEAN_D, OCEAN_S = (18, 42, 82), (40, 96, 140)

def terran(S, seed):
    h = fbm(S.P, 2.2, 7, seed); m = fbm(S.P, 3.0, 5, seed + 50)
    land = smooth(0.50, 0.53, h)
    ocean = lerp(OCEAN_D, OCEAN_S, smooth(0.38, 0.5, h))
    green = lerp((62, 96, 46), (120, 120, 70), smooth(0.4, 0.62, m))
    hi = smooth(0.62, 0.72, h); grey = lerp(green, (130, 122, 112), hi)
    col = lerp(ocean, grey, land)
    ice = smooth(1.12, 1.30, np.abs(S.lat) + (h - 0.5) * 0.6); col = lerp(col, (232, 236, 242), ice)
    cities = (land * (1 - ice) * smooth(0.63, 0.72, fbm(S.P, 14, 3, seed + 9)) * smooth(0.45, 0.6, m))
    return dict(albedo=col, height=(h - 0.5) * land * 0.06, emission=np.asarray((255, 196, 120), np.float32) * cities[..., None] * 0.55,
                clouds=0.55, cloud_freq=2.6, atmo=(110, 170, 255), atmo_k=1.0)

def ocean_world(S, seed):
    h = fbm(S.P, 2.6, 7, seed)
    land = smooth(0.62, 0.64, h)
    col = lerp(lerp(OCEAN_D, (30, 90, 130), smooth(0.4, 0.6, h)), (176, 164, 120), land)
    col = lerp(col, (88, 120, 70), land * smooth(0.65, 0.7, h))
    ice = smooth(1.25, 1.4, np.abs(S.lat)); col = lerp(col, (225, 232, 240), ice)
    cities = land * smooth(0.66, 0.7, fbm(S.P, 16, 3, seed + 9))
    return dict(albedo=col, height=(h - 0.6) * land * 0.04, emission=np.asarray((255, 210, 150), np.float32) * cities[..., None] * 0.5,
                clouds=0.62, cloud_freq=3.0, atmo=(120, 200, 255), atmo_k=1.15)

def desert(S, seed):
    h = fbm(S.P, 2.0, 6, seed); dunes = fbm(S.P * np.asarray([1, 2.2, 1])[:, None, None], 6, 4, seed + 3, ridged=True)
    col = lerp((196, 150, 92), (222, 186, 124), smooth(0.35, 0.75, dunes))
    col = lerp(col, (120, 82, 54), smooth(0.58, 0.68, h))
    col = lerp(col, (236, 226, 210), smooth(1.35, 1.45, np.abs(S.lat)))
    return dict(albedo=col, height=(h - 0.5) * 0.05 + (dunes - 0.5) * 0.012, emission=None,
                clouds=0.15, cloud_freq=4.0, atmo=(240, 190, 130), atmo_k=0.6)

def ice_world(S, seed):
    h = fbm(S.P, 2.4, 6, seed); cr = fbm(S.P, 7, 5, seed + 4, ridged=True)
    col = lerp((176, 196, 214), (236, 242, 248), smooth(0.35, 0.7, h))
    col = lerp(col, (120, 152, 184), smooth(0.88, 0.96, cr) * 0.55)
    return dict(albedo=col, height=(h - 0.5) * 0.04 - smooth(0.86, 0.95, cr) * 0.01, emission=None,
                clouds=0.2, cloud_freq=3.0, atmo=(200, 225, 255), atmo_k=0.5)

def volcanic(S, seed):
    h = fbm(S.P, 2.5, 7, seed); lava = smooth(0.80, 0.9, fbm(S.P, 4.5, 6, seed + 2, ridged=True)) * smooth(0.5, 0.42, h)
    col = lerp((34, 30, 30), (78, 66, 60), smooth(0.4, 0.7, h))
    col = lerp(col, (90, 38, 20), lava)
    em = lerp((255, 90, 20), (255, 200, 90), smooth(0.9, 1.0, lava)) * lava[..., None]
    return dict(albedo=col, height=(h - 0.5) * 0.07 + craters(S, 10, seed + 1, 0.03, 0.08, 0.3), emission=em,
                clouds=0.35, cloud_freq=3.4, cloud_col=(70, 62, 60), atmo=(255, 120, 60), atmo_k=0.8)

def barren(S, seed):
    h = fbm(S.P, 3.0, 7, seed)
    c = craters(S, 70, seed + 1, 0.02, 0.16, 0.6)
    col = lerp((92, 90, 88), (164, 160, 154), smooth(0.3, 0.75, h + c * 2))
    col = lerp(col, (70, 68, 66), smooth(0.55, 0.62, fbm(S.P, 1.5, 3, seed + 7)) * 0.5)
    return dict(albedo=col, height=(h - 0.5) * 0.04 + c * 0.35, emission=None, clouds=0, atmo=None)

def rust(S, seed):
    h = fbm(S.P, 2.3, 7, seed)
    col = lerp((104, 52, 34), (176, 104, 58), smooth(0.35, 0.7, h))
    col = lerp(col, (60, 40, 34), smooth(0.62, 0.7, h))
    cities = smooth(0.66, 0.74, fbm(S.P, 15, 3, seed + 9)) * smooth(0.45, 0.55, h)
    return dict(albedo=col, height=(h - 0.5) * 0.06, emission=np.asarray((255, 150, 80), np.float32) * cities[..., None] * 0.5,
                clouds=0.5, cloud_freq=2.8, cloud_col=(206, 196, 120), atmo=(210, 200, 110), atmo_k=0.9)

def gas_giant(S, seed):
    warp = fbm(S.P, 2.0, 5, seed) - 0.5
    lat = S.lat + warp * 0.12 + (fbm(S.P, 9, 5, seed + 2) - 0.5) * 0.05
    bands = np.sin(lat * 9.0) * 0.5 + 0.5; fine = np.sin(lat * 31 + warp * 6) * 0.5 + 0.5
    col = lerp((196, 160, 118), (232, 214, 182), bands)
    col = lerp(col, (160, 112, 78), smooth(0.65, 0.95, fine) * 0.45)
    # storm: an oval spot
    d = np.asarray([0.55, -0.25, 0.8]); d /= np.linalg.norm(d)
    dx = S.P[0] - d[0]; dy = S.P[1] - d[1]; dz = S.P[2] - d[2]
    sp = np.sqrt((dx ** 2 + dz ** 2) / 0.018 + dy ** 2 / 0.006)
    col = lerp(col, (176, 84, 56), smooth(1.0, 0.6, sp))
    col = lerp(col, (220, 150, 110), smooth(0.5, 0.2, sp))
    return dict(albedo=col, height=(bands - 0.5) * 0.004, emission=None, clouds=0, atmo=(240, 210, 170), atmo_k=0.7,
                rings=dict(inner=1.28, outer=2.05, col=(206, 184, 150)))

PLANETS = {
    'planet_terran': (terran, 3, 'Terran'),
    'planet_ocean': (ocean_world, 8, 'Ocean'),
    'planet_desert': (desert, 13, 'Desert'),
    'planet_ice': (ice_world, 21, 'Ice'),
    'planet_volcanic': (volcanic, 34, 'Volcanic'),
    'planet_barren': (barren, 55, 'Barren moon'),
    'planet_rust': (rust, 89, 'Rust (toxic)'),
    'planet_gas_giant': (gas_giant, 144, 'Gas giant'),
}

# ---------------- map building ----------------
_LB = np.array([-0.55, 0.55, 0.63]); _LB /= np.linalg.norm(_LB)

def _down(a, ss):
    if a.ndim == 2:
        return np.asarray(Image.fromarray(a.astype(np.float32), 'F').resize((a.shape[1] // ss, a.shape[0] // ss), Image.BOX), np.float32)
    return np.stack([_down(a[..., i], ss) for i in range(a.shape[-1])], -1)

def _rgba(rgb, a):
    return Image.fromarray(np.dstack([np.clip(rgb, 0, 255).astype(np.uint8), np.clip(a * 255, 0, 255).astype(np.uint8)]), 'RGBA')

def _nimg(n, a):
    n = n / np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-4)
    n[a <= 0] = (0, 0, 1)
    return _rgba((n * 0.5 + 0.5) * 255, (a > 0).astype(np.float32) if a.max() <= 1 else a)

def _bump(S, n, h, k):
    gy, gx = np.gradient(h * S.N / 2)
    n = n.copy(); n[..., 0] -= gx * k; n[..., 1] += gy * k
    return n

def planet(name, seed=None):
    fn, sd, _ = PLANETS[name]; seed = sd if seed is None else seed
    S = Sphere(tilt=(18 + seed % 20, 30 + seed % 50, 8 + seed % 15))
    spec = fn(S, seed)
    ss, inside = S.ss, S.inside.astype(np.float32)
    nrm = np.stack([S.u, -S.v, S.z], -1).astype(np.float32)
    n_surf = _bump(S, nrm, spec["height"], 2.5)
    out = {}
    a = _down(inside, ss)
    alb = _down(spec['albedo'] * inside[..., None], ss) / np.maximum(a[..., None], 1e-3)
    nn = _down(n_surf * inside[..., None], ss)
    out['albedo'] = _rgba(alb, (a > 0.5)); out['n'] = _nimg(nn, (a > 0.5).astype(np.float32))
    em = spec.get('emission')
    out['e'] = _rgba(_down(em * inside[..., None], ss), (a > 0.5)) if em is not None else None
    # clouds
    cl = spec.get('clouds', 0)
    if cl:
        P = S.P
        c = fbm(P + np.asarray([3.1, 0, 0])[:, None, None], spec['cloud_freq'], 6, seed + 77)
        streak = fbm(P * np.asarray([1, 4, 1])[:, None, None], spec['cloud_freq'] * 1.2, 4, seed + 78)
        dens = smooth(1 - cl, 1 - cl + 0.25, c * 0.7 + streak * 0.3) * inside
        cn = _bump(S, nrm, dens * 0.02, 0.9)
        ca = _down(dens, ss)
        out['clouds'] = _rgba(np.broadcast_to(np.asarray(spec.get('cloud_col', (240, 244, 248)), np.float32), ca.shape + (3,)), ca * 0.92)
        out['clouds_n'] = _nimg(_down(cn * inside[..., None], ss), (ca > 0.02).astype(np.float32))
    # atmosphere rim: thin inside the limb, fading out beyond it
    if spec.get('atmo'):
        r = S.r; k = spec.get('atmo_k', 1)
        dens = np.where(r < 1, smooth(0.82, 1.0, r) * 0.55, np.exp(-((r - 1) / 0.035)) * 0.9) * k
        dens *= (r < 1.12)
        ux, uy = S.u / np.maximum(r, 1e-4), -S.v / np.maximum(r, 1e-4)
        an = np.stack([ux * 0.75, uy * 0.75, np.full_like(ux, 0.66)], -1)
        da = np.clip(_down(dens, ss), 0, 1)
        out['atmo'] = _rgba(np.broadcast_to(np.asarray(spec['atmo'], np.float32), da.shape + (3,)), da)
        out['atmo_n'] = _nimg(_down(an, ss), (da > 0.01).astype(np.float32))
    if spec.get('rings'):
        out['rings'], out['rings_n'] = rings(spec['rings'], seed)
    out['sprite'] = baked(out)
    out['meta'] = dict(id=name, kind='planet', size_px=[CANVAS, CANVAS], disc_px=DISC,
                       sprite_scale='radius * 2 / disc_px', layers=[k for k in ('albedo', 'n', 'e', 'clouds', 'clouds_n', 'atmo', 'atmo_n', 'rings', 'rings_n') if out.get(k) is not None])
    if out.get('rings') is not None: out['meta']['rings_px'] = list(out['rings'].size)
    return out

RINGS_CANVAS = 1900

def rings(spec, seed):
    N = RINGS_CANVAS * SS
    c = (np.arange(N) + 0.5 - N / 2) / (DISC * SS / 2)
    u, v = np.meshgrid(c, c); r = np.hypot(u, v)
    t = (r - spec['inner']) / (spec['outer'] - spec['inner'])
    rng = np.random.default_rng(seed)
    dens = np.zeros_like(r)
    for _ in range(26):
        c0, w, k = rng.uniform(0, 1), rng.uniform(0.01, 0.08), rng.uniform(0.3, 1)
        dens += k * np.exp(-((t - c0) / w) ** 2)
    dens = np.clip(0.25 + dens / 3.0, 0, 1) * smooth(0, 0.04, t) * smooth(1, 0.94, t)
    dens *= 1 - 0.85 * np.exp(-((t - 0.62) / 0.018) ** 2)            # a Cassini-style gap
    tone = 0.85 + 0.3 * (fbm(np.stack([t * 40, np.zeros_like(t), np.zeros_like(t) + seed]), 1.0, 4, seed) - 0.5)
    col = np.asarray(spec['col'], np.float32) * tone[..., None]
    a = _down(dens, SS); rgb = _down(col * dens[..., None], SS) / np.maximum(a[..., None], 1e-3)
    img = _rgba(rgb, a * 0.9)
    n = np.zeros(a.shape + (3,), np.float32); n[..., 2] = 1
    return img, _nimg(n, (a > 0.01).astype(np.float32))

def _lam(nimg, alpha_img=None):
    n = np.asarray(nimg, np.float32)[..., :3] / 255 * 2 - 1
    return 0.14 + 0.95 * np.clip((n * _LB).sum(-1), 0, 1)

def baked(o):
    """Fallback sprite: layers composited with the light baked from the top-left."""
    alb = np.asarray(o['albedo'], np.float32); a = alb[..., 3:] / 255
    rgb = alb[..., :3] * _lam(o['n'])[..., None]
    if o.get('e') is not None: rgb += np.asarray(o['e'], np.float32)[..., :3] * 0.6
    if o.get('clouds') is not None:
        c = np.asarray(o['clouds'], np.float32); ca = c[..., 3:] / 255
        rgb = rgb * (1 - ca) + c[..., :3] * _lam(o['clouds_n'])[..., None] * ca
    rgb = rgb * a                                          # premultiplied from here
    out_a = a[..., 0]
    if o.get('atmo') is not None:
        at = np.asarray(o['atmo'], np.float32); aa = at[..., 3:] / 255
        rgb = rgb + at[..., :3] * aa * _lam(o['atmo_n'])[..., None] * 0.8
        out_a = np.maximum(out_a, aa[..., 0])
    rgb = rgb / np.maximum(out_a[..., None], 1e-3)
    return _rgba(rgb, out_a)

# ---------------- the star ----------------
STAR_CANVAS, STAR_DISC = 1024, 460

def star(seed=5):
    S = Sphere(STAR_CANVAS, STAR_DISC, SS, tilt=(10, 20, 0))
    r = S.r; inside = S.inside
    gran = fbm(S.P, 28, 4, seed); cells = fbm(S.P, 7, 4, seed + 1)
    limb = 0.62 + 0.38 * S.z ** 0.6
    disc = (0.86 + 0.14 * gran) * limb * (1 - 0.25 * smooth(0.7, 0.85, cells) * 0.4)
    disc = np.where(inside, disc, 0)
    ang = np.arctan2(S.v, S.u)
    streams = fbm(np.stack([np.cos(ang) * 3, np.sin(ang) * 3, np.zeros_like(ang)]), 1.6, 5, seed + 3)
    out_r = np.maximum(r - 1, 0)
    corona = np.exp(-out_r / (0.10 + 0.22 * streams ** 2)) * 0.85 + np.exp(-out_r / 0.03) * 0.5
    corona = np.where(inside, 0, corona) * smooth(1.17, 1.0, r / (STAR_CANVAS / STAR_DISC))
    lum = np.clip(disc + corona, 0, 1.2)
    lum = _down(lum, SS)
    v = np.clip(lum, 0, 1)
    rgb = np.stack([v, v, v], -1) * 255
    img = _rgba(rgb, np.clip(v * 1.6, 0, 1))
    meta = dict(id='star', kind='star', size_px=[STAR_CANVAS, STAR_CANVAS], disc_px=STAR_DISC, sprite_scale='radius * 2 / disc_px',
                note='emission only, greyscale: modulate by the star colour and draw additive')
    return {'e': img, 'meta': meta}

# ---------------- lit preview (same light model as skit.lit) ----------------
def _l(a): return np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
def _s(a):
    a = np.clip(a, 0, 1); return np.where(a <= 0.0031308, a * 12.92, 1.055 * a ** (1 / 2.4) - 0.055)

def lit(o, star_az=90, star_el=18, bg=(10, 8, 7), energy=2.2):
    az, el = math.radians(star_az), math.radians(star_el)
    L = np.array([math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)])
    col = np.array([1.0, 0.62, 0.28]) * energy; amb = np.array([0.6, 0.7, 1.0]) * 0.12
    def light(nimg):
        n = np.asarray(nimg, np.float32)[..., :3] / 255 * 2 - 1
        return amb + np.clip((n * L).sum(-1, keepdims=True), 0, 1) * col
    def rgba(img): x = np.asarray(img, np.float32) / 255; return _l(x[..., :3]), x[..., 3:]
    W, H = o['albedo'].size
    out = np.broadcast_to(_l(np.asarray(bg, np.float32) / 255), (H, W, 3)).copy()
    if o.get('rings') is not None:
        rg, ra = rgba(o['rings']); rl = light(o['rings_n'])
        R = o['rings'].size[0]; off = (R - W) // 2
        big = np.broadcast_to(_l(np.asarray(bg, np.float32) / 255), (R, R, 3)).copy()
        big = big * (1 - ra) + rg * rl * ra
        big[off:off + H, off:off + W] = _compose(out, o, light, rgba, big[off:off + H, off:off + W])
        return Image.fromarray((_s(big) * 255).astype(np.uint8), 'RGB')
    return Image.fromarray((_s(_compose(out, o, light, rgba, out)) * 255).astype(np.uint8), 'RGB')

def _compose(out, o, light, rgba, base):
    al, aa = rgba(o['albedo']); res = base * (1 - aa) + al * light(o['n']) * aa
    if o.get('e') is not None:
        e, _ = rgba(o['e']); res = res + e * aa * 1.3
    if o.get('clouds') is not None:
        c, ca = rgba(o['clouds']); res = res * (1 - ca) + c * light(o['clouds_n']) * ca
    if o.get('atmo') is not None:
        t, ta = rgba(o['atmo']); res = res + t * ta * light(o['atmo_n']) * 0.9
    return res
