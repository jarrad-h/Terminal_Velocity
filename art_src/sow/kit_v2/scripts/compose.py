"""SOW hull composer: kitbash hulls from the cut parts library.

Units = base-sheet pixels. Nose up, centre line x = 0. In game, 1 game px ~ 14.6 units
(the S-A shuttle reference is ~1750 units tall = 120 px).
"""
import json, os, numpy as np
from PIL import Image
from scipy import ndimage as ndi

PARTS = os.path.join(os.path.dirname(__file__), '..', 'kit', 'parts')
UNITS_PER_GAME_PX = 12.5   # calibrated: shuttle ref cap (451 px) = base_00 cap (320 u); shuttle 1504 u = 120 px
CYAN = np.array([0x5a, 0xe0, 0xff], np.float32) / 255
_cache = {}

def load(pid):
    if pid not in _cache:
        _cache[pid] = np.array(Image.open(f'{PARTS}/{pid}.png')).astype(np.float32) / 255
    return _cache[pid]

class Hull:
    def __init__(self, name, W=2400, H=4000):
        self.name = name
        self.c = np.zeros((H, W, 3), np.float32)
        self.a = np.zeros((H, W), np.float32)
        self.e = np.zeros((H, W, 3), np.float32)
        self.o = W // 2   # x origin (centre line)
        self.oy = 400     # y origin (nose region)
        self.dy = 0       # shift applied to every placement (lets the nose grow without re-numbering recipes)

    def place(self, pid, x, y, w=None, h=None, rot=0, flip=False, shadow=0.55, glow=None, tint=None, scale=None, flip_y=False):
        """Place part centred at (x, y). w/h = target size in units (keeps aspect if only one given).
        rot in degrees counter-clockwise (multiples of 90 stay crisp). glow='exit' lights the bottom band."""
        p = load(pid)
        im = Image.fromarray((p * 255).astype(np.uint8), 'RGBA')
        if flip: im = im.transpose(Image.FLIP_LEFT_RIGHT)
        if flip_y: im = im.transpose(Image.FLIP_TOP_BOTTOM)
        if scale:   # designer-tool order: scale native -> rotate about centre
            im = im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)
        if rot % 360:
            im = im.rotate(rot, Image.BICUBIC, expand=True)
        W0, H0 = im.size
        if scale: size = (W0, H0)
        elif w and h: size = (int(w), int(h))
        elif w: size = (int(w), int(round(H0 * w / W0)))
        elif h: size = (int(round(W0 * h / H0)), int(h))
        else: size = (W0, H0)
        im = im.resize(size, Image.LANCZOS)
        q = np.array(im).astype(np.float32) / 255
        rgb, al = q[..., :3], q[..., 3]
        if tint is not None:
            rgb = rgb * np.array(tint, np.float32)
        x0 = int(round(self.o + x - size[0] / 2)); y0 = int(round(self.oy + y + self.dy - size[1] / 2))
        sl = (slice(y0, y0 + size[1]), slice(x0, x0 + size[0]))
        # contact shadow on what's underneath (non-directional)
        if shadow:
            pad = 30
            big = np.zeros((size[1] + 2 * pad, size[0] + 2 * pad), np.float32)
            big[pad:-pad, pad:-pad] = al
            sh = np.clip(ndi.gaussian_filter(big, 9) * 1.6, 0, 1)
            ssl = (slice(y0 - pad, y0 + size[1] + pad), slice(x0 - pad, x0 + size[0] + pad))
            under = self.a[ssl] > 0
            self.c[ssl] *= (1 - shadow * sh * under)[..., None]
        A = al[..., None]
        self.c[sl] = rgb * A + self.c[sl] * (1 - A)
        self.e[sl] *= (1 - A)
        self.a[sl] = al + self.a[sl] * (1 - al)
        # glass: cyan pixels in the art glow
        r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
        glass = (b > 0.75) & (g > 0.6) & (r < 0.55) & (al > 0.5)
        if glass.any():
            self.e[sl][glass] = np.maximum(self.e[sl][glass], CYAN * np.clip((b[glass] - 0.55) * 2.2, 0, 1)[:, None])
        if glow == 'exit':
            m = al > 0.5
            rows = np.where(m.any(1))[0]
            band = max(int((rows[-1] - rows[0]) * 0.10), 6)
            ex = np.zeros_like(m); ex[rows[-1] - band:rows[-1] + 1] = True
            ex &= ndi.binary_erosion(m, iterations=3)
            fall = np.linspace(0.25, 1.0, band + 1)
            prof = np.zeros(m.shape[0], np.float32); prof[rows[-1] - band:rows[-1] + 1] = fall
            e = (ex * prof[:, None])[..., None] * CYAN
            self.e[sl] = np.maximum(self.e[sl], e)
            self.c[sl] = np.where(ex[..., None], self.c[sl] * 0.4 + CYAN * 0.6 * prof[:, None, None] + 0.1, self.c[sl])
        return self

    def pair(self, pid, dx, y, pid_right=None, **k):
        """Mirrored pair at x = -dx (as drawn) and +dx (flipped, or pid_right as drawn)."""
        self.place(pid, -dx, y, **k)
        if pid_right: self.place(pid_right, dx, y, **k)
        else: self.place(pid, dx, y, flip=not k.pop('flip', False), **k)
        return self

    def finish(self, outdir, margin=24):
        A = self.a > 0.02
        ys, xs = np.where(A)
        cx = self.o
        half = max(cx - xs.min(), xs.max() - cx) + margin  # keep centre line centred
        y0, y1 = ys.min() - margin, ys.max() + margin
        sl = (slice(y0, y1), slice(cx - half, cx + half))
        c, a, e = self.c[sl], self.a[sl], self.e[sl]
        os.makedirs(outdir, exist_ok=True)
        out = {}
        for tag, scale in [('master', 0.5), ('x3', 3 / UNITS_PER_GAME_PX), ('game', 1 / UNITS_PER_GAME_PX)]:
            Wt, Ht = max(1, round(c.shape[1] * scale)), max(1, round(c.shape[0] * scale))
            rgba = np.dstack([c * a[..., None], a])
            img = Image.fromarray((np.clip(rgba, 0, 1) * 255).astype(np.uint8), 'RGBA').resize((Wt, Ht), Image.LANCZOS)
            arr = np.array(img).astype(np.float32)
            al = arr[..., 3:4] / 255
            arr[..., :3] = np.where(al > 0, arr[..., :3] / np.maximum(al, 1e-6), 0)
            Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8), 'RGBA').save(f'{outdir}/{self.name}_{tag}.png')
            eim = Image.fromarray((np.clip(e, 0, 1) * 255).astype(np.uint8)).resize((Wt, Ht), Image.LANCZOS)
            eim.save(f'{outdir}/{self.name}_{tag}_glow.png')
            out[tag] = (Wt, Ht)
        return out


def render_design(path, outdir):
    """Render a design JSON from the ship designer tool (see DESIGN_FORMAT in the tool prompt)."""
    d = json.load(open(path))
    h = Hull(d['name'], W=d.get('canvas', [2400, 4000])[0], H=d.get('canvas', [2400, 4000])[1])
    h.oy = d.get('canvas', [2400, 4000])[1] // 2
    for p in sorted(d['parts'], key=lambda q: q.get('z', 0)):
        h.place(p['part'], p['x'], p['y'], rot=p.get('rot', 0), scale=p.get('scale', 1.0),
                flip=p.get('flipX', False), flip_y=p.get('flipY', False),
                shadow=p.get('shadow', 0.55), glow=p.get('glow'))
    return h.finish(outdir)
