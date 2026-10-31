# SOW kit v2: illustrated parts

The second SOW art direction is illustrated parts with ink outlines and painted grime, set by Jarrad's reference shuttle (`sheets/sow_s_a_shuttle_reference_lit.jpg`). Gemini drew the part sheets on flat magenta (#FF00FF) so they can be cut out from JPG. Claude cut them into a parts library and builds hulls from recipes.

**Status:** in progress. The hulls here are concepts. They are not wired into `assets/` or `data/` yet, and they have no normal maps yet. The kit v1 sprites in `assets/sprites/ships/sow/` are still what the game uses.

## Layout

| Path | What |
|---|---|
| `sheets/` | Source part sheets on magenta (base, trade, combat) and the shuttle reference |
| `parts/` | 118 cut parts (RGBA PNG) plus `manifest.json` (category, size, mirror partner, glow flag). `_montage.jpg` labels every part |
| `example_design.json` | A small hull in the `tv-ship-design/1` format (see `docs/art/ship-designer-brief.md`) |
| `scripts/` | The pipeline (below) |

Concept renders of the C and F hulls are in `docs/art/concepts/sow_kit_v2/`.

## Units

- Part images are 1 px = 1 kit unit at scale 1.0.
- 12.5 kit units = 1 game px. This is calibrated so the reference shuttle is 120 px tall.
- Art faces up, with +y aft and x = 0 on the centre line.

## Parts

- `base_*`: hull modules, collars, flanks, engine pods and bells.
- `trade_*`: containers, tanks, clamps and pipes.
- `combat_*`: turrets, guns, missile racks, armour plates, sensor masts, glass canopies and large engines.
- `shuttle_upper`: the module the red nose cap sits on, cut from the shuttle reference. A `nose_cap` always sits on it.

## Scripts

Run them from a working folder that has `kit/` beside the scripts. The paths inside the scripts are relative.

| Script | Purpose |
|---|---|
| `key_magenta.py <sheet.jpg> <outdir>` | Chroma-key a magenta sheet and despill the JPG fringe |
| `extract_parts.py` | Split keyed sheets into `parts/<sheet>_<nn>.png` |
| `extract_shuttle_upper.py` | Cut the nose module from the shuttle reference |
| `compose.py` | The `Hull` class (`place` / `pair` / `finish`) and `render_design(design.json, outdir)`. Each part gets a contact shadow, and the glow layer is built from cyan glass and `glow="exit"` engine parts |
| `hulls_cf.py` | Recipes for C-A/B/C and F-A/B/C |
| `hull_sheet.py` / `montage.py` | Overview sheets |

## Next

- Normal maps and the albedo/normal/emission set for each hull.
- `hull.json` for each hull. Hardpoints and engines need re-placing, because the sizes changed.
- Combat hulls (P, K, R) from the combat parts.
- `tools/ship-designer`, so Jarrad can lay out hulls himself (brief: `docs/art/ship-designer-brief.md`).
