---
name: milestone
description: Use when Jarrad asks to build, start, continue or finish a milestone or a set of requirement IDs (e.g. "/milestone 3", "do C1-C4", "build the radar").
---

# Build a milestone

Argument: a milestone number or a list of requirement IDs.

## 1. Plan (stop for approval)
- Read `docs/spec.md`, `docs/decisions.md`, the tail of `docs/devlog.md`, and the code the work touches.
- Create branch `m<N>-<slug>` from `main` (or continue it if it exists).
- Present a plan: requirement IDs covered, files to add/change, data schema changes, tests to add, and anything in the spec that is ambiguous. Ask the ambiguous questions now, in one batch.
- Wait for Jarrad's go-ahead before writing code.

## 2. Build in vertical slices
For each slice (one or a few requirement IDs):
- Write or extend tests first where the logic is pure (flight maths, damage, AI odds, data validation) — `tests/unit/`.
- Implement. Data-driven: anything tunable goes in JSON, not constants.
- Add the debug commands the spec assigns to this milestone (they go through the DebugCommands autoload).
- Run `python tools/check.py`. Fix until it prints GREEN.
- Run the game through the godot MCP server (run project, read debug output) for at least a few seconds and fix any runtime errors or warnings you introduced.
- Commit: `m<N>: <IDs> <summary>`.

## 3. Hand over for playtest
- Run the `godot-reviewer` agent on the branch and fix anything it marks `fix first`.
- Append to `docs/devlog.md`: date, IDs done, what to look at, known gaps, any spec questions.
- Give Jarrad a short playtest checklist: each requirement ID with the exact keys/debug commands to verify it.
- Do not merge to `main` until Jarrad confirms the playtest (see the `playtest` skill).
