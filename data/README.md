# Data files

Every definition is a JSON file named after its ID (`data/ships/courier.json` has ID `courier`). An `"id"` field is optional; if present it must match the file name.

**Load order and mods.** Files load from `data/`, then `mods/` (same folder layout). A file in `mods/` with the same ID replaces the `data/` one completely; fields are not merged. `game.json` is the exception: `mods/game.json` overrides only the fields it lists.

**Validation.** On start (and on debug reload), every field is type-checked, and every reference to another ID must exist. Unknown fields are errors, which catches typos. If anything is wrong the game does not start and lists each error with its file and field. A failed debug reload keeps the old data.

**Units.** Speed px/s · acceleration px/s² · turn and spin rate degrees/s · regen points/s · time seconds · positions and sizes px. Positions are `[x, y]`; ranges are `[min, max]` (a single number means min = max). Colours are `"#rrggbb"`.

Fields marked **required** have no default.

## `game.json` — global settings

| Field | Meaning | Default |
| --- | --- | --- |
| `player_ship` | Ship ID the player starts in | `"courier"` |
| `system` | System ID loaded at start | `"test_nebula"` |
| `player.credits` | Credits the player starts with | `0` |
| `player.record` | Starting legal record with every government | `0` |
| `combat.friendly_fire_pct` | % damage AI shots do to their own and allied governments' ships (C11); 0 = off. Player shots always do full damage | `100` |
| `camera.zoom` | Camera zoom; above 1 zooms in | `1.0` |
| `camera.smoothing_speed` | How fast the camera catches up; `0` locks it to the ship | `0` |
| `local_space.chunk_size` | Side of one local-space chunk in px | `1024` |
| `radar.size` | Radar diameter in px (bottom-right corner) | `200` |
| `radar.range` | World distance from the player to the radar rim, px | `3000` |
| `radar.margin` | Gap from the screen edges, px | `16` |
| `radar.colours` | `background`, `rim`, `player`, `hostile` (ships hostile to you), `warned` (ships with a grievance against you, not yet hostile), `friendly` (non-hostile ships with a government), `neutral` (ships with no government), `target` (ring round the selected target), `scenery` | see `game.json` |
| `ai.landing_speed` | AI ships land when slower than this, px/s (A1) | `60` |
| `ai.land_radius_fraction` | …and within this fraction of the planet's radius of its centre | `0.6` |
| `ai.thrust_angle` | AI thrusts only when within this many degrees of the direction it wants | `35` |
| `ai.standoff_fraction` | In a fight, AI stops closing at this fraction of its weapon range | `0.4` |
| `ai.think_interval` | Seconds between AI decisions (steering runs every frame) | `0.25` |
| `ai.disengage_factor` | AI gives up a chase beyond sensor range × this | `1.5` |
| `ai.waypoint_reached_fraction` | A patrol waypoint counts as reached within sensor range × this | `0.1` |
| `ai.object_patrol_chance` | Chance a warship's next waypoint is near a system object (else anywhere in `roam_band`) | `0.6` |
| `ai.object_patrol_offset_factor` | Warship waypoints sit object radius + sensor range × this from the object | `0.3` |
| `ai.roam_band` | Roaming waypoints lie between these fractions of the edge radius `[min, max]` | `[0.1, 0.6]` |
| `ai.jump_out_factor` | Leaving ships head for edge radius × this before jumping out (at least 1) | `1.05` |
| `ai.planet_spawn_chance` | For pools with `spawn_from_planets`: chance a replacement takes off from a planet rather than jumping in at the edge | `0.5` |
| `ai.arrival_speed_fraction` | Ships jumping in at the edge start at this fraction of their top speed | `0.5` |
| `ai.spawn_keep_away_factor` | Traffic placed at system load starts beyond sensor range × this from the player | `1.2` |
| `ai.inside_spawn_band` | …and between these fractions of the edge radius `[min, max]` | `[0.15, 0.7]` |
| `debug.time_scales` | Time-scale buttons in the debug panel | `[0.25, 0.5, 1, 2, 4]` |
| `debug.velocity_vector_seconds` | Velocity overlay length, as seconds of travel | `0.5` |
| `debug.spawn_distance` | How far ahead of the player debug-spawned ships appear (px); tick "Spawn at cursor" in the panel to place them with a click instead | `350` |
| `debug.spawn_at_start` | Ships spawned at start in debug builds: `[{"ship": <ID>, "position": [x, y], "government": <ID>}]` (government optional). Idle until AI arrives | `[]` (data has the target dummy) |

## `ships/` — hull classes

| Field | Meaning | Default |
| --- | --- | --- |
| `name` | Display name | **required** |
| `accel` | Thrust acceleration | **required** |
| `top_speed` | Hard speed cap | **required** |
| `turn_rate` | Turn rate | **required** |
| `sprite` | Path under `assets/sprites/`, art facing up; placeholder arrow if missing | `""` |
| `mass` | Mass (unused until boarding/capture) | `50` |
| `shield`, `shield_regen` | Shield points and recharge per second (no recharge while disabled) | `0`, `0` |
| `shield_recharge_delay` | Seconds without taking damage before shields start recharging; any hit resets it (C6) | `3` |
| `armor` | Armour points | `100` |
| `disable_armor_pct` | Disabled (drifts, can't fire) at or below this % of max armour; destroyed at 0 | `33` |
| `strength` | Combat strength for AI odds | `1` |
| `crew` | Crew count | `1` |
| `hit_radius` | Hit circle radius in px (also placeholder art size) | `16` |
| `hardpoints` | `{"gun": [[x, y], …], "turret": …, "guided": …, "beam": …}` exit points relative to the ship centre, ship facing up. Every equipped weapon needs at least one point of its kind; extra weapons share points | none |
| `default_weapons` | `[{"weapon": <weapon ID>, "count": n}]`; `count` defaults to 1 | `[]` |

## `weapons/`

Kinds: `gun` fires along the heading; `turret` leads the selected target within its arc (fires ahead with no target); `guided` homes on the target selected at launch at `turn_rate` (straight with no target); `beam` hits the first thing along its length every frame while held. Primary fire (Space) drives guns, turrets and beams; secondary (F) launches guided weapons.

| Field | Meaning | Default |
| --- | --- | --- |
| `name` | Display name | **required** |
| `kind` | `gun`, `turret`, `guided` or `beam` | **required** |
| `damage_shield`, `damage_armor` | Damage per hit (per second for beams) | `0`, `0` |
| `range` | Max distance in px; `0` means use `lifetime` | `0` |
| `lifetime` | Shot lifetime in s | `1` |
| `speed` | Shot speed | `600` |
| `reload` | Seconds between shots | `0.5` |
| `turn_rate` | Missile turn rate (guided) | `0` |
| `arc` | Turret tracking arc in degrees, centred on the heading; the turret holds fire when the lead point is outside it | `360` |
| `inherit_velocity` | Guns and turrets: shots add the ship's velocity | `true` |
| `falloff_start_pct` | Full damage up to this % of the weapon's reach (C12), 0–100; 100 = no falloff. Shots measure their own travel (speed × time), so the ship's speed doesn't change it | `100` |
| `falloff_min_pct` | Damage % at full reach, 0–100, falling linearly from `falloff_start_pct`. Shots and beams fade to match | `100` |
| `colour`, `sprite`, `sound` | Look and sound | `"#ffffff"`, `""`, `""` |

## `governments/`

Hostility (G1, G3, A8): two governments are hostile if either lists the other in `enemies`. All of a government's ships treat the player as hostile while the player's record with it is below `crime_threshold` (pirates start there). Damage the player does to a non-hostile ship builds that ship's grievance (% of its total shield + armour, draining at `forgiveness_pct_per_s`); past `tolerance_pct` × its personality's `tolerance_factor`, that ship alone turns hostile and the attack ("shoot") penalty is charged. Disable, board and kill penalties apply immediately, once each per ship. A ship that is already hostile (record below threshold) charges the attack penalty on the first hit. Ships with no government use the default tolerance (20%) and forgiveness (4%/s).

| Field | Meaning | Default |
| --- | --- | --- |
| `name` | Display name | **required** |
| `colour` | Radar/HUD colour | `"#ffffff"` |
| `allies`, `enemies` | Lists of government IDs (one ID can't be in both) | `[]` |
| `crime_threshold` | Record below which its warships attack the player | `-50` |
| `penalties` | `{"shoot", "disable", "board", "kill"}`: record lost per act | all `0` |
| `max_odds` | Engages only if enemy strength ÷ own strength ≤ this | `1` |
| `flee_shield_pct` | Retreats below this shield % | `25` |
| `tolerance_pct` | A8: how much of a ship's total shield + armour the player can damage before that ship turns hostile (grievance) | `20` |
| `forgiveness_pct_per_s` | A8: how fast grievance drains, % per second | `4` |

## `ai_pools/` — traffic types

| Field | Meaning | Default |
| --- | --- | --- |
| `government` | Government ID | **required** |
| `behaviour` | `trader`, `warship` or `pirate` | **required** |
| `ships` | `[{"ship": <ship ID>, "weight": w}]`, at least one, weights adding up to more than 0; `weight` defaults to 1 | **required** |
| `personalities` | `[{"personality": <personality ID>, "weight": w}]`; one is picked per ship (A7). Empty = neutral | `[]` |
| `sensor_range` | How far its ships notice others, px | `1500` |
| `stay_time` | Warships and pirates leave after this many seconds with nothing to fight `[min, max]` | `[60, 120]` |
| `dwell_time` | Traders stay docked this long at each planet, s | `[6, 12]` |
| `stops` | Traders visit this many planets before leaving `[min, max]` | `[1, 3]` |
| `spawn_from_planets` | New ships may take off from landable planets (chance `ai.planet_spawn_chance`) instead of arriving at the edge | `true` for traders |
| `fire_angle` | Fire only when aimed within this many degrees | `8` |

Roles (A1–A3): **trader** flies planet to planet, docks for `dwell_time`, leaves after `stops`; **warship** patrols and attacks enemies of its government and a hostile player; **pirate** roams and attacks traders and the player on sight. Any ship retreats below its government's `flee_shield_pct` (shifted by its personality) and leaves the system (A4). Before starting a fight it compares the strength of each side within `sensor_range` against `max_odds` × its personality's `odds_factor` (A5).

## `personalities/` — individual AI temperament (A7)

Group level (government + AI pool) decides who is friend or foe and the role; a personality only shades how the ship behaves within that.

| Field | Meaning | Default |
| --- | --- | --- |
| `name` | Display name | **required** |
| `odds_factor` | Multiplies the government's `max_odds` (1.5 = takes longer odds) | `1` |
| `flee_shield_offset` | Percentage points added to the government's `flee_shield_pct` (−15 = stays in longer); result clamped 0–100 | `0` |
| `when_attacked` | `role` (traders flee, others fight), `fight` or `flee` | `"role"` |
| `starts_fights` | `role` (warships and pirates on sight, traders never), `never` or `on_sight` | `"role"` |
| `tolerance_factor` | Multiplies the government's `tolerance_pct` (A8; below 1 = quicker to anger) | `1` |

## `scenery/` — local-space object types

One generic Scenery scene is built from these fields; a new kind of object (wrecks, flora, fauna) is a new file, not code.

Solid scenery takes weapon damage to its armour. Destroyed scenery stays destroyed until you switch system (it survives a data reload). Drifting solid scenery is generated where its drift has carried it since you entered the system; non-solid scenery (dust) always appears at its start position.

| Field | Meaning | Default |
| --- | --- | --- |
| `name` | Display name | **required** |
| `sprites` | Paths under `assets/sprites/`; one picked per object. Placeholder polygon if empty or missing | `[]` |
| `size` | Diameter range in px | `[8, 8]` |
| `spin` | Spin range in degrees/s (negative spins the other way) | `[0, 0]` |
| `drift` | Drift speed range in px/s, random direction; only with `behaviour: "drift"` | `[0, 0]` |
| `behaviour` | `static` (stays put) or `drift` | `"static"` |
| `depth` | Parallax depth range; 1 = moves with the world, below 1 further away. Non-solid only | `[1, 1]` |
| `solid` | Has a hitbox and armour (weapons hit it from milestone 3) | `false` |
| `armor` | Armour points when solid | `0` |
| `fragments` | `[{"scenery": <scenery ID>, "count": n}]` thrown off as cosmetic pieces when destroyed | `[]` |
| `fragment_speed` | Fragment launch speed range in px/s | `[20, 80]` |
| `fragment_lifetime` | Seconds before fragments fade out | `6` |
| `radar` | Shown on the radar | `false` |
| `placeholder.colour` | Placeholder polygon colour | `"#999999"` |
| `placeholder.sides` | Polygon corners (≥ 3) | `7` |
| `placeholder.roughness` | 0 = regular, 1 = very jagged | `0.3` |
| `placeholder.aspect` | Width ÷ height; above 1 for long shapes like hulls | `1` |

## `systems/`

| Field | Meaning | Default |
| --- | --- | --- |
| `name` | Display name | **required** |
| `seed` | Seeds local-space generation; same seed, same scenery | `0` |
| `objects` | Stars, planets, stations (see below); drawn from milestone 5 | `[]` |
| `traffic` | `[{"pool": <AI pool ID>, "count": n}]` target population; each pool at most once | `[]` |
| `backdrop` | Distant stars and nebula (see below) | all defaults |
| `local_space` | `[{"scenery": <scenery ID>, "density": d, "region": {…}}]` | `[]` |
| `edge_radius` | Traffic arrives and leaves this far from the system centre, px (A6) | `6000` |
| `respawn_delay` | Seconds before replacing a ship that left or died `[min, max]` | `[5, 15]` |

**`objects[]`:** `id` (**required**, unique in the system), `type` (`star`, `planet`, `station`; **required**), `name` (**required**), `position` (**required**), `radius` (`100`), `colour` (`"#7f99cc"`), `sprite` (`""`), `description` (`""`), `landable` (`false`), `government` (government ID, `""`), `min_record` (`-1000`).

**`local_space[]`:** `density` (**required**) is objects per 1,000,000 px² (a 1000 × 1000 px area) inside the region. `region.shape` is `whole` (default, everywhere), `circle` (`centre`, `radius`) or `ring` (`centre`, `inner_radius`, `radius` = outer). `centre` defaults to `[0, 0]`.

**`backdrop`:**

| Field | Meaning | Default |
| --- | --- | --- |
| `parallax` | Fraction of camera motion the backdrop moves | `0.02` |
| `base_colour` | Empty-space colour | `"#05060c"` |
| `stars.density` | Chance (0–1) that each star cell holds a star | `0.05` |
| `stars.brightness` | Brightest star (0–1+) | `0.8` |
| `stars.size` | Star radius in px | `1.2` |
| `stars.spacing` | Star cell size in px; smaller packs more stars | `16` |
| `nebula.coverage` | 0 = no nebula, 1 = nebula everywhere | `0.4` |
| `nebula.intensity` | Nebula opacity at its densest (0–1) | `0.6` |
| `nebula.softness` | Edge fade width (noise units, 0–1) | `0.3` |
| `nebula.gradient` | Colours from thin to dense nebula (at least 2) | purple/pink |
| `noise.seed` | FastNoiseLite seed | `0` |
| `noise.frequency` | Lower = bigger clouds | `0.006` |
| `noise.octaves` | Detail layers | `5` |
| `noise.texture_size` | Noise texture size in px (it tiles) | `1024` |
| `noise.scale` | Screen px per noise pixel | `2` |
