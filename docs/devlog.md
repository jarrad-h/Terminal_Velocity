# Devlog

One entry per milestone: what was built (by requirement ID), deviations from the spec and why, known issues, and the key tuning values at the end of the milestone. Newest first.

---

## Phase 2 Milestone 2: Gates and lighting (30 Oct 2026)

Playtest confirmed by Jarrad on 30 Oct 2026; merged to `main`. Branch `p2m2-gates-lighting`, built in a cloud session (Godot 4.7.2 headless; checked by unit tests and the scenario test, plus measurements and screenshots rendered under a virtual display). Scope widened on 30 Oct to fold in lit ships after the light maps landed (PR #4); first-pass stellar art (PR #5) merged into `main` and wired in here. Decisions: `docs/decisions.md`, 30 Oct entries on lighting and milestone 2.

### Built

- **TR5, TR6 gates:**
  - **Data:** gates are a new stellar type, with `government`, `min_record`, `fee` and `open_condition` (`""`, `flag` or `!flag`; the milestone 7 condition grammar will read the same field).
  - **Links:** gate links are `gate_links` in the galaxy file, two-way, with `days`.
  - **Loader checks:**
    - at most one gate per system;
    - both ends of a link need a gate;
    - a link is never slower than the start ship's hyperlane route, and is strictly faster when that route takes more than a day.
  - **Docking:** **L** near a gate docks, using the same distance and speed rules as landing. It's refused when the gate is closed or your record is below its minimum.
  - **Gate list:** it pauses the game and uses the shared theme. Each destination shows its days and the departure gate's fee; a closed or unaffordable destination is greyed out.
  - **Travel:** going through charges the fee and advances the days. You arrive stopped at the destination gate's `jump_point`, with a flash, and a plotted route is replotted from the new system.
  - **Flags:** a minimal flag store in GameState (saved with everything else) and a `flag <name> [n]` console command.
  - **Test cluster:** one gate in each of the 4 core systems, all linked at 1 day each. Fees are 40–80. Graveyard's gate closes with `graveyard_gate_closed`; Lumen's gate needs record 15.
- **TR7:** gate links are drawn dashed in amber on the map, dimmed while either gate is closed. The system view shows the art's 64 px icons, with the star's icon tinted.
- **H5:** `assets/ui/theme.tres` is the shared theme (dark panel, amber border and accents). `Dialog.use_shared_theme()` applies it; the gate list is the first screen to use it.
- **V6, V7 lit ships:**
  - `LitSprite` draws hulls and turrets as albedo plus normal map, with emission as an additive, unshaded child.
  - Sprites without maps (the pirate raider) use their baked image, drawn unshaded.
  - `SystemLighting` adds a `DirectionalLight2D` aimed from the system's star towards the player each frame, and a `CanvasModulate` for the ambient level. Values are in `game.json` `lighting`, and any system can override them in its own `lighting` block.
  - Things without maps (dust, shots, beams, flashes, engine glow, labels, placeholders) are unshaded, so they keep their brightness. The backdrop and HUD are on their own layers.
- **V8:** point lights in the weapon's colour on shots and at a beam's far end; a fading light at impacts; one dim light at each ship's engines that follows thrust. Shot, beam and impact lights are capped (`lighting.max_lights`, 24) and are released with their owners.
- **V9 stellars:**
  - **Data:** each stellar names an `art` set, replacing the unused `sprite` field. The loader checks the set exists and suits the stellar's type. The art's manifest gives sizes and anchors, and scale is radius × 2 ÷ the art's disc or width.
  - **Planets:** layers drawn in order (rings, surface, emission, clouds turning slowly, additive atmosphere). City lights are masked to the night side by `night_lights.gdshader` for the art sets in `stellars.night_only_emission`; lava glows everywhere.
  - **Star, stations and gates:** the star is tinted emission. Stations and gates are lit. A closed gate hides its ring and field; the beacons stay on.
  - **Scenery:** large asteroids, rocks, small debris and derelict hulls now use the PR #5 sprites, lit.
  - **New stations:** a trader yard at Solace and a pirate rock at Redhaven, so all three station art sets appear in the cluster.
- **D14:** console `light on|off`, `star angle <deg>|auto` and `star height <0-1>`, plus a Lighting section in the debug panel.

### Stopped at / Next step

Stopped at: P2M2 merged to `main` (30 Oct 2026). Next step: plan Phase 2 milestone 3 (persistence foundation, PS1–PS7, plus AI hyperspace travel and gate traffic from the M2 playtest) on `p2m3-<slug>`.

### Checks

- **Headings:** with the light forced from the right, the shuttle's right half is brighter at every heading, and flipping the light flips it (measured on rendered frames, 8 headings).
- **Shot lights:** with starlight off, a hull parked beside the line of fire is about 50% brighter with shot lights on (13 → 19 mean brightness).
- **Performance:** in a 10-ship fight under software rendering, average frame time is the same with lighting on and off (about 24 ms, 900 frames each, two runs). Your windowed run on a real GPU is the real check.
- **Tests:**
  - unit: gate rules, plus the loader's gate, gate-link and art errors;
  - scenario: docking, every refusal, gate travel, flags, lit hulls and turrets, the raider fallback, star and ambient from data, every stellar drawn from its art with the right scale, planet layers, the night mask, gas giant rings, the closed-gate ring, lit rocks, the shot-light cap and release, and D14.

### 2026-10-30 — Playtest notes (Jarrad)

- **Bug (V8): laser fire made large highlights on planets.**
  - Cause: shot lights lit everything with normal maps, including planets, which are huge and sit far below the action.
  - Fix: light masks. Weapon and engine lights reach only hulls, stations, gates and scenery (`LitSprite.NEAR_LIGHT`); the star still lights everything.
  - Checks: under a virtual display the planet's brightness under the line of fire is unchanged by firing; scenario checks the masks.
- **Bug (V9): the nebula showed through the star.**
  - Cause: the star art is additive emission, which brightens the backdrop without hiding it.
  - Fix: an opaque disc just inside the limb sits under the glow (`stellars.star_disc_cover` 0.97, `star_disc_colour` black).
  - Check: scenario checks the disc exists.
- **Design changes, confirmed by Jarrad and built (V7, V9):**
  - **Star colour:** starlight takes the star's own colour, tinted towards white (`lighting.star.tint` 0.6). Redhaven's red star gives pink-red light.
  - **Distance:** starlight strength scales from `near_factor` 2.0 at the star's edge to `far_factor` 0.8 at 8 radii.
  - **Glare:** from 2 radii in, the light turns overhead, the ambient rises to the light's colour and the direct light fades to 0.15. Inside the star the hull is lit evenly in its hue with no shadow side, and the change is gradual. A first try blended the ambient to white and blew hulls out to white; fixed before commit.
  - **Gate light:** an open gate's field is a violet light (`stellars.gate_light`) that lights nearby ships and its ring, and goes out when closed.
  - Checks: unit tests for `StarLight`; scenario checks for the colour, distance, glare and gate light; screenshots at four distances from Redhaven's star and beside Vela Gate.
- **Moved to milestone 3:** AI ships flying the hyperspace sequence, and scheduled traffic through the gate network.
- **Confirmed:** 1-day gate links equal to 1-day hyperlane routes are fine; the Solace and Redhaven stations stay.

### Review (godot-reviewer) and fixes

- **Fixed before handover:**
  - `data/README.md` still listed the removed `sprite` field. `art` is now documented for every stellar.
  - Unit tests added for the lighting and stellar settings, per-system lighting overrides, `SystemLighting.settings_for` and `GalaxyDef.gate_destinations`.
  - Gate rings now refresh when flags are reset or loaded.
  - Console `star height` no longer crashes outside a system.
- **Recorded in `docs/decisions.md`:**
  - engine lights sit outside the light cap;
  - 1-day gate links may equal a 1-day hyperlane route (to confirm with Jarrad).
- **Left for later:**
  - The light is aimed at the player, so distant stellars are lit from the player's direction rather than their own. Check at playtest.
  - An exported build must include the art manifests (`*.json` under `assets/`).
  - Dialog title size and margins aren't in the theme yet.
  - A few cosmetic numbers (placeholder gate ring, closed-link dimming, shader softness) are in code.
  - Planet manifest layers aren't checked by the loader.
  - `lighting.enabled` isn't re-read on a data reload.

### Key values

- **Lighting:**
  - ambient `#4b5161`;
  - star colour `#ffc890`, energy 1.2, height 0.3.
- **Point lights (energy / radius / height):**
  - shot: 2.5 / 150 / 20;
  - beam: 3.0 / 180 / 20;
  - impact: 4.0 / 220 / 24 over 0.3 s;
  - engine: 1.5 / 90 / 12;
  - cap: 24.
- **Clouds:** turn at 0.6 degrees/s.

### Known gaps and questions

- AI ships don't use gates yet.
- Stations show empty turret rings (station weapons are agreed for Phase 3).
- The gate placeholder field colour in `system_objects.gd` is only used when a gate has no art.
- How everything looks under a real GPU and at your screen size is for the playtest. All the lighting numbers are data.

---

## Phase 2 Milestone 1: Galaxy, hyperlanes and the day clock (30 Oct 2026)

Playtest confirmed by Jarrad on 30 Oct 2026; merged to `main`. Branch `p2m1-galaxy-hyperlanes`, built in a cloud session (Godot 4.7.2 headless; checked by unit tests, the scenario test, and screenshots rendered under a virtual display). Design agreed with Jarrad first: see `docs/decisions.md` "P2M1 scope" and the updated TR2, TR4, TR7, TR8 and TM2.

### Built

- **TR1 galaxy:** new `galaxy` data type (`data/galaxy/test_cluster.json`): systems with map positions and a starting map state, two-way hyperlanes, a start system. `game.json` `galaxy` replaces `system`.
- **Test cluster (10 systems):**
  - Lawful core loop: Test Nebula (start), Test Graveyard, Lumen, Aster.
  - Chokepoint: Aster → Drift (empty transit) → Brink.
  - Frontier: Brink, Solace, Ember (independent traders).
  - Pirate haven: Redhaven, reached via Ember, or via Hollow, an empty transit system that starts **hidden**.
  - Every system with a planet sells fuel; both transit systems are one jump from fuel.
- **TR2 jump sequence:**
  - J with a destination checks the jump radius and fuel, then locks the controls.
  - The ship flies the jump itself with its own turn rate and thrust (`JumpSequence`): stop, turn to the destination's map bearing, countdown, then overdrive past the speed cap until the hyperdrive speed.
  - J or firing cancels; so does being disabled. Hits don't cancel.
  - Ship data: `jump_countdown`. `game.json` `hyperspace`: stop speed, align tolerance, thrust angle, overdrive ×6 acceleration, engage at ×4 top speed.
- **TR4 arrival:** at the destination's `jump_radius`, on the side facing the origin, moving inward at 0.5 × top speed, with a flash. Every arrival is a fresh visit until persistence (P2M3).
- **TR7 galaxy map (M, pauses):**
  - Shows systems and lanes. Explored systems are drawn in their government's colour; unexplored ones are labelled "Unexplored"; hidden ones and their lanes aren't drawn or routable.
  - Shows your system and the plotted route with its jumps, days and fuel, plus a warning when the fuel won't cover the route.
  - Click a system to plot the fewest-days route. Each arrival selects the next leg.
  - Side panel: a stylised system view drawn from the system data (star, planets, stations, landable rings, the dashed jump radius), for explored systems only.
- **TR8 fuel:**
  - Ships have `fuel` and `jump_fuel`: flat per jump for now, with the rule in one function (`Hyperlanes.jump_fuel`).
  - Refuel on the landed screen buys as much as you can afford, at the port's `refuel_price`.
  - Starting credits are 1000, so the first refuels are possible.
- **TM1–TM3 day clock:**
  - The date comes from a day count from `calendar.start_date` (3200-01-01), shown "3 Jan 3200" on the HUD and the landed screen.
  - Days pass on jumps (lane length ÷ ship `jump_speed`, rounded up, at least 1), on landing (`landing_days` 1), on take-off (`takeoff_days` 0) and for days adrift after an escape-pod rescue.
  - `DayClock` steps one day at a time and `GameState.day_passed` fires for each day. Nothing listens yet (TM3).
- **HUD:** date, fuel, the destination ("Jump to Aster +1 more (J)") and the jump status ("Hyperspace in 2.7").
- **D11 debug:**
  - console: `goto <system>` (no fuel or days), `days <n>`, `route <system>`, `reveal <system>` and `fuel`;
  - panel: Go to system, Reveal, Refuel, +1/+7/+30 days.
- **Saves groundwork:** `TravelState` (current system, fuel, route, map changes) and `GameState.to_dict` / `from_dict` hold everything new as plain values.
- **Tests:**
  - unit: loader rules for galaxy, ship, system, stellar and settings fields; `Hyperlanes`, `JumpSequence`, `Calendar`, `DayClock`, `TravelState` round trip, `MapLayout` and `PortRules.refuel`;
  - scenario: map open and close, route plotting, every jump refusal and cancel, a full jump (phases, days, fuel, arrival point and speed, next leg), landing days, refuel, rescue days and D11;
  - smoke: visits all 10 systems.

### 2026-10-30 — Playtest notes (Jarrad)

- **Feels good:** the jump sequence, the jump radius and the countdown length.
- **Tuning: the high-speed run before the jump is too short and doesn't land** (wanted about 1 s more).
  - `game.json` `hyperspace.engage_speed_factor` 4 → 8 and `overdrive_accel_factor` 6 → 5.
  - The shuttle's run goes from 0.8 s to 1.9 s and it leaves at twice the speed (2080 px/s).
  - Other ships: courier 1.7 s, raider 1.7 s, corvette 1.85 s, freighter 2.6 s.
  - Jarrad then retuned it on his PC: `overdrive_accel_factor` 3, `engage_speed_factor` 12. The shuttle's run is now about 4.7 s and it leaves at 3120 px/s. These are the values merged.
- **Bug (H2): radar scenery popped in at about 2–3k px** (derelict hulls in Hollow).
  - Cause: radar-visible scenery came only from loaded chunks, which reach just past the screen edge, while the radar reaches 6000 px (since M6).
  - Fix: `LocalSpace.distant_radar_points` generates radar-visible placements for unloaded chunks inside radar range from the same seed, without building nodes. Destroyed objects and drift are respected.
  - Scenario check: distant hulls show, and they sit where the chunk later loads them.
- **Design change, confirmed and built (TR4):** arrivals appear `hyperspace.arrival_grace_seconds` (2) of inward travel outside the jump radius, so J works straight away for the next leg. The shuttle arrives 260 px out. Spec and decisions updated; scenario checks the distance and that J works on arrival.
- **Design change, confirmed and built (C7):** disabled ships, the player's included, coast to a stop at `combat.disabled_drag` (30 px/s²). A raider at full speed stops in about 11 s. `FlightModel.coast` has a unit test; the scenario checks a disabled ship slows and stops.

### Review (godot-reviewer) and fixes

- **Fixed before handover:**
  - **The countdown ran about 3× fast.** Ship body, weapons and engine glow each called `get_flight_input()`, and each call stepped the autopilot. Input is now computed once per physics tick and cached (`Ship.get_flight_input`). The scenario now checks the countdown lasts its data time.
  - Jumping, landing and boarding now refuse each other.
  - The map won't open mid-jump.
  - `hyperspace.overdrive_accel_factor` must be more than 0.
  - Fuel is clamped when the ship changes.
  - `goto` to the current system refills its traffic.
- **Left for later:**
  - The arrival flash's colour, size and length are hard-coded, as the AI's jump flash already is. They could move to data with the next effects pass.
  - The map remembers whether the game was paused when it opened, so a debug console `pause`/`resume` while it's open is undone on close (same as Dialog).
  - The saves milestone should check that loaded system IDs exist, and should only save while landed: a jump in progress isn't saved.

### Key values

- **Shuttle:** fuel 300, 100 per jump (3 jumps), countdown 3 s, jump speed 150.
- **Other ships:** courier 400 / 2 s / 200; freighter 500 / 5 s / 100.
- **Lanes:** 130–162 map units, so the shuttle takes 1–2 days per jump. Test Nebula to Redhaven is 5 jumps and 7 days.
- **Systems:** jump radius 10000 in most systems (6000 in the transit systems, 11000 in Graveyard).
- **Fuel price:** refuel price 2 (the pirate port 4), so a full shuttle tank is 600 cr.

### Stopped at / Next step

Stopped at: P2M1 merged to `main` (30 Oct 2026). Next step: Phase 2 milestone 2 (gates, TR5–TR6) on `p2m2-<slug>` when Jarrad says go; Jarrad also has art-asset work to slot into Phase 2 (see the conversation's answer: decide where before starting).

### Known gaps and questions

- No windowed run on a PC yet: screenshots under a virtual display showed the map, the countdown and the arrival, but feel needs Jarrad's playtest.
- Gates on the map (TR7 "gate links") come with P2M2.
- Reveal sources (map purchases, intel, found gates, missions) come in later milestones; until then `reveal` is debug-only.
- Hold-to-aim (F5) and the other carried-over items are unchanged.

---

### 2026-10-30 — session wrap-up (cloud session)
Branch: main (M6 `m6-art` and M7 `m7-hud-tuning` both merged after confirmed playtests; Jarrad's Phase 2 spec and hardpoint editor, PRs #2 and #3, merged in)
Done:
- M6 art integration: V1–V5 (SOW and pirate art, capsule hitboxes, hardpoints by size and mount, pivot and turret aiming, turret sprites, engine glow), C1/C2 rewrite, world ×2. Merged 2026-10-29.
- M7 HUD and tuning: H1, H3 schematic target panel with shield bubble, H4 message kinds, G5 standing (pale radar pips when disabled), review tidy-ups, raider beam on a pivot mount, `tools/balance.py`, balance pass (fights about 13 s raider vs shuttle), A8 retuned. Merged 2026-10-29.
Stopped at: nothing in progress. Every prototype milestone in docs/spec.md is ticked, and the Phase 2 spec (docs/phase2-spec.md) is in.
Next step: Phase 2 milestone 1 (galaxy, hyperlanes and the day clock) on a `p2m1-<slug>` branch when Jarrad says go. Run the `milestone` skill against docs/phase2-spec.md, and check its plan against the open questions below.
Open questions:
- Hold-to-aim (F5) can lead for only one shot speed; this will matter once mass drivers exist.
- The AI never finishes off disabled ships.
- Hot reload doesn't recolour the HUD.
- `tools/balance.py` ignores shield regen.
- Flak is unused until point-defence (C13) hulls arrive.
Check: GREEN

---

## Phase 2 planning (30 Oct 2026)

Designed with Jarrad in claude.ai and committed as `docs/phase2-spec.md`, with the decisions in `docs/decisions.md` (30 Oct entries). `tools/hardpoint-editor/` added (PR #2): a browser tool that writes `hull.json` hull manifests, ahead of OF7. CLAUDE.md and the skills now point at the Phase 2 spec; Phase 2 branches are `p2m<N>-<slug>`.

### Stopped at / Next step

Stopped at: Phase 2 spec merged. Next step: Phase 2 milestone 1 (galaxy, hyperlanes and the day clock) when Jarrad says go; the setting is being worked on separately and doesn't block it.

---

## Milestone 7: HUD and tuning pass (29 Oct 2026)

Playtest confirmed by Jarrad on 29 Oct 2026. Branch `m7-hud-tuning`. Designed with Jarrad first (spec and decisions 2026-10-29); built in the cloud session (checked headless, by the scenario test, a 10-minute soak, and rendering under a virtual display).

### 2026-10-29 — Playtest notes (Jarrad)

- **Time to kill too long; "at least halved",** because these are small, delicate hulls. Ship shield, regen and armour ÷2; grievance tolerance and forgiveness ×2 to keep A8 behaving the same (traders 12% and 0.6%/s, authority 10% and 0.5%/s, pirates 6% and 0.24%/s, defaults 10% and 0.5%/s). Report at 50% hits: raider disables shuttle 13 s, corvette beats raider 20 s vs 46 s, shuttle disables raider 52 s, raider disables freighter 45 s.
- **Target shield shown as a blue bubble** round the silhouette, not an outline.
- **Disabled ships are pale on the radar** (`radar.disabled_pale` 0.55).

### Built

- **H3 target panel.**
  - A nose-up silhouette of the target, in green → yellow → red by armour, with a shield outline that fades as its shield drops; grey when disabled.
  - Beside it: class, type (role), government, standing, shield and armour bars, distance, and a hint ("Disabled: B to board", read from the key binding).
  - Shader: `assets/shaders/silhouette.gdshader`; colour maths: `HudMath`.
- **H1 player panel:** ship name, credits, bars, and a DISABLED warning. Colours come from game.json `hud`.
- **H4 messages** come in four kinds (info, combat, standing, credits), each with its own colour. Timing is data (`messages`). New events:
  - destroyed;
  - "turns hostile" (A8);
  - a government "now / no longer treats you as hostile" (G3 threshold, posted from `GameState.set_record`);
  - credits taken.
- **G5 standing.** Hostile, angry (grievance), friendly (record ≥ the government's `friendly_record`, default 25; pirates 1100) or neutral. The radar and target panel both use it (`Relations.standing`).
- **Tidy-ups from the M6 review:**
  - the loader checks that ship and turret sprite paths exist;
  - `arc` or `traverse` on fixed and launcher mounts is an error;
  - the engine glow's idle level and response come from `engine_glow`.
- **Raider's mining beam** now sits on a pivot mount.
- **`tools/balance.py`:** an offline report of time to disable and destroy for each pair of ships, plus one-on-one duels. Assumes accuracy (default 50%), fight distance (default 400 px) and no shield regen under constant fire.
- **Balance pass (data only):**
  - ship shield, regen and armour ×3; weapon damage ×0.5; scenery armour ×0.5 (time to break rocks unchanged);
  - AI sensor ranges ×1.5 (2700 / 2400 / 1800);
  - courier strength 1;
  - A8 retuned to match (found at review: after the ×6 longer fights, forgiveness out-ran the damage, so nothing ever turned hostile). Tolerance and forgiveness: traders 6% and 0.3%/s, authority 5% and 0.25%/s, pirates 3% and 0.12%/s; defaults 5% and 0.25%/s.
- **Tests:**
  - unit: `Relations.standing` and `threshold_crossing`, `HudMath`, and the new loader rules;
  - a real-data A8 regression: sustained fire from the start ship turns every lawful pool ship hostile within 40 s, while five stray hits are forgiven;
  - scenario: the target panel, standing, the turns-hostile and threshold messages, and friendly at `friendly_record`.

### Balance report (50% hits, 400 px)

- **Raider vs shuttle:** the raider disables the shuttle in 26 s ✓ target 20–30 s. The shuttle needs 104 s to disable a raider.
- **Patrol corvette vs raider:** the corvette disables the raider in 42 s; the raider needs 92 s to disable the corvette ✓.
- **Other times:** the raider needs 90 s on a freighter; the shuttle needs 224 s on a freighter and 100 s on a courier.
- **Every fight is now 6× longer than in M6.** The targets are met, but the start shuttle is weak against everything, which is a risk to "10 minutes without feeling flat". Jarrad to judge in the playtest. The levers are data: weapon damage, health, or the start ship.

### Soak (10 simulated minutes, `test_nebula`, player parked out of the way)

- 0 errors.
- At most 13 ships at once.
- 18 AI attack spells (median 15 s, longest 91 s): pirates attacked shuttles, couriers, freighters and corvettes; patrols attacked pirates.
- Raiders disabled 2 shuttles; patrols disabled 2 raiders. Nothing was destroyed, because the AI doesn't finish off disabled ships (known since M4).

### Deviations and why

- **Grievance tuning changed** with the health scale (above); the A8 rule itself is unchanged.
- **The loader checks sprite paths only for ships and turrets.** Scenery and system-object sprites still fall back to placeholders silently.

### Known issues (for later)

- **Hold-to-aim (F5)** leads for the first projectile. A fixed beam is aimed by hand (accepted 2026-10-29). Mixed shot speeds (mass drivers later) will need a choice of which weapon to lead for.
- **Hot reload** recolours the radar but not the HUD or target panel; a restart does.
- **The balance report** ignores shield regen. With regen ×3, a pause in fire longer than the recharge delay undoes progress faster than the report suggests.
- **"Turns hostile"** can post twice if a ship forgets the player while still over tolerance.
- Everything still open from M6 (AI fire uses the widest arc, flak unused).

### Key tuning values

- **Shuttle:** shield 180, armour 120. **Raider:** 270 / 225. **Corvette:** 600 / 450. **Freighter:** 450 / 600. **Courier:** 300 / 180 (after the playtest halving).
- **Weapons:** small laser 5 / 3 per shot every 0.25 s; medium 8 / 5; large 12 / 8; mining beam 4 / 10 per s; homing missile 15 / 22; flak 3 / 4.
- **AI sensor range:** patrol 2700, pirates 2400, traders 1800.
- **Messages:** 4 s shown, 1 s fade, 3 lines.

### Stopped at / Next step

Stopped at: M7 merged to main (29 Oct 2026); every milestone in the spec is done. Next step: Jarrad decides what comes after the prototype (the open items above, or a new milestone via the design skill).

---

## Milestone 6: Art integration (29 Oct 2026)

Playtest confirmed by Jarrad on 29 Oct 2026. Branch `m6-art` (with `art/sow-kit` merged in). Designed with Jarrad first (spec and decisions 2026-10-29), built in the cloud session (checked headless, by the scenario test, and by rendering under a virtual display).

### Built

- **V1 sprites.**
  - SOW and pirate hulls are drawn at 1:1 × `art_scale` (game.json, 1.0).
  - Ships use the art: shuttle = S-A, courier = C-B Booster, freighter = F-A Stack, patrol corvette = P-B, pirate raider = R-1C.
  - The target dummy keeps its placeholder.
- **V2 capsule hitboxes.** `hit_size` [w, l] and `hit_offset` cover the hull body only; the freighter's hull sits 14 px left of its solar panel. Boarding range is measured hull edge to hull edge (`Capsule.gap`).
- **V3 hardpoints by size and mount.**
  - Hardpoints are copied verbatim from `hardpoints.json` (raider asymmetry kept).
  - Weapons have a `size` and the `mounts` they come in.
  - A ship's `loadout` names the hardpoint, the weapon and the item's mount. The loader refuses misfits (`MountFit`).
  - Arcs and traverse come from game.json `mounts` defaults (pivot 30°, turret 360°; 180 and 360°/s); a hardpoint can override them.
  - Pivots hold at the arc edge and keep firing. Turrets fire once the barrel is within `fire_tolerance` (5°).
- **V4 turret sprites.** A rotating child on each turret ring (tur1 small, tur2 medium, pd1 for `point_defence` hardpoints); shots leave along the barrel.
- **V5 engine glow.** At the art's engine exits; bright while thrusting, faint at idle. Colour and size come from data (pirates orange).
- **Data follows the art.**
  - The courier is unarmed and the player starts in the shuttle.
  - Patrol: 2 small turret lasers + homing missile in a small launcher.
  - Freighter: small turret laser.
  - Raider: 2 small fixed lasers + small fixed mining beam.
  - `light_laser` became `laser_small`, plus `laser_medium` (×1.6 damage) and `laser_large` (×2.5).
  - Weapon kinds are now `projectile`, `beam` and `guided`.
- **World scale (data only).** Planet radii ×4; object positions, scenery regions and the system edge ×2; camera zoom 0.75; radar range 6000.
- **D9.** The hitbox overlay draws capsules, hardpoints with barrel and arc lines, and engine exits.
- **C13** point defence is specified only: the hardpoint `role` is accepted and picks the PD sprite.
- **Tests.**
  - Unit (`test_mounts.gd`): `MountFit`, `MountAim` (arc clamp, traverse, short way round, limited arcs never swing through the back) and `Capsule.gap`.
  - Loader: every new validation rule, plus a check that the real ships follow the art.
  - Scenario: shuttle start, capsule, glow, a turret swinging onto and hitting a target abeam, a pivot held at ±15° and still firing, and a pivot tracking 10° off the nose.

### Deviations and why

- **Traverse is on the mount, not the weapon.** It follows the "arcs belong to the mount" decision, so a weapon's numbers are identical on every mount.
- **The world also doubled in size, and the radar range doubled with it.** Planets ×4 alone would have crowded the system.
- **`docs/` has a `.gdignore`,** so Godot doesn't import the art spec sheets.

### Known issues (from review and playtest; for M7)

- **Playtest: hold-to-aim (F5) and the raider's beam.** While the player is moving, T leads the target for the lasers, whose shots inherit the ship's velocity, so they drift onto it. The beam is instant and inherits nothing, so it lands beside the target by that lead offset. Stopped, both hit. One heading can't serve both while drifting. The AI's attack aim has the same split. Options for M7: aim for the beam when one is fitted, aim for the weapon group being fired, or put beams on pivot mounts so they track the target themselves.

- AI `sensor_range` is unchanged in a world twice the size, so raids may find traders less often. The unarmed courier keeps `strength` 10, which skews AI odds.
- AI fire uses the widest mount arc. A future hull mixing fixed guns with a 360° turret would fire its fixed guns off-axis (no current ship does).
- Engine-glow shape numbers (idle level, fade, halo sizes) are code constants. A missing or mistyped turret sprite path draws nothing, without an error.
- `arc` or `traverse` on a fixed or launcher hardpoint is accepted and ignored.
- Flak is defined but no ship carries it until point-defence hulls arrive.

### Key tuning values

- **Hulls (art px):** shuttle 48×119 (hit 46×119), courier 74×94 (64×94), freighter 76×184 (46×184, offset −14), patrol 48×159 (46×159), raider 62×128 (50×128).
- **Mounts:** pivot arc 30°, traverse 180°/s; turret arc 360°, traverse 360°/s; fire tolerance 5°.
- **World:** `test_nebula` edge 14000, Haven r 640, Tethys r 1200; `test_graveyard` edge 12000. Zoom 0.75, radar 6000.

---

## Milestone 5: Board and land (28–29 Oct 2026)

Playtest confirmed by Jarrad on 29 Oct 2026; detail tweaks to follow later.

Branch `m5-board-and-land`. Designed with Jarrad first (spec and decisions 2026-10-28), built in the cloud session (no godot MCP there: checked headless, by soak and scenario tests, and by rendering under a virtual display).

### Built

- **S2 / G4 landing (L).** Within `landing.radius_fraction` of a planet's centre and below `landing.max_speed` (shared with AI landing). Refused if the player's record with its government is below its `min_record`. Otherwise L only shows a hint ("Too far", "Slow down", "refuses you landing").
- **S3 landed screen.** Planet name, description and government. Repair (`landing.repair_cost_per_point`, free by default) and Take off. It sits on a reusable modal `Dialog` that pauses the world; number keys pick options.
- **C9 boarding (B).** Stop alongside a disabled ship (hull gap ≤ `boarding.range`, relative speed ≤ `boarding.max_speed`). A `boarding.time` progress bar runs, and aborts if you drift off, the wreck goes, or you take damage. Then the paused boarding window:
  - **Take credits:** hull `board_credits` × pool `wealth_factor` × roll, rolled once per ship; G2 board penalty.
  - **Assist:** back to `assist_armor_pct`, forgives you, leaves the system, +`assist_reward` record. Once per ship.
  - **Scuttle:** kill penalty.
  - **Leave:** reboard later.
  - Looted ships offer only Scuttle or Leave. Wrecks stay until you leave the system.
- **C10 escape pod.** On destruction the pod flies for `pod_time` at `pod_speed`, then a paused rescue report: days passed, the rescuer (the port's government), the rescue fee (`rescue_fee_pct` of credits) and insurance (insured: same hull; uninsured: `uninsured_ship`).
  - You wake up landed at the nearest port that accepts you, else any port.
  - Rescue counts as leaving and returning: every other ship, shots and fragments go, destroyed scenery returns, traffic refills. Record and grudges stay.
  - No pod: "Lost with all hands" and Restart.
- **F5:** hold T to face the target's lead point.
- **H2:** a radar rim arrow points at a target beyond radar range.
- **H4 (minimal):** a message line for hints, refusals, boarding, the escape pod and "X disabled".
- **D10 console (F1).**
  - Commands: spawn, pool, swap, system, reload, time, pause, resume, step, invuln, ai, traffic, radar, kill, disable, clear, credits, record, overlay, ids, pos, help.
  - They run through `DebugCommands.run_command`, the same layer as the panel. Up recalls; Esc/F1 closes; flight keys are ignored while it's open.
- **Tests.** Unit: `PortRules` (landing, boarding, credits, options, fee, rescue port, repair cost), `ConsoleParser`, `after_assist`, and loader validation for the new fields. The scenario test covers:
  - landing hints, refusal, repair and take off;
  - boarding (too far, abort under fire, take, reboard lock-out, assist once, scuttle, freed wreck);
  - rescue and wake-up landed, and game over without a pod;
  - F5, the H2 arrow and console commands.

### Deviations and why

- **Escape pod and insurance replace "respawn at the station"** (Jarrad). They are `game.json` flags that start owned until outfits exist.
- **Assist is once per ship** (found at review, to stop record farming). Jarrad can overturn it.
- **H4 and the H2 arrow came forward from M6** as minimal versions.
- **The HUD keeps updating behind paused windows.**

### Known issues

- If a system has no landable port at all, the rescued player is placed at the system centre with no landed screen.
- Dialogs each save and restore the pause state. Only one is open at a time, but a debug pause/resume while landed can unpause the world under the landed screen (debug only).
- Message-line timing (4 s, fade 1 s, 3 lines) is a UI constant, not data. Polish in M6.
- AI ships don't board or rescue anyone; NPC reactions to the escape pod come later.

### Key tuning values

- **Landing:** max speed 60, radius 0.6, repairs free.
- **Boarding:** range 60 px, max relative speed 40, time 2 s, assist to 50% armour.
- **Board credits:** shuttle 100–400, courier 300–1200, freighter 2000–6000, corvette 500–1500, raider 400–2000.
- **Wealth:** traders 1.0, pirates 0.6, patrol 0.1.
- **Assist reward:** law 10, traders 15, pirates 5.
- **Rescue:** fee 10%, 2–5 days, pod 600 px/s for 3 s, uninsured hull: shuttle.

---

## Milestone 4: AI and governments (26–28 Oct 2026)

### 2026-10-27 — Playtest bug: crash firing missiles after the target died (Jarrad)

**Error:** `Invalid type in function 'fire' … argument 8 (previously freed)` at `weapon_mounts.gd`. It happened when firing missiles after the targeted pirate was destroyed or jumped out.

**Cause:** in Godot 4 a freed object compares equal to `null`. `Ship.get_target()` guarded with `_target != null`, so it handed the freed ship to `Projectile.fire`.

**Fix:** the target is tracked by instance ID (`is_instance_id_valid`). Other `!= null and is_instance_valid` guards are simplified to `is_instance_valid`.

**Regression test:** the scenario test frees a targeted ship, then fires missiles and guns. It reproduced the exact error on the old code and passes now. The earlier "target cleared" check had missed it, because `get_target() == null` is also true for a freed object.

### 2026-10-26 — Milestone 4 playtest notes (Jarrad)

Notes received and how they were sorted:
- **Tuning:** weapon range looked short. Effective range equals the visible tracer (range = shot lifetime). `light_laser` range 700 → 1000, `flak_turret` 450 → 1000, so shots cross the screen (half-diagonal ≈ 920 px). `mining_beam` left at 300 pending Jarrad.
- **Design, agreed:** G3 applies to every ship of a government, not only warships (spec and decisions updated). Pirates can become non-hostile through future missions that raise the player's pirate record.
- **Design, agreed and built** (spec and decisions updated):
  - **C8:** R nearest hostile, Tab nearest any, Shift+R cycles hostiles, Shift+Tab cycles all.
  - **A8 + G2 leniency:** a per-ship grievance replaces faction-wide provocation. Only the ship pushed past its tolerance turns hostile, and the attack penalty is charged then. Allies ignore it; the rest of the government reacts only through the record.
    - Governments: `tolerance_pct` (law 20, traders 25, pirates 10) and `forgiveness_pct_per_s` (4 / 5 / 2).
    - Personalities: `tolerance_factor` (aggressive 0.5, cautious 1.5).
    - Radar shows annoyed ships in amber.
  - **C6:** `shield_recharge_delay` (3 s default). Any hit resets it.
  - **C12:** weapon damage falloff with distance; shots and beams fade to show it. `mining_beam` range 300 → 1000, falloff from 30% of range down to 10%.
- **Tuning to watch:**
  - Traders' high flee threshold (60%) means a damaged trader often runs rather than fighting back, even when brave.
  - The beam's fade mostly happens off-screen at zoom 1 (screen top ≈ 450 px ≈ 80% damage). Lower `falloff_start_pct` if you want it visible.


Branch `m4-ai-governments`. Built in the cloud session (no godot MCP there; runs checked headless and under a virtual display).

### Built

- **G1–G3, A8 relations.** `Relations` (pure, tested) decides hostility. Governments are hostile if either lists the other as an enemy. A government's ships treat the player as hostile below its `crime_threshold`; pirates' 1000 threshold makes them hostile from the start. **A8** (as built first; replaced after playtest by per-ship grievance leniency, see the 2026-10-26 playtest notes): a ship the player damaged, and its government's warships, stayed hostile until the player left the system.
- **G2 legal record.** A `GameState` autoload holds credits and the record per government (starting values in `game.json` → `player`). Penalties apply once per ship per act (first hit, disable, kill); boarding comes in M5.
- **A1–A4, A7 AI.** One `AIController` produces the same `FlightInput` as the player, so AI obeys the same flight model and weapons.
  - **Traders:** fly planet to planet, dock (hidden, untargetable) for `dwell_time`, relaunch, and leave via the edge after `stops` planets.
  - **Warships:** patrol near system objects.
  - **Pirates:** roam.
  - **Group vs individual (A7):** the government plus AI pool set friends and foes, role, base odds and flee threshold. A personality (new `personality` type: steady, brave, aggressive, cautious, skittish, weighted per pool) shades the odds factor, the flee offset, fight-or-flee when attacked, and whether it starts fights.
  - **A5:** before starting a fight, compares friendly against hostile strength within `sensor_range`.
  - **A4:** below the flee threshold, traders run to the nearest planet and land for good; others jump out at the edge.
  - **Steering** (`Steering`, pure, tested against the real flight model): arrive with turn-around braking, lead aiming, fire only when aligned (turrets fire whenever in range).
- **A6 traffic.** `TrafficSpawner` keeps each system traffic entry at its count. The system starts populated, outside the player's sensor range. Replacements jump in at `edge_radius` or take off from a landable planet after `respawn_delay`.
- **C11 friendly fire.** AI shots on their own or allied governments' ships do `combat.friendly_fire_pct` % (100 now; 0 turns it off). Player shots always do full damage.
- **C8:** R targets the nearest hostile ship (playtest later added Tab = nearest any, Shift+R / Shift+Tab = cycle).
- **H1:** the HUD shows credits.
- **H2:** radar ships are red (hostile), green (friendly) or grey (no government).
- **Debug.**
  - D3: spawn an AI pool with a count and government override.
  - D4: AI paused; radar shows all ships.
  - D6: set credits and the record per government (the panel marks governments hostile below threshold).
  - Traffic on/off.
  - The panel now scrolls.
- **Tests.** Unit tests for Relations (incl. friendly fire), Behaviour, WeightedPick and Steering. The scenario test covers:
  - a pirate raid on a trader drawing in the patrol
  - a steady trader fleeing and a brave trader fighting back
  - G2 once per ship, the G3 threshold, A8 provocation
  - C11 scaling, AI pause, D3/D6, and the A6 refill

### Deviations and why

- **Two-level AI behaviour (A7)**, provoked (A8), friendly-fire % (C11), once-per-ship penalties and docking traders were agreed in design before building. See `docs/decisions.md` (2026-10-26).
- **Disabled AI ships stay in space** (boarding is M5) but stop counting towards traffic, so replacements still arrive.
- **The odds check runs only before starting a fight.** Ships that fight back when attacked do so whatever the odds; retreat is left to the A4 shield threshold.
- **Single-ship debug spawns stay idle;** pool spawns get AI.
- **Initial traffic spawns outside the player's sensor range** (× 1.2) so nothing opens fire the moment the system loads.

### Known issues

- **Radar colour for low-record traders:** hostility to the player is a government's record rule, so traders turn red on radar below their own threshold even though they never attack (they only flee).
- **AI dogfighting is simple:** face the lead point, thrust until within `standoff_fraction` of weapon range, so fights look like jousting passes.
- **AI doesn't finish off disabled ships** and doesn't board (M5).
- **AI friendly fire changes no records;** only the player's record is tracked.
- **G3 (settled 2026-10-26):** every ship of a government is hostile below its threshold; role and personality decide who fights.

### Final audit before merge (2026-10-28)

**Soak test.** 10 simulated minutes across both systems at 4× speed, with the player fighting throughout, a hot reload, a traffic toggle and a system switch. Result: 0 errors, 0 stuck AI ships, at most 15 ships at once.
- It found that a hot reload healed and revived every ship, so disabled traffic counted again and the population went over target (10/7). **Fixed:** reload keeps current damage and the disabled state (`Health.retune`); ship swap still restores full health. Regression test added.

**Reviewer pass.** Fixed:
- replacements ignored `respawn_delay` at first and after reload or toggle;
- `ai.jump_out_factor` below 1 trapped leaving ships (now validated ≥ 1);
- a pool listed twice in one system's traffic (now rejected);
- debug pool spawns survived a system switch;
- D3 "at the cursor" was missing (now a panel option: tick it, press Spawn, click in space);
- spec G2 didn't cover hitting an already-hostile ship (it now counts as past tolerance, so the first hit charges).

**Known issues, deferred:**
- An AI ship hit by a non-allied AI ship holds the grudge permanently, with no leniency. Today only ships with no government can be hit this way, but a future neutral government would feud forever from one stray shot.
- Beams assume the shooter is a Ship, which will matter when station turrets reuse WeaponMounts.
- Disabled AI ships accumulate until boarding (M5) or destruction.

### Review (godot-reviewer, before handover)

Verdict was "fix first"; all fixed in `m4: review fixes`:
- docked traders reappeared after a hot reload;
- disabled traffic ships were never freed on a system switch;
- attacks didn't end when the target stopped being hostile;
- a freed-ship filter used a typed lambda;
- friendly fire was lost when the shooter died;
- zero-weight pools were accepted;
- several hard-coded spawn and patrol numbers (now `game.json` → `ai.*`);
- personality and game.json sections had no loader tests.

### Key tuning values

| | Sensor range | Stay | Personality weights |
| --- | --- | --- | --- |
| trader_traffic | 1200 | — (dwell 6–12 s, 1–3 stops) | skittish 3, cautious 3, steady 2, brave 1, aggressive 1 |
| authority_patrol | 1800 | 90–180 s | steady 3, brave 2, aggressive 1, cautious 1 |
| pirate_raid | 1600 | 60–120 s | aggressive 3, brave 2, steady 2, cautious 1 |

Personalities (odds × / flee offset / when attacked / starts fights): steady 1/0/role/role · brave 1.5/−15/fight/role · aggressive 1.25/−10/fight/on sight · cautious 0.6/+20/role/role · skittish 0.3/+40/flee/never.

Governments (max_odds / flee %): local_authority 1.5/15 · independent_traders 0.5/60 · pirates 2.0/30. Edge radius: test_nebula 7000, test_graveyard 6000. AI: landing speed 60, thrust angle 35°, standoff 0.4 × range, think every 0.25 s. Friendly fire 100%.

---

## Milestone 3: Fight (16 Oct 2026)

### Built

- **C1–C4 weapons.** `WeaponMounts` gives each equipped weapon an exit point of its kind (`hardpoints`), sharing points round-robin when weapons outnumber them.
  - Guns fire along the heading.
  - Turrets lead the selected target (`Aim.intercept_direction`) within their `arc`.
  - Guided missiles home on the target selected at launch at their own `turn_rate` for their lifetime.
  - Beams ray-test their length every physics frame while held.
  - Primary fire (Space) drives guns, turrets and beams; secondary fire (F / Left Ctrl) launches missiles.
- **C5–C7 damage.** `DamageModel` (pure) puts shield damage first, and a shield-breaking hit carries its unspent fraction through to armour. `Health` regenerates shields, disables at `disable_armor_pct` (33%) and destroys at 0. A disabled ship drifts with no input and can't fire.
- **C8 targeting.** R targets the nearest ship and Tab cycles nearest-first (`Targeting`, pure). Yellow brackets mark the target. A minimal HUD (top right) shows player shield and armour (H1) and the target's name, distance, shield and armour.
- **Dummy target.** A `target_dummy` ship (300 shield, 400 armour, no engines) spawns at (0, −450) in debug builds via `game.json` → `debug.spawn_at_start`.
- **L4 scenery damage.**
  - Shots and beams damage solid scenery through `Health`.
  - Destroyed scenery throws off its `fragments` as cosmetic `RigidBody2D` pieces that fade out.
  - `DestroyedScenery` keys destroyed objects by (chunk, scenery ID, placement index). The generator skips those keys, and the set clears on system change but survives hot reload.
  - Drifting solid scenery is generated at start + velocity × elapsed game time; non-solid scenery skips this.
- **System objects (S1, placeholder).** The star, planets and stations are drawn from the system file as flat circles with names.
- **H2 radar.** Bottom-right, centred on the player.
  - Ships are coloured by government, or neutral grey with none.
  - System objects beyond range sit as hollow pips on the rim.
  - The selected target is ringed.
  - Scenery shows only for `radar: true` types, read from a list `LocalSpace` keeps rather than by scanning scenery nodes.
  - Size, range, margin and colours come from `game.json` → `radar`.
- **Debug.**
  - D3: spawn any ship ID with a count and optional government, ahead of the player.
  - D4: player invulnerability.
  - D5: disable or destroy the target, and clear all non-player ships.
  - D9: the panel always shows the player's world position and chunk coordinates.
- **Tests.** Unit tests for DamageModel, Aim, Targeting, the destroyed set and the drift offset. The smoke test fires all four weapon kinds at the dummy, destroys scenery and revisits it, and checks the radar list and every new debug command.

### Deviations and why

- **C8 targets the nearest ship, not the nearest hostile.** Hostility needs governments and the legal record (M4).
- **Shots ray-test their path each frame** against the `Area2D` hitboxes (`HitQuery`) instead of using overlap signals. Fast shots (900 px/s, 15 px per frame) would otherwise tunnel through small debris.
- **Turrets hold fire** when the lead point is outside their arc, and fire straight ahead with no target (Nova behaviour).
- **Beams deal damage per second** and ignore `reload`.
- **Shields don't recharge while disabled.**
- **Player destruction:** the ship vanishes and stays gone until respawn (C10, M5). Swapping ship in the debug panel restores it.
- **Minimal HUD pulled forward** from M6: C8 needs the target's shield and armour on screen.
- **Ship swap and hot reload restore full shield and armour.**
- **Added data fields, each with a documented default:**
  - Ships: `disable_armor_pct` (33).
  - Weapons: `inherit_velocity` (true).
  - Scenery: `fragment_speed` ([20, 80]), `fragment_lifetime` (6).
  - `game.json`: `debug.spawn_distance`, `debug.spawn_at_start`, `radar.*`.
- **`target_dummy` is a sixth ship file.** It's test content, not one of the five prototype ships.
- **Placeholder ships are tinted by government** (player pale blue, neutral grey) so they can be told apart. The shape is still one arrow for every hull.

### Known issues

- **Drift offset pop-in.** A drifting object belongs to the chunk it was generated in. After a long stay in a system (drift speed × time > about one chunk, e.g. 70 s for 15 px/s debris), objects can appear or vanish at the edge of the loaded area as their home chunk loads or unloads. Possible fixes if it shows: load drifting types from a wider ring of chunks, or wrap drift within the home chunk.
- **Hull hitboxes are circles** of the generated size. Long derelict hulls are only hittable near their middle.
- **No friendly-fire rules yet:** shots hit any ship except the one that fired them (M4).
- **Spawned ships idle** (IdleController) until the AI controllers in M4.
- **Fragments have no hitboxes,** by design (cosmetic).

### Key tuning values

| Weapon | Kind | Shield / armour dmg | Speed | Range / life | Reload | Other |
| --- | --- | --- | --- | --- | --- | --- |
| light_laser | gun | 10 / 6 | 900 | 700 px | 0.25 s | |
| flak_turret | turret | 6 / 8 | 600 | 450 px | 0.6 s | arc 270° |
| homing_missile | guided | 30 / 45 | 400 | 4 s | 2.5 s | turn 140°/s |
| mining_beam | beam | 8 / 20 per s | — | 300 px | — | |

Ships (shield / armour): shuttle 120/80, courier 200/120, freighter 300/400, patrol_corvette 400/300, pirate_raider 180/150, target_dummy 300/400 (regen 10/s). Disable at 33%. Radar: 200 px across, 3000 px range.

---

## Milestone 2: Data loader and local space (14 Oct 2026)

### Built

- **Data loader.** `DataRegistry` loads all six types (ships, weapons, governments, AI pools, systems, scenery) from `data/` then `mods/`.
  - A later file with the same ID replaces the earlier one, and IDs must match file names.
  - Each type has a typed `Def` class with documented defaults (`data/README.md`).
  - Every cross-reference is resolved. Invalid data refuses to start with an on-screen list naming each file and field, and exits 1 headless.
  - Unit tests cover validation and the override rule.
- **D8 hot reload** re-reads everything and emits `data_reloaded`; ships, backdrop and scenery rebuild. A failed reload keeps the old data and shows the errors.
- **D2 ship swap** keeps position, heading and velocity. A debug command switches systems.
- **Content.** 5 ships, 4 weapons, 3 governments, 3 AI pools, 5 scenery types, and two systems:
  - `test_nebula`: heavy nebula, sparse dust and rocks.
  - `test_graveyard`: sparse nebula, a derelict-hull ring and an asteroid cluster.
- **B1–B2 backdrop.** A shader draws hashed stars and a FastNoiseLite nebula coloured by a gradient, on a screen layer moving at the system's parallax (0.02). Every setting comes from the system file.
- **L1–L3 local space.**
  - Scenery streams in 1024 px chunks around the camera, and distant chunks unload.
  - Each chunk is seeded from (system seed, chunk, scenery ID), so revisits match.
  - Density and whole/ring/circle regions come from the system file.
  - One generic Scenery scene, configured from data. Solid scenery gets a hitbox and Health; dust gets neither and may sit at a parallax depth.

### Deviations and why

- **Unknown fields are errors.** Typos (e.g. `top_sped`) would otherwise silently take defaults.
- **`game.json` (global settings) isn't one of the six types.** It merges field by field from `mods/`, while definitions replace whole files.
- **Extra fields**, each with a documented default:
  - Ships: `hit_radius`.
  - Scenery `placeholder.*`: generic placeholder art.
  - Backdrop: `base_colour`, `stars.spacing`, `nebula.softness`, `noise.texture_size`, `noise.scale`.
- **Density unit:** objects per 1,000,000 px².
- **The gas giant is a non-landable `planet`;** there's no separate object type.
- **The player starts in the courier,** because the M2 done-check names `courier.json`. Set `game.json` → `player_ship` to `shuttle` to match the content table.
- **The smoke test is a scene,** because scripts run via `--script` can't see autoloads.

### Known issues

- An exported build needs `*.json` in the export include filter.
- `--quit` exits 0 even after script errors, so read the output.

### Key tuning values

- **Backdrop:**
  - `test_nebula`: coverage 0.75, intensity 0.85, frequency 0.004, 6 octaves.
  - `test_graveyard`: coverage 0.2, intensity 0.4.
  - Parallax 0.02 in both.
- **Dust:** size 2–3.5 px, depth 0.9–1.1. Density 30 in `test_nebula`, 35 in `test_graveyard`.
- **Graveyard ring:** radius 1200–3200 around (0, 0).
- **Chunk size:** 1024 px.

---

## Milestone 1: Fly (13 Oct 2026)

### Built

- **F1–F3:** kinematic `FlightModel` (pure, unit-tested) with fixed-rate turning, thrust along the heading, a hard speed cap and no drag. Reverse (Down/S) turns to face against the velocity.
- **F4:** a follow camera and, at the time, a parallax starfield (replaced by the backdrop and local space in M2).
- **D1:** debug panel on backtick, debug builds only.
- **D7:** time scale 0.25×–4×, pause, single-frame step.
- **D9:** overlays for hitboxes, velocity vectors, state labels, and FPS / counts.
- All debug actions go through the `DebugCommands` autoload.

### Deviations and why

- **Reverse only turns;** braking is reverse plus thrust, as the spec words it.
- **2D physics interpolation is enabled,** for smooth motion on high-refresh displays.
- **A minimal data reader existed in M1** so flight values came from `courier.json` before the M2 loader.

### Key tuning values

- **Courier:** accel 300 px/s², top speed 320 px/s, turn 180°/s.
- **Camera:** zoom 1, no smoothing.
- No playtest tuning changes recorded yet.
