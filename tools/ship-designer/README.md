# Ship Designer

A standalone browser tool for building ship hulls from a kit of painted parts. Drag parts onto a canvas, arrange them, mark hardpoints, engine exhausts, lights and the hit capsule, and save a **design file**. Claude's art pipeline renders the final art (albedo, normal map, glow) from that file; this tool does not.

## Use

Open `index.html` in Chrome or Firefox (double-click it). No install, server or build step.

1. **Open kit folder** and pick the kit folder (the folder holding `manifest.json` and the part PNGs, or any folder above it, such as `art_src/sow/kit_v2`). **Open kit zip** reads a zip of the same. You can also drop the folder or zip on the canvas. In Chrome the folder is remembered, so next time **Reopen kit** brings it back.
2. Drag parts from the palette onto the canvas, or click one to add it at the view centre. Search filters by id, category and note.
3. Arrange them: move, rotate, scale, flip, restack, lock, group. **Mirror** (M) keeps a partner on the other side of the centre line.
4. Pick **Hardpoint** (H), **Engine** (E) or **Light** (L) and click the hull to place markers. Mirror places pairs.
5. Press **Fit to composed sprite** under Hit capsule, then trim it.
6. Fix anything under **Checks**, then **Save design** (`<hull_id>.design.json`). Hand that file to Claude for the art. **Save hull.json** and **Save preview PNGs** are there too.

The game-size preview (bottom right of the canvas) shows the composed ship at 1:1 game pixels and at 3×, so you can judge readability. The work is autosaved in the browser (per browser, per machine); the design file is the real copy.

### Keys

| Key | Does |
| --- | --- |
| V / H / E / L | Select / Hardpoint / Engine / Light tool |
| M | Mirror mode on/off |
| G / S | Grid on/off / snap on/off (hold Alt while dragging to place freely) |
| B | Cycle the canvas background: dark (#0a0807), checker, light |
| Click, Shift-click | Select; add or remove. Clicking a grouped part selects the group; Alt-click picks one part |
| Drag on empty canvas | Marquee select (Shift adds) |
| Arrows | Nudge one grid step (1 unit with snap off); Shift ×10 |
| R / Shift+R | Rotate 90° clockwise / counter-clockwise |
| Rotate handle (circle above the selection) | Free rotation; hold Shift to snap to 15° |
| Scale handle (square at a corner) | Uniform scale; hold Shift for 0.05 steps |
| F / Shift+F | Flip horizontally / vertically |
| Ctrl+D | Duplicate |
| ] / [ | Bring forward / send backward |
| Shift+] / Shift+[ | Bring to front / send to back |
| K | Lock or unlock |
| Ctrl+G / Ctrl+Shift+G | Group / ungroup |
| U | Break the mirror link |
| Delete, Backspace | Delete (a part takes its mirror partner with it; break the link first to keep one side) |
| Ctrl+A | Select all parts |
| Escape | Clear the selection |
| Ctrl+Z / Ctrl+Shift+Z or Ctrl+Y | Undo / redo (unlimited) |
| Ctrl+S / Ctrl+O | Save / open a design |
| Space-drag, right-drag, middle-drag | Pan |
| Wheel | Zoom |
| 0 | Fit the design in view |
| ? | Key list |

The marker keys (V, H, E, M, arrows, Delete, undo/redo, pan, zoom) are the same as `tools/hardpoint-editor`.

### Layers

The layers list shows parts in draw order, top of the list on top. Drag rows to reorder, use the dot to hide a part and the padlock to lock it, and double-click a name to rename it (a label only; the part id doesn't change). Restacking renumbers `z` from 1 at the bottom.

### Mirror mode

- Placing a part off the centre line adds a mirrored partner. The partner is the part's `mirror_of` from the kit manifest (for example `base_06` ↔ `base_12`); a part without one gets a flipped copy of itself.
- Moving, rotating, scaling or flipping either part keeps the other in step (x = −x, rot = −rot, same y, scale, flipY, shadow, glow and hidden). Dragging a part from the centre line out to one side adds a partner; dragging it back removes it.
- **Break mirror link** (U) unlinks the selected part so it moves on its own. **Add mirror** gives a lone off-centre part a partner.
- Hardpoints, engines and lights pair the way the hardpoint editor pairs them: by position (a marker at −x, same y, same mount and size).

## Coordinates and scale

- Design space is in **kit units**. x = 0 is the centre line, +x is starboard (right), +y is aft (down); the ship faces up.
- Part images are 1 px = 1 kit unit at scale 1.0. `units_per_game_px` (12.5 for the SOW kit) kit units make one game pixel; it comes from the kit manifest.
- A part's `x`, `y` is its centre. `rot` is degrees, positive **counter-clockwise** on screen. `scale` is uniform, relative to the native image. `flipX`, `flipY` mirror the image. `z` is draw order, higher on top; equal `z` draws in file order.
- **Transform order:** flip, then scale, then rotate about the part centre. `compose.py render_design` applies the same order; the tool's composite was checked against it (same sprite size, 98% alpha overlap, the rest is the renderer's contact shadows and glow).
- The render canvas is 2400 × 4000 kit units centred on the origin (a design's optional `canvas: [w, h]` overrides it, as in `render_design`). The dashed rectangle shows it; parts must stay inside.
- The **composed sprite** is what the renderer crops: the bounding box of all visible parts' pixels (alpha above 0.02), plus a 24-unit margin, widened so the centre line stays at x = 0.

## Design file (`<hull_id>.design.json`, format `tv-ship-design/1`)

The main output. All positions are kit units in design space. Unknown fields at any level are kept when loading and saving, so the format can grow. Parts, hardpoints, engines and lights are written one per line.

```json
{
  "format": "tv-ship-design/1",
  "name": "sow_c_a_clamp",
  "display_name": "SOW C-A Clamp",
  "kit": "sow",
  "units_per_game_px": 12.5,
  "parts": [
    {"part": "base_02", "x": 0, "y": -165, "rot": 0, "scale": 0.78, "flipX": false, "flipY": false, "z": 1, "shadow": 0.55, "glow": null, "label": "neck collar", "group": null, "mirror_link": null}
  ],
  "hardpoints": [{"id": "T1", "size": "small", "mount": "turret", "x": 0, "y": -40, "arc": 360, "facing": 0}],
  "engines": [{"x": -21, "y": 254, "size": 1, "dir": 180}],
  "hit": {"type": "capsule", "size": [466, 940], "offset": [0, -205]},
  "lights": [{"x": -200, "y": 100, "colour": "#ff4a3d"}]
}
```

| Field | Meaning |
| --- | --- |
| `name` | Hull ID (lowercase snake_case); also the file name and hull.json `id` |
| `display_name` | Optional; hull.json `name` |
| `kit`, `units_per_game_px` | Kit the parts come from and its scale (from the kit manifest) |
| `parts[].part` | Part id in the kit manifest |
| `parts[].x`, `y`, `rot`, `scale`, `flipX`, `flipY`, `z` | Placement (see Coordinates). Missing values default to 0, 0, 0, 1.0, false, false, 0 |
| `parts[].shadow` | Contact-shadow strength 0–1 the renderer casts on what's under the part. Default 0.55 |
| `parts[].glow` | `"exit"` lights the part's lower edge (engine exits) or `null`. New parts take the kit's `glow` |
| `parts[].label` | A name for the layers list only |
| `parts[].group` | Group id (`"g1"`…) or `null`; grouped parts select together |
| `parts[].mirror_link` | Link id (`"m1"`…) shared by a mirrored pair, or `null` |
| `parts[].hidden`, `locked` | Written only when true. `hidden` parts are left out of the composite, hull.json and previews; the renderer must skip them too. `locked` is editor-only |
| `hardpoints[]` | As hull.json hardpoints (`id`, `size`, `mount`, `arc`, `facing`, `traverse`, `role`, `part`, `cells`), with `x`, `y` in kit units instead of `pos` |
| `engines[]` | `x`, `y`; `dir` in degrees clockwise from the nose (180 = straight aft, the default); `size` (1 = normal) |
| `hit` | `type: "capsule"`, `size: [width, length]`, `offset: [x, y]`, all in kit units; `offset` is the capsule centre in design space |
| `lights[]` | `x`, `y`, `colour` (`#rrggbb`) for nav and beacon lights (optional) |
| `canvas` | Optional `[w, h]` render canvas, kit units (default 2400 × 4000) |

`art_src/sow/kit_v2/example_design.json` is a valid design.

## hull.json (schema 1)

The same manifest `tools/hardpoint-editor` writes, built with the same shared code. Marker positions become **art pixels from the composed sprite's centre**: kit units ÷ `units_per_game_px`, with the centre at x = 0 and halfway between the composed sprite's top and bottom. If the parts sit off-centre, the sprite is widened rather than moved (a check says so). `size_px` is the composed sprite in game pixels, `sprite` is `<hull_id>.png` and `scale` is 1. Engine `dir` and `size`, and lights, have no hull.json field yet, so they stay in the design file only. A turret or pivot `arc` equal to the mount default is left out, as the hardpoint editor does.

## Preview PNGs

**Save preview PNGs** writes `<hull_id>_preview_game.png` (1:1 game pixels) and `<hull_id>_preview_x3.png` (3×), the parts flattened on transparency. They are for reference, not production art: no contact shadows or glow.

## Kits

A kit is a folder (or zip) with `manifest.json` and the part images. The tool finds `manifest.json` anywhere inside and resolves each part's `file` beside it, so it doesn't assume a path or a manufacturer.

```json
{
  "kit": "sow", "version": 2, "units_per_game_px": 12.5,
  "orientation": "nose up, +y aft",
  "image_units": "part images are 1 px = 1 kit unit at scale 1.0",
  "parts": [
    {"id": "base_00", "file": "base_00.png", "category": "nose_cap", "w": 320, "h": 224,
     "default_scale": 1.0, "mirror_of": null, "glow": null, "note": null}
  ]
}
```

The palette groups parts by category. It knows the part categories in `designer.js` (`KNOWN_CATEGORIES`) plus any a manifest lists in an optional `"categories"` array; anything else goes under **misc**. The image's own size wins over `w`/`h` (the renderer uses the image). Reading a zip loads JSZip 3.10.1 from cdnjs, so it needs a connection; folders work offline.

## Checks

The hardpoint editor's checks (shared code, mirroring the game loader's rules) run on the hull.json the design would export, plus:

- parts reaching off the render canvas (error), and parts not in the open kit (error);
- no engine parts (engine pods, bells, large engines or `glow: "exit"`), and no engine exhausts;
- a hardpoint not over any part;
- a `nose_cap` without a `nose_module` drawn under it, with the cap overlapping the module's top edge;
- a broken mirror link, a design for a different kit or scale, and an off-centre composite.

Click a check to select what it's about.

## Files

| File | What |
| --- | --- |
| `index.html` | Page and styles |
| `designer.js` | The designer |
| `../shared/hull-markers.js` | Marker conventions, drawing, mirror pairing, hull.json output and checks, shared with `tools/hardpoint-editor`. Change marker rules there, once |

`window.__designer` exposes a few functions for automated checks (load a kit, open a design, read the hull.json); the UI doesn't use it.

## Keep in step

- With the game: the checks mirror the loader's rules (`scripts/data/ship_def.gd`, `hardpoint_def.gd`) and the mount defaults mirror `data/game.json` `mounts`, through `tools/shared/hull-markers.js`. When OF7 changes the manifest, update the shared file and both tools in the same change.
- With the renderer: transform order, the render canvas, the 24-unit margin and the alpha threshold match `art_src/sow/kit_v2/scripts/compose.py`. If the renderer changes any of them, change `designer.js` too.
