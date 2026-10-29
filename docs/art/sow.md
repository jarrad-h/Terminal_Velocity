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
| P-B | Patrol corvette (2 light turrets, VLS-4 strip launcher) | `ships/sow_p_b_patrol.png` |
| K-A | Boarding cutter (docking collar + clamps, 1 light turret) | `ships/sow_k_a_boarding.png` |
| K-B | Escort cutter (heavy turret, tapered neck, VLS-4 strip, 2 PD, small nacelles) | `ships/sow_k_b_escort.png` |
| R-A | Gun cruiser (2 heavy + 2 light turrets, 2 PD, forward guns, big nacelles) | `ships/sow_r_a_gun_cruiser.png` |
| R-B | Missile cruiser (2× VLS-3 round-hatch batteries, heavy + 2 light turrets, 2 PD, big nacelles) | `ships/sow_r_b_missile_cruiser.png` |

Armed hull sprites have **empty turret rings**; turrets are separate sprites (`parts/tur1.png` light twin, `parts/tur2.png` heavy twin, `parts/pd1.png` point defence) whose **image centre is the pivot**, barrels pointing up at rotation 0. Larger armed hulls stay on the standard 46 px plate and grow by length. A neck is always taper (TPR, standard hull plating) → narrow spine (SPN-N) → taper back out. Engine nacelles (NAC, NAC big) hug the hull on short stub pylons and splay 8° outward towards the stern. Missile launchers come in two styles: VLS-4 centre strip (`parts/msl_vls_strip.png`) on small hulls, VLS-3 round hatches (`parts/msl_vls_round.png`) on cruisers.

`preview/` holds the same hulls with turrets fitted, for reference only.

Every hull (civilian and armed) has its weapon hardpoints and engine exits in `assets/sprites/ships/sow/hardpoints.json`, summarised per ship in `docs/art/hardpoints.md` with mount type (fixed / turret / launcher) and size (small / medium / large), plus a labelled spec sheet image per hull in `docs/art/specs/`. Civilian turret segments also use empty rings now; no hull sprite has a baked-in turret.

## Kit standards

- Standard hull plate is 46 px wide (wide plate 70 px). Segment lengths step in 7 px; a standard segment (SEG-16) is 28 px long.
- Modules are joined by 2 px collars.
- One standard nozzle (N1) used in banks; N2 is the efficiency-focused cruise nozzle (C-C, F-A, F-B).
- Parts are in `assets/sprites/ships/sow/parts/` (codes match the concept board's parts list).

## Handoff notes for the game

These sprites are **not wired in yet**. The ship JSON still points at `ships/<id>.png`, which doesn't exist, so the placeholder arrows are used. Before wiring them in, decide:

1. **Scale.** The sprites are larger than the current hit radii (the shuttle is 48 × 119 px against `hit_radius` 13). Either scale the sprite node down, or raise hit radii and hardpoint offsets to match the art. Pick one rule for all ships.
2. **Hardpoints.** Use `hardpoints.json` / `docs/art/hardpoints.md`: every gun, turret ring, missile launcher and beam with its position. Turrets are separate rotating sprites on the rings.
3. **Engine glow.** Nozzles are painted unlit at the rim; glow should be an in-engine effect anchored at each nozzle exit.
4. **Solar panels** (C-C, F-A) are meant to roll toward the star as a separate sprite, with tilt frames still to draw.

## Regenerating

Sprites are generated, not hand-edited. Change the scripts in `art_src/sow/` and run:

```
python art_src/sow/export.py            # everything
python art_src/sow/export.py sow_f_a_stack n2   # just these
```

Needs Python 3.10+ with `numpy` and `Pillow`. `art_src/.gdignore` keeps Godot from scanning the scripts.

## Current ship data vs art (as of this branch)

Suggested sprite for each data ship, and where its current loadout (`data/ships/*.json`) doesn't match the hardpoints in the art. Decide per ship whether the data or the art changes.

| Data ship | Suggested sprite | Data loadout | Art hardpoints | Match |
|---|---|---|---|---|
| `shuttle` | S-A | 1 gun (nose) | 1× small turret, no fixed gun | ✗ |
| `courier` | C-B Booster | 2 guns + 1 turret | none (civilian) | ✗ |
| `freighter` | F-A Long stack | 1 turret | 1× small turret | ✓ |
| `patrol_corvette` | P-B Patrol | 2 guns + 1 turret + 1 guided | 2× small turret + 1× small missile launcher, no fixed guns | ✗ (P-A has 2× small fixed gun + 1× small turret, no launcher) |
| `pirate_raider` | pirates/pirate_raider | 2 guns + 1 beam | 2× small fixed gun + 1× small fixed beam | ✓ |
