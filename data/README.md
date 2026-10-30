# Data files

Every definition is a JSON file named after its ID (`data/ships/courier.json` has ID `courier`). An `"id"` field is optional; if present it must match the file name.

**Load order and mods.** Files load from `data/`, then `mods/` (same folder layout). A file in `mods/` with the same ID replaces the `data/` one completely; fields are not merged. `game.json` is the exception: `mods/game.json` overrides only the fields it lists.

**Validation.** On start (and on debug reload), every field is type-checked, and every reference to another ID must exist. Unknown fields are errors, which catches typos. If anything is wrong the game does not start and lists each error with its file and field. A failed debug reload keeps the old data.

**Units.** Speed px/s · acceleration px/s² · turn and spin rate degrees/s · regen points/s · time seconds · positions and sizes px. Positions are `[x, y]`; ranges are `[min, max]` (a single number means min = max). Colours are `"#rrggbb"`.

Fields marked **required** have no default.

## `game.json` — global settings

| Field | Meaning | Default |
| --- | --- | --- |
| `player_ship` | Ship ID the player starts in | `"shuttle"` |
| `galaxy` | TR1: galaxy ID (from `galaxy/`); the player starts in its `start_system` | `"test_cluster"` |
| `calendar.start_date` | TM1: the date of day 0, `"YYYY-MM-DD"` (placeholder until the setting decides) | `"3200-01-01"` |
| `hyperspace.stop_speed` | TR2: during the jump sequence the ship counts as stopped below this speed (px/s) and is held still | `2` |
| `hyperspace.align_tolerance` | TR2: degrees from the destination bearing at which the ship counts as facing it | `1` |
| `hyperspace.thrust_angle` | TR2: while stopping, the ship burns once within this many degrees of facing against its velocity | `20` |
| `hyperspace.overdrive_accel_factor` | TR2: after the countdown the ship accelerates at its `accel` × this, past its speed cap | `6` |
| `hyperspace.engage_speed_factor` | TR2: the hyperdrive engages at the ship's `top_speed` × this (more than 1) | `4` |
| `hyperspace.arrival_speed_fraction` | TR4: arrivals enter at this fraction of top speed (0–1) | `0.5` |
| `art_scale` | V1: one scale for all ship art: sprites, hitboxes, hardpoints and engine exits (all written in art px) are multiplied by it. More than 0 | `1.0` |
| `mounts.arc.pivot`, `mounts.arc.turret` | V3: default total arc in degrees (0–360) for pivot and turret hardpoints, centred on the heading; a hardpoint's `arc` overrides it. Fixed mounts have no arc | `30`, `360` |
| `mounts.traverse.pivot`, `mounts.traverse.turret` | V4: how fast a pivot or turret barrel swings, degrees/s; a hardpoint's `traverse` overrides it | `180`, `360` |
| `mounts.fire_tolerance` | A turret fires once its barrel is within this many degrees of its aim point | `5` |
| `mounts.turret_sprites` | V4: turret sprite (path under `assets/sprites/`, must exist) by hardpoint size `small`, `medium`, `large`, plus `point_defence` for PD hardpoints; `""` draws no turret | `""` each (data: `tur1`, `tur2`, none, `pd1`) |
| `player.credits` | Credits the player starts with | `0` |
| `player.record` | Starting legal record with every government | `0` |
| `player.escape_pod` | C10: owns an escape pod (until outfits exist). Without one, destruction ends the game | `true` |
| `player.insured` | C10: owns insurance; the ship is replaced like for like after a rescue | `true` |
| `player.uninsured_ship` | C10: hull given after a rescue when uninsured (ship ID) | `"shuttle"` |
| `player.rescue_fee_pct` | C10: share of credits charged by the rescuer, 0–100 | `10` |
| `player.rescue_days` | C10: days that pass before rescue `[min, max]` (shown in the report) | `[2, 5]` |
| `player.pod_speed`, `player.pod_time` | C10: escape pod speed (px/s, added to the ship's) and flight time (s) | `600`, `3` |
| `landing.max_speed` | S2: land only below this speed (player and AI), px/s | `60` |
| `landing.radius_fraction` | S2: …and within this fraction of the planet's radius of its centre | `0.6` |
| `landing.repair_cost_per_point` | S3: credits per missing shield/armour point; 0 = free repairs | `0` |
| `boarding.range` | C9: board when the hulls' edges are this close, px | `60` |
| `boarding.max_speed` | C9: …and relative speed is below this, px/s | `40` |
| `boarding.time` | C9: seconds the boarding progress bar runs (more than 0) | `2` |
| `boarding.assist_armor_pct` | C9 Assist: patched-up ships get back to this % of max armour, up to 100 (keep it above ships' `disable_armor_pct`) | `50` |
| `combat.friendly_fire_pct` | % damage AI shots do to their own and allied governments' ships (C11); 0 = off. Player shots always do full damage | `100` |
| `camera.zoom` | Camera zoom; above 1 zooms in (data: `0.75` for the 1:1 ship art) | `1.0` |
| `camera.smoothing_speed` | How fast the camera catches up; `0` locks it to the ship | `0` |
| `local_space.chunk_size` | Side of one local-space chunk in px | `1024` |
| `radar.size` | Radar diameter in px (bottom-right corner) | `200` |
| `radar.range` | World distance from the player to the radar rim, px | `3000` |
| `radar.margin` | Gap from the screen edges, px | `16` |
| `radar.disabled_pale` | H2: a disabled ship shows its standing colour blended this far towards white (0–1) | `0.55` |
| `radar.colours` | `background`, `rim`, `player`, `hostile` (ships hostile to you), `warned` (ships with a grievance against you, not yet hostile), `friendly` (non-hostile ships with a government), `neutral` (ships with no government), `target` (ring round the selected target), `scenery` | see `game.json` |
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
| `engine_glow.idle`, `engine_glow.response` | V5: glow strength at idle (0–1, share of full thrust) and how fast it changes (strength per second) | `0.25`, `6` |
| `galaxy_map.colours` | TR7: galaxy map (M) colours: `background`, `lane` (hyperlanes), `route` (plotted route), `current` (ring round your system), `selected` (ring round the picked system), `unexplored` (unvisited systems), `label` (text), `jump_radius` (the dashed ring in the system view). Explored systems use their government's colour | see `game.json` |
| `messages.show_seconds`, `messages.fade_seconds`, `messages.max_lines` | H4: how long a message shows before fading, the fade time, and how many lines show at once (at least 1) | `4`, `1`, `3` |
| `messages.colours` | H4: text colour by kind: `info` (hints, refusals), `combat` (disabled, destroyed, scuttled), `standing` (turns hostile, crime threshold crossed), `credits` | see `game.json` |
| `hud.colours` | H1, H3: `shield` and `armor` bar colours; the target schematic's fill at full, half and empty armour (`schematic_full`, `schematic_half`, `schematic_empty`, blended between) and when disabled (`schematic_disabled`); `warning` colours your DISABLED warning. The schematic's shield outline uses `shield` | see `game.json` |
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
| `sprite` | Path under `assets/sprites/`, art facing up, drawn at 1:1 × `art_scale` (V1). A named file must exist; `""` draws the placeholder arrow | `""` |
| `mass` | Mass (unused until boarding/capture) | `50` |
| `shield`, `shield_regen` | Shield points and recharge per second (no recharge while disabled) | `0`, `0` |
| `shield_recharge_delay` | Seconds without taking damage before shields start recharging; any hit resets it (C6) | `3` |
| `armor` | Armour points | `100` |
| `disable_armor_pct` | Disabled (drifts, can't fire) at or below this % of max armour; destroyed at 0 | `33` |
| `strength` | Combat strength for AI odds | `1` |
| `crew` | Crew count | `1` |
| `hit_size` | V2: capsule hitbox `[width, length]` in art px, running along the hull (width ≤ length; equal values make a circle). Cover the hull body, not ornaments. Also sizes the placeholder arrow | `[32, 32]` |
| `hit_offset` | V2: capsule centre relative to the sprite centre, art px (e.g. the freighter's hull sits left of its solar panel) | `[0, 0]` |
| `board_credits` | C9: credits aboard `[min, max]`, before the AI pool's `wealth_factor` | `[0, 0]` |
| `hardpoints` | V3: `[{"id", "size", "mount", "pos", "arc", "traverse", "role"}]`. `id` names it (unique on the ship, from the art: `T1`, `G2`…); `size` is `small`, `medium` or `large`; `mount` is `fixed`, `pivot`, `turret` or `launcher`; `pos` is `[x, y]` in art px from the sprite centre (+x starboard, +y aft, ship facing up), copied from `assets/sprites/ships/*/hardpoints.json`. Optional: `arc` (0–360) and `traverse` override the `mounts` defaults (pivot and turret only; an error on fixed or launcher mounts); `role` `"point_defence"` (turrets only) picks the PD sprite (C13 behaviour comes later). All of `id`, `size`, `mount`, `pos` are **required** | `[]` |
| `loadout` | V3: installed weapons, `[{"hardpoint": <id>, "weapon": <weapon ID>, "mount": <mount type>}]`, at most one per hardpoint. `mount` is the mount the item was built for. The weapon's `size` must equal the hardpoint's, the item's `mount` must equal the hardpoint's, and the weapon must come in that mount; otherwise the game won't start | `[]` |
| `engines` | V5: engine exits `[[x, y], …]` in art px (from `hardpoints.json`), where the glow is drawn | `[]` |
| `engine_glow` | V5: `{"colour": "#rrggbb", "size": px}`; brightens with thrust | `{"colour": "#a8d8ff", "size": 6}` |
| `fuel` | TR8: fuel capacity, units | `300` |
| `jump_fuel` | TR8: fuel one hyperlane jump costs (flat per jump for now; the rule lives in `Hyperlanes.jump_fuel`) | `100` |
| `jump_countdown` | TR2: seconds of hyperspace countdown once stopped and facing the destination | `3` |
| `jump_speed` | TM2: galaxy-map units travelled per day; a jump takes lane length ÷ this days, rounded up, at least 1 (more than 0) | `150` |

## `weapons/`

Kinds: `projectile` fires shots (lasers, flak); `guided` homes on the target selected at launch at `turn_rate` (straight with no target); `beam` hits the first thing along its length every frame while held. Primary fire (Space) drives projectiles and beams; secondary (F) launches guided weapons.

Mounts (V3) decide how a weapon aims, from the hardpoint it sits on: `fixed` fires along the heading; `pivot` swings toward the selected target's lead point within its arc (held at the edge, still firing, when the target is outside); `turret` swings toward it within its arc at its traverse rate and fires once on target (forward with no target; holds fire while the target is outside its arc); `launcher` is for guided weapons. A weapon's numbers are the same on every mount it comes in; there is one file per size (`laser_small`, `laser_medium`, `laser_large`).

| Field | Meaning | Default |
| --- | --- | --- |
| `name` | Display name | **required** |
| `kind` | `projectile`, `guided` or `beam` | **required** |
| `size` | V3: `small`, `medium` or `large`; fits hardpoints of the same size | `"small"` |
| `mounts` | V3: mount types it comes in, from `fixed`, `pivot`, `turret`; guided weapons use `launcher` (and only they do) | **required** |
| `damage_shield`, `damage_armor` | Damage per hit (per second for beams) | `0`, `0` |
| `range` | Max distance in px; `0` means use `lifetime` | `0` |
| `lifetime` | Shot lifetime in s | `1` |
| `speed` | Shot speed | `600` |
| `reload` | Seconds between shots | `0.5` |
| `turn_rate` | Missile turn rate (guided) | `0` |
| `inherit_velocity` | Projectiles: shots add the ship's velocity | `true` |
| `falloff_start_pct` | Full damage up to this % of the weapon's reach (C12), 0–100; 100 = no falloff. Shots measure their own travel (speed × time), so the ship's speed doesn't change it | `100` |
| `falloff_min_pct` | Damage % at full reach, 0–100, falling linearly from `falloff_start_pct`. Shots and beams fade to match | `100` |
| `colour`, `sprite`, `sound` | Look and sound | `"#ffffff"`, `""`, `""` |

## `governments/`

Hostility (G1, G3, A8): two governments are hostile if either lists the other in `enemies`. All of a government's ships treat the player as hostile while the player's record with it is below `crime_threshold` (pirates start there). Damage the player does to a non-hostile ship builds that ship's grievance (% of its total shield + armour, draining at `forgiveness_pct_per_s`); past `tolerance_pct` × its personality's `tolerance_factor`, that ship alone turns hostile and the attack ("shoot") penalty is charged. Disable, board and kill penalties apply immediately, once each per ship. A ship that is already hostile (record below threshold) charges the attack penalty on the first hit. Ships with no government use the default tolerance (10%) and forgiveness (0.5%/s). Keep forgiveness well below the share of a ship's health the player's guns deal per second, or sustained fire never turns it hostile.

| Field | Meaning | Default |
| --- | --- | --- |
| `name` | Display name | **required** |
| `colour` | Radar/HUD colour | `"#ffffff"` |
| `allies`, `enemies` | Lists of government IDs (one ID can't be in both) | `[]` |
| `crime_threshold` | Record below which its warships attack the player | `-50` |
| `friendly_record` | G5: record at or above which its ships show as friendly (radar, target panel); must be above `crime_threshold` | `25` |
| `penalties` | `{"shoot", "disable", "board", "kill"}`: record lost per act | all `0` |
| `max_odds` | Engages only if enemy strength ÷ own strength ≤ this | `1` |
| `flee_shield_pct` | Retreats below this shield % | `25` |
| `tolerance_pct` | A8: how much of a ship's total shield + armour the player can damage before that ship turns hostile (grievance) | `10` |
| `forgiveness_pct_per_s` | A8: how fast grievance drains, % per second | `0.5` |
| `assist_reward` | C9: record gained for assisting one of its disabled ships | `0` |

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
| `wealth_factor` | C9: multiplies its ships' `board_credits` (traders rich, patrols poor) | `1` |

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

## `galaxy/` — the map (TR1, TR7)

| Field | Meaning | Default |
| --- | --- | --- |
| `name` | Display name | **required** |
| `start_system` | System the player starts in; must be listed and not `hidden` | **required** |
| `systems` | `[{"system": <system ID>, "position": [x, y], "map_state": …}]`, each system once. `position` is in map units (+y is down, as in space); `map_state` is how it starts on the map: `explored` (name, government and system view shown), `unexplored` (shown as "Unexplored" until visited) or `hidden` (not drawn or routable, nor its lanes, until revealed) | **required**; `map_state` `"unexplored"` |
| `hyperlanes` | `[{"from": <system ID>, "to": <system ID>}]`; two-way, each pair once, both ends listed in `systems` | `[]` |

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
| `jump_radius` | TR2: hyperlane jumps need the ship at least this far from the centre, px; TR4: arrivals appear at this distance | `8000` |

**`objects[]`:** `id` (**required**, unique in the system), `type` (`star`, `planet`, `station`; **required**), `name` (**required**), `position` (**required**), `radius` (`100`), `colour` (`"#7f99cc"`), `sprite` (`""`), `description` (`""`), `landable` (`false`), `government` (government ID, `""`), `min_record` (`-1000`), `sells_fuel` (TR8, landable objects only; `true`), `refuel_price` (TR8: credits per unit of fuel; `2`), `landing_days` (TM2: days that pass on landing; `1`), `takeoff_days` (TM2: days that pass on taking off; `0`). Landed activities (trade, missions) will carry their own day costs when they exist.

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
