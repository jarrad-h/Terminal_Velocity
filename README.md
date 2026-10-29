# Terminal Velocity

A top-down space trading and combat game in the spirit of EV Nova, built in Godot 4.

Current stage: single-system prototype. See [docs/spec.md](docs/spec.md) for scope, requirements and milestones.

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
| Space | Fire primary weapons (guns, turrets, beams) |
| F / Left Ctrl | Fire secondary weapons (guided missiles) |
| R | Target nearest hostile ship |
| Tab | Target nearest ship of any kind |
| Shift+R | Cycle hostile ships, nearest first |
| Shift+Tab | Cycle all ships, nearest first |
| L | Land on the nearest planet or station (fly in slowly first) |
| B | Board a disabled ship alongside (stop next to it) |
| Hold T | Keep facing the target's lead point |
| 1–4 | Pick an option in the landed, boarding and rescue windows |
| ` (backtick) | Debug panel (debug builds only) |
| F1 | Debug console (debug builds only) |

## Data and mods

All ships, weapons, governments, traffic pools and the star system are JSON files in `data/`. Files in `mods/` with the same ID replace the originals.
