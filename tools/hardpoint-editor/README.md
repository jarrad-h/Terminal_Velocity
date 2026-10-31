# Hardpoint Editor

A standalone browser tool for placing hardpoints, engine exhausts and the hit capsule on a hull sprite, and saving the `hull.json` manifest (schema 1) that the game will read for hull geometry (Phase 2, OF7).

## Use

Open `index.html` in a browser (double-click it). No install or server needed.

1. **Open sprite (PNG)**, or drop the PNG on the canvas.
2. Pick **Hardpoint** (H), choose mount and size, click the hull. **Mirror** (M) places left/right pairs and keeps them in step when dragged.
3. Pick **Engine** (E) and click each exhaust.
4. Set the hit capsule, or press **Fit hit capsule to sprite**.
5. Fix anything under **Checks**, then **Save hull.json** and commit it beside the sprite on an `art/*` branch.

**Open JSON** also reads the existing art `hardpoints.json` (pick a hull) and prototype ship files, for migrating current hulls.

Keys: V select, H hardpoint, E engine, M mirror, arrows nudge (Shift ×10), Delete removes, Ctrl+Z / Ctrl+Shift+Z undo / redo, Space-drag or right-drag pans, wheel zooms.

## Conventions

Positions are art pixels from the sprite centre: +x starboard, +y towards the stern, art facing up (same as `data/README.md`). Mount types and default arcs follow `data/game.json` (`mounts`).

## Keep in step with the game

The editor's checks mirror the loader's rules. When the manifest format changes (OF7: compound hit shapes, sprite layers, size class, built-from parts), update this tool in the same change.

The marker code (mount defaults, marker drawing, mirror pairing, hull.json output and the checks) lives in `tools/shared/hull-markers.js`, which this page and `tools/ship-designer` both load. Change marker rules there, once; keep the folder layout so the relative `../shared/` path still resolves.

A published copy also exists as a claude.ai artifact; this file is the master. Republishing it means publishing `hull-markers.js` with it and pointing the script tag at that copy.
