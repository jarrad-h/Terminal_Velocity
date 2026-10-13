# Terminal Velocity

A top-down space trading and combat game in the spirit of EV Nova, built in Godot 4.

Current stage: single-system prototype. See [docs/prototype-spec.md](docs/prototype-spec.md) for scope, requirements and milestones.

## Running

1. Install Godot 4 (standard build, not .NET).
2. Open Godot, choose **Import**, and select `project.godot` in this folder.
3. Press F5 to run.

## Controls

| Key | Action |
| --- | --- |
| Up / W | Thrust |
| Left, Right / A, D | Turn |
| Down / S | Reverse: turn to face against your drift (hold thrust too to brake) |
| ` (backtick) | Debug panel (debug builds only) |

## Data and mods

All ships, weapons, governments, traffic pools and the star system are JSON files in `data/`. Files in `mods/` with the same ID replace the originals.
