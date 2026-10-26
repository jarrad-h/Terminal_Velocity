# Decisions

Append-only. Newest at the bottom. Each entry: date, decision, why, alternatives rejected.
The spec says *what*; this file says *why*, so nobody (human or Claude) re-litigates a settled call.

## 2026-10-13 — Engine and language: Godot 4.x stable, GDScript throughout
Why: free, light, good 2D; one language keeps Claude's output consistent.
Rejected: C# (heavier tooling, split language).

## 2026-10-13 — Data format: JSON definitions with readable string IDs
Why: hand-editable, diffable, hot-reloadable; explicit references instead of Nova's numeric offsets.
Later files with the same ID override earlier ones (base → mods), from day one.

## 2026-10-13 — Missions: declarative data with optional script hooks
Why: Endless Sky-style data covers most missions; hooks handle edge cases without Naev-style full scripting.

## 2026-10-13 — Controls: Nova-style keyboard thrust/turn, no mouse aim

## 2026-10-13 — Physics: custom kinematic movement for ships
Why: fixed turn rate, drift, hard speed cap map one-to-one to data values; predictable AI steering; ships pass through each other like Nova.
Rejected: RigidBody2D (angular momentum fights the speed cap, adds collisions). RigidBody2D only for cosmetic debris/fragments.

## 2026-10-13 — Project: "Terminal Velocity", own repo, separate from the strategy game

## 2026-10 (M2 review) — Scenery persistence
Destroyed scenery stays destroyed until the player leaves the system (in-memory set). Drifting solid scenery spawns at start + velocity × elapsed time; dust and non-solid scenery skip this for performance.

## 2026-10 (M3 scope) — Radar and placeholder system objects pulled forward into Milestone 3
Scenery gains a `radar` boolean; only large asteroids and derelict hulls set it in prototype data.

## 2026-10-26 — Workflow: repo is the single source of truth; Claude Code is the primary surface
Why: removes copy-paste between claude.ai and Claude Code. `docs/spec.md` replaces the Claude Docs spec; design talk happens through the `design` skill.
