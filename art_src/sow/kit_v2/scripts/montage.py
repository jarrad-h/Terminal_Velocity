import json, numpy as np
from PIL import Image, ImageDraw, ImageFont
idx = json.load(open('kit/parts/index.json'))
cell = 170; cols = 13
names = list(idx)
rows = (len(names) + cols - 1) // cols
can = Image.new('RGB', (cols * cell, rows * (cell + 18)), (10, 8, 7))
d = ImageDraw.Draw(can); f = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf', 13)
for i, n in enumerate(names):
    im = Image.open(f'kit/parts/{n}.png'); im.thumbnail((cell - 10, cell - 10))
    x, y = (i % cols) * cell, (i // cols) * (cell + 18)
    can.paste(im, (x + 5, y + 5), im); d.text((x + 5, y + cell), n, font=f, fill=(255, 179, 71))
can.save('kit/parts_montage.jpg', quality=85); print(can.size)
