"""Cut every part from the keyed sheets into its own RGBA PNG, named by sheet + index."""
import json, os, numpy as np
from PIL import Image
from scipy import ndimage as ndi
SHEETS = {'base': 'kit/c6d2de3c', 'trade': 'kit/6c41bd41', 'combat': 'kit/b7efd00a'}
OUT = 'kit/parts'; os.makedirs(OUT, exist_ok=True)
index = {}
for name, d in SHEETS.items():
    rgba = np.array(Image.open(f'{d}/sheet_cut.png')).astype(np.float32)
    a = rgba[..., 3] / 255
    solid = a > 0.5
    grp = ndi.binary_dilation(solid, iterations=6)
    gl, gn = ndi.label(grp)
    sl = ndi.find_objects(gl)
    boxes = [[s[1].start, s[0].start, s[1].stop, s[0].stop] for s in sl]
    order = sorted(range(gn), key=lambda i: (round(boxes[i][1] / 120), boxes[i][0]))
    for k, i in enumerate(order):
        s = sl[i]
        m = (gl[s] == i + 1)
        crop = rgba[s].copy(); crop[..., 3] *= m
        pid = f'{name}_{k:02d}'
        Image.fromarray(crop.astype(np.uint8), 'RGBA').save(f'{OUT}/{pid}.png')
        index[pid] = {'w': int(crop.shape[1]), 'h': int(crop.shape[0])}
json.dump(index, open(f'{OUT}/index.json', 'w'), indent=0)
print(len(index))
