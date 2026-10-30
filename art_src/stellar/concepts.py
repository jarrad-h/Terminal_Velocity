"""Render concept sheets for review (not production art).

Usage (from the repo root):  python art_src/stellar/concepts.py [gates|stations] [name ...] [--ss 4]
Writes docs/art/concepts/<name>.png (lit at 1:1, star from screen right) plus a closed-gate render and the
baked sprite, so concepts can be judged in the Amber Glass look before production."""
import os, sys, time, json
HERE = os.path.dirname(os.path.abspath(__file__)); sys.path.insert(0, HERE)
import skit  # noqa: E402  (also puts art_src/sow on the path)
import kit  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, '..', '..'))
OUT = os.path.join(ROOT, 'docs', 'art', 'concepts')

def main(argv):
    ss = 4
    if '--ss' in argv:
        i = argv.index('--ss'); ss = int(argv[i + 1]); argv = argv[:i] + argv[i + 2:]
    kit.SS = ss
    group = argv[0] if argv else 'gates'
    mod = __import__(group)
    want = set(argv[1:])
    os.makedirs(OUT, exist_ok=True)
    for name, title, fn, _ in mod.CONCEPTS:
        if want and name not in want: continue
        t = time.time()
        imgs = skit.render(fn, mod.U, getattr(mod, 'UH', mod.U), seed=11)
        skit.save(imgs, os.path.join(OUT, 'maps'), name)
        skit.lit(imgs, 90).save(os.path.join(OUT, f'{name}_lit.png'))
        skit.lit(imgs, 220).save(os.path.join(OUT, f'{name}_lit_sw.png'))
        if imgs['e_ring'].getbbox():
            skit.lit(imgs, 90, ring_on=False).save(os.path.join(OUT, f'{name}_closed.png'))
        if imgs['hps']:
            json.dump([dict(zip(('id', 'size', 'mount', 'x', 'y'), h)) for h in imgs['hps']], open(os.path.join(OUT, 'maps', f'{name}_hardpoints.json'), 'w'), indent=1)
        print(f'{name}: {imgs["sprite"].size} in {time.time() - t:.1f}s')

if __name__ == '__main__':
    main(sys.argv[1:])
