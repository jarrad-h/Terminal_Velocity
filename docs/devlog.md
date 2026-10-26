# Devlog

One entry per milestone: what was built (by requirement ID), deviations from the spec and why, known issues, and the key tuning values at the end of the milestone. Newest first.

---

## Milestone 4: AI and governments (26 Oct 2026) — awaiting playtest

### 2026-10-26 — Milestone 4 playtest notes (Jarrad)

Notes received and how they were sorted:
- **Tuning:** weapon range looked short. Effective range equals the visible tracer (range = shot lifetime). `light_laser` range 700 → 1000, `flak_turret` 450 → 1000, so shots cross the screen (half-diagonal ≈ 920 px). `mining_beam` left at 300 pending Jarrad.
- **Design, agreed:** G3 applies to every ship of a government, not only warships (spec and decisions updated). Pirates can become non-hostile through future missions that raise the player's pirate record.
- **Design, agreed and built** (spec and decisions updated):
  - **C8:** R nearest hostile, Tab nearest any, Shift+R cycles hostiles, Shift+Tab cycles all.
  - **A8 + G2 leniency:** a per-ship grievance replaces faction-wide provocation. Only the ship pushed past its tolerance turns hostile, and the attack penalty is charged then. Allies ignore it; the rest of the government reacts only through the record.
    - Governments: `tolerance_pct` (law 20, traders 25, pirates 10) and `forgiveness_pct_per_s` (4 / 5 / 2).
    - Personalities: `tolerance_factor` (aggressive 0.5, cautious 1.5).
    - Radar shows annoyed ships in amber.
  - **C6:** `shield_recharge_delay` (3 s default). Any hit resets it.
  - **C12:** weapon damage falloff with distance; shots and beams fade to show it. `mining_beam` range 300 → 1000, falloff from 30% of range down to 10%.
- **Tuning to watch:**
  - Traders' high flee threshold (60%) means a damaged trader often runs rather than fighting back, even when brave.
  - The beam's fade mostly happens off-screen at zoom 1 (screen top ≈ 450 px ≈ 80% damage). Lower `falloff_start_pct` if you want it visible.


Branch `m4-ai-governments`. Built in the cloud session (no godot MCP there; runs checked headless and under a virtual display).

### Built

- **G1–G3, A8 relations.** `Relations` (pure, tested) decides hostility. Governments are hostile if either lists the other as an enemy. A government's ships treat the player as hostile below its `crime_threshold`; pirates' 1000 threshold makes them hostile from the start. **A8:** a ship the player damages, and its government's warships, stay hostile until the player leaves the system. Ships also remember non-allied attackers.
- **G2 legal record.** A `GameState` autoload holds credits and the record per government (starting values in `game.json` → `player`). Penalties apply once per ship per act (first hit, disable, kill); boarding comes in M5.
- **A1–A4, A7 AI.** One `AIController` produces the same `FlightInput` as the player, so AI obeys the same flight model and weapons.
  - **Traders:** fly planet to planet, dock (hidden, untargetable) for `dwell_time`, relaunch, and leave via the edge after `stops` planets.
  - **Warships:** patrol near system objects.
  - **Pirates:** roam.
  - **Group vs individual (A7):** the government plus AI pool set friends and foes, role, base odds and flee threshold. A personality (new `personality` type: steady, brave, aggressive, cautious, skittish, weighted per pool) shades the odds factor, the flee offset, fight-or-flee when attacked, and whether it starts fights.
  - **A5:** before starting a fight, compares friendly against hostile strength within `sensor_range`.
  - **A4:** below the flee threshold, traders run to the nearest planet and land for good; others jump out at the edge.
  - **Steering** (`Steering`, pure, tested against the real flight model): arrive with turn-around braking, lead aiming, fire only when aligned (turrets fire whenever in range).
- **A6 traffic.** `TrafficSpawner` keeps each system traffic entry at its count. The system starts populated, outside the player's sensor range. Replacements jump in at `edge_radius` or take off from a landable planet after `respawn_delay`.
- **C11 friendly fire.** AI shots on their own or allied governments' ships do `combat.friendly_fire_pct` % (100 now; 0 turns it off). Player shots always do full damage.
- **C8:** R targets the nearest hostile ship.
- **H1:** the HUD shows credits.
- **H2:** radar ships are red (hostile), green (friendly) or grey (no government).
- **Debug.**
  - D3: spawn an AI pool with a count and government override.
  - D4: AI paused; radar shows all ships.
  - D6: set credits and the record per government (the panel marks governments hostile below threshold).
  - Traffic on/off.
  - The panel now scrolls.
- **Tests.** Unit tests for Relations (incl. friendly fire), Behaviour, WeightedPick and Steering. The scenario test covers:
  - a pirate raid on a trader drawing in the patrol
  - a steady trader fleeing and a brave trader fighting back
  - G2 once per ship, the G3 threshold, A8 provocation
  - C11 scaling, AI pause, D3/D6, and the A6 refill

### Deviations and why

- **Two-level AI behaviour (A7)**, provoked (A8), friendly-fire % (C11), once-per-ship penalties and docking traders were agreed in design before building. See `docs/decisions.md` (2026-10-26).
- **Disabled AI ships stay in space** (boarding is M5) but stop counting towards traffic, so replacements still arrive.
- **The odds check runs only before starting a fight.** Ships that fight back when attacked do so whatever the odds; retreat is left to the A4 shield threshold.
- **Single-ship debug spawns stay idle;** pool spawns get AI.
- **Initial traffic spawns outside the player's sensor range** (× 1.2) so nothing opens fire the moment the system loads.

### Known issues

- **Radar colour for low-record traders:** hostility to the player is a government's record rule, so traders turn red on radar below their own threshold even though they never attack (they only flee).
- **AI dogfighting is simple:** face the lead point, thrust until within `standoff_fraction` of weapon range, so fights look like jousting passes.
- **AI doesn't finish off disabled ships** and doesn't board (M5).
- **AI friendly fire changes no records;** only the player's record is tracked.
- **Spec question (G3, open):** the spec says "that government's **warships** turn hostile" below the crime threshold. The code makes **every** ship of that government hostile, which pirates rely on for A3. So low-record traders show red and brave or aggressive traders may fight. Waiting on Jarrad.

### Review (godot-reviewer, before handover)

Verdict was "fix first"; all fixed in `m4: review fixes`:
- docked traders reappeared after a hot reload;
- disabled traffic ships were never freed on a system switch;
- attacks didn't end when the target stopped being hostile;
- a freed-ship filter used a typed lambda;
- friendly fire was lost when the shooter died;
- zero-weight pools were accepted;
- several hard-coded spawn and patrol numbers (now `game.json` → `ai.*`);
- personality and game.json sections had no loader tests.

### Key tuning values

| | Sensor range | Stay | Personality weights |
| --- | --- | --- | --- |
| trader_traffic | 1200 | — (dwell 6–12 s, 1–3 stops) | skittish 3, cautious 3, steady 2, brave 1, aggressive 1 |
| authority_patrol | 1800 | 90–180 s | steady 3, brave 2, aggressive 1, cautious 1 |
| pirate_raid | 1600 | 60–120 s | aggressive 3, brave 2, steady 2, cautious 1 |

Personalities (odds × / flee offset / when attacked / starts fights): steady 1/0/role/role · brave 1.5/−15/fight/role · aggressive 1.25/−10/fight/on sight · cautious 0.6/+20/role/role · skittish 0.3/+40/flee/never.

Governments (max_odds / flee %): local_authority 1.5/15 · independent_traders 0.5/60 · pirates 2.0/30. Edge radius: test_nebula 7000, test_graveyard 6000. AI: landing speed 60, thrust angle 35°, standoff 0.4 × range, think every 0.25 s. Friendly fire 100%.

---

## Milestone 3: Fight (16 Oct 2026)

### Built

- **C1–C4 weapons.** `WeaponMounts` gives each equipped weapon an exit point of its kind (`hardpoints`), sharing points round-robin when weapons outnumber them.
  - Guns fire along the heading.
  - Turrets lead the selected target (`Aim.intercept_direction`) within their `arc`.
  - Guided missiles home on the target selected at launch at their own `turn_rate` for their lifetime.
  - Beams ray-test their length every physics frame while held.
  - Primary fire (Space) drives guns, turrets and beams; secondary fire (F / Left Ctrl) launches missiles.
- **C5–C7 damage.** `DamageModel` (pure) puts shield damage first, and a shield-breaking hit carries its unspent fraction through to armour. `Health` regenerates shields, disables at `disable_armor_pct` (33%) and destroys at 0. A disabled ship drifts with no input and can't fire.
- **C8 targeting.** R targets the nearest ship and Tab cycles nearest-first (`Targeting`, pure). Yellow brackets mark the target. A minimal HUD (top right) shows player shield and armour (H1) and the target's name, distance, shield and armour.
- **Dummy target.** A `target_dummy` ship (300 shield, 400 armour, no engines) spawns at (0, −450) in debug builds via `game.json` → `debug.spawn_at_start`.
- **L4 scenery damage.**
  - Shots and beams damage solid scenery through `Health`.
  - Destroyed scenery throws off its `fragments` as cosmetic `RigidBody2D` pieces that fade out.
  - `DestroyedScenery` keys destroyed objects by (chunk, scenery ID, placement index). The generator skips those keys, and the set clears on system change but survives hot reload.
  - Drifting solid scenery is generated at start + velocity × elapsed game time; non-solid scenery skips this.
- **System objects (S1, placeholder).** The star, planets and stations are drawn from the system file as flat circles with names.
- **H2 radar.** Bottom-right, centred on the player.
  - Ships are coloured by government, or neutral grey with none.
  - System objects beyond range sit as hollow pips on the rim.
  - The selected target is ringed.
  - Scenery shows only for `radar: true` types, read from a list `LocalSpace` keeps rather than by scanning scenery nodes.
  - Size, range, margin and colours come from `game.json` → `radar`.
- **Debug.**
  - D3: spawn any ship ID with a count and optional government, ahead of the player.
  - D4: player invulnerability.
  - D5: disable or destroy the target, and clear all non-player ships.
  - D9: the panel always shows the player's world position and chunk coordinates.
- **Tests.** Unit tests for DamageModel, Aim, Targeting, the destroyed set and the drift offset. The smoke test fires all four weapon kinds at the dummy, destroys scenery and revisits it, and checks the radar list and every new debug command.

### Deviations and why

- **C8 targets the nearest ship, not the nearest hostile.** Hostility needs governments and the legal record (M4).
- **Shots ray-test their path each frame** against the `Area2D` hitboxes (`HitQuery`) instead of using overlap signals. Fast shots (900 px/s, 15 px per frame) would otherwise tunnel through small debris.
- **Turrets hold fire** when the lead point is outside their arc, and fire straight ahead with no target (Nova behaviour).
- **Beams deal damage per second** and ignore `reload`.
- **Shields don't recharge while disabled.**
- **Player destruction:** the ship vanishes and stays gone until respawn (C10, M5). Swapping ship in the debug panel restores it.
- **Minimal HUD pulled forward** from M6: C8 needs the target's shield and armour on screen.
- **Ship swap and hot reload restore full shield and armour.**
- **Added data fields, each with a documented default:**
  - Ships: `disable_armor_pct` (33).
  - Weapons: `inherit_velocity` (true).
  - Scenery: `fragment_speed` ([20, 80]), `fragment_lifetime` (6).
  - `game.json`: `debug.spawn_distance`, `debug.spawn_at_start`, `radar.*`.
- **`target_dummy` is a sixth ship file.** It's test content, not one of the five prototype ships.
- **Placeholder ships are tinted by government** (player pale blue, neutral grey) so they can be told apart. The shape is still one arrow for every hull.

### Known issues

- **Drift offset pop-in.** A drifting object belongs to the chunk it was generated in. After a long stay in a system (drift speed × time > about one chunk, e.g. 70 s for 15 px/s debris), objects can appear or vanish at the edge of the loaded area as their home chunk loads or unloads. Possible fixes if it shows: load drifting types from a wider ring of chunks, or wrap drift within the home chunk.
- **Hull hitboxes are circles** of the generated size. Long derelict hulls are only hittable near their middle.
- **No friendly-fire rules yet:** shots hit any ship except the one that fired them (M4).
- **Spawned ships idle** (IdleController) until the AI controllers in M4.
- **Fragments have no hitboxes,** by design (cosmetic).

### Key tuning values

| Weapon | Kind | Shield / armour dmg | Speed | Range / life | Reload | Other |
| --- | --- | --- | --- | --- | --- | --- |
| light_laser | gun | 10 / 6 | 900 | 700 px | 0.25 s | |
| flak_turret | turret | 6 / 8 | 600 | 450 px | 0.6 s | arc 270° |
| homing_missile | guided | 30 / 45 | 400 | 4 s | 2.5 s | turn 140°/s |
| mining_beam | beam | 8 / 20 per s | — | 300 px | — | |

Ships (shield / armour): shuttle 120/80, courier 200/120, freighter 300/400, patrol_corvette 400/300, pirate_raider 180/150, target_dummy 300/400 (regen 10/s). Disable at 33%. Radar: 200 px across, 3000 px range.

---

## Milestone 2: Data loader and local space (14 Oct 2026)

### Built

- **Data loader.** `DataRegistry` loads all six types (ships, weapons, governments, AI pools, systems, scenery) from `data/` then `mods/`.
  - A later file with the same ID replaces the earlier one, and IDs must match file names.
  - Each type has a typed `Def` class with documented defaults (`data/README.md`).
  - Every cross-reference is resolved. Invalid data refuses to start with an on-screen list naming each file and field, and exits 1 headless.
  - Unit tests cover validation and the override rule.
- **D8 hot reload** re-reads everything and emits `data_reloaded`; ships, backdrop and scenery rebuild. A failed reload keeps the old data and shows the errors.
- **D2 ship swap** keeps position, heading and velocity. A debug command switches systems.
- **Content.** 5 ships, 4 weapons, 3 governments, 3 AI pools, 5 scenery types, and two systems:
  - `test_nebula`: heavy nebula, sparse dust and rocks.
  - `test_graveyard`: sparse nebula, a derelict-hull ring and an asteroid cluster.
- **B1–B2 backdrop.** A shader draws hashed stars and a FastNoiseLite nebula coloured by a gradient, on a screen layer moving at the system's parallax (0.02). Every setting comes from the system file.
- **L1–L3 local space.**
  - Scenery streams in 1024 px chunks around the camera, and distant chunks unload.
  - Each chunk is seeded from (system seed, chunk, scenery ID), so revisits match.
  - Density and whole/ring/circle regions come from the system file.
  - One generic Scenery scene, configured from data. Solid scenery gets a hitbox and Health; dust gets neither and may sit at a parallax depth.

### Deviations and why

- **Unknown fields are errors.** Typos (e.g. `top_sped`) would otherwise silently take defaults.
- **`game.json` (global settings) isn't one of the six types.** It merges field by field from `mods/`, while definitions replace whole files.
- **Extra fields**, each with a documented default:
  - Ships: `hit_radius`.
  - Scenery `placeholder.*`: generic placeholder art.
  - Backdrop: `base_colour`, `stars.spacing`, `nebula.softness`, `noise.texture_size`, `noise.scale`.
- **Density unit:** objects per 1,000,000 px².
- **The gas giant is a non-landable `planet`;** there's no separate object type.
- **The player starts in the courier,** because the M2 done-check names `courier.json`. Set `game.json` → `player_ship` to `shuttle` to match the content table.
- **The smoke test is a scene,** because scripts run via `--script` can't see autoloads.

### Known issues

- An exported build needs `*.json` in the export include filter.
- `--quit` exits 0 even after script errors, so read the output.

### Key tuning values

- **Backdrop:**
  - `test_nebula`: coverage 0.75, intensity 0.85, frequency 0.004, 6 octaves.
  - `test_graveyard`: coverage 0.2, intensity 0.4.
  - Parallax 0.02 in both.
- **Dust:** size 2–3.5 px, depth 0.9–1.1. Density 30 in `test_nebula`, 35 in `test_graveyard`.
- **Graveyard ring:** radius 1200–3200 around (0, 0).
- **Chunk size:** 1024 px.

---

## Milestone 1: Fly (13 Oct 2026)

### Built

- **F1–F3:** kinematic `FlightModel` (pure, unit-tested) with fixed-rate turning, thrust along the heading, a hard speed cap and no drag. Reverse (Down/S) turns to face against the velocity.
- **F4:** a follow camera and, at the time, a parallax starfield (replaced by the backdrop and local space in M2).
- **D1:** debug panel on backtick, debug builds only.
- **D7:** time scale 0.25×–4×, pause, single-frame step.
- **D9:** overlays for hitboxes, velocity vectors, state labels, and FPS / counts.
- All debug actions go through the `DebugCommands` autoload.

### Deviations and why

- **Reverse only turns;** braking is reverse plus thrust, as the spec words it.
- **2D physics interpolation is enabled,** for smooth motion on high-refresh displays.
- **A minimal data reader existed in M1** so flight values came from `courier.json` before the M2 loader.

### Key tuning values

- **Courier:** accel 300 px/s², top speed 320 px/s, turn 180°/s.
- **Camera:** zoom 1, no smoothing.
- No playtest tuning changes recorded yet.
