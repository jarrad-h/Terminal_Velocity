"""SOW long-haul courier (C-C): crew segment, strap-on fuel tanks, cargo segment, cruise drive with radiators."""
import os, sys
import numpy as np
from kit import Paint, collar, nozzle, emblem, rcs, m_bow_bridge, reduce, deck, LIGHT, DARK, RED, RIB, STEEL, HX0, HX1, CX
from kit2 import seg, solar

def tank(p, cx, y0, L, hull_x):
    """TNK: strap-on cylindrical fuel tank with saddle straps to the hull."""
    for sy in (y0 + 2.5, y0 + L - 3.5):
        x0, x1 = sorted((cx, hull_x)); s = p.rect(x0, sy, x1, sy + 1); p.fill(s, (50, 56, 70))
    m = p.rect(cx - 3.2, y0, cx + 3.2, y0 + L, r=3.0)
    p.fill(m, np.clip(np.asarray((176, 182, 194), np.float32) * p.facet(cx - 3.2, cx + 3.2, 4)[..., None], 0, 255)); p.edges(m, 0.45)
    for sy in (y0 + 2.5, y0 + L - 3.5): p.fill(m * p.rect(cx - 3.2, sy, cx + 3.2, sy + 1), (60, 66, 80))
    p.fill(m * p.rect(cx - 3.2, y0 + L / 2 - 0.5, cx + 3.2, y0 + L / 2 + 0.5), RED)
    p.fill(p.ell(cx - 0.7, y0 + 0.8, cx + 0.7, y0 + 2.2), (70, 76, 90))

def radiator(p, side, y_root, hull_x, length=12, sweep=7):
    """RAD: swept radiator fin, fixed. Light panels with dark coolant channels."""
    xr = hull_x
    xo = xr + side * length
    m = p.poly([(xr, y_root), (xo, y_root + sweep), (xo, y_root + sweep + 3.2), (xr, y_root + 4.6)])
    p.fill(m, (188, 192, 200)); p.edges(m, 0.4)
    for k in range(1, 6):
        t = k / 6; x = xr + side * length * t
        p.fill(m * p.line([(x, y_root - 1), (x, y_root + sweep + 5)], 0.25), (70, 76, 90), 0.8, solid=False)
    root = p.rect(min(xr, xr + side * 1.6), y_root, max(xr, xr + side * 1.6), y_root + 4.6); p.fill(root, (50, 56, 70))

def aft_cruise(p, y0, L=12, x0=HX0, x1=HX1):
    """AFT-C: aft block with one N2 cruise nozzle and two N1 manoeuvring nozzles."""
    m = deck(p, y0, y0 + L, x0, x1)
    p.fill(m * p.rect(x0, y0 + 4.4, x1, y0 + 6.6), RED)
    emblem(p, x0 + 8.6, y0 + 9)
    p.fill(p.rect(x1 - 11, y0 + 8, x1 - 4, y0 + 9), (40, 44, 54), 0.7, solid=False)
    rcs(p, x0 + 2.4, y0 + 2.2); rcs(p, x1 - 2.4, y0 + 2.2)
    nozzle(p, CX, y0 + L, 10, 6.5)          # N2
    nozzle(p, x0 + 3.4, y0 + L, 4, 3); nozzle(p, x1 - 3.4, y0 + L, 4, 3)
    p.wear(m, 10)

def courier_c(p):
    radiator(p, -1, 74.2, HX0 - 0.6); radiator(p, 1, 74.2, HX1 + 0.6)
    solar(p, -1, 23, HX0 - 0.6, 11, 7); solar(p, 1, 23, HX1 + 0.6, 11, 7)
    tank(p, 22.6, 41.2, 14.4, HX0); tank(p, 57.4, 41.2, 14.4, HX1)
    m_bow_bridge(p, 6); collar(p, 22)
    seg(p, 23.2, 16, 'hatch', ('light', 'grille')); collar(p, 39.2)
    seg(p, 40.4, 16, 'plain', ('grille', 'grille')); collar(p, 56.4)
    seg(p, 57.6, 16, 'cargo', ('grille', 'light')); collar(p, 73.6)
    aft_cruise(p, 74.8, 12)

if __name__ == '__main__':
    OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
    p = Paint(80, 98); courier_c(p)
    im = reduce(p); im = im.crop(im.getbbox()); im.save(f'{OUT}/courier_longhaul.png'); print(im.size)
    for name, fn, h in (('tank', lambda q: tank(q, 40, 2, 14.4, 46), 18), ('radiator', lambda q: radiator(q, 1, 2, 30), 16),
                        ('aft_cruise', lambda q: aft_cruise(q, 2), 24)):
        q = Paint(80, h); fn(q); im = reduce(q); im.crop(im.getbbox()).save(f'{OUT}/part_{name}.png')
    print('ok')
