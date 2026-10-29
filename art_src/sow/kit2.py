"""Courier and freighter variants from the no-frills kit, plus the new standard parts they need."""
import os, sys
import numpy as np
from PIL import Image
from kit import (Paint, deck, collar, grille, lightstrip, rcs, turret, hatch, nozzle, emblem, m_bow_bridge,
                 reduce, hires, LIGHT, WHITE, DARK, NAVY, RED, CYAN, RIB, STEEL, HX0, HX1, CX)

CONT = {'rust': (150, 92, 62), 'teal': (82, 112, 122), 'sand': (172, 152, 112), 'grey': (124, 132, 146)}

# ---- generalised standard modules ----
def seg(p, y0, L=16, variant='plain', flank=('grille', 'light'), x0=HX0, x1=HX1):
    m = deck(p, y0, y0 + L, x0, x1); cx = (x0 + x1) / 2
    p.seam(m, [(x0, y0 + L / 2), (x1, y0 + L / 2)], 0.35)
    for side, kind in zip((x0 + 0.6, x1 - 3.6), flank):
        if kind == 'grille': grille(p, side, y0 + 2.5, min(7, L - 5))
        elif kind == 'light': lightstrip(p, side + (1.8 if side > cx else 0), y0 + 4, 3.6)
    if variant == 'turret': turret(p, cx, y0 + L / 2 + 0.5)
    elif variant == 'hatch': hatch(p, cx, y0 + L / 2)
    elif variant == 'cargo':
        n = max(2, int((x1 - x0 - 8) // 7)); w = (x1 - x0 - 8 - (n - 1) * 1) / n
        for i in range(n):
            lx = x0 + 4 + i * (w + 1)
            c = p.rect(lx + 0.5, y0 + 2.5, lx + w - 0.5, y0 + L - 2.5, r=0.4); p.fill(c, (178, 184, 196)); p.edges(c, 0.4)
            p.fill(p.rect(lx + w / 2 - 0.6, y0 + L / 2 - 0.4, lx + w / 2 + 0.6, y0 + L / 2 + 0.4), (60, 66, 80))
    p.wear(m, 12)
    return m

def aft(p, y0, L=12, nozzles=4, x0=HX0, x1=HX1):
    m = deck(p, y0, y0 + L, x0, x1)
    p.fill(m * p.rect(x0, y0 + 4.4, x1, y0 + 6.6), RED)
    emblem(p, x0 + 8.6, y0 + 9)
    p.fill(p.rect(x1 - 11, y0 + 8, x1 - 4, y0 + 9), (40, 44, 54), 0.7, solid=False)
    rcs(p, x0 + 2.4, y0 + 2.2); rcs(p, x1 - 2.4, y0 + 2.2)
    span = x1 - x0 - 5.2
    for i in range(nozzles): nozzle(p, x0 + 2.6 + span * (i + 0.5) / nozzles, y0 + L)
    p.wear(m, 10)
    return m

def adapter(p, y0, L, wx0, wx1, nx0=HX0, nx1=HX1):
    """Tapered transition plate from the standard hull to the wide hull."""
    m = p.poly([(nx0, y0), (nx1, y0), (wx1, y0 + L), (wx0, y0 + L)])
    cw = (nx1 - nx0) * 0.3
    col = np.where((np.abs(p.X - CX) < cw)[..., None], np.asarray(LIGHT, np.float32), np.asarray(DARK, np.float32))
    p.fill(m, np.clip(col * p.facet(wx0, wx1, 7)[..., None], 0, 255)); p.edges(m)
    for xe in (CX - cw, CX + cw): p.seam(m, [(xe, y0), (xe, y0 + L)], 0.45)
    p.rivets(m, y0 + L - 0.8, wx0 + 1, wx1 - 1)
    for xs in (wx0 + 2.5, wx1 - 2.5): rcs(p, xs, y0 + L - 2.6)
    p.wear(m, 6)
    return m

def container(p, x0, y0, x1, y1, kind='rust'):
    """Standard cargo container: ribbed box, door end, stencil block."""
    m = p.rect(x0, y0, x1, y1, r=0.3)
    base = np.asarray(CONT[kind], np.float32)
    p.fill(m, np.clip(base * p.facet(x0, x1, 3)[..., None], 0, 255)); p.edges(m, 0.4)
    for y in np.arange(y0 + 1.2, y1 - 0.8, 1.4):
        p.fill(m * p.rect(x0 + 0.4, y, x1 - 0.4, y + 0.35), (30, 30, 34), 0.35, solid=False)
    p.fill(p.rect(x0 + 0.4, y1 - 1.6, x1 - 0.4, y1 - 0.5), np.clip(base * 0.6, 0, 255))
    p.fill(p.rect(x0 + 1, y0 + 1.6, x0 + 1 + (x1 - x0) * 0.45, y0 + 2.3), (225, 225, 220), 0.6, solid=False)
    p.wear(m, 3)

def clamp(p, y0, L, x0=HX0, x1=HX1, kinds=('rust',)):
    """Open clamp frame: two side rails and end braces holding standard containers."""
    for rx0, rx1 in ((x0, x0 + 3), (x1 - 3, x1)):
        r = p.rect(rx0, y0, rx1, y0 + L)
        p.fill(r, np.clip(np.asarray(DARK, np.float32) * p.facet(rx0, rx1, 2)[..., None], 0, 255)); p.edges(r, 0.4)
        p.rivets(r, y0 + 1, rx0 + 0.6, rx1, 1.2); p.rivets(r, y0 + L - 1, rx0 + 0.6, rx1, 1.2)
    for by in (y0, y0 + L - 1.4):
        b = p.rect(x0 + 3, by, x1 - 3, by + 1.4); p.fill(b, (58, 66, 82)); p.edges(b, 0.3)
    n = len(kinds); h = (L - 3.6 - (n - 1) * 0.8) / n
    for i, k in enumerate(kinds):
        cy0 = y0 + 1.8 + i * (h + 0.8)
        container(p, x0 + 3.6, cy0, x1 - 3.6, cy0 + h, k)
        for ty in (cy0 + 1, cy0 + h - 2):
            p.fill(p.rect(x0 + 2.4, ty, x0 + 4, ty + 1), RED); p.fill(p.rect(x1 - 4, ty, x1 - 2.4, ty + 1), RED)

def spine_bay(p, y0, L, kinds_l, kinds_r, sx0=35, sx1=45, cw=11):
    """Narrow spine segment with containers clamped either side."""
    m = deck(p, y0, y0 + L, sx0, sx1, ch=0.5)
    for side, kinds in ((-1, kinds_l), (1, kinds_r)):
        n = len(kinds); h = (L - 1.2 - (n - 1) * 0.8) / n
        for i, k in enumerate(kinds):
            cy0 = y0 + 0.6 + i * (h + 0.8)
            cx0, cx1 = (sx0 - 0.8 - cw, sx0 - 0.8) if side < 0 else (sx1 + 0.8, sx1 + 0.8 + cw)
            container(p, cx0, cy0, cx1, cy0 + h, k)
            arm = p.rect(sx0 - 1.2, cy0 + h / 2 - 0.6, sx0, cy0 + h / 2 + 0.6) if side < 0 else p.rect(sx1, cy0 + h / 2 - 0.6, sx1 + 1.2, cy0 + h / 2 + 0.6)
            p.fill(arm, RED)
    return m

def booster(p, cx, y0, L, strut_ys, hull_x):
    """Bolt-on side booster pod: faceted drum, red nose cap, one N1 nozzle, struts to the hull."""
    for sy in strut_ys:
        x0, x1 = sorted((cx, hull_x)); s = p.rect(x0, sy, x1, sy + 1.4); p.fill(s, (50, 56, 70)); p.edges(s, 0.3)
    m = p.rect(cx - 2.8, y0, cx + 2.8, y0 + L, r=1.2)
    p.fill(m, np.clip(np.asarray(DARK, np.float32) * p.facet(cx - 2.8, cx + 2.8, 3)[..., None], 0, 255)); p.edges(m, 0.45)
    p.fill(m * p.rect(cx - 2.8, y0, cx + 2.8, y0 + 1.6), RED)
    for y in (y0 + L * 0.4, y0 + L * 0.7): p.fill(m * p.rect(cx - 2.8, y, cx + 2.8, y + 0.4), RIB, 0.7, solid=False)
    nozzle(p, cx, y0 + L, 4.2, 3)

def solar(p, side, y, hull_x, w=13, h=8):
    """Bolt-on solar wing: fixed arm, panel rotates in place (flat frame shown)."""
    ax0, ax1 = (hull_x - 3, hull_x) if side < 0 else (hull_x, hull_x + 3)
    a = p.rect(ax0, y - 0.6, ax1, y + 0.6); p.fill(a, STEEL); p.fill(a * p.rect(ax0, y, ax1, y + 0.6), (90, 96, 110))
    px0 = ax0 - w if side < 0 else ax1
    f = p.rect(px0, y - h / 2, px0 + w, y + h / 2); p.fill(f, (170, 176, 188)); p.edges(f, 0.45)
    inner = p.rect(px0 + 0.7, y - h / 2 + 0.7, px0 + w - 0.7, y + h / 2 - 0.7)
    p.fill(inner, np.clip(np.array([34, 56, 108], np.float32) * (1.1 - 0.3 * (p.Y - (y - h / 2)) / h)[..., None], 0, 255))
    for gx in np.linspace(px0 + 0.7, px0 + w - 0.7, 5)[1:-1]: p.fill(inner * p.rect(gx - 0.2, y - h / 2, gx + 0.2, y + h / 2), (150, 160, 176))
    p.fill(inner * p.rect(px0, y - 0.2, px0 + w, y + 0.2), (150, 160, 176))

# ---- ships ----
def courier_a(p):   # booster stretch
    booster(p, 21.5, 26, 30, (28, 48), HX0); booster(p, 58.5, 26, 30, (28, 48), HX1)
    m_bow_bridge(p, 6); collar(p, 22); seg(p, 23.2, 16, 'cargo', ('grille', 'grille')); collar(p, 39.2); aft(p, 40.4, 12, 4)
def courier_b(p):   # container clamp
    m_bow_bridge(p, 6); collar(p, 22); clamp(p, 23.2, 24, kinds=('rust',)); collar(p, 47.2); aft(p, 48.4, 12, 4)
def courier_c(p):   # solar long-hauler
    solar(p, -1, 40, HX0 - 0.6); solar(p, 1, 40, HX1 + 0.6)
    m_bow_bridge(p, 6); collar(p, 22); seg(p, 23.2, 16, 'turret'); collar(p, 39.2)
    seg(p, 40.4, 16, 'cargo', ('light', 'grille')); collar(p, 56.4); aft(p, 57.6, 12, 4)
def freighter_a(p):  # long stack
    m_bow_bridge(p, 6); collar(p, 22); y = 23.2
    for v, fl in (('cargo', ('grille', 'light')), ('turret', ('grille', 'grille')), ('cargo', ('light', 'grille')), ('cargo', ('grille', 'light'))):
        seg(p, y, 16, v, fl); collar(p, y + 16); y += 17.2
    solar(p, 1, y - 9.2, HX1 + 0.6)
    aft(p, y, 12, 4)
def freighter_b(p):  # container spine
    m_bow_bridge(p, 6); collar(p, 22); y = 23.2
    bays = ((('rust', 'teal'), ('grey', 'sand')), (('sand', 'grey'), ('rust', 'rust')), (('teal', 'rust'), ('sand', 'teal')))
    for l, r in bays:
        spine_bay(p, y, 26, l, r); collar(p, y + 26, 33.8, 46.2); y += 27.2
    adapter(p, y, 5, 22, 58, 34, 46); collar(p, y + 5, 21.4, 58.6); aft(p, y + 6.2, 12, 6, 22, 58)
def freighter_c(p):  # wide body
    W0, W1 = 20, 60
    m_bow_bridge(p, 6); collar(p, 22); adapter(p, 23.2, 9, W0, W1); collar(p, 32.2, W0 - 0.6, W1 + 0.6)
    y = 33.4
    for v, fl in (('cargo', ('grille', 'light')), ('turret', ('light', 'grille')), ('cargo', ('grille', 'grille')), ('hatch', ('grille', 'light'))):
        seg(p, y, 16, v, fl, W0, W1); collar(p, y + 16, W0 - 0.6, W1 + 0.6); y += 17.2
    aft(p, y, 12, 6, W0, W1)

if __name__ == '__main__':
    OUT = sys.argv[1]; os.makedirs(OUT, exist_ok=True)
    SHIPS = {'courier_a': (courier_a, 76), 'courier_b': (courier_b, 76), 'courier_c': (courier_c, 84),
             'freighter_a': (freighter_a, 116), 'freighter_b': (freighter_b, 130), 'freighter_c': (freighter_c, 120)}
    only = sys.argv[2:] or list(SHIPS)
    for name in only:
        fn, uh = SHIPS[name]
        p = Paint(80, uh); fn(p)
        im = reduce(p); im = im.crop(im.getbbox()); im.save(f'{OUT}/{name}.png')
        print(name, im.size)

    # new parts for the pack
    if not sys.argv[2:]:
        parts = {
            'clamp_container': (lambda q: clamp(q, 2, 24, kinds=('rust',)), 30),
            'container_set': (lambda q: [container(q, 14 + i * 14, 2, 25 + i * 14, 14, k) for i, k in enumerate(('rust', 'teal', 'sand', 'grey'))], 16),
            'booster': (lambda q: booster(q, 40, 2, 30, (), 40), 38),
            'solar_wing': (lambda q: solar(q, 1, 8, 30), 16),
            'adapter_wide': (lambda q: adapter(q, 2, 9, 20, 60), 13),
            'spine_bay': (lambda q: spine_bay(q, 2, 26, ('rust', 'teal'), ('grey', 'sand')), 30),
            'aft_wide6': (lambda q: aft(q, 2, 12, 6, 20, 60), 20),
        }
        for name, (fn, h) in parts.items():
            q = Paint(80, h); fn(q); im = reduce(q); im.crop(im.getbbox()).save(f'{OUT}/part_{name}.png')
        print('parts ok')
