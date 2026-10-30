# Stellars: gates and stations (first pass)

First-pass production art for Phase 2 milestone 2 (V9): one hyperspace gate and one station per owner. Jarrad has signed these off as stand-ins; more iterations will follow (the gate especially, which is expected to become more complex and animated later). Concepts and the picks are in `docs/art/concepts/` and on the claude.ai design canvas "Terminal Velocity Gates and Stations Concepts".

| Asset | Sprite | Size at 1:1 | Data radius | Owner |
|---|---|---|---|---|
| Gate, Halo | `stellars/gates/gate_halo.png` | 600 × 600 | 300 | consortium-built; whoever controls the system operates it |
| Authority station, Ring | `stellars/stations/station_authority_ring.png` | 480 × 480 | 240 | local authority (Standard Orbital Works build) |
| Trader station, Container yard | `stellars/stations/station_trader_yard.png` | 480 × 480 | 240 | independent traders |
| Pirate station, Hollowed rock | `stellars/stations/station_pirate_rock.png` | 480 × 480 | 240 | pirates |

Paths are under `assets/sprites/`. Each sprite's diameter is its stellar's data radius × 2, as the milestone 2 plan asked, so `sprite_scale` is 1 for all four.

![Halo gate, lit](stellars/gate_halo_lit.png)

## Files per asset

Same conventions as `docs/art/lighting.md`; every image is the same size and pixel-aligned, and **the image centre is the stellar's centre** (canvases are never cropped).

| File | What it is |
|---|---|
| `<name>.png` | Baked sprite, light from the top-left (unlit fallback). |
| `<name>_albedo.png` | Colours without baked shading. |
| `<name>_n.png` | Normal map (+X right, +Y up the image, +Z towards the viewer; flat = 128, 128, 255). |
| `<name>_e.png` | Always-on emission: beacons, windows, light strips, hot vents (and their heat on the rock). |
| `<name>_e_ring.png` | **Gates only.** The ring emitters and the aperture field. Hide this layer to close the gate; the beacons in `_e` stay lit. The field has no hull under it, so this image has alpha where `_albedo` doesn't; draw it additive and unshaded like `_e`. |
| `<name>.json` | Manifest: `id`, `name`, `size_px`, `sprite_scale`, `hardpoints`, and for gates `jump_point`. |

## Anchors and hardpoints

Positions are pixels from the sprite centre at 1:1 (× `sprite_scale`): +x right, +y down the image, same as ship hardpoints.

- **Gate `jump_point`:** `[0, 0]`, the centre of the field.
- **Station hardpoints** use the ship format (`id`, `size`, `mount`, `pos`, optional `role: "point_defence"`). Station sprites show **empty turret rings**; turrets are the existing SOW turret sprites (`ships/sow/parts/tur1.png` small, `tur2.png` medium, `pd1.png` point defence), image centre = pivot, barrels up at rotation 0. The review sheets fit them facing outwards.

| Station | Mounts |
|---|---|
| Authority ring | T1–T4 small turrets on the ring, T5–T6 medium on the hub, T7–T10 small point defence on the rim |
| Container yard | T1–T2 small turrets on the spine |
| Hollowed rock | T1 medium, T2–T4 small, on bolted plating |

## For the code session

- **Station weapons need a requirement.** The art carries mounts, but stations can't fire yet and nothing in the Phase 2 spec asks them to. The architecture note (WeaponMounts and Health reused for station turrets) is the natural route.
- **Hardpoint editor:** it can open these sprites, but it has no named anchor points (`jump_point`, future docking ports) and one hit capsule only; the yard and the rock would want compound shapes (OF7).
- **Manifests sit beside the sprites** in `assets/sprites/stellars/`. Godot will import the PNGs on the next run (no `.import` files committed with this branch).
- No large turret sprite exists yet; none of these stations uses a large mount.
- Pirates use SOW turrets for now; a pirate turret style is a later art task.

## Review sheets

`docs/art/stellars/`: `<name>_lit.png` (star from screen right, 18° up, turrets fitted), `_lit_sw.png` (star from the lower left), `_lit_2x.png` (2× detail), `gate_halo_closed.png`, and for stations `_rings.png` (empty rings) and `_hardpoints.png` (mounts labelled; point defence in amber).

## Regenerating

Generated, not hand-edited. Sources are in `art_src/stellar/`: `prod.py` (the production painters), `skit.py` (radial shapes, the ring emission channel, light maps on top of the SOW painter), `export.py`.

```
python art_src/stellar/export.py all                 # everything, production quality (about 30 minutes)
python art_src/stellar/export.py station_pirate_rock  # one asset
python art_src/stellar/export.py gate_halo --ss 4     # quick draft (overwrites the committed files)
```

Concepts: `python art_src/stellar/concepts.py gates|stations` writes `docs/art/concepts/`.

## Still to come in this art session

Planets (eight types at half size with `sprite_scale` 2, cloud, atmosphere and ring layers), a tintable star (quarter size, emission only), asteroid and debris variants, wrecks broken up from the SOW parts, nav buoys, and galaxy-map icons.
