---
name: wrap-up
description: Use when Jarrad ends a session or switches computers on Terminal Velocity — "wrap up", "done for today", "switching PCs", "save my place".
---

# Wrap up a session

Goal: the other PC (or a fresh session on this one) can carry on from the repo alone. Nothing may be left only on this machine or only in this conversation.

1. **Check health.** Run `python tools/check.py`. Don't block on RED (half-finished work is fine on a feature branch), but record what's failing.
2. **Capture design changes.** If this session agreed anything about the design that isn't yet in the spec (`docs/phase2-spec.md` or `docs/spec.md`) or `docs/decisions.md`, add it now (follow the `design` skill's rules for IDs and the decision log).
3. **Write the handover** — append to `docs/devlog.md` under today's date:
   ```
   ### YYYY-MM-DD — session wrap-up (<machine name from $env:COMPUTERNAME>)
   Branch: <branch>
   Done: <requirement IDs / fixes, one line each>
   Stopped at: <exactly where — file and function if mid-change>
   Next step: <the single next thing to do>
   Open questions: <for Jarrad or the spec; "none" if none>
   Check: GREEN | RED (<which check, why>)
   ```
   Be concrete enough that someone with no memory of this conversation could resume.
4. **Commit everything.** Stage all changes including Godot `.uid` files (never `.godot/`). Commit message: `wip: <summary>` if the work is mid-slice or checks are RED, otherwise `m<N>: <IDs> <summary>`. Do not merge to `main` here; that only happens after a confirmed playtest.
5. **Push.** `git push -u origin <branch>`. If the push fails, say so plainly — the session isn't wrapped until the push succeeds.
6. **Confirm** in two or three lines: branch pushed, the "Next step" line, and the reminder to say "start" on the other PC.
