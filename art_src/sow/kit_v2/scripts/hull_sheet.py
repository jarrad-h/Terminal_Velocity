import sys, json, numpy as np
from PIL import Image, ImageDraw, ImageFont
from scipy import ndimage as ndi
D = sys.argv[1]; tag = sys.argv[2] if len(sys.argv) > 2 else 'master'
names = ['sow_c_a_clamp', 'sow_c_b_booster', 'sow_c_c_longhauler', 'sow_f_a_stack', 'sow_f_b_spine', 'sow_f_c_widebody']
labels = ['C-A clamp', 'C-B booster', 'C-C longhauler', 'F-A stack', 'F-B spine', 'F-C widebody']
G = np.array([10, 8, 7], np.float32) / 255
def comp(path, gpath=None, bloom=6):
    im = np.array(Image.open(path).convert('RGBA')).astype(np.float32) / 255
    a = im[..., 3:4]; c = im[..., :3] * a
    if gpath:
        e = np.array(Image.open(gpath).convert('RGB')).astype(np.float32) / 255
        c = c * (1 - (e.max(-1, keepdims=True) > 0.05) * 0) + 0
        glow = ndi.gaussian_filter(e, (bloom, bloom, 0)) * 1.6 + e * 0.6
        return c, a, glow
    return c, a, None
items = []
# shuttle for scale (cut from the clean reference; 2120 px hull = 1750 units)
sh = Image.open('kit/2cccb5ab/sheet_cut.png')
bb = sh.getbbox(); sh = sh.crop(bb)
s = (0.5 if tag == 'master' else 3 / 12.5) * 320 / 451
sh = sh.resize((int(sh.width * s), int(sh.height * s)), Image.LANCZOS)
sh.save(f'{D}/_shuttle_{tag}.png')
items.append(('S-A shuttle (ref)', f'{D}/_shuttle_{tag}.png', None))
for n, l in zip(names, labels):
    items.append((l, f'{D}/{n}_{tag}.png', f'{D}/{n}_{tag}_glow.png'))
ims = [comp(p, g, bloom=6 if tag == 'master' else 3) for _, p, g in items]
pad = 50
Wt = sum(c.shape[1] for c, _, _ in ims) + pad * (len(ims) + 1)
Ht = max(c.shape[0] for c, _, _ in ims) + 160
can = np.ones((Ht, Wt, 3), np.float32) * G
x = pad
for (c, a, g) in ims:
    y = 90
    h, w = c.shape[:2]
    reg = can[y:y + h, x:x + w]
    reg[:] = c + reg * (1 - a)
    if g is not None:
        reg[:] = np.clip(reg + g, 0, 1)
    x += w + pad
img = Image.fromarray((np.clip(can, 0, 1) * 255).astype(np.uint8))
d = ImageDraw.Draw(img); f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 20 if tag == 'master' else 14)
x = pad
for (l, _, _), (c, _, _) in zip(items, ims):
    d.text((x, 40), l, font=f, fill=(255, 179, 71)); x += c.shape[1] + pad
d.text((pad, Ht - 50), 'Standard Orbital Works couriers and freighters, kitbashed from the Gemini part sheets. Glow layer shown with bloom.', font=f, fill=(201, 167, 122))
img.save(f'{D}/sow_cf_hulls_{tag}.png'); print(img.size)
