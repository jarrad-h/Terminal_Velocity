# Terminal Velocity — guide for Claude Code

Terminal Velocity is a top-down space trading and combat game in the style of EV Nova, built in Godot 4 with GDScript. The current goal is the single-system prototype described in `docs/spec.md`. Read it (and `docs/decisions.md`) before starting any milestone; requirement IDs (F1, C3, D7…) come from it.

## How we work (read every session)

- **Source of truth:** `docs/spec.md` (what), `docs/decisions.md` (why), `docs/devlog.md` (what happened). Nothing lives only in chat. If a conversation changes the design, the spec changes in the same session.
- **Skills:** `design` for design talk (no code), `milestone` to build requirement IDs (plan → approve → build → test → playtest handover), `playtest` for Jarrad's feedback (bug / tuning / design change). Use them even if Jarrad doesn't name them.
- **Two PCs:** Jarrad switches between two Windows machines. Run the `start` skill at the beginning of every session and `wrap-up` at the end, even if he doesn't name them. Session history doesn't travel between machines; the devlog "Stopped at / Next step" note does.
- **Pinned Godot version:** 4.6.1-stable (`4.6.1.stable.official.14d19694e`) — both machines must match.
- **Commit** Godot `.uid` files; never commit `.godot/`.
- **Requirement IDs** (F1, C3, D8 …) are stable references. Cite them in commits, tests and devlog entries.
- **Verify, don't guess:** after code changes, run `python tools/check.py` and run the game via the `godot` MCP server to read real runtime errors. "It should work" is not done; GREEN plus a clean run is.
- **Tuning is data:** feel/balance feedback changes JSON in `data/`, not code.
- **Branches:** one per milestone (`m<N>-<slug>`). Merge to `main` only after Jarrad confirms the playtest.
- **Milestones in order:** work one milestone at a time, in the order the spec lists. At the end of each, stop and hand over for playtest; do not start the next one until Jarrad says so.
- **Commits:** small steps, message `m<N>: <IDs> <summary>` (e.g. `m3: C5 shields absorb damage before armour`).
- **Ask, don't guess:** if the spec is ambiguous or a requirement seems wrong, ask rather than guess. Do not expand scope beyond the current milestone.
- **Debug tools** ship with the milestone that needs them (see the Milestones section of the spec).
- **Devlog:** at the end of each milestone, add an entry to `docs/devlog.md` in the same format.
- **Godot 4 only:** `@export`, `@onready`, `await`, `CharacterBody2D`/`Node2D` + custom kinematics. Physics in `_physics_process`.
- **Review:** run the `godot-reviewer` agent before every playtest handover.
- **Windows:** Jarrad is on Windows; use the Godot *console* executable via `GODOT_PATH` for headless runs so output is captured.

## Hard rules

- **Everything tunable comes from data.** Ship, weapon, government, AI pool, scenery and system values live in JSON under `data/`. No gameplay numbers hard-coded in scripts; if a value is needed, add a field to the definition, loader validation and a documented default in `data/README.md`.
- **Kinematic flight, not physics bodies.** Ships move with our own maths each physics frame (fixed-rate turning, thrust, hard speed cap, drift). Ships do not collide with each other. Hitboxes are `Area2D`s (shots ray-test against them). `RigidBody2D` only for cosmetic debris.
- **One Ship scene for player and AI.** Behaviour differences live in the controller (PlayerController, IdleController, later AIController), never in separate ship scenes.
- **Simulation logic in plain classes** (`scripts/sim/`) that take state in and return state out, so it can be unit-tested without a running scene.
- **Debug code stays out of release builds**: guard with `OS.is_debug_build()`; all debug actions go through the `DebugCommands` autoload.

## Layout

```
data/         JSON definitions: ships/, weapons/, governments/, ai_pools/, systems/, scenery/ (fields in data/README.md)
mods/         Same structure; files here override data/ by ID
scenes/       .tscn files
scripts/
  autoload/   DataRegistry, GameState, DebugCommands
  data/       Typed definition classes and the DataLoader (validation, mod override)
  ship/       ShipBody, WeaponMounts, Health, controllers
  combat/     Projectiles, beams, hit queries, fragments, effects
  ai/         AI behaviours
  sim/        Pure logic (flight maths, damage, odds) — unit-testable
  ui/         HUD, radar, LandedScreen
  debug/      DebugPanel, Console, overlays
  world/      SystemScene, camera, Backdrop, LocalSpace, Scenery
assets/       sprites/, audio/, shaders/ (placeholder art is fine)
addons/gut/   GUT unit-test framework (vendored, 9.6.1 for Godot 4.6)
tests/
  unit/       GUT tests (test_*.gd) for scripts/sim and the data loader
  fixtures/   Data folders the loader tests read
  smoke/      smoke.tscn (boot + spawn every ship, must print no errors) and scenario.tscn (scripted end-to-end checks)
tools/        check.py (one health check), hooks/post_edit.py (edit hook)
docs/         spec.md, decisions.md, devlog.md
```

## Conventions

- GDScript with static typing everywhere (`var speed: float`, typed function signatures, typed arrays).
- snake_case for files, functions and variables; PascalCase for classes (`class_name`) and nodes.
- Data units: speed in px/s, acceleration in px/s², turn rate in degrees/s, regen in points/s, time in seconds.
- Data IDs are lowercase snake_case strings (`pirate_raider`) and match the file name.
- Prefer signals over polling for events (disabled, destroyed, landed, record changed).
- Keep scenes small and composed; avoid deep inheritance.

## Checking work

- `python tools/check.py` is the one health check: JSON parses, the project imports cleanly, GUT unit tests pass, the smoke scene prints no errors or warnings, and the scenario test passes. GREEN before every commit.
- Godot comes from `GODOT_PATH` (the console exe on Windows), else `godot` on PATH. A fresh clone imports on the first check run.
- Single pieces: unit tests `"$GODOT_PATH" --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -ginclude_subdirs -gexit`; smoke `"$GODOT_PATH" --headless --path . res://tests/smoke/smoke.tscn --quit-after 600`.
- `--quit` exits 0 even after script errors, so read output for `SCRIPT ERROR`/`ERROR` lines (check.py does). Invalid data makes the game exit 1 headless.
- Add or update tests in `tests/unit/` for anything in `scripts/sim/` and for the data loader's validation rules.
