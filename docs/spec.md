# Terminal Velocity Prototype — Requirements & Scope

Source of truth for design. Edit this file (not a chat or external doc) when design changes. Requirement IDs are stable; never renumber.

## Purpose and success criteria

The prototype proves that ship-to-ship combat in one star system is fun and that every ship, weapon and government is defined in data files, not code. It is a throwaway-quality game but a keep-quality data layer.

The prototype is done when:

1. The player can fly, fight and destroy, disable or board AI ships in one system for 10 minutes without it feeling flat.
2. Traders, warships and a hostile pirate faction behave visibly differently, driven by government relationships.
3. Adding a new ship or weapon needs only a new data file and a sprite, with no code change.
4. Tuning a stat (speed, shield, damage) in a data file changes the game on the next run.
5. Landing on a planet opens a stub screen that repairs the ship, proving the space-to-landed transition.

## Scope

One system, one player ship, combat and AI first; everything that needs more than one system or a story waits.

| Area | In the prototype | Out (later milestones) |
| --- | --- | --- |
| World | One system: a star, 2–3 planets, 1 station, a noise-generated backdrop, local debris and an asteroid field | Multiple systems, hyperspace, galaxy map, fuel (spent only on jumps and afterburners) |
| Player ship | Fly, fire, take damage, be disabled, die and respawn | Buying ships, escorts, capture keeping the ship |
| Weapons | Lasers, beams and guided missiles in sizes and mount types (fixed, pivot, turret, launcher) | Buying and fitting weapons, missile variants, point-defence behaviour (C13), afterburner, ammo economy, ion, jamming, cloaking |
| Damage model | Shields, armour, disabled state, destruction | Armour recharge, repair systems |
| AI | Trader, warship and pirate behaviours, flee threshold | Interceptor scanning, bribes, hailing |
| Governments | 3 governments with ally/enemy relations and a legal record | Reputation spreading to allies, ranks |
| Boarding | Board a disabled ship for credits | Plunder of cargo and outfits, capture odds |
| Landing | Stub screen: repair, take off | Shipyard, outfitter, trade, bar, missions |
| Data | Ships, weapons, governments, AI pools, system definition | Missions, flags, crons, persons, plugins |
| Presentation | Generated ship art for the SOW hulls and the pirate raider (scope change 2026-10-29), placeholder art for everything else, basic HUD, radar | Final art beyond ships, audio polish, menus, save/load |
| Debug | Debug panel and console: ship swap, spawning, invulnerability, time scale, data hot-reload, overlays | Player-facing cheats, mission and flag debugging |

## Functional requirements

Each requirement has an ID so later milestones and tests can refer to it.

**Flight**

- F1: Thrust, turn and reverse-thrust (turn to face opposite velocity) controls, keyboard first, gamepad later.
- F2: Velocity is capped at the ship's top speed; there is no drag, so the ship drifts when not thrusting.
- F3: Acceleration, top speed and turn rate come from the ship definition.
- F4: The camera follows the player; speed reads from passing local-space objects (L1), while the distant backdrop barely moves (B1).
- F5: Holding T keeps the ship turning to face the selected target's lead point (where its primary guns must aim to hit), at the ship's normal turn rate; thrust and fire stay manual.

**Backdrop and local space**

- B1: The backdrop is distant stars plus nebula generated from noise (Godot's FastNoiseLite), drawn behind everything with a very small parallax factor (default 0.02, so it moves 2% of camera motion).
- B2: Each system sets its backdrop in data: star density and brightness, nebula coverage and intensity, a colour gradient, noise seed, frequency and octaves, and the parallax factor. The balance of stars to nebula is a data change.
- L1: Local space is filled with scenery in world space, from dust through to large asteroids, moving past at true speed so it carries the sense of motion. Dust is cosmetic only and may use a depth of 0.9–1.1 for slight layering.
- L2: Scenery is generated in chunks around the player from the system seed, so the same place always holds the same objects; distant chunks unload.
- L3: Each scenery type is a data definition; a system lists the types it uses, each with a density and an optional region (whole system, ring or circle). Swapping dust and asteroids for wrecks, flora or fauna is a data change, and a behaviour field (static or drift now) leaves room for moving fauna later.
- L4: Solid scenery uses the same Health component as ships (armour only), so weapons can hit it from milestone 3; destroyed objects can spawn fragment scenery as cosmetic RigidBody2D pieces. Ships pass through scenery, as they pass through each other. Destroyed scenery stays destroyed until the player leaves the system (an in-memory set, cleared on system change). Drifting solid scenery spawns at its start position plus velocity × elapsed game time, so reloaded chunks don't snap it back; dust and other non-solid scenery skip this.

**Combat**

- C1: Weapons fire from the ship's hardpoints; each hardpoint has a size and a mount type, and a weapon fits only a hardpoint of its size and mount (V3).
- C2: Fixed weapons fire along the ship's heading; pivot mounts track the selected target within a narrow forward arc; turrets rotate to track it within their arc (V3, V4).
- C3: Guided missiles home on the target with their own turn rate and lifetime.
- C4: Beams hit instantly along their length while held; their damage can fall off with distance (C12).
- C5: Damage hits shields first, then armour; weapons can weight shield vs armour damage differently.
- C6: Shields start recharging only after a set time without taking damage (any hit resets it), then refill at a set rate up to their cap; armour does not recharge in the prototype. Recharge delay, rate and cap are per-ship stats that later upgrades will modify.
- C7: A ship is disabled at 33% armour (drifts, cannot fire) and destroyed at 0%.
- C8: R selects the nearest hostile ship and Tab the nearest ship of any kind; Shift+R cycles through hostile ships and Shift+Tab through all ships, nearest first. The HUD shows the target's shield and armour.
- C9: A disabled ship can be boarded by stopping alongside it (within a set range and relative speed) and holding position while a short boarding timer runs (cancelled by drifting away or taking damage). The game then pauses on a boarding window with options: **Take credits** (credits from the hull's range × the AI pool's wealth factor, with randomness; G2 board penalty), **Assist** (patch it up so it leaves the system; raises the player's record with its government), **Scuttle** (destroy it; G2 kill penalty) or **Leave** (no action). Earlier choices limit later ones (after taking credits only Scuttle or Leave remain; a ship can be assisted only once); after Leave the player may reboard any time. Disabled ships stay in the system until the player leaves it.
- C10: When the player's ship is destroyed and they own an escape pod, the pod launches at high speed for a few seconds, then a window reports that days have passed and who rescued them, charges a rescue fee (a share of credits) and wakes them landed at the nearest port that will accept them (G4), else any landable port. If insured, the ship is replaced like for like; if not, they get a basic hull. Rescue counts as leaving and returning: wrecks and destroyed scenery are cleared and traffic refreshed; legal record and grudges remain. Without an escape pod, the game ends ("lost with all hands", restart). Until outfits exist, escape pod and insurance are data flags that start owned.
- C11: AI shots damage ships of their own and allied governments at a percentage set in data (100 = full damage, 0 = friendly fire off). The player's shots always do full damage.
- C12: A weapon's damage can fall off with distance (shot travel or beam length): full damage up to a set fraction of its range, falling linearly to a set minimum at full range. Shots and beams fade with distance so the falloff is visible.

- C13 (specified now, built when a hull with point-defence mounts enters the game): point defence is a small turret weapon with a point-defence role. It runs its own behaviour: it fires automatically, without player or AI input, at incoming missiles (and later other threats) in range, rather than at the selected target. The role tag lives on the hardpoint (and picks the PD turret sprite); the behaviour lives on the weapon.

**AI**

- A1: Traders fly between planets, land, and take off again (the same ship docks for a while, then launches); they flee when attacked unless their personality makes them fight back (A7).
- A2: Warships patrol and attack ships of enemy governments, including the player when hostile.
- A3: Pirates attack traders and the player on sight.
- A4: Each AI ship retreats below a shield threshold set by its government.
- A5: Before engaging, AI compares the summed strength of each side against its government's maximum odds.
- A6: Traffic spawns at the system edge or from planets to keep a target population, and leaves when its job is done.
- A7: AI behaviour works at two levels. The **group** (government plus AI pool) sets standing and broad behaviour: who is friend or foe, the role (trader, warship, pirate), base odds and flee threshold. The **individual** gets a personality, picked by weight from its AI pool, that shades behaviour within those rules: how long the odds it accepts, how early it runs, whether it fights back when attacked and whether it starts fights with its enemies. A personality never changes who a ship's friends and enemies are.
- A8: Leniency (replaces the earlier "provoked" rule, 2026-10-26): damage the player does to a ship that isn't hostile to them builds that ship's grievance, measured as a share of its total shield plus armour, which drains over time. Only when grievance passes the ship's government's tolerance (shaded by its personality) does that one ship turn hostile to the player; accidental shots are forgiven. Other ships of its government turn hostile only through the legal record (G3), and allies ignore it. Pirates follow the same rules; they simply start hostile.

**Governments and legal record**

- G1: Each ship belongs to a government; governments declare allies and enemies.
- G2: Attacking, disabling, boarding or destroying a government's ship lowers the player's record with it by set amounts. The attack penalty applies once per ship, when that ship's grievance passes its tolerance (A8); a ship already hostile through the record counts as past its tolerance, so the first hit charges it. Disable, board and destroy apply once each, immediately.
- G3: Below a crime threshold, that government's ships turn hostile to the player; its warships attack, while traders and other non-combat roles only act on it as their personality allows (A7). A government with a very high threshold (pirates) is hostile from the start until the player's record with it rises.
- G4: A planet refuses landing when the player's record with its government is below its minimum.
- G5: Standing (shown on the radar and target panel): a ship is **hostile** when it treats the player as hostile (G3, A8), **angry** when it holds a grievance against the player but isn't hostile yet (A8), **friendly** when the player's record with its government is at or above that government's `friendly_record`, and **neutral** otherwise (including ships with no government).

**System and landing**

- S1: The system is loaded from a data file: positions of the star, planets and station, and the traffic pools.
- S2: The player lands by approaching a planet slowly and pressing land (L): within a set fraction of its radius and below a set speed (shared with AI landing). Pressing L elsewhere only shows a hint. The world pauses while landed.
- S3: The landed screen shows the planet's name and description, and offers repair and take off.

**HUD**

- H1: Your ship's name, shield and armour bars, credits, and a disabled warning.
- H2: A small radar in a screen corner shows ships, system objects (star, planets, stations) and the selected target around the player. Ships are coloured by standing (G5): hostile, angry (warning colour), friendly or neutral. Scenery appears only when its definition sets radar visibility, which the prototype data sets on large asteroids and derelict hulls; dust, small debris and rocks never show. Radar range comes from data. When the selected target is beyond radar range, an arrow on the radar rim points towards it.
- H3: Target panel (milestone 7): a schematic of the target (a flat silhouette of its sprite, nose up; placeholder ships use their arrow shape) whose fill shades from green through yellow to red as its armour falls, inside a glowing outline that fades as its shield drops; grey when disabled. Beside it: shield and armour readouts (bars and numbers), the ship class (its ship name), its type (role: trader, warship, pirate), government, standing (G5, coloured as on the radar), distance, and a hint line (e.g. "Disabled: B to board").
- H4: Message line for events, colour-coded by kind: hints and refusals, combat (target disabled or destroyed), standing (a ship turns hostile to you, A8; your record with a government crosses its crime threshold either way, G3), and credits gained. Timing (how long a message shows, its fade, how many lines) comes from data. A minimal version came forward into milestone 5; milestone 7 completes it.

**Ship art (visuals)**

- V1: Ships with generated art draw their sprite at 1:1 times one global `art_scale` (game.json, default 1.0). Hardpoint, engine and hitbox positions are copied from the art data (`assets/sprites/ships/*/hardpoints.json`, summarised in `docs/art/hardpoints.md`) and multiplied by `art_scale`, keeping any asymmetry. Ships without art keep their placeholder drawing.
- V2: The hitbox is a capsule (width × length, plus an offset) covering the main hull body; ornamental parts such as the freighter's solar panel are not hit. The hitbox overlay (D9) draws the capsule.
- V3: Mounts and sizes. Each hardpoint has an ID (from the art, e.g. T1, G2), a size (small, medium, large) and a mount type: **fixed** (fires along the heading), **pivot** (tracks the target within a narrow arc), **turret** (rotating, within its arc) or **launcher** (missiles). Each weapon has a size and the mount types it comes in; within one size a weapon's numbers are the same on every mount, only the aiming differs. A ship's loadout names, per hardpoint, the weapon and the mount the item is built for (an installed item records its mount, because later the player buys a weapon by mount type). The loader refuses a loadout whose weapon size or mount doesn't match its hardpoint. Arcs come from mount-type defaults in game.json (fixed 0°, pivot 30° total, turret 360°) and a hardpoint may override its arc.
- V4: A turret weapon draws a turret sprite as a rotating child on its ring (image centre is the pivot, barrels up at rotation 0): small turrets use `parts/tur1.png`, medium `parts/tur2.png`, and a point-defence hardpoint `parts/pd1.png`. Turrets turn at a traverse rate from data and their shots leave along the drawn barrel. Fixed guns, beams and launchers are part of the hull sprite.
- V5: Engine glow is drawn at each engine exit from the art data, brightening with thrust; colour and size come from data.

**Debug tools**

- D1: A debug panel toggles with the backtick key and exists only in debug builds.
- D2: Swap the player's ship to any ship ID in the data, keeping position and velocity.
- D3: Spawn any ship or AI pool near the player or at the cursor, with a count and a government override.
- D4: Toggles: player invulnerability, infinite ammo, AI paused, show all ships on radar.
- D5: Destroy or disable the current target; clear all AI ships from the system.
- D6: Set credits and the player's legal record with each government.
- D7: Time scale from 0.25× to 4×, plus pause and single-frame step.
- D8: Reload all data files at runtime, so tuning a JSON value needs no restart.
- D9: Overlays: hitboxes (capsules, V2), hardpoints and engine exits (V3, V5), velocity vectors, AI state labels, FPS and ship count. The debug panel always shows the player's world position and current local-space chunk (grid) coordinates.
- D10: A text console accepts the same actions as typed commands (for example `spawn pirate_raider 3`); panel and console call one shared command layer.

## Data requirements

Seven definition types load from JSON files at startup; IDs are readable strings, and references use explicit fields rather than Nova's numeric offsets.

| Type | Defines | Key fields |
| --- | --- | --- |
| `ship` | A hull class | name, sprite, hit\_size and hit\_offset (V2), mass, accel, top\_speed, turn\_rate, shield, shield\_regen, armor, hardpoints (id, size, mount, position, optional arc, traverse and role; V3), engines (V5), loadout (per hardpoint: weapon and mount; V3), strength, crew, shield recharge delay, board credits range (C9) |
| `weapon` | A laser, beam, flak or missile | kind (projectile, beam, guided), size, mounts it comes in (V3), damage\_shield, damage\_armor, range or lifetime, speed, reload, turn\_rate (guided), damage falloff (C12), sprite or colour, sound |
| `government` | A faction | name, colour, allies, enemies, crime\_threshold, friendly\_record (G5), penalties (shoot, disable, board, kill), max\_odds, flee\_shield\_pct, tolerance and forgiveness (A8), assist reward (C9) |
| `ai_pool` | A traffic type (Nova's dude) | government, behaviour (trader, warship, pirate), weighted list of ship IDs, weighted list of personality IDs, sensor range, stay and dwell times, wealth factor (C9) |
| `personality` | An individual AI temperament (A7) | name, odds factor, flee threshold offset, response when attacked, whether it starts fights, tolerance factor (A8) |
| `system` | The one star system | name, objects (star, planets, station with position, sprite, description, landable, min\_record), traffic (pool ID + target count), edge radius, backdrop (B2 settings), local\_space (scenery IDs with density and region), seed |
| `scenery` | A local-space object type | name, sprites (random pick), size range, spin range, drift range, depth, solid, armor, fragments (scenery ID + count), behaviour, radar (shown on radar or not) |

An example ship file:

```json
{
  "id": "courier",
  "name": "Courier",
  "sprite": "ships/courier.png",
  "mass": 40,
  "accel": 300,
  "top_speed": 320,
  "turn_rate": 180,
  "shield": 200,
  "shield_regen": 6,
  "armor": 120,
  "strength": 10,
  "crew": 2,
  "hardpoints": [
    {"id": "G1", "size": "small", "mount": "fixed", "pos": [-6, -18]},
    {"id": "G2", "size": "small", "mount": "fixed", "pos": [6, -18]},
    {"id": "T1", "size": "small", "mount": "turret", "pos": [0, 4]}
  ],
  "loadout": [
    {"hardpoint": "G1", "weapon": "laser_small", "mount": "fixed"},
    {"hardpoint": "G2", "weapon": "laser_small", "mount": "fixed"},
    {"hardpoint": "T1", "weapon": "laser_small", "mount": "turret"}
  ]
}
```

Rules the loader enforces:

- Every reference (weapon ID in a ship, ship ID in a pool) must resolve, or the game refuses to start and names the bad file and field.
- Missing optional fields take documented defaults.
- Units are stated once: speed in pixels per second, turn rate in degrees per second, regen in points per second.
- Files load in order from a base folder then a mods folder; a later file with the same ID replaces the earlier one (the plugin override rule, kept from day one).

## Technical architecture

One Ship scene serves both the player and every AI ship; swapping its controller is the only difference, so flight and combat are tuned once.

```
Data files (JSON) ──► DataRegistry (autoload: load, validate, mod overrides)
                                │ definitions
GameState (autoload: credits, legal record per government)
                                │ record changes
SystemScene (one star system)
  ├─ TrafficSpawner   spawns ships from ai_pools to target counts
  ├─ System objects   star, planets, station from the system file
  ├─ Backdrop         noise stars + nebula on a slow parallax layer
  ├─ LocalSpace       streams scenery chunks around the camera
  ├─ Ship (player and AI)
  │    ├─ ShipBody      flight model
  │    ├─ WeaponMounts  hardpoints
  │    ├─ Health        shield, armour, disable
  │    └─ Controller    PlayerController | AIController (trader, warship, pirate)
  └─ Shots            projectiles, missiles, beams; apply damage
HUD           shield, armour, radar, target, messages (reads the player ship)
LandedScreen  repair and take off; checks the landing record
DebugCommands (autoload) ◄── DebugPanel, Console
```

- **Autoloads:** DataRegistry holds every definition after load; GameState holds credits and the legal record so they survive scene changes.
- **Composition over inheritance:** ShipBody, WeaponMounts and Health are child nodes, so a future station turret can reuse WeaponMounts and Health without flight.
- **Signals for events:** Health emits `disabled` and `destroyed`; GameState listens to apply legal penalties, and the HUD listens to show messages.
- **Simulation separate from visuals:** flight and damage maths live in plain classes the scene calls each physics frame, so they can be unit-tested.

- **Debug layer:** a DebugCommands autoload holds every debug action; the DebugPanel scene and the console both call it, so the same commands can also drive automated tests. Both are excluded from release builds.

- **Backdrop and local space:** a Backdrop node renders stars and nebula with a shader on a parallax layer; a LocalSpace node streams scenery chunks around the camera. Each scenery object is one generic Scenery scene configured from its definition, so new object kinds need data and sprites, not code.

## Prototype content

Just enough content to make the three behaviours and the weapon kinds and mounts distinguishable; ships use the generated art (V1), everything else is placeholder.

| Content | Count | Items |
| --- | --- | --- |
| Ships | 5 | Shuttle (player start; SOW S-A, small laser turret), courier (SOW C-B Booster, unarmed), freighter (SOW F-A Stack, small laser turret), patrol corvette (SOW P-B, 2 small laser turrets + homing missile in a small launcher), pirate raider (2 small fixed lasers + small fixed mining beam); plus the placeholder target dummy |
| Weapons | 6 | Small, medium and large laser (each on fixed, pivot or turret mounts), small mining beam (same mounts), small flak turret (stand-in for point defence until C13; no current ship carries it), homing missile (small launcher) |
| Governments | 3 | Local authority, independent traders, pirates (enemy of both) |
| AI pools | 3 | Trader traffic, authority patrol, pirate raid |
| System objects | 5 | A star, 2 landable planets, 1 station, 1 gas giant (not landable) |
| Scenery | 5 | Dust, small debris, rock, large asteroid, derelict hull (proves a data-only swap) |

Placeholder art: single top-down sprites rotated in engine (no 36-frame sheets), flat-coloured planets, a noise-generated nebula backdrop, and generated beam and projectile visuals. Free asset packs (Kenney space shooter assets are CC0) cover ships and effects until real art exists. Ship art (2026-10-29): Standard Orbital Works hulls and the pirate raider are generated sprites (`art_src/sow/export.py`, see `docs/art/`), never hand-edited; the target dummy and anything without art keep placeholders.

## Milestones

Seven steps, each ending in something playable; the data loader comes second so nothing after it is hard-coded.

1. ✅ (merged 2026-10-26) **Fly:** player ship, flight model, camera, starfield. Done when flight feels right (F1–F4).
2. ✅ (merged 2026-10-26) **Data loader and local space:** JSON definitions for all six types, typed resource classes, reference validation, mod override and hot reload; then the system file drives the backdrop and local-space scenery, replacing the milestone 1 starfield. Done when changing the backdrop or scenery in JSON changes the scene (B1–B2, L1–L3) and the player ship loads from `courier.json`.
3. ✅ (merged 2026-10-26) **Fight:** four weapon kinds, shields and armour, disable and destroy, targeting, a static dummy target. Placeholder drawing of system objects and the radar (H2) come forward into this milestone. Done when C1–C8 work against a dummy, shots damage and destroy solid scenery (L4), and the radar shows the dummy, system objects and large scenery.
4. ✅ (merged 2026-10-28) **AI and governments:** trader, warship and pirate behaviours, traffic spawning, government relations and the legal record. Done when a pirate raid on traders draws in the patrol (A1–A8, G1–G3, C11, C12, and the C6/C8 playtest changes).
5. ✅ (merged 2026-10-29) **Board and land:** boarding (with the boarding window), landing with the repair stub, escape pod and rescue, plus the debug console, hold-to-aim (F5), the radar target arrow and a minimal message line (H4). Done when C9–C10, G4, S1–S3, F5 and D10 work.
6. ✅ (merged 2026-10-29) **Art integration** (added 2026-10-29): the generated ship sprites at one scale rule, capsule hitboxes, hardpoints with sizes and mount types taken from the art, the pivot mount, rotating turret sprites and engine glow; ship data follows the art (courier unarmed, player starts in the shuttle, patrol corvette on the P-B hull), and the world grows in data to match the bigger ships (planet radii ×4, positions and system edge ×2, camera zoom 0.75, radar range 6000). The hitbox and hardpoint overlays come with it (D9). Done when V1–V5 work, every ship's loadout passes the fit rule, and turrets visibly track their target.
7. **HUD and tuning pass:** the target panel (H3), your ship's panel (H1), the full message line (H4), standing on the radar (G5), tidy-ups from the milestone 6 review (engine glow shape in data, loader checks for sprite paths and for arc or traverse on mounts that ignore them), then a balance pass on the data files only, guided by an offline balance report (`tools/balance.py`: damage per second, time to disable and destroy for each pair of ships). Balance targets: a pirate raider disables the player's shuttle in about 20–30 s, and a patrol corvette beats a raider one on one. The raider's mining beam moves to a pivot mount. Done when the success criteria in the first section are met.

Debug tools grow with the milestones rather than waiting for the end: the toggle, time scale and overlays in milestone 1; ship swap and data hot-reload in 2; invulnerability, target kill and spawning in 3; AI pause, legal record and government overrides in 4; the console in 5; hitbox and hardpoint overlays in 6.

Rough effort for one part-time developer: 6–10 weekends, most of it in milestones 3 and 4.

## Decisions

All six are settled and apply from milestone 1.

- [x] **Data format:** JSON.
- [x] **Language:** GDScript throughout.
- [x] **Godot version:** Godot 4.x stable.

- [x] **Controls:** keyboard thrust/turn like Nova; no mouse-aim.

- [x] **Physics:** custom kinematic movement for ships. Ships turn at a fixed rate with no spin-up, drift, and stop at a hard speed cap, so data values map one-to-one to behaviour and AI steering stays predictable. RigidBody2D would add angular momentum, fight the speed cap and make ships collide (Nova ships pass through each other). RigidBody2D is used only for cosmetic debris, cargo boxes and asteroid fragments.
- [x] **Project name and repo:** Terminal Velocity, in its own repo separate from the strategy game.
