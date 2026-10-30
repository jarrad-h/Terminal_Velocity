"""Light maps for the generated sprites: albedo, normal and emission, so the game can light ships live.

The painter already models light while it paints: `facet()` is a curved surface across a part's width,
`edges()` is a bevel, `lit()` marks hand-written shading, `glow()` is self-lit. Inside `active()` those
calls stop baking light into the colour and instead record:

  albedo  the colours with the baked shading removed (same reduction, palette and dark rim as the sprite)
  normal  which way each pixel faces, RGB = XYZ * 0.5 + 0.5, +X right, +Y up the image, +Z towards
          the viewer (OpenGL / Godot convention); flat surface = (128, 128, 255)
  emission what glows (glass, light strips, engine exits), black elsewhere

Outside `active()` nothing changes, so the baked sprites stay byte-identical.
"""
from contextlib import contextmanager
import numpy as np
from PIL import Image

import kit
from kit import Paint, K

FLAT = 0.86          # facet() profile averaged across a part, so the albedo keeps the sprite's overall value
FACET_TILT = 0.85    # how far the outermost facet leans
EDGE_TILT = 0.72     # how far a bevel pixel leans outward

_ORIG = {}

def _init(self, *a, **kw):
    _ORIG['__init__'](self, *a, **kw)
    h, w = self.a.shape
    self.nrm = np.zeros((h, w, 3), np.float32); self.nrm[..., 2] = 1
    self.em = np.zeros((h, w, 3), np.float32)
    self._pending = None

def _take_pending(self, m, k=1.0):
    """Write the pending surface direction under mask m. Fills with no pending direction keep the
    surface they are painted on (decals, bands, grilles)."""
    pend, self._pending = self._pending, None
    if pend is None:
        return
    nx, ny_down = pend
    nx = np.clip(np.broadcast_to(nx, m.shape), -0.97, 0.97)
    ny = np.zeros_like(nx) if ny_down is None else -np.clip(np.broadcast_to(ny_down, m.shape), -0.97, 0.97)
    nz = np.sqrt(np.clip(1 - nx ** 2 - ny ** 2, 0.02, 1))
    v = np.stack([nx, ny, nz], -1)
    sel = (m * k) > 0.5
    self.nrm[sel] = v[sel]

def _facet(self, x0, x1, facets=5):
    n = np.clip((self.X - (x0 + x1) / 2) / ((x1 - x0) / 2), -0.99, 0.99)
    nf = np.clip((np.floor((n + 1) / 2 * facets) + 0.5) / facets * 2 - 1, -0.99, 0.99)
    self._pending = (nf * FACET_TILT, None)
    return np.full_like(self.X, FLAT)

def _lit(self, f, nx, ny=None, flat=FLAT):
    self._pending = (nx, ny)
    return np.full_like(self.X, flat)

def _fill(self, m, col, alpha=1.0, solid=True):
    _ORIG['fill'](self, m, col, alpha, solid)
    k = (m * alpha)[..., None]
    self.em = self.em * (1 - k)                       # anything painted over a light covers it
    if solid:
        _take_pending(self, m, alpha)
    else:
        self._pending = None

def _shade(self, m, f):
    if self._pending is not None:
        _take_pending(self, m)                        # shading baked by shade(): keep the direction, skip the shade

def _edges(self, m, d=0.55, lit=1.22, dark=0.58):
    s = max(1, int(d * kit.SS))
    inside = m > 0.5
    out_l = np.roll(m, s, 1) < 0.5; out_r = np.roll(m, -s, 1) < 0.5
    out_t = np.roll(m, s, 0) < 0.5; out_b = np.roll(m, -s, 0) < 0.5
    sign = 1.0 if lit >= dark else -1.0               # an inverted bevel is a recess
    tx = (out_r.astype(np.float32) - out_l) * EDGE_TILT * sign
    ty = (out_t.astype(np.float32) - out_b) * EDGE_TILT * sign
    sel = inside & ((tx != 0) | (ty != 0))
    v = self.nrm + np.stack([tx, ty, np.zeros_like(tx)], -1)
    v /= np.maximum(np.linalg.norm(v, axis=-1, keepdims=True), 1e-4)
    self.nrm[sel] = v[sel]

def _glow(self, m, col=kit.CYAN):
    _ORIG['glow'](self, m, col)
    k = m[..., None]
    self.em = self.em * (1 - k) + np.asarray(col, np.float32) * k

_PATCH = {'__init__': _init, 'fill': _fill, 'shade': _shade, 'edges': _edges, 'facet': _facet, 'lit': _lit, 'glow': _glow}

@contextmanager
def active():
    """Paints created inside this block record light maps instead of baking light."""
    for name, fn in _PATCH.items():
        _ORIG[name] = getattr(Paint, name); setattr(Paint, name, fn)
    try:
        yield
    finally:
        for name in _PATCH:
            setattr(Paint, name, _ORIG[name])

def _down(p, arr):
    W, H = int(round(p.uw * K)), int(round(p.uh * K))
    return np.asarray(Image.fromarray(arr.astype(np.float32), 'F').resize((W, H), Image.BOX), np.float32)

def maps(p, bbox=None):
    """(albedo, normal, emission) RGBA images at 1:1 for a Paint made inside active(), cropped to bbox
    (pass the baked sprite's bbox so all four images line up pixel for pixel)."""
    alb = kit.reduce(p)
    alpha = np.asarray(alb)[..., 3]
    a = p.a
    ad = np.maximum(_down(p, a), 1e-3)[..., None]
    nrm = np.stack([_down(p, p.nrm[..., i] * a) for i in range(3)], -1) / ad
    nrm /= np.maximum(np.linalg.norm(nrm, axis=-1, keepdims=True), 1e-4)
    nrm[alpha == 0] = (0, 0, 1)
    em = np.stack([_down(p, p.em[..., i] * a) for i in range(3)], -1) / ad
    em[alpha == 0] = 0
    n_img = Image.fromarray(np.dstack([np.round((nrm * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8), alpha]), 'RGBA')
    e_img = Image.fromarray(np.dstack([em.clip(0, 255).astype(np.uint8), alpha]), 'RGBA')
    if bbox is None:
        bbox = alb.getbbox()
    return alb.crop(bbox), n_img.crop(bbox), e_img.crop(bbox)

def save(images, folder, name):
    alb, nrm, em = images
    alb.save(f'{folder}/{name}_albedo.png'); nrm.save(f'{folder}/{name}_n.png'); em.save(f'{folder}/{name}_e.png')
