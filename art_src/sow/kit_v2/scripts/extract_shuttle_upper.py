"""Isolate the shuttle's upper module (white body + grey side pods + rails) that the red cap sits on."""
import numpy as np, json
from PIL import Image
im = np.array(Image.open('kit/2cccb5ab/sheet_cut.png')).astype(np.float32)
OX, OY = 330, 300                      # offset of the inspection crop
y0, y1 = OY + 135, OY + 640            # just under the cap band .. below the pod tails
x0, x1 = OX + 40, OX + 740
reg = im[y0:y1, x0:x1].copy()
H, W = reg.shape[:2]
yy, xx = np.mgrid[0:H, 0:W]
# remove the ribbed collar under the module (centre strip below the white body)
cx0, cx1 = 175 - 40, 607 - 40          # collar x-range in region coords
body_bottom = 588 - 135                # white body bottom edge (incl. small tabs)
collar = (yy > body_bottom) & (xx > cx0) & (xx < cx1)
reg[..., 3] *= ~collar
# feather the top cut a little so it tucks under the cap band
top = np.clip(yy / 6.0, 0, 1)
reg[..., 3] *= top
img = Image.fromarray(reg.astype(np.uint8), 'RGBA')
img = img.crop(img.getbbox())
s = 320 / 451                          # shuttle-image px -> kit units (cap width match)
img = img.resize((round(img.width * s), round(img.height * s)), Image.LANCZOS)
img.save('kit/parts/shuttle_upper.png')
idx = json.load(open('kit/parts/index.json')); idx['shuttle_upper'] = {'w': img.width, 'h': img.height}
json.dump(idx, open('kit/parts/index.json', 'w'), indent=0)
print(img.size)
bg = Image.new('RGBA', img.size, (10, 8, 7, 255)); bg.alpha_composite(img); bg.convert('RGB').resize((img.width * 2, img.height * 2)).save('kit/shuttle_upper_preview.png')
