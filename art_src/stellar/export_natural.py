"""Export planets, the star, scenery (asteroids, debris, wrecks, buoys) and galaxy-map icons.

Usage (from the repo root):  python art_src/stellar/export_natural.py [planets|star|scenery|icons|all] [name ...]
Writes under assets/sprites/stellars/:
  planets/<planet>_{albedo,n,e,clouds,clouds_n,atmo,atmo_n,rings,rings_n}.png, <planet>.png (baked), <planet>.json
  stars/star_e.png, star.json
  scenery/<name>{,_albedo,_n,_e}.png
  icons/<name>.png (64 px, lit from the upper right)
and review sheets in docs/art/stellars/. Icons are made from the planet, star and station renders, so
export those first. Needs Python 3.10+ with numpy and Pillow."""
import os, sys, json, time
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
sys.dont_write_bytecode = True
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import skit, kit
import natural, scenery

REPO = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(REPO, 'assets', 'sprites', 'stellars')
DOCS = os.path.join(REPO, 'docs', 'art', 'stellars')
LAYERS = ('albedo', 'n', 'e', 'clouds', 'clouds_n', 'atmo', 'atmo_n', 'rings', 'rings_n')

def _font(sz): return ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', sz)

def load_planet(name):
    d = os.path.join(OUT, 'planets'); o = {}
    for k in LAYERS:
        p = os.path.join(d, f'{name}_{k}.png'); o[k] = Image.open(p) if os.path.exists(p) else None
    return o

def planets(names):
    d = os.path.join(OUT, 'planets'); os.makedirs(d, exist_ok=True); os.makedirs(DOCS, exist_ok=True)
    for name in names or natural.PLANETS:
        t = time.time(); o = natural.planet(name)
        o['meta']['name'] = natural.PLANETS[name][2]
        for k in LAYERS:
            if o.get(k) is not None: o[k].save(os.path.join(d, f'{name}_{k}.png'))
        o['sprite'].save(os.path.join(d, f'{name}.png'))
        json.dump(o['meta'], open(os.path.join(d, f'{name}.json'), 'w'), indent=1)
        print(f'{name}: {time.time() - t:.0f}s')
    sheet_planets()

def sheet_planets():
    names = list(natural.PLANETS); T = 420
    s = Image.new('RGB', (4 * T, 2 * (T + 30) * 2), (10, 8, 7)); dr = ImageDraw.Draw(s)
    for i, n in enumerate(names):
        o = load_planet(n)
        for j, az in enumerate((90, 220)):
            im = natural.lit(o, az).resize((T, T), Image.LANCZOS)
            x, y = (i % 4) * T, (i // 4) * (T + 30) + j * 2 * (T + 30)
            s.paste(im, (x, y + 26)); dr.text((x + 10, y + 4), f'{natural.PLANETS[n][2]} · star {"right" if az == 90 else "lower left"}', font=_font(15), fill=(201, 167, 122))
    s.save(os.path.join(DOCS, 'planets_lit.png'))
    for n in names: natural.lit(load_planet(n), 90).save(os.path.join(DOCS, f'{n}_lit.png'))

def star():
    d = os.path.join(OUT, 'stars'); os.makedirs(d, exist_ok=True)
    o = natural.star(); o['e'].save(os.path.join(d, 'star_e.png'))
    json.dump(o['meta'], open(os.path.join(d, 'star.json'), 'w'), indent=1)
    e = np.asarray(o['e'], np.float32)[..., :3] / 255; tiles = []
    for col in ('#ffffff', '#fff4d8', '#ffd090', '#ff7040', '#ff5050'):
        c = np.array([int(col[i:i + 2], 16) for i in (1, 3, 5)]) / 255
        lin = natural._l(e) * natural._l(c)
        glow = np.asarray(Image.fromarray((np.clip(lin, 0, 1) * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(14)), np.float32) / 255
        rgb = natural._s(np.clip(lin * 1.2 + glow * 0.6 + natural._l(np.array([10, 8, 7]) / 255), 0, 1))
        tiles.append(Image.fromarray((rgb * 255).astype(np.uint8)).resize((360, 360), Image.LANCZOS))
    s = Image.new('RGB', (360 * len(tiles), 360)); [s.paste(t, (i * 360, 0)) for i, t in enumerate(tiles)]
    s.save(os.path.join(DOCS, 'star_tints.png')); print('star')

def _square(imgs):
    bb = imgs['sprite'].getbbox(); w, h = bb[2] - bb[0], bb[3] - bb[1]; sz = max(w, h) + 2
    cx, cy = (bb[0] + bb[2]) // 2, (bb[1] + bb[3]) // 2
    box = (cx - sz // 2, cy - sz // 2, cx - sz // 2 + sz, cy - sz // 2 + sz)
    for k in ('sprite', 'albedo', 'n', 'e'): imgs[k] = imgs[k].crop(box)
    return imgs

SCENERY_PLAN = [('asteroid_large_rock', 180, 'rock', 4), ('asteroid_large_ice', 180, 'ice', 3), ('asteroid_large_metal', 180, 'metal', 3),
                ('asteroid_rock', 48, 'rock', 6), ('asteroid_rock_ice', 48, 'ice', 4), ('asteroid_rock_metal', 48, 'metal', 4),
                ('debris_rock', 12, 'rock', 6)]

def scenery_all():
    kit.SS = 8
    d = os.path.join(OUT, 'scenery'); os.makedirs(d, exist_ok=True); items = {}
    for base, px, kind, n in SCENERY_PLAN:
        for i in range(n):
            items[f'{base}_{i + 1}'] = _square(scenery.asteroid(px, kind, seed=(sum(map(ord, base)) * 7 + i * 13) % 997, craters=px > 20))
    for i in range(6):
        im = skit.render(scenery.metal_bit(i), 10, 10, seed=i); im['e_ring'] = None; items[f'debris_metal_{i + 1}'] = _square(im)
    for name, (fn, uh) in scenery.WRECKS.items():
        items[name] = scenery.render_paint(fn, uh)
    for k in ('authority', 'gate'):
        im = skit.render(scenery.buoy(k), 20, 20, seed=1); im['e_ring'] = None; items[f'buoy_{k}'] = im
    for name, im in items.items(): skit.save(im, d, name)
    sheet_scenery(d); print(len(items), 'scenery sprites')

def sheet_scenery(d):
    names = sorted({f[:-11] for f in os.listdir(d) if f.endswith('_albedo.png')})
    groups = {}
    for n in names: groups.setdefault(n.rsplit('_', 1)[0] if n[-1].isdigit() else n.split('_')[0] + '_' + n.split('_')[1], []).append(n)
    rows = []
    for g, ns in groups.items():
        ims = []
        for n in ns:
            imgs = {k: Image.open(os.path.join(d, f'{n}{s}.png')) for k, s in (('albedo', '_albedo'), ('n', '_n'), ('e', '_e'))}; imgs['e_ring'] = None
            im = skit.lit(imgs, 90); z = 2 if im.width > 60 else (4 if im.width > 20 else 8)
            ims.append(im.resize((im.width * z, im.height * z), Image.NEAREST))
        rows.append((g, ims))
    W = max(sum(i.width + 16 for i in ims) for _, ims in rows) + 32; H = sum(max(i.height for i in ims) + 44 for _, ims in rows) + 20
    s = Image.new('RGB', (W, H), (10, 8, 7)); dr = ImageDraw.Draw(s); y = 10
    for g, ims in rows:
        dr.text((16, y), g.replace('_', ' '), font=_font(16), fill=(201, 167, 122)); x = 16; y += 24
        for i in ims: s.paste(i, (x, y)); x += i.width + 16
        y += max(i.height for i in ims) + 20
    s.save(os.path.join(DOCS, 'scenery_lit.png'))

def icons():
    d = os.path.join(OUT, 'icons'); os.makedirs(d, exist_ok=True); S = 64
    def save(im, name):
        im = im.convert('RGBA'); a = np.asarray(im, np.float32)
        lum = a[..., :3].max(-1); a[..., 3] = np.clip((lum - 14) * 4, 0, 255)       # dark background -> transparent
        Image.fromarray(a.astype(np.uint8)).resize((S, S), Image.LANCZOS).save(os.path.join(d, f'{name}.png'))
    for n in natural.PLANETS:
        o = load_planet(n); im = natural.lit(o, 45, 35)
        if o.get('rings') is not None: save(im, f'icon_{n}')
        else: save(im, f'icon_{n}')
    e = Image.open(os.path.join(OUT, 'stars', 'star_e.png')); save(e, 'icon_star')
    for name, sub in (('gate_halo', 'gates'), ('station_authority_ring', 'stations'), ('station_trader_yard', 'stations'), ('station_pirate_rock', 'stations')):
        imgs = {k: Image.open(os.path.join(OUT, sub, f'{name}{s}.png')) for k, s in (('albedo', '_albedo'), ('n', '_n'), ('e', '_e'))}
        p = os.path.join(OUT, sub, f'{name}_e_ring.png'); imgs['e_ring'] = Image.open(p) if os.path.exists(p) else None
        save(skit.lit(imgs, 45), f'icon_{name}')
    names = sorted(f for f in os.listdir(d) if f.endswith('.png'))
    s = Image.new('RGB', (len(names) * 80 + 16, 96), (10, 8, 7))
    for i, f in enumerate(names): s.paste(Image.open(os.path.join(d, f)), (16 + i * 80, 16), Image.open(os.path.join(d, f)))
    s.save(os.path.join(DOCS, 'icons.png')); print(len(names), 'icons')

def main(argv):
    what = argv[0] if argv else 'all'; rest = argv[1:]
    os.makedirs(DOCS, exist_ok=True)
    if what in ('planets', 'all'): planets(rest if what == 'planets' else None)
    if what in ('star', 'all'): star()
    if what in ('scenery', 'all'): scenery_all()
    if what in ('icons', 'all'): icons()

if __name__ == '__main__':
    main(sys.argv[1:])
