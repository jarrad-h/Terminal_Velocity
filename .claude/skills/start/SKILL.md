---
name: start
description: Use at the beginning of a work session on Terminal Velocity, or when Jarrad says "start", "pick up where I left off", "I'm on the other PC", or similar.
---

# Start a session

Jarrad works across two Windows PCs (project at `C:\Dev\Terminal_Velocity` on both) and also starts cloud sessions from the Claude app (for example from his phone), usually one per phase or milestone. This machine may be behind the others. Get in sync before touching anything.

## Standing behaviours (agreed with Jarrad, 30 Oct 2026; apply every session)

- **Read before acting.** CLAUDE.md, the current phase spec it names (now `docs/phase2-spec.md`), `docs/spec.md`, `docs/decisions.md` and the tail of `docs/devlog.md`.
- **Ask first.** Before starting a milestone or any non-trivial change, ask clarifying questions in one batch, each with a proposed default, so Jarrad can answer "defaults are fine" from his phone. Don't write code until he says go.
- **Design talk lands in the repo the same session.** Anything agreed in chat (behaviour, keys, day costs, data shape) goes into the phase spec and `docs/decisions.md` before or with the code.
- **Playtest method.** Jarrad plays in the Godot editor on his PC and reports feel ("turning is too slow", "drift feels floaty"). Follow the `playtest` skill and CLAUDE.md: tuning changes JSON in `data/`; code changes only for bugs, or to add a data field when the value isn't in data yet (with loader validation and a `data/README.md` default).
- **Keep commands portable.** The check uses `GODOT_PATH` (the exe) and `--path .` (the repo root), so it works on both PCs and in the cloud; don't hard-code a machine's path in CLAUDE.md or tools.
- **Future-proof data shapes.** When Jarrad picks a simple rule for now (e.g. flat fuel per jump), structure the data so a richer rule can replace it later without a format change, and say how.

## Steps

1. **Check for local leftovers.** Run `git status`. If there are uncommitted changes, stop and show them; ask whether to commit, stash or discard before pulling. Never discard without a clear yes.
2. **Sync.** `git fetch --all --prune`, then `git switch` to the branch named in the latest devlog "Stopped at" note (fall back to the newest `p2m<N>-*` / `m<N>-*` branch, then `main`). `git pull --ff-only`. If fast-forward fails, stop and explain the divergence instead of merging or rebasing on your own.
   - **Cloud sessions** are often assigned a `ccr-*` branch. Milestone work still follows CLAUDE.md's branch rule (`p2m<N>-<slug>`); Jarrad approved this on 30 Oct 2026, but confirm the branch name in the plan before pushing a new one.
3. **Check the machine.** Work out which kind of machine this is (Windows PC, or a Linux cloud container: `uname`, no `C:` drive).
   - **Windows PC:** `& $env:GODOT_PATH --version` (or `godot --version`) matches the pinned version in CLAUDE.md. If it differs, warn before opening the project in the editor: a different Godot version rewrites project and scene files. `claude mcp list` shows `godot` connected; if not, point Jarrad at SETUP.md step 3 for this machine.
   - **Cloud container:** Godot isn't installed and there is no godot MCP server. Install the pinned version headless (Jarrad approves the download prompt):
     ```
     mkdir -p /opt/godot && cd /opt/godot
     curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
     unzip -oq godot.zip && rm godot.zip
     export GODOT_PATH=/opt/godot/Godot_v4.7.2-stable_linux.x86_64   # set it in every shell that runs checks
     "$GODOT_PATH" --headless --version                               # must print the pinned version
     ```
     (Change the version in the URL if CLAUDE.md's pin changes.) Without the MCP server, "run the game" means the headless smoke and scenario runs in `tools/check.py`; say in the handover that Jarrad's windowed run on his PC is the first visual check.
   - `python --version` works (the edit hook and checks need it).
4. **Health check.** Run `python tools/check.py`. If it's RED on a fresh pull, that's a problem left from last session or a machine difference; say which check failed before doing anything else.
5. **Brief Jarrad** in a few lines:
   - Branch and last commit (date, message, which machine if the devlog says).
   - The latest devlog "Stopped at" / "Next step" note.
   - Check result (GREEN / RED and why).
   - Any machine warnings from step 3.
   Then ask what he wants to do, suggesting the devlog's next step as the default.
