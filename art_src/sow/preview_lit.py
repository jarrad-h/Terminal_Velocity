"""Preview the light maps outside Godot: every SOW hull lit by an amber star at screen right, at three headings.

Usage (from the repo root):  python art_src/sow/preview_lit.py
Writes docs/art/lighting/sow_lit.png. The maths is the same as Godot's 2D lights (Lambert N·L per light,
light height from its elevation) with emission added on top, so it is a reference for the in-game look,
not a replacement for checking in the engine.
"""
import os, math, json
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
SHIPS = os.path.join(ROOT, 'assets', 'sprites', 'ships', 'sow', 'ships')
OUT = os.path.join(ROOT, 'docs', 'art', 'lighting')

STAR_COL, STAR_AZ, STAR_EL, STAR_E = (1.0, 0.62, 0.28), 90, 18, 2.2   # from screen right, 18° up
AMBIENT = np.array([0.6, 0.7, 1.0]) * 0.12
ZOOM, HEADINGS = 2, (0, 135, 250)

def lin(a): return np.where(a <= 0.04045, a / 12.92, ((a + 0.055) / 1.055) ** 2.4)
def srgb(a):
    a = np.clip(a, 0, 1); return np.where(a <= 0.0031308, a * 12.92, 1.055 * a ** (1 / 2.4) - 0.055)

def _prep(path, heading, frame):
    im = Image.open(path).convert('RGBA')
    im = im.resize((im.width * ZOOM, im.height * ZOOM), Image.NEAREST).rotate(-heading, Image.NEAREST, expand=True)
    c = Image.new('RGBA', (frame, frame)); c.paste(im, ((frame - im.width) // 2, (frame - im.height) // 2))
    return np.asarray(c).astype(np.float32) / 255

def lit(name, heading, frame):
    base = os.path.join(SHIPS, name)
    al, nm, em = (_prep(f'{base}{s}.png', heading, frame) for s in ('_albedo', '_n', '_e'))
    a = al[..., 3:4]
    n = nm[..., :3] * 2 - 1
    t = math.radians(-heading)                                   # turn the normals with the sprite
    nx = n[..., 0] * math.cos(t) - n[..., 1] * math.sin(t); ny = n[..., 0] * math.sin(t) + n[..., 1] * math.cos(t)
    n = np.stack([nx, ny, n[..., 2]], -1); n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-4)
    az, el = math.radians(STAR_AZ), math.radians(STAR_EL)
    L = np.array([math.sin(az) * math.cos(el), math.cos(az) * math.cos(el), math.sin(el)])
    light = AMBIENT + np.clip((n * L).sum(-1, keepdims=True), 0, 1) * np.array(STAR_COL) * STAR_E
    e = lin(em[..., :3])
    rgb = (lin(al[..., :3]) * light + e * 1.4) * a
    glow = np.asarray(Image.fromarray((np.clip(e * a, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2 * ZOOM)),
                      np.float32) / 255 * 0.8
    rgb += glow; a = np.clip(np.maximum(a, glow.max(-1, keepdims=True) * 1.3), 0, 1)
    return Image.fromarray((np.concatenate([srgb(rgb / np.maximum(a, 1e-4)), a], -1) * 255).astype(np.uint8), 'RGBA')

def main():
    os.makedirs(OUT, exist_ok=True)
    names = sorted(f[:-11] for f in os.listdir(SHIPS) if f.endswith('_albedo.png'))
    sizes = [Image.open(os.path.join(SHIPS, f'{n}.png')).size for n in names]
    frames = [int(math.hypot(w, h) * ZOOM) + 8 for w, h in sizes]   # each row as tall as its own hull needs
    frame = max(frames)
    cols = len(HEADINGS) + 1
    sheet = Image.new('RGBA', (cols * frame, sum(f + 24 for f in frames) + 40), (10, 8, 7, 255))
    d = ImageDraw.Draw(sheet)
    try: f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 15)
    except OSError: f = ImageFont.load_default()
    d.text((12, 12), f'Star from screen right, {STAR_EL}° up · {ZOOM}× zoom · columns: baked sprite (no lights), then headings '
           + ', '.join(f'{h}°' for h in HEADINGS), font=f, fill=(201, 167, 122))
    y = 40
    for n, fr in zip(names, frames):
        d.text((12, y), n, font=f, fill=(243, 227, 204))
        baked = Image.open(os.path.join(SHIPS, f'{n}.png')).convert('RGBA')
        baked = baked.resize((baked.width * ZOOM, baked.height * ZOOM), Image.NEAREST)
        sheet.alpha_composite(baked, ((frame - baked.width) // 2, y + 24 + (fr - baked.height) // 2))
        for c, h in enumerate(HEADINGS):
            sheet.alpha_composite(lit(n, h, fr), ((c + 1) * frame + (frame - fr) // 2, y + 24))
        y += fr + 24
    sheet.convert('RGB').save(os.path.join(OUT, 'sow_lit.png'))
    print('docs/art/lighting/sow_lit.png', sheet.size)

if __name__ == '__main__':
    main()
