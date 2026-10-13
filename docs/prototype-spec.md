# Terminal Velocity Prototype — Requirements & Scope

Exported from the planning doc on 13 Oct 2026. The planning doc is the source of truth; refresh this copy when it changes.

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
| World | One system: a star, 2–3 planets, 1 station, an asteroid field optional | Multiple systems, hyperspace, galaxy map, fuel |
| Player ship | Fly, fire, take damage, be disabled, die and respawn | Buying ships, escorts, capture keeping the ship |
| Weapons | Fixed gun, turret, guided missile, beam | Ammo economy, point defence, ion, jamming, cloaking |
| Damage model | Shields, armour, disabled state, destruction | Armour recharge, repair systems |
| AI | Trader, warship and pirate behaviours, flee threshold | Interceptor scanning, bribes, hailing |
| Governments | 3 governments with ally/enemy relations and a legal record | Reputation spreading to allies, ranks |
| Boarding | Board a disabled ship for credits | Plunder of cargo and outfits, capture odds |
| Landing | Stub screen: repair, take off | Shipyard, outfitter, trade, bar, missions |
| Data | Ships, weapons, governments, AI pools, system definition | Missions, flags, crons, persons, plugins |
| Presentation | Placeholder art, basic HUD, radar | Final art, audio polish, menus, save/load |
| Debug | Debug panel and console: ship swap, spawning, invulnerability, time scale, data hot-reload, overlays | Player-facing cheats, mission and flag debugging |

## Functional requirements

Each requirement has an ID so milestones, commits and tests can refer to it.

**Flight**

- F1: Thrust, turn and reverse-thrust (turn to face opposite velocity) controls, keyboard first, gamepad later.
- F2: Velocity is capped at the ship's top speed; there is no drag, so the ship drifts when not thrusting.
- F3: Acceleration, top speed and turn rate come from the ship definition.
- F4: The camera follows the player; a parallax starfield shows motion.

**Combat**

- C1: Weapons fire from named exit points on the ship (gun, turret, guided, beam).
- C2: Fixed guns fire along the ship's heading; turrets track the selected target within an arc.
- C3: Guided missiles home on the target with their own turn rate and lifetime.
- C4: Beams hit instantly along their length while held.
- C5: Damage hits shields first, then armour; weapons can weight shield vs armour damage differently.
- C6: Shields recharge over time; armour does not in the prototype.
- C7: A ship is disabled at 33% armour (drifts, cannot fire) and destroyed at 0%.
- C8: The player can select the nearest hostile or cycle targets; the HUD shows the target's shield and armour.
- C9: A disabled ship can be boarded by stopping alongside it, granting credits.
- C10: When the player is destroyed, they respawn at the station after a short delay.

**AI**

- A1: Traders fly between planets, land, and take off again; they flee when attacked.
- A2: Warships patrol and attack ships of enemy governments, including the player when hostile.
- A3: Pirates attack traders and the player on sight.
- A4: Each AI ship retreats below a shield threshold set by its government.
- A5: Before engaging, AI compares the summed strength of each side against its government's maximum odds.
- A6: Traffic spawns at the system edge or from planets to keep a target population, and leaves when its job is done.

**Governments and legal record**

- G1: Each ship belongs to a government; governments declare allies and enemies.
- G2: Attacking, disabling, boarding or destroying a government's ship lowers the player's record with it by set amounts.
- G3: Below a crime threshold, that government's warships turn hostile to the player.
- G4: A planet refuses landing when the player's record with its government is below its minimum.

**System and landing**

- S1: The system is loaded from a data file: positions of the star, planets and station, and the traffic pools.
- S2: The player lands by approaching a planet slowly and pressing land.
- S3: The landed screen shows the planet's name and description, and offers repair and take off.

**HUD**

- H1: Shield and armour bars; credits.
- H2: Radar showing ships coloured by hostility, planets and the selected target.
- H3: Target panel: name, government, shield and armour.
- H4: Message line for events (target disabled, landing refused).

**Debug tools**

- D1: A debug panel toggles with the backtick key and exists only in debug builds.
- D2: Swap the player's ship to any ship ID in the data, keeping position and velocity.
- D3: Spawn any ship or AI pool near the player or at the cursor, with a count and a government override.
- D4: Toggles: player invulnerability, infinite ammo, AI paused, show all ships on radar.
- D5: Destroy or disable the current target; clear all AI ships from the system.
- D6: Set credits and the player's legal record with each government.
- D7: Time scale from 0.25× to 4×, plus pause and single-frame step.
- D8: Reload all data files at runtime, so tuning a JSON value needs no restart.
- D9: Overlays: hitboxes, velocity vectors, AI state labels, FPS and ship count.
- D10: A text console accepts the same actions as typed commands (for example `spawn pirate_raider 3`); panel and console call one shared command layer.

## Data requirements

Five definition types load from JSON files at startup; IDs are readable strings, and references use explicit fields rather than Nova's numeric offsets.

| Type | Defines | Key fields |
| --- | --- | --- |
| `ship` | A hull class | name, sprite, mass, accel, top_speed, turn_rate, shield, shield_regen, armor, hardpoints (gun/turret/guided/beam exit points), default_weapons, strength, crew |
| `weapon` | A gun, turret, missile or beam | kind, damage_shield, damage_armor, range or lifetime, speed, reload, turn_rate (guided), arc (turret), sprite or colour, sound |
| `government` | A faction | name, colour, allies, enemies, crime_threshold, penalties (shoot, disable, board, kill), max_odds, flee_shield_pct |
| `ai_pool` | A traffic type (Nova's dude) | government, behaviour (trader, warship, pirate), weighted list of ship IDs |
| `system` | The one star system | name, objects (star, planets, station with position, sprite, description, landable, min_record), traffic (pool ID + target count) |

See `data/ships/courier.json` for an example ship file.

Rules the loader enforces:

- Every reference (weapon ID in a ship, ship ID in a pool) must resolve, or the game refuses to start and names the bad file and field.
- Missing optional fields take documented defaults.
- Units are stated once: speed in pixels per second, turn rate in degrees per second, regen in points per second.
- Files load in order from `data/` then `mods/`; a later file with the same ID replaces the earlier one (the plugin override rule, kept from day one).

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

## Prototype content

Just enough content to make the three behaviours and the four weapon kinds distinguishable; all art is placeholder.

| Content | Count | Items |
| --- | --- | --- |
| Ships | 5 | Shuttle (player start), courier, freighter, patrol corvette, pirate raider |
| Weapons | 4 | Light laser (gun), flak turret, homing missile, mining beam |
| Governments | 3 | Local authority, independent traders, pirates (enemy of both) |
| AI pools | 3 | Trader traffic, authority patrol, pirate raid |
| System objects | 5 | A star, 2 landable planets, 1 station, 1 gas giant (not landable) |

Placeholder art: single top-down sprites rotated in engine (no 36-frame sheets), flat-coloured planets, and generated beam and projectile visuals. Free asset packs (Kenney space shooter assets are CC0) cover ships and effects until real art exists.

## Milestones

Six steps, each ending in something playable; the data loader comes second so nothing after it is hard-coded.

1. **Fly:** player ship, flight model, camera, starfield. Done when flight feels right (F1–F4).
2. **Data loader:** JSON definitions, typed resource classes, reference validation, mod override. Done when the player ship loads from `courier.json`.
3. **Fight:** four weapon kinds, shields and armour, disable and destroy, targeting, a static dummy target. Done when C1–C8 work against a dummy.
4. **AI and governments:** trader, warship and pirate behaviours, traffic spawning, government relations and the legal record. Done when a pirate raid on traders draws in the patrol (A1–A6, G1–G3).
5. **Board and land:** boarding for credits, landing with the repair stub, respawn. Done when C9–C10, G4 and S1–S3 work.
6. **HUD and tuning pass:** radar, target panel, messages, then a balance pass on the data files only. Done when the success criteria in the first section are met.

Debug tools grow with the milestones rather than waiting for the end: the toggle, time scale and overlays in milestone 1; ship swap and data hot-reload in 2; invulnerability, target kill and spawning in 3; AI pause, legal record and government overrides in 4; the console in 5.

Rough effort for one part-time developer: 6–10 weekends, most of it in milestones 3 and 4.

## Decisions

All six are settled and apply from milestone 1.

- **Data format:** JSON.
- **Language:** GDScript throughout.
- **Godot version:** Godot 4.x stable.
- **Controls:** keyboard thrust/turn like Nova; no mouse-aim.
- **Physics:** custom kinematic movement for ships. Ships turn at a fixed rate with no spin-up, drift, and stop at a hard speed cap, so data values map one-to-one to behaviour and AI steering stays predictable. RigidBody2D would add angular momentum, fight the speed cap and make ships collide (Nova ships pass through each other). RigidBody2D is used only for cosmetic debris, cargo boxes and asteroid fragments.
- **Project name and repo:** Terminal Velocity, in its own repo separate from the strategy game.
