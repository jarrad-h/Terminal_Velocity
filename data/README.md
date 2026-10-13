# Data files

Units: speed px/s, acceleration px/s², turn rate degrees/s, regen points/s, time seconds.

## `game.json` — global settings

| Field | Meaning | Default |
| --- | --- | --- |
| `player_ship` | Ship ID the player starts in | `"courier"` |
| `background_colour` | Space colour behind the starfield | `"#05060c"` |
| `camera.zoom` | Camera zoom; above 1 zooms in, below 1 zooms out | `1.0` |
| `camera.smoothing_speed` | How fast the camera catches up to the ship; `0` locks it to the ship | `0` |
| `starfield.seed` | Random seed for star placement | `1` |
| `starfield.tile_size` | Size in px of the repeating star tile | `2048` |
| `starfield.layers[]` | One parallax layer each: `scroll_scale` (0 = fixed to screen, 1 = moves with the world), `count` (stars per tile), `size` (px), `brightness` (0–1) | three layers |
| `debug.time_scales` | Time-scale buttons in the debug panel | `[0.25, 0.5, 1, 2, 4]` |
| `debug.velocity_vector_seconds` | Velocity overlay line length, as seconds of travel | `0.5` |

## `ships/<id>.json`

Flight fields used from milestone 1 (required): `accel`, `top_speed`, `turn_rate`.

| Optional field | Meaning | Default |
| --- | --- | --- |
| `hit_radius` | Radius in px of the hit circle (and placeholder art size) | `16` |
| `sprite` | Path under `assets/sprites/`; art faces up. A placeholder shape is drawn if the file is missing | `""` |

Other fields (shield, armor, hardpoints…) are used from later milestones.
