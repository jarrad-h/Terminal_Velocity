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

## 2026-10-26 — Provoked ships retaliate regardless of legal record (A8) — superseded later that day by grievance leniency
A ship the player damages, and its government's warships, are hostile to the player until the player leaves the system. Allies don't react.
Why: without it, the patrol ignores the player shooting traders for many hits, because the record falls slowly (3 per ship). Nova-like.
Rejected: strict threshold-only hostility (feels unresponsive).

## 2026-10-26 — Legal penalties apply once per ship per kind of act (G2) — attack penalty timing superseded by grievance leniency
The attack ("shoot") penalty applies on the first hit on a ship, not per hit; disable, board and destroy once each. Lasers fire 4 times a second, so per-hit penalties would swamp the record.

## 2026-10-26 — Traders dock and relaunch as the same ship (A1)
A landed trader stays docked (hidden, untargetable) for a dwell time, then takes off again. Rejected: despawn on landing and spawn a fresh trader (loses continuity).

## 2026-10-26 — AI friendly fire is a data percentage (C11)
AI shots hit own and allied ships at `combat.friendly_fire_pct` (game.json; 0 = off). Player shots always do full damage. Only the player's legal record is tracked.

## 2026-10-26 — R targets the nearest hostile (C8) — superseded by the R / Tab / Shift keys entry
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

## 2026-10-28 — Attacking an already-hostile ship charges the attack penalty on the first hit (G2)
A ship that is already hostile through the legal record counts as past its tolerance, so the attack penalty applies on the player's first hit (once per ship).
Why: leniency exists to forgive accidental fire on friends, not attacks on ships already at odds with the player. Recorded at the final M4 audit to match the code; Jarrad can overturn it.

## 2026-10-28 — Boarding: timed, then a paused boarding window with choices (C9)
Stop alongside a disabled ship; a 2 s boarding timer (cancelled by drifting off or taking damage), then the game pauses on a window: Take credits, Assist (it leaves; +record), Scuttle (kill penalty) or Leave. Choices lock out others (looted ships can't be assisted); Leave allows reboarding later. Credits = hull board_credits range × AI pool wealth_factor × randomness, so traders carry money and police patrols don't. Disabled ships stay until the player leaves the system.
Why: gives boarding tension and a lawful use (rescue traders pirates disabled), and room to read. Rejected: one-shot instant boarding (Jarrad); credits from strength (a patrol isn't rich).
Later: capture, cargo/outfit plunder, personality wealth.

## 2026-10-28 — Death: escape pod and insurance instead of station respawn (C10)
If the player owns an escape pod, it launches, then a paused window reports days passing, the rescuer and a rescue fee; the player wakes landed at the nearest port that accepts them. Insured: same hull replaced; uninsured: a basic hull. No pod: game over and restart. Rescue counts as leaving and returning (wrecks and destroyed scenery cleared, traffic refreshed); record and grudges stay. Pod and insurance are data flags (owned) until outfits exist.
Rejected: respawn at the station after a delay (Jarrad: no consequence, no fiction).

## 2026-10-28 — Hold T to face the target's lead point (F5)
Ad hoc control request. Turns at the ship's normal turn rate toward the lead point for its primary guns; thrust and fire stay manual.

## 2026-10-28 — Radar arrow for an out-of-range target (H2); minimal message line pulled into M5 (H4)
Why: the arrow keeps a distant target findable without zooming the radar out (Jarrad's ad hoc request). The message line is the only feedback for landing hints, refusals, boarding results and the escape pod, so a minimal one comes forward from milestone 6, which will polish it.

## 2026-10-28 — Assist is once per ship (C9)
A ship the player has assisted can't be assisted again, even if disabled again. Found at review: disable → assist → disable again would otherwise farm record. Jarrad can overturn it.

## 2026-10-29 — Scope change: generated ship art comes into the prototype
The Standard Orbital Works (SOW) hulls and the pirate raider (generated by `art_src/sow/export.py`, branch `art/sow-kit`, documented in `docs/art/`) are wired into the game: ship sprites, hitboxes and hardpoints that line up with the art, and turret and engine visuals where cheap. Other art stays placeholder. Sprites are never hand-edited; changes go back to Jarrad's generator.
Why: the art exists and the prototype's feel (10 minutes of fighting without feeling flat) is easier to judge with real ships; hitbox and hardpoint sizes change with the art, so they must settle before the balance pass.
Rejected: keeping placeholders until after the prototype (tuning would be redone once sizes change).
Placement and scale rule: see the next entry.

## 2026-10-29 — Art integration is Milestone 6; one scale rule; weapons by size and mount (V1–V5, C1, C2, C13)
- **Placement:** a new Milestone 6 before the HUD and tuning pass (now Milestone 7), so hitbox and hardpoint sizes settle before balancing.
- **Scale rule:** art at 1:1 times one global `art_scale` (1.0). Hardpoints and engine exits copied verbatim from `hardpoints.json` × `art_scale`; capsule hitboxes cover the hull body only (ornaments like the freighter's solar panel don't count). Rejected: per-ship shrink factors (one rule is easier to reason about and keeps art and data in step) and a global ×0.5 (wastes the art's detail). The world grows in data instead: planet radii ×4, object positions, scenery regions and the system edge ×2, camera zoom 0.75 and radar range 6000 (starting points for playtest; AI sensor ranges are left for the M7 balance pass).
- **Art is the reference for ship data:** the courier is unarmed (C-B Booster), so the player starts in the shuttle (as the content table always said); the patrol corvette uses P-B (2 light turrets + VLS-4) and loses its fixed lasers.
- **Weapons come in size and mount type:** hardpoints are small/medium/large × fixed/pivot/turret/launcher. Within a size, a weapon's numbers are the same on every mount (only aiming differs), so there is one weapon file per size (`laser_small`, `laser_medium`, `laser_large`) and each installed item records its mount, because the player will later buy weapons by mount type. Beams follow the same pattern; missiles use the launcher mount and will get their own variants. Rejected: a weapon file per size-and-mount pair (numbers would drift apart).
- **Arcs** belong to the mount, not the weapon: game.json defaults (fixed 0°, pivot 30° total, turret 360°), overridable per hardpoint. The art's suggested arcs are guidance only.
- **Point defence** is a small turret with a PD role tag on the hardpoint (picks the `pd1` sprite) and its own behaviour on the weapon (auto-fires at missiles, no input). Specified now as C13, built when a PD hull enters the game; flak stands in until then.
- **Launcher cells** (VLS-4 6, VLS-3 11) are guidance only; missile ammo stays in data until missile variants arrive.
Why: Jarrad's direction (2026-10-29), keeping sizes, mounts and arcs data-driven for the later outfitter.

## 2026-10-29 — M7 scope: target schematic, standing, beam aim (H3, H4, G5, F5)
- **Target panel** is a schematic: a nose-up silhouette tinted green → yellow → red by armour, a shield outline that fades, grey when disabled; plus class, type (role), government, standing, distance and a hint. The label stays "Armour" (Jarrad).
- **Standing (G5):** friendly needs the player's record with the government at or above its `friendly_record` (default 25); hostile as before; neutral in between and for ships with no government; angry (grievance, A8) shows in the warning colour. This replaces the radar's old "any non-hostile government ship is friendly". Traders the record makes hostile stay red even though they only flee (Jarrad: red means hostile).
- **Hold-to-aim and beams:** accepted as is. F5 and the AI keep leading for projectiles; a fixed beam is aimed by hand, or fitted on a pivot mount. The raider's mining beam moves to a pivot mount (data; the art's mount types are guidance). Known risk: when weapons with different shot speeds share a ship (lasers vs mass drivers later), one lead point can't serve them all.
- **Balance targets:** raider disables the shuttle in about 20–30 s; a patrol corvette beats a raider one on one.
Why: Jarrad's direction, 2026-10-29.

## 2026-10-29 — M7 playtest: fights twice as fast; shield bubble; pale disabled pips (H2, H3)
- Time to kill was too long: the prototype's hulls are small and should be delicate. Ship shield, regen and armour halved (weapon and scenery numbers unchanged), so every fight takes half as long: raider disables the shuttle in about 13 s at 50% hits (was 26). Grievance tolerance and forgiveness doubled so stray hits are still forgiven and sustained fire still turns ships hostile in the same time.
- The target schematic shows the shield as a translucent bubble round the hull, not an outline.
- Disabled ships show on the radar as a pale version of their standing colour (`radar.disabled_pale`).
Why: Jarrad's playtest, 2026-10-29. Supersedes the 20–30 s target in the M7 scope entry.

## 2026-10-30 — Phase 2 is "the loop"; spec in docs/phase2-spec.md
Phase 2 turns the prototype into an hour of play: galaxy and travel, a day calendar, persistence, saves, economy, shipyard and outfitter, a mission engine, progression and one short arc, in that milestone order.
Why: the prototype proved combat; it has no reason to keep playing. Persistence comes before saves so the save format is designed around it.
Rejected: building more combat depth first (AI finishing ships, point defence, escorts); kept on the review list.

## 2026-10-30 — Travel: hyperlanes and gates now; jump drive and currents in Phase 3 (TR)
Hyperlane jumps go to adjacent systems only, need the ship beyond the jump radius, and stop the ship for a countdown, so jumping is not an instant escape. Gates are owned by whoever controls the system, link to other gates regardless of adjacency, charge a fee and check the record, and can be closed by a flag. A player-earned jump drive and another faction's one-way "currents" are agreed for Phase 3.
Why: Jarrad's design; two clear trade-offs first, exotic travel once the faction that owns it exists. Rejected for now: leviathan travel (revisit with fauna).

## 2026-10-30 — Time is a day calendar advanced only by actions (TM)
Landing and taking off, jumps, gate travel and some missions cost days; nothing ticks in real time. Days are the smallest grain.
Why: Jarrad's direction; gives deadlines, fleet arrivals and price events meaning without a real-time clock.

## 2026-10-30 — Persistence at three levels of detail (PS)
The current system is fully simulated; persistent entities (named characters, fleets, ships the player marked) are tracked galaxy-wide in summary and materialise when the player is present; every system has a memory (alert, pirate presence, wrecks) that recovers over days. Phase 2 builds the foundation and three test entities; the war front is Phase 3.
Why: Jarrad wants characters and fleets that can be followed between systems and no free reset by jumping out and back. Rejected: everything resets on leaving (exploitable); full simulation of every system (cost).

## 2026-10-30 — Economy: fixed price tiers plus price events (EC)
Nova-style low/medium/high tiers per stellar, with data-driven temporary events. Dynamic supply and demand goes on the review list.
Why: predictable to balance first. Rejected for now: dynamic supply and demand.

## 2026-10-30 — Ironman pilots; full trader playstyle; broad progression (SV, OF6, PR)
Ironman is chosen at pilot creation and locks the pilot to one save. A pure trader must be viable, with escape (afterburner, hyperspace tuning, sensors, cargo decoys) as the trader's answer to danger. Progression is money, faction standing and ranks, combat and trade ratings, and data-defined achievements.
Why: Jarrad's direction.

## 2026-10-30 — Hull manifests replace documented hardpoints; editor in the repo (OF7–OF9)
Each hull's geometry lives in one `hull.json`; ship data names the hull and a loadout by hardpoint ID, and nothing is copied by hand. Readable summaries and spec sheets are generated for review only. The manifest gains compound hit shapes (wide hulls), sprite layers, size class and displacement, and the parts a generated hull was built from. Shipyards cap the hull size they sell (OF8); hull base stats go through the outfit modifier system (OF9). `tools/hardpoint-editor/index.html` writes the manifest and changes with its format. Built in Phase 2 milestone 6.
Why: the art-to-data hand-off via written summaries drifted (three ships disagreed with their art); the capsule rule (width at most length) can't fit wide hulls.
Rejected: keeping prose hardpoint documentation as the contract.

## 2026-10-30 — Prepare for player-built ships; art phase before Phase 3
Every ship is saved as a design plus instance state (SV1), and art is kept as individual part assets with their own manifests (category, attachment points, paint mask, cosmetic flag), so a late-game ship designer and player shipyards stay possible without rework. An art phase between Phase 2 and Phase 3 builds the expanded asset library.
Why: Jarrad wants player stations and ship manufacturing late game; these choices are cheap now and expensive to retrofit.

## 2026-10-30 — P2M1 scope: the jump flies itself; separate day costs; three map states (TR2, TR4, TR7, TR8, TM2)
- **Jump sequence (TR2):** pressing J with a valid destination locks the controls and the ship flies the jump with its own turn rate and thrust: stop (turn and burn against velocity), turn to the destination's galaxy-map bearing, then the countdown (only once stopped and facing), then a hard acceleration past the speed cap to the hyperdrive speed, where it leaves. Overdrive acceleration and hyperdrive speed are data. Fire or J cancels until the hyperdrive engages; disabled cancels; hits don't.
- **Arrival (TR4):** at the destination's jump radius, on the side facing the origin, moving inward at a data fraction of top speed.
- **Day costs (TM2):** landing 1 (per stellar), take-off 0 (per stellar), landed activities 0 until activities exist, each with its own cost. Jump days = lane length on the map ÷ ship jump speed, rounded up, at least 1.
- **Fuel (TR8):** flat `jump_fuel` per jump for now, computed by one function that takes ship, lane and distance, so a distance or lane-based rule needs no format change.
- **Map states (TR7):** explored, unexplored (shown, labelled "Unexplored") and hidden (not drawn or routable until revealed by a map purchase, intel, a found gate or a mission). Galaxy data sets each system's starting state; reveals are game state. Selecting a system shows a stylised system view (star, planets, stations from system data) for explored systems.
- **Calendar (TM1):** a real calendar from a data start date (placeholder 1 Jan 3200), shown "14 Mar 3200", until the setting decides.
- **Keys:** J jump/cancel, M map, click a system to plot the shortest route.
- **Stranding:** every system with a planet sells fuel and the empty transit systems are one jump from fuel; hailing for fuel and rescue come later.
Why: Jarrad's direction, 30 Oct 2026 (normal ship movement into the jump reads as flying, not a teleport; separate day costs leave room for activities; hidden systems leave room for discovery).
