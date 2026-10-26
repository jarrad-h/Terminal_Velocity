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

## 2026-10-26 — Fuel is only for hyperspace jumps and afterburners; out of prototype scope
Why: both jumps (multiple systems) and afterburners are outside the single-system prototype, so fuel has nothing to drive yet. The landing stub repairs only; refuelling arrives with jumps or afterburners.
Rejected: a refuel button on the landing stub now (fuel with no use is dead UI).

## 2026-10-26 — Pin Godot 4.7.2-stable (was 4.6.1) and GUT 9.7.1
Why: 4.7.2 is the current stable release. The project, all unit tests, the smoke and scenario tests and a windowed run pass on it unchanged, and GUT 9.7.1 (built for 4.7) also removes a harmless timer-leak warning GUT 9.6.1 printed on every `--import`.
Both PCs must run the same version: opening the project in a different Godot version rewrites project and scene files.
Rejected: staying on 4.6.1 (no reason to lag the stable release this early).

## 2026-10-26 — AI behaviour has a group level and an individual level (A7)
The group (government + AI pool) decides standing and broad behaviour: friends and foes, role, base odds and flee threshold. Each AI ship also gets a personality (a new `personality` definition type, picked by weight from its pool) that shades behaviour within those rules: odds tolerance, flee threshold, fight-or-flee when attacked, and whether it starts fights. Personalities never change who is a friend or enemy.
Why: traders, warships and pirates should not all act alike within a faction (a brave trader fights back, a skittish one bolts), while faction relations stay predictable and data-driven. Personalities are their own type so one "brave" can be reused across pools.
Rejected: personality fields inline in each AI pool (duplicated values); per-ship-hull temperament (hull and pilot are different things).

## 2026-10-26 — Provoked ships retaliate regardless of legal record (A8)
A ship the player damages, and its government's warships, are hostile to the player until the player leaves the system. Allies don't react.
Why: without it, the patrol ignores the player shooting traders for many hits, because the record falls slowly (3 per ship). Nova-like.
Rejected: strict threshold-only hostility (feels unresponsive).

## 2026-10-26 — Legal penalties apply once per ship per kind of act (G2)
The attack ("shoot") penalty applies on the first hit on a ship, not per hit; disable, board and destroy once each. Lasers fire 4 times a second, so per-hit penalties would swamp the record.

## 2026-10-26 — Traders dock and relaunch as the same ship (A1)
A landed trader stays docked (hidden, untargetable) for a dwell time, then takes off again. Rejected: despawn on landing and spawn a fresh trader (loses continuity).

## 2026-10-26 — AI friendly fire is a data percentage (C11)
AI shots hit own and allied ships at `combat.friendly_fire_pct` (game.json; 0 = off). Player shots always do full damage. Only the player's legal record is tracked.

## 2026-10-26 — R targets the nearest hostile (C8)
R selects the nearest hostile ship (falling back to the nearest ship if none are hostile); Tab still cycles all ships nearest first.

## 2026-10-26 — G3 applies to every ship of a government, not only warships
Below a government's crime threshold all its ships are hostile to the player; role and personality decide whether they actually fight. Pirates are hostile from the start through their high threshold, so future missions that raise the player's pirate record can make pirates non-hostile with no special case.
Rejected: warships-only hostility plus a separate "pirates are always hostile" rule (two mechanisms, and no path to siding with pirates).

## 2026-10-26 — Leniency replaces faction-wide provocation (A8, G2)
Damage from the player builds a per-ship grievance (share of the ship's total shield + armour) that drains over time; the ship turns hostile only when it passes its government's tolerance (shaded by personality). Crossing it charges the attack penalty; disable and destroy still charge immediately. Other ships of the government react only through the legal record (G3); allies ignore it. Pirates follow the same rules.
Why: accidental shots are common in a crowded fight; one stray hit shouldn't turn a neutral or ally red, and one ship's grudge shouldn't turn a whole faction.
Rejected: hit counts within a time window (unfair between 4-shots-a-second lasers and slow missiles); warn-then-hostile (no proportion); keeping the earlier "provoke all its warships" rule (too punishing).

## 2026-10-26 — Shields recharge after a delay without damage (C6)
Any hit resets a per-ship recharge delay; after it, shields refill at shield_regen up to the cap. Delay, rate and cap are the stats future upgrades (outfits) will modify, so they stay separate ship fields.

## 2026-10-26 — Targeting keys: R / Tab nearest, Shift+R / Shift+Tab cycle (C8)
R nearest hostile, Tab nearest of any kind, Shift+R cycles hostiles, Shift+Tab cycles all, nearest first. Replaces "R nearest hostile, Tab cycles all".

## 2026-10-26 — Weapon damage falloff with distance (C12)
Any weapon can lose damage with distance (full damage to a set fraction of range, linear down to a set minimum at full range); shots and beams fade to show it. The mining beam's range rises to cross the screen, balanced by falloff.
Rejected: keeping the beam short (Jarrad wants it long).
