# Terminal Velocity — guide for Claude Code

Terminal Velocity is a top-down space trading and combat game in the style of EV Nova, built in Godot 4 with GDScript. The current goal is the single-system prototype described in `docs/prototype-spec.md`. Read that file before starting any milestone; requirement IDs (F1, C3, D7…) come from it.

## How we work

- Work one milestone at a time, in the order the spec lists. At the end of each milestone, stop and summarise what to playtest; do not start the next one until Jarrad says so.
- Within a milestone, commit in small steps with messages that cite requirement IDs, e.g. `C5: shields absorb damage before armour`.
- If the spec is ambiguous or a requirement seems wrong, ask rather than guess. Do not expand scope beyond the current milestone.
- Debug tools ship with the milestone that needs them (see the Milestones section of the spec).

## Hard rules

- **Everything tunable comes from data.** Ship, weapon, government, AI pool and system values live in JSON under `data/`. No gameplay numbers hard-coded in scripts; if a value is needed, add a field to the definition and a documented default.
- **Kinematic flight, not physics bodies.** Ships move with our own maths each physics frame (fixed-rate turning, thrust, hard speed cap, drift). Ships do not collide with each other. Use `Area2D` overlaps for hit detection. `RigidBody2D` only for cosmetic debris.
- **One Ship scene for player and AI.** Behaviour differences live in the controller (PlayerController or AIController), never in separate ship scenes.
- **Simulation logic in plain classes** (`scripts/sim/`) that take state in and return state out, so it can be unit-tested without a running scene.
- **Debug code stays out of release builds**: guard with `OS.is_debug_build()`; all debug actions go through the `DebugCommands` autoload.

## Layout

```
data/         JSON definitions: ships/, weapons/, governments/, ai_pools/, systems/
mods/         Same structure; files here override data/ by ID
scenes/       .tscn files
scripts/
  autoload/   DataRegistry, GameState, DebugCommands
  ship/       ShipBody, WeaponMounts, Health, controllers
  ai/         AI behaviours
  sim/        Pure logic (flight maths, damage, odds) — unit-testable
  ui/         HUD, LandedScreen
  debug/      DebugPanel, Console, overlays
assets/       sprites/, audio/ (placeholder art is fine)
tests/        Unit tests for scripts/sim and the data loader
docs/         Spec and design notes
```

## Conventions

- GDScript with static typing everywhere (`var speed: float`, typed function signatures, typed arrays).
- snake_case for files, functions and variables; PascalCase for classes (`class_name`) and nodes.
- Data units: speed in px/s, acceleration in px/s², turn rate in degrees/s, regen in points/s, time in seconds.
- Data IDs are lowercase snake_case strings (`pirate_raider`) and match the file name.
- Prefer signals over polling for events (disabled, destroyed, landed, record changed).
- Keep scenes small and composed; avoid deep inheritance.

## Checking work

- Run the project headless to catch script errors before handing back: `godot --headless --path . --quit` (adjust the Godot executable name for this machine).
- Add or update tests in `tests/` for anything in `scripts/sim/` and for the data loader's validation rules.
