"""Export production stellars (gates, stations) and their review sheets.

Usage (from the repo root):  python art_src/stellar/export.py <asset> [<asset> ...] [--ss 8]
                             python art_src/stellar/export.py all
Assets are listed in prod.ASSETS. Writes assets/sprites/stellars/<gates|stations>/<asset>.png plus
_albedo, _n, _e (and _e_ring for gates), <asset>.json (size, hardpoints, jump_point), and review sheets
in docs/art/stellars/ (lit, lit from the SW, closed gate, turrets fitted, hardpoints overlay, 2x detail).
--ss sets supersampling (8 = production, 4 = quick draft). A full-quality gate takes about 13 minutes."""
import os, sys, json, math, time
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
os.environ.setdefault('PYTHONDONTWRITEBYTECODE', '1'); sys.dont_write_bytecode = True
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import skit, kit
REPO = os.path.normpath(os.path.join(HERE, '..', '..'))
PARTS = os.path.join(REPO, 'assets/sprites/ships/sow/parts')
TUR = {'t1': ('tur1', 'small', None), 't2': ('tur2', 'medium', None), 'pd': ('pd1', 'small', 'point_defence')}

def load_part(code):
    return {k: Image.open(os.path.join(PARTS, f'{code}{s}.png')).convert('RGBA') for k, s in (('albedo', '_albedo'), ('n', '_n'), ('e', '_e'))}

def rot_normals(img, deg):
    """Rotate a normal-map image clockwise by deg and turn its vectors with it."""
    im = img.rotate(-deg, Image.NEAREST, expand=True)
    a = np.asarray(im, np.float32); n = a[..., :3] / 255 * 2 - 1
    t = math.radians(deg)
    nx = n[..., 0] * math.cos(t) + n[..., 1] * math.sin(t); ny = -n[..., 0] * math.sin(t) + n[..., 1] * math.cos(t)
    out = np.stack([nx, ny, n[..., 2]], -1) * 0.5 + 0.5
    return Image.fromarray(np.dstack([np.clip(out * 255, 0, 255).astype(np.uint8), a[..., 3].astype(np.uint8)]), 'RGBA')

def fit_turrets(imgs, mounts_px):
    out = {k: (imgs[k].copy() if imgs.get(k) is not None else None) for k in ('albedo', 'n', 'e', 'e_ring')}
    cx, cy = out['albedo'].width / 2, out['albedo'].height / 2
    for h in mounts_px:
        part = load_part(TUR[h['kind']][0])
        x, y = cx + h['pos'][0], cy + h['pos'][1]
        deg = math.degrees(math.atan2(h['pos'][0], -h['pos'][1])) if (h['pos'][0] or h['pos'][1]) else 0
        for k in ('albedo', 'n', 'e'):
            im = rot_normals(part[k], deg) if k == 'n' else part[k].rotate(-deg, Image.NEAREST, expand=True)
            out[k].alpha_composite(im, (int(round(x - im.width / 2)), int(round(y - im.height / 2))))
    return out

def main(argv):
    ss = 8
    if '--ss' in argv: i = argv.index('--ss'); ss = int(argv[i + 1]); argv = argv[:i] + argv[i + 2:]
    kit.SS = ss
    import prod
    for name in (list(prod.ASSETS) if argv == ['all'] else argv): export(prod, name)

def export(prod, name):
    fn, U, title = prod.ASSETS[name]
    t = time.time()
    imgs = skit.render(fn, U, U, seed=11)
    A = os.path.join(REPO, 'assets', 'sprites', 'stellars', 'gates' if name.startswith('gate') else 'stations')
    R = os.path.join(REPO, 'docs', 'art', 'stellars'); os.makedirs(A, exist_ok=True); os.makedirs(R, exist_ok=True)
    if not imgs['e_ring'].convert('RGB').getbbox(): imgs['e_ring'] = None     # only gates have a switchable ring
    skit.save(imgs, A, name)
    C = U / 2
    mounts = [{'kind': k, 'pos': [round((x - C) * kit.K, 1), round((y - C) * kit.K, 1)]} for (x, y, k) in imgs['mounts']]
    hps = []
    for i, m in enumerate(mounts):
        code, size, role = TUR[m['kind']]
        h = {'id': f'T{i + 1}', 'size': size, 'mount': 'turret', 'pos': m['pos']}
        if role: h['role'] = role
        hps.append(h)
    meta = {'id': name, 'name': title, 'size_px': list(imgs['sprite'].size), 'sprite_scale': 1, 'hardpoints': hps}
    if name.startswith('gate'): meta['jump_point'] = list(prod.GATE_JUMP_POINT)
    json.dump(meta, open(os.path.join(A, f'{name}.json'), 'w'), indent=1)
    view = fit_turrets(imgs, mounts) if mounts else imgs
    skit.lit(view, 90).save(os.path.join(R, f'{name}_lit.png'))
    skit.lit(view, 220).save(os.path.join(R, f'{name}_lit_sw.png'))
    if imgs['e_ring'] is not None:
        skit.lit(imgs, 90, ring_on=False).save(os.path.join(R, f'{name}_closed.png'))
    if mounts:
        skit.lit(imgs, 90).save(os.path.join(R, f'{name}_rings.png'))
        im = skit.lit(imgs, 90); im = Image.blend(im, Image.new('RGB', im.size, (10, 8, 7)), 0.45); d = ImageDraw.Draw(im)
        f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 11)
        for h in hps:
            x, y = im.width / 2 + h['pos'][0], im.height / 2 + h['pos'][1]; r = 9 if h['size'] == 'small' else 13
            c = (255, 176, 64) if h.get('role') else (95, 216, 255)
            d.ellipse([x - r, y - r, x + r, y + r], outline=c, width=2); d.text((x + r + 3, y - 7), h['id'], font=f, fill=c)
        im.save(os.path.join(R, f'{name}_hardpoints.png'))
    big = skit.lit(view, 90); big.resize((big.width * 2, big.height * 2), Image.NEAREST).save(os.path.join(R, f'{name}_lit_2x.png'))
    print(f'{name}: {imgs["sprite"].size}, {len(hps)} mounts, {time.time() - t:.0f}s')

if __name__ == '__main__':
    main(sys.argv[1:])
