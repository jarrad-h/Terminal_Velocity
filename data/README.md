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
| `camera.zoom` | Camera zoom; above 1 zooms in | `1.0` |
| `camera.smoothing_speed` | How fast the camera catches up; `0` locks it to the ship | `0` |
| `local_space.chunk_size` | Side of one local-space chunk in px | `1024` |
| `debug.time_scales` | Time-scale buttons in the debug panel | `[0.25, 0.5, 1, 2, 4]` |
| `debug.velocity_vector_seconds` | Velocity overlay length, as seconds of travel | `0.5` |
| `debug.spawn_distance` | How far from the player debug-spawned ships appear (px) | `350` |
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
| `colour`, `sprite`, `sound` | Look and sound | `"#ffffff"`, `""`, `""` |

## `governments/`

| Field | Meaning | Default |
| --- | --- | --- |
| `name` | Display name | **required** |
| `colour` | Radar/HUD colour | `"#ffffff"` |
| `allies`, `enemies` | Lists of government IDs (one ID can't be in both) | `[]` |
| `crime_threshold` | Record below which its warships attack the player | `-50` |
| `penalties` | `{"shoot", "disable", "board", "kill"}`: record lost per act | all `0` |
| `max_odds` | Engages only if enemy strength ÷ own strength ≤ this | `1` |
| `flee_shield_pct` | Retreats below this shield % | `25` |

## `ai_pools/` — traffic types

| Field | Meaning | Default |
| --- | --- | --- |
| `government` | Government ID | **required** |
| `behaviour` | `trader`, `warship` or `pirate` | **required** |
| `ships` | `[{"ship": <ship ID>, "weight": w}]`, at least one; `weight` defaults to 1 | **required** |

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
| `traffic` | `[{"pool": <AI pool ID>, "count": n}]` target population (milestone 4) | `[]` |
| `backdrop` | Distant stars and nebula (see below) | all defaults |
| `local_space` | `[{"scenery": <scenery ID>, "density": d, "region": {…}}]` | `[]` |

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
