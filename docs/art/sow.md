# Standard Orbital Works (SOW) — art direction and kit

SOW is the first ship manufacturer. It's an old shipyard that never rebranded: cheap, modular and no-frills, but not bad. Every hull is built from the same standard parts, so a new ship is mostly a new arrangement of existing sprites.

Concept board (exploration history, variants, parts list): the Claude design canvas "Terminal Velocity Concept Board".

## Style

- **Painted pixels at 1:1**, Starsector-style: each sprite is painted at high resolution and reduced to native size with a 64-colour palette, crisp alpha and a darker rim pixel (no black outline).
- **Light is baked in from the top-left** (placeholder, accepted). The sprite rotates in-engine, so the light rotates with it. Normal maps can be added later without redrawing.
- **Palette:** white deck plates over slate flanks, dark ribbed collars between modules, red livery (bow cap, aft band, emblem), cyan glass and engine glow.
- **Art faces up** (nose towards −Y), matching `data/README.md`.

## Hull designations

Class letter + size letter. A is the smallest hull in a class.

| Designation | Name | Sprite |
|---|---|---|
| S-A | Shuttle | `ships/sow_s_a_shuttle.png` |
| C-A | Clamp courier (one container) | `ships/sow_c_a_clamp.png` |
| C-B | Booster courier (side booster pods) | `ships/sow_c_b_booster.png` |
| C-C | Long-hauler (fuel module, N2 cruise drive) | `ships/sow_c_c_longhauler.png` |
| F-A | Long-stack freighter (N2 cruise drive) | `ships/sow_f_a_stack.png` |
| F-B | Container-spine freighter (twin N2) | `ships/sow_f_b_spine.png` |
| F-C | Wide-body freighter (6× N1, the quick heavy) | `ships/sow_f_c_widebody.png` |

### Armed hulls

| Designation | Name | Sprite |
|---|---|---|
| P-A | Picket corvette (armoured, forward guns, 1 light turret) | `ships/sow_p_a_picket.png` |
| P-B | Patrol corvette (2 light turrets, missile segment) | `ships/sow_p_b_patrol.png` |
| K-A | Boarding cutter (docking collar + clamps, 1 light turret) | `ships/sow_k_a_boarding.png` |
| K-B | Escort cutter (wide, heavy turret, missiles, 2 PD) | `ships/sow_k_b_escort.png` |
| R-A | Gun cruiser (3 heavy + 2 light turrets, 4 PD, forward guns) | `ships/sow_r_a_gun_cruiser.png` |
| R-B | Missile cruiser (3 missile segments, heavy + 2 light turrets, 4 PD, twin N2) | `ships/sow_r_b_missile_cruiser.png` |

Armed hull sprites have **empty turret rings**; turrets are separate sprites (`parts/tur1.png` light twin, `parts/tur2.png` heavy twin, `parts/pd1.png` point defence) whose **image centre is the pivot**, barrels pointing up at rotation 0. `preview/` holds the same hulls with turrets fitted, for reference only.

`mounts.json` lists, per armed hull, the sprite size and each turret mount (`kind`: `t1`/`t2`/`pd`) and fixed forward gun muzzle as pixel offsets from the sprite centre (+x right, +y towards the stern, art facing up). These map directly onto `hardpoints` once a scale rule is chosen.

## Kit standards

- Standard hull plate is 46 px wide (wide plate 70 px). Segment lengths step in 7 px; a standard segment (SEG-16) is 28 px long.
- Modules are joined by 2 px collars.
- One standard nozzle (N1) used in banks; N2 is the efficiency-focused cruise nozzle (C-C, F-A, F-B).
- Parts are in `assets/sprites/ships/sow/parts/` (codes match the concept board's parts list).

## Handoff notes for the game

These sprites are **not wired in yet**. The ship JSON still points at `ships/<id>.png`, which doesn't exist, so the placeholder arrows are used. Before wiring them in, decide:

1. **Scale.** The sprites are larger than the current hit radii (the shuttle is 48 × 119 px against `hit_radius` 13). Either scale the sprite node down, or raise hit radii and hardpoint offsets to match the art. Pick one rule for all ships.
2. **Hardpoints.** Gun and turret exit points in the ship JSON should line up with the art: the shuttle's turret ring is the centre of the second module. Turrets will become separate rotating sprites (TUR-1) on mount points in the armed-hull pass; until then they're baked into the hull.
3. **Engine glow.** Nozzles are painted unlit at the rim; glow should be an in-engine effect anchored at each nozzle exit.
4. **Solar panels** (C-C, F-A) are meant to roll toward the star as a separate sprite, with tilt frames still to draw.

## Regenerating

Sprites are generated, not hand-edited. Change the scripts in `art_src/sow/` and run:

```
python art_src/sow/export.py            # everything
python art_src/sow/export.py sow_f_a_stack n2   # just these
```

Needs Python 3.10+ with `numpy` and `Pillow`. `art_src/.gdignore` keeps Godot from scanning the scripts.
