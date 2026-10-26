---
name: start
description: Use at the beginning of a work session on Terminal Velocity, or when Jarrad says "start", "pick up where I left off", "I'm on the other PC", or similar.
---

# Start a session

Jarrad works across two Windows PCs. This machine may be behind the other one. Get in sync before touching anything.

1. **Check for local leftovers.** Run `git status`. If there are uncommitted changes, stop and show them; ask whether to commit, stash or discard before pulling. Never discard without a clear yes.
2. **Sync.** `git fetch --all --prune`, then `git switch` to the branch named in the latest devlog "Stopped at" note (fall back to the newest `m<N>-*` branch, then `main`). `git pull --ff-only`. If fast-forward fails, stop and explain the divergence instead of merging or rebasing on your own.
3. **Check the machine.**
   - `& $env:GODOT_PATH --version` (or `godot --version`) matches the pinned version in CLAUDE.md. If it differs, warn before opening the project in the editor: a different Godot version rewrites project and scene files.
   - `claude mcp list` shows `godot` connected. If not, point Jarrad at SETUP.md step 3 for this machine.
   - `python --version` works (the edit hook and checks need it).
4. **Health check.** Run `python tools/check.py`. If it's RED on a fresh pull, that's a problem left from last session or a machine difference; say which check failed before doing anything else.
5. **Brief Jarrad** in a few lines:
   - Branch and last commit (date, message, which machine if the devlog says).
   - The latest devlog "Stopped at" / "Next step" note.
   - Check result (GREEN / RED and why).
   - Any machine warnings from step 3.
   Then ask what he wants to do, suggesting the devlog's next step as the default.
