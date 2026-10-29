"""SOW update: FUEL-16 (Moss-dome fuel module), wide cruise aft, revised C-C, F-A, F-B."""
import os, sys
import numpy as np
from kit import Paint, collar, nozzle, emblem, rcs, m_bow_bridge, reduce, deck, LIGHT, DARK, RED, RIB, STEEL, HX0, HX1, CX
from kit2 import seg, solar, spine_bay, adapter
from kit3 import aft_cruise

def fuel(p, y0, L=16, x0=HX0, x1=HX1):
    """FUEL-16: standard segment carrying one spherical fuel tank, like a Moss-type LNG carrier."""
    m = deck(p, y0, y0 + L, x0, x1)
    cx, cy, r = (x0 + x1) / 2, y0 + L / 2, min(L, x1 - x0) / 2 - 1.2
    p.fill(p.ell(cx - r - 0.9, cy - r - 0.9, cx + r + 0.9, cy + r + 0.9), (40, 46, 58))     # foundation skirt
    d = p.ell(cx - r, cy - r, cx + r, cy + r)
    nx = np.clip((p.X - cx) / r, -1, 1); ny = np.clip((p.Y - cy) / r, -1, 1)
    nz = np.sqrt(np.clip(1 - nx ** 2 - ny ** 2, 0, 1))
    L_ = np.array([-0.45, -0.45, 0.77]); L_ /= np.linalg.norm(L_)
    lam = np.clip(nx * L_[0] + ny * L_[1] + nz * L_[2], 0, 1)
    f = 0.5 + 0.62 * lam + 0.35 * np.clip(lam - 0.9, 0, 1) * 10
    p.fill(d, np.clip(np.asarray((206, 208, 212), np.float32) * f[..., None], 0, 255))
    # equator belt and shading ring
    belt = d * (np.abs(np.hypot(p.X - cx, p.Y - cy) - r * 0.97) < 0.35)
    p.fill(belt, (70, 76, 90), 0.8, solid=False)
    # pipe rack running over the dome along the centreline
    for dx in (-0.8, 0.8):
        p.fill(p.rect(cx + dx - 0.25, y0, cx + dx + 0.25, y0 + L), (90, 98, 114))
    vb = p.ell(cx - 1.5, cy - r * 0.55 - 1.5, cx + 1.5, cy - r * 0.55 + 1.5); p.fill(vb, (120, 126, 140)); p.edges(vb, 0.3)
    # hazard stencil
    p.fill(p.rect(x0 + 1.2, y0 + 2, x0 + 2.4, y0 + 4.6), RED); p.fill(p.rect(x1 - 2.4, y0 + L - 4.6, x1 - 1.2, y0 + L - 2), RED)
    p.wear(m, 8)
    return m

def aft_cruise_w(p, y0, L=12, x0=20, x1=60, n2=2):
    """AFT-WC: wide cruise aft, N2 cruise nozzles with N1 manoeuvring nozzles outboard."""
    m = deck(p, y0, y0 + L, x0, x1)
    p.fill(m * p.rect(x0, y0 + 4.4, x1, y0 + 6.6), RED)
    emblem(p, x0 + 8.6, y0 + 9)
    p.fill(p.rect(x1 - 11, y0 + 8, x1 - 4, y0 + 9), (40, 44, 54), 0.7, solid=False)
    rcs(p, x0 + 2.4, y0 + 2.2); rcs(p, x1 - 2.4, y0 + 2.2)
    span = x1 - x0 - 10
    for i in range(n2): nozzle(p, x0 + 5 + span * (i + 0.5) / n2, y0 + L, 10, 6.5)
    nozzle(p, x0 + 3.4, y0 + L, 4, 3); nozzle(p, x1 - 3.4, y0 + L, 4, 3)
    p.wear(m, 10)

def courier_c(p):
    solar(p, -1, 23, HX0 - 0.6, 11, 7); solar(p, 1, 23, HX1 + 0.6, 11, 7)
    m_bow_bridge(p, 6); collar(p, 22)
    seg(p, 23.2, 16, 'hatch', ('light', 'grille')); collar(p, 39.2)
    fuel(p, 40.4); collar(p, 56.4)
    seg(p, 57.6, 16, 'cargo', ('grille', 'light')); collar(p, 73.6)
    aft_cruise(p, 74.8, 12)

def freighter_a(p):
    m_bow_bridge(p, 6); collar(p, 22); y = 23.2
    for v, fl in (('cargo', ('grille', 'light')), ('turret', ('grille', 'grille')), ('cargo', ('light', 'grille')), ('cargo', ('grille', 'light'))):
        seg(p, y, 16, v, fl); collar(p, y + 16); y += 17.2
    solar(p, 1, y - 9.2, HX1 + 0.6)
    aft_cruise(p, y, 12)

def freighter_b(p):
    m_bow_bridge(p, 6); collar(p, 22); y = 23.2
    bays = ((('rust', 'teal'), ('grey', 'sand')), (('sand', 'grey'), ('rust', 'rust')), (('teal', 'rust'), ('sand', 'teal')))
    for l, r in bays:
        spine_bay(p, y, 26, l, r); collar(p, y + 26, 33.8, 46.2); y += 27.2
    adapter(p, y, 5, 22, 58, 34, 46); collar(p, y + 5, 21.4, 58.6); aft_cruise_w(p, y + 6.2, 12, 22, 58, 2)

if __name__ == '__main__':
    OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
    for name, fn, h in (('courier_c2', courier_c, 98), ('freighter_a2', freighter_a, 124), ('freighter_b2', freighter_b, 136)):
        p = Paint(80, h); fn(p); im = reduce(p); im = im.crop(im.getbbox()); im.save(f'{OUT}/{name}.png'); print(name, im.size)
    for name, fn, h in (('fuel16', lambda q: fuel(q, 2), 20), ('aft_cruise_w', lambda q: aft_cruise_w(q, 2), 24)):
        q = Paint(80, h); fn(q); im = reduce(q); im = im.crop(im.getbbox()); im.save(f'{OUT}/part_{name}.png'); print(name, im.size)
