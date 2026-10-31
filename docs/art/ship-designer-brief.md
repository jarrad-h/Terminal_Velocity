# Build a ship designer tool for Terminal Velocity

I want a tool for building ship hulls myself from a kit of painted parts, so I'm not describing layouts to Claude. I drag parts onto a canvas, arrange them, mark hardpoints and engine exhausts, and save a design file. Claude (in an art session) takes that design file and renders the final art: albedo, normal map and glow layer. Your job is the tool, not the rendering.

## Read first

- `tools/hardpoint-editor/index.html` and its `README.md`. That editor already places hardpoints, engines and the hit capsule, and saves `hull.json` (schema 1). Reuse its marker logic, its conventions, its keyboard scheme and its checks. Don't reinvent them.
- `data/README.md`, `data/game.json` (`mounts`) and one ship file such as `data/ships/freighter.json`, for the marker conventions.
- Whatever the game's loader does with `hull.json`, so the checks stay in step with it.

## Where things go

- Tool: `tools/ship-designer/`, a standalone browser page like the hardpoint editor. Double-click `index.html` and it works, with no install, server or build step. Plain JS and canvas. If you need a library (for example JSZip to read a zip), load a pinned version from cdnjs. If shared marker code makes sense, put it in a `.js` file both tools load. Don't fork it.
- Parts kit: I'll commit it to `art_src/sow/kit_v2/`. It holds `parts/*.png`, `manifest.json` and `example_design.json`, and I'll give you the files. The tool must not assume that path, because I'll open the kit folder or zip from disk.
- Work on an `art/*` branch and open a PR. Touch only `tools/` (plus the hardpoint editor if you share code with it) and docs.

## The parts kit

`manifest.json`:

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

- 118 parts in about 35 categories: nose_cap, nose_module, collar, hull_module, hull_module_t, flank, engine_pod, engine_bell, engine_large, aft_module, containers by colour, tanks, clamps, pipework, struts, turrets, guns, missile racks, armour plates, sensor masts, canopies and so on.
- Images are RGBA PNGs with transparent backgrounds, drawn top-down with the nose up.
- `mirror_of` names the left/right partner part, for example `base_06`/`base_12` flanks and `base_24`/`base_26` engine pods.
- `glow: "exit"` marks engine parts whose lower edge glows.
- `nose_module` (`shuttle_upper`) always sits directly under a `nose_cap`, and the cap overlaps its top edge.

Load the kit by choosing a folder (folder input or the File System Access API) or by dropping the folder or a zip. Unknown categories fall into "misc". Later kits from other manufacturers will use the same format, so don't hard-code SOW.

## Coordinates and scale (important)

- Design space is in kit units. x = 0 is the centre line, with +x to starboard (right) and +y aft (down), and the ship faces up.
- 12.5 kit units = 1 game pixel, read from the manifest's `units_per_game_px`.
- Each part has a position (its centre), a rotation in degrees with positive meaning counter-clockwise on screen, a uniform `scale` relative to its native image, `flipX`/`flipY`, and `z` (draw order, higher on top).
- Transform order is flip, then scale, then rotate about the part centre. Claude's renderer applies the same order, so what I see must match what comes back.

## Must have

**Canvas and view**
- Dark background (#0a0807), with a toggle for a checker or a light background.
- Centre-line guide, an optional grid with snap and an adjustable grid size, pan and zoom.
- A live game-size preview pane that shows the composed ship at 1:1 game pixels and at 3×, so I can judge readability.

**Parts palette**
- Thumbnails grouped by category, with a search box.
- Drag a part onto the canvas, or click it to add at the view centre.

**Editing**
- Select, multi-select (shift-click and marquee), move, nudge with the arrow keys (Shift for ×10).
- Rotate: free rotation with a handle, R/Shift+R for 90° steps, and snapping to 15° while holding a modifier.
- Uniform scale with a handle, plus a numeric field.
- Flip H and V, duplicate, delete, and bring forward/back or to front/back.
- Lock a part, and group/ungroup parts.

**Mirror mode**
- Placing or moving a part off the centre line keeps a mirrored partner on the other side in step.
- The partner uses `mirror_of` when the part has one; otherwise it's a flipped copy.
- I can break the link for a single part.

**Properties panel**
- Editable fields for x, y, rot, scale, flips, z, the glow flag and the contact-shadow strength (0 to 1, default 0.55) of the selected part.

**Layers list**
- Lists the parts in draw order, with drag to reorder, hide, lock and rename (a label only).

**Markers**, reusing the hardpoint editor's tools and data:
- **Hardpoints:** id, size, mount type (from `data/game.json` mounts), facing and arc for fixed mounts, plus mirror pairs.
- **Engine exhausts:** position, direction (default straight aft) and size.
- **Hit capsule:** with "fit to composed sprite".
- **Lights** (optional): position and colour, for nav and beacon lights later.
- Markers live in design space alongside the parts and move with the view.

**Checks**
- The hardpoint editor's checks, plus parts placed off-canvas, no engines, a hardpoint not over any part, and a `nose_cap` with no `nose_module` under it.

**Undo/redo, autosave and file actions**
- Unlimited undo and redo.
- Autosave to localStorage, wrapped in try/catch.
- New / Open / Save design.

## Exports

1. **Design file**, `<hull_id>.design.json`. This is the main output and the thing I hand to Claude. Format `tv-ship-design/1`:

```json
{
  "format": "tv-ship-design/1",
  "name": "sow_c_a_clamp",
  "kit": "sow",
  "units_per_game_px": 12.5,
  "parts": [
    {"part": "base_02", "x": 0, "y": -165, "rot": 0, "scale": 0.78, "flipX": false, "flipY": false,
     "z": 1, "shadow": 0.55, "glow": null, "label": "neck collar", "group": null, "mirror_link": null}
  ],
  "hardpoints": [{"id": "T1", "size": "small", "mount": "turret", "x": 0, "y": -40, "arc": 360, "facing": 0}],
  "engines": [{"x": -21, "y": 254, "size": 1.0, "dir": 180}],
  "hit": {"type": "capsule", "...": "same fields as hull.json, in kit units"},
  "lights": []
}
```

   - All positions in this file are kit units in design space. Keep unknown fields when loading and saving, so the format can grow.
   - `example_design.json` in the kit is a valid design and must load and look right.

2. **`hull.json`** (schema 1, as the hardpoint editor writes it). Markers are converted to art pixels measured from the composed sprite's centre: the centre of the bounding box of all visible parts, with the centre line kept at x = 0. Divide kit units by `units_per_game_px`. If the composed sprite would be off-centre horizontally, use the centre line anyway and widen the sprite to match.

3. **Preview PNG** of the composed ship at game size and at 3×, flattened on transparency. This is for reference only, not production art, so it doesn't need contact shadows or glow.

## Out of scope

- Rendering the final art (albedo, normal and glow layers). Claude's art pipeline does that from the design file.
- Cutting new part sheets. Claude does that and adds them to the kit.
- Any changes to the game itself.

## Open question to raise with me, not decide

The new art is painted at about 3× game size and shown smaller ("paint big, shrink on display"), while `hull.json` positions are 1:1 art pixels today. Say whether `hull.json` or the ship data needs a sprite scale field, and where the loader would read it. Propose the change, but don't make it in this PR.

## Done when

- I can open the kit, rebuild `example_design.json` from scratch by dragging parts, save it, reopen it and get the same result.
- The mirrored hardpoints and engines I place export to a `hull.json` that passes the existing checks and loads in the game.
- The README documents the keys, the file formats and the coordinate rules above.
- The tool works in current Chrome and Firefox by opening `index.html` directly.
