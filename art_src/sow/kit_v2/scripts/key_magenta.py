import sys, os, json, numpy as np
from PIL import Image
from scipy import ndimage as ndi
src, out = sys.argv[1], sys.argv[2]; os.makedirs(out, exist_ok=True)
a = np.array(Image.open(src).convert('RGB')).astype(np.float32)
R, G, B = a[..., 0], a[..., 1], a[..., 2]
mag = np.minimum(R, B) - G                # magenta-ness
bg_val = np.median(a[mag > 150], axis=0)
alpha = np.clip((170 - mag) / (170 - 70), 0, 1)   # soft key: >=170 bg, <=70 solid
# despill: pull excess magenta out of semi/edge pixels
spill = np.clip(np.minimum(R, B) - G - 12, 0, None)
k = np.clip(spill / 60, 0, 1)[..., None] * (alpha < 1)[..., None] + (spill > 25)[..., None] * 0.6
gray = np.stack([G + 0.5 * (np.minimum(R, B) - G).clip(0, 25)] * 3, -1)
a2 = a * (1 - k) + gray * k
a2[..., 0] = np.minimum(a2[..., 0], np.maximum(a2[..., 1] + 40, a2[..., 0] * (1 - k[..., 0])))
# hard despill: no pixel may be more magenta than neutral grey + a little (keeps reds/oranges, which have low blue)
mn = np.minimum(a2[..., 0], a2[..., 2]); exc = np.clip(mn - a2[..., 1] - 6, 0, None)
a2[..., 0] -= exc; a2[..., 2] -= exc
solid = alpha > 0.5
# remove specks, keep enclosed magenta (frames) transparent
solid = ndi.binary_opening(solid, iterations=1)
lab, n = ndi.label(solid)
sizes = ndi.sum(solid, lab, range(1, n + 1))
keep_ids = np.where(sizes > 400)[0] + 1
keep = np.isin(lab, keep_ids)
alpha = alpha * ndi.binary_dilation(keep, iterations=2)
rgba = np.dstack([np.clip(a2, 0, 255), alpha * 255]).astype(np.uint8)
Image.fromarray(rgba, 'RGBA').save(f'{out}/sheet_cut.png')
# leftover magenta check inside kept parts
inside = keep & (mag > 40)
print(os.path.basename(src), 'bg', bg_val.round(), 'parts', len(keep_ids), 'magenta px left inside parts', int(inside.sum()))
for name, bg in [('dark', (10, 8, 7)), ('light', (235, 235, 235))]:
    c = a2 * alpha[..., None] + np.array(bg, np.float32) * (1 - alpha[..., None])
    Image.fromarray(np.clip(c, 0, 255).astype(np.uint8)).save(f'{out}/preview_{name}.jpg', quality=92)
# per-part bounding boxes (merge nearby fragments so a part with gaps stays one part)
grp = ndi.binary_dilation(keep, iterations=6)
gl, gn = ndi.label(grp)
boxes = ndi.find_objects(gl)
json.dump([[int(s[1].start), int(s[0].start), int(s[1].stop), int(s[0].stop)] for s in boxes], open(f'{out}/boxes.json', 'w'))
print('grouped parts', gn)
