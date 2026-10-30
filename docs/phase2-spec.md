# Terminal Velocity Phase 2 — The Loop

Source of truth for Phase 2 design, agreed with Jarrad on 30 Oct 2026 (drafted in a claude.ai doc, moved here so nothing lives only in chat). Edit this file when Phase 2 design changes; requirement IDs are stable, never renumber. Phase 1 (the prototype) is `docs/spec.md`.

Phase 2 turns the one-system combat prototype into a game you can play for an hour: jump, land, trade or take a job, upgrade, jump again, in a galaxy that remembers what happened.

## Purpose and success criteria

Phase 2 is done when a new pilot can play for an hour across the test cluster and every playstyle (trader, fighter, mercenary) has a way forward.

1. Starting in the shuttle, the player can earn money by trading alone, carrying only defensive weapons and relying on escape, across at least four systems.
2. The player can travel by hyperlane and by gate, and each has a clear trade-off: hyperlanes are adjacent-only with an edge jump and countdown; gates are fast and long-range but controlled by a government.
3. Days pass only through actions, and the date visibly drives mission deadlines, price events and fleet arrivals.
4. A named character and a government fleet move between systems on their own schedule; the player can learn where they are headed, follow them, or meet them at the destination.
5. Leaving a system and returning does not reset it: wrecks, alert levels and pirate presence recover over days, not instantly.
6. The player can buy and sell hulls and fit weapons and outfits by hardpoint, and the upgrade path is visible from the shuttle onward.
7. Generic missions (cargo, passenger, bounty, escort) and one short story arc run entirely from data.
8. The game saves and loads mid-play; an ironman pilot has a single locked save.

Setting, faction names and story text are placeholders until the separate setting work lands; nothing in Phase 2 depends on them.

## Scope

Phase 2 builds the loop and the foundations under it; the war, exotic travel and ownership wait for Phase 3.

| Area | Phase 2 | Phase 3 or later |
| --- | --- | --- |
| Galaxy | Disposable test cluster of about 10 systems | First real region of the setting |
| Travel | Hyperlanes (edge jump, countdown), gates | Jump drive, currents, player-built gates |
| Time | Day calendar advanced by actions | Crons and scheduled galaxy events |
| Persistence | Three-level model: current system, persistent entities, system memory; one travelling character and one patrol fleet | War front: territory control, off-screen battles shaping the galaxy, gates closing in war |
| Saves | Save/load, ironman | Cloud or multiple-slot management |
| Economy | Commodities, cargo, fixed price tiers plus price events | Dynamic supply and demand (review) |
| Ships and outfits | Shipyard, outfitter, weapons by mount and size, trader escape kit | Station ownership, capture keeping the ship |
| Missions | Flags, conditions, declarative missions with a script hook, generic templates, one short arc | Faction mission paths, multi-branch storylines |
| Progression | Combat and trade ratings, faction standing, ranks, achievements | Achievements tied to ownership and the war |
| Art | Existing SOW and pirate art, placeholders for gates and new stellars | Art phase before Phase 3: expanded asset library and manifest pipeline |

## Requirements

IDs continue the prototype's scheme with new prefixes, so commits, tests and the devlog can cite them. Every number named here is a data value.

**Travel (TR)**

- TR1: The galaxy is a set of systems joined by hyperlanes; a hyperlane jump goes only to an adjacent system, so distant systems take several jumps.
- TR2: A hyperlane jump needs a destination adjacent to the current system (selected on the galaxy map), the ship beyond the system's jump radius, and enough fuel. Pressing jump (J) when all three hold locks out the player's flight controls, and the ship flies the jump sequence itself with normal ship movement (its own turn rate and acceleration, no magic braking): (1) turn and thrust against its velocity until it is stopped; (2) turn to face the destination's bearing (the direction of the destination from the current system on the galaxy map); (3) run the countdown, set by the ship and its outfits, which starts only once the ship is stopped and facing the bearing; (4) accelerate rapidly along the bearing, beyond its normal speed cap, until it reaches the hyperdrive speed, when the hyperdrive engages and the ship leaves. Firing or pressing jump again cancels at any point before the hyperdrive engages, and so does being disabled; the speed cap then applies again. Hits do not cancel. Pressing jump when a condition fails only shows why (no destination, inside the jump radius, not enough fuel).
- TR3: The countdown is the deliberate risk: the player cannot escape a fight instantly, and outfits that shorten it are the trader's main escape tool (OF6).
- TR4: The player arrives at the destination's jump radius on the bearing from the origin system (the side facing the origin, travelling inward along the bearing), at a reduced speed (a fraction of top speed, in data).
- TR5: Gates are system objects owned by a government, or faction, whoever controls the local system. Docking with a gate lists the other gates it connects to; travel between gates ignores adjacency and costs fewer days than the equivalent hyperlane route.
- TR6: A gate refuses the player whose record with its government is below the gate's minimum, and charges a fee set per gate. A gate can be closed by a flag, which Phase 3 uses in war.
- TR7: A galaxy map (M; pauses the game) shows systems, hyperlanes, gate links, the plotted route and its day and fuel cost. Clicking a system plots the shortest route to it; the player jumps along it one jump at a time, and each arrival selects the next leg. Each system has one of three map states: **explored** (visited: name, government and system view shown), **unexplored** (visible with its lanes but shown as "Unexplored" until visited) or **hidden** (not drawn and not routable, nor are its lanes, until something reveals it: a bought map, faction intel, a found gate, a mission; Phase 2 gives the galaxy data a per-system starting state and the reveal as a game-state change, with the reveal sources arriving in later milestones and a debug command now). Selecting a system shows a stylised system view beside the map: its star, planets and stations laid out from the system data, with names, government and which can be landed on (explored systems only).
- TR8: Fuel is spent only on jumps and afterburners (existing decision). A hyperlane jump costs a flat amount set by the ship (`jump_fuel`) for now; the cost is computed in one place from the ship, the lane and its distance, so a later rule (by distance, by lane, by outfit) is a data and one-function change. Ships refuel when landed, at a price per unit set by the stellar.

**Time (TM)**

- TM1: The game date is a day count shown as a calendar date. It never advances in real time.
- TM2: Actions cost days: landing, landed activities and taking off are separate costs (per stellar: landing 1, take-off 0 by default; activities 0 for now, each activity gaining its own cost when activities exist), a hyperlane jump (lane distance on the galaxy map ÷ the ship's jump speed, rounded up, at least 1), gate travel (per link), and some missions (a stated time cost on accept or completion).
- TM3: When days pass, the galaxy simulation steps one day at a time: persistent entities move, system memory recovers, price events start and end, mission deadlines check.

**Persistence (PS)**

- PS1: The current system is fully simulated, as in the prototype.
- PS2: Persistent entities are tracked across the galaxy at all times: named characters, government fleets, mission fleets, and ships the player has marked by their actions (a ship left disabled, a pirate holding a grudge). Each has a location (a system, or in transit with an arrival day), orders (hold, patrol a route, travel to, follow) and a summary state (ships, hull and shield fractions, cargo).
- PS3: Persistent entities travel by the same rules and day costs as the player, using hyperlanes and gates.
- PS4: When the player is in a system with a persistent entity, it materialises as real ships from its summary; an entity arriving while the player is present jumps in at the edge or arrives at a gate. When the player leaves, or the entity departs, its state is written back to the summary.
- PS5: When hostile persistent entities share a system off-screen on a day tick, a strength comparison with randomness resolves the encounter and writes the outcome back. The result becomes news.
- PS6: Each system has a memory: named values with a baseline and a recovery rate per day. The prototype set is alert level (raised by player crimes), pirate presence (lowered by pirate losses) and a wreck list (disabled ships left behind, each scavenged after a set number of days). Ambient traffic generation reads this memory.
- PS7: News on landing lists recent off-screen events and announced fleet movements ("departs X, due at Y in N days").

**Saves (SV)**

- SV1: A pilot file holds everything persistent: player ship and outfits, cargo, credits, records, ratings, flags, missions, the date, the galaxy simulation state and system memory. The current system is saved as its persistent parts only. Every ship, the player's included, is saved as a design reference plus instance state (name, damage, fitted items, cargo); premade ships are designs too, so player-made designs can be saved later without a format change.
- SV2: The player saves and loads from the main menu and when landed; the game autosaves on landing.
- SV3: Ironman is chosen when the pilot is created and cannot be changed. An ironman pilot has one save slot, autosaves on landing and on each jump, and cannot load an older state. Death follows the same escape-pod and insurance rules as normal play.
- SV4: The save format carries a version number; older saves are migrated or refused with a clear message.

**Economy (EC)**

- EC1: Commodities are data definitions with a base price and a mass per unit. Each stellar with a market sets a price tier per commodity: none, low, medium or high.
- EC2: Price events are data: a commodity, where it applies (stellars, systems or governments), a price change, a duration in days and a chance per day, optionally gated by flags. Active events show in the trade screen and the news.
- EC3: Ships have a cargo capacity; cargo pods add to it. The trade screen buys and sells by unit with live totals and remaining space.
- EC4: Commodities can be illegal to a government; scanning for contraband is Phase 3, but the legality field exists now.

**Shipyard and outfitter (OF)**

- OF1: Hulls are for sale at stellars by tech level and availability conditions. Buying trades in the current hull and its fitted items at a data-set fraction of their value.
- OF2: Outfits have a mass; each hull has free mass. Weapons fit only a hardpoint of matching size and mount type (prototype rule V3); the outfitter shows which hardpoints each weapon fits.
- OF3: Non-weapon outfits in Phase 2: shield and armour boosters, shield regen, cargo pods, fuel tanks, afterburner, sensor range, and hyperspace tuning (shorter countdown).
- OF4: Items sell back at a data-set fraction of their price; mission-granted items can be flagged unsellable.
- OF5: Every number an outfit changes uses one modifier system, so a new outfit type is data unless it needs new behaviour.
- OF6: The trader escape kit is the design target for a non-combat player: afterburner, hyperspace tuning, sensor range, and cargo jettison as a decoy that pirates break off to collect.
- OF7: Hull geometry (sprite, scale, hit shape, hardpoints, engines, part sprites) lives in one manifest per hull, `hull.json`. Ship data names its hull and holds only stats and a loadout by hardpoint ID; hardpoints the loadout leaves empty are upgrade slots. A check validates every manifest and every loadout against its hull; generated spec sheets are for review only. The manifest also carries, so player-built ships stay possible later: a size class and displacement; a hit shape made of one or more primitives (capsules at any angle, circles, boxes), replacing the single along-the-hull capsule that cannot fit wide hulls; sprite layers (several sprites at offsets and depths, as turrets already are); and, for generated hulls, the list of parts each was built from. Schema 1 is what `tools/hardpoint-editor` writes today; OF7 extends it.
- OF8: A shipyard sets the largest hull size class it builds or sells, as well as its tech level, so small yards offer only small hulls.
- OF9: A hull's base stats pass through the same modifier system as outfits (OF5), so a later phase can derive the base from a ship's parts without changing flight or combat code.

**Missions (MS)**

- MS1: Named flags hold booleans and integers. Conditions are expressions over flags, records, ratings, the date, owned items and hull, location and credits; set expressions change flags and grant or remove items, credits and records.
- MS2: Missions are declarative data: availability (where, conditions, chance), offer location (mission board, bar, spaceport), briefing text with substitutions, objectives (travel to, deliver cargo, carry passengers, destroy, disable, board, escort, observe a target), a deadline in days, rewards, failure rules and a time cost.
- MS3: A mission may name an optional script hook for behaviour data cannot express (existing decision); hooks get a small fixed API.
- MS4: Mission targets and escorts can be persistent entities, so a target can move between systems and an escort travels over days.
- MS5: Templates generate generic missions (cargo, passenger, bounty, escort) with destinations chosen within a jump range, pay scaled by distance, risk and deadline.
- MS6: Missions show in a mission log with objectives, destination on the map and days remaining.

**Progression (PR)**

- PR1: Combat rating grows from ships disabled and destroyed, weighted by their strength.
- PR2: Trade rating grows from trade profit and delivered cargo.
- PR3: Faction standing is the existing legal record; ranks are data granted by missions, with privileges (salary, price modifier, landing rights).
- PR4: Achievements are data conditions over game state (for example owning a hull over a size, or reaching a point in a faction's missions), shown in the pilot screen.

**Debug (D, continued)**

- D11: Jump directly to any system; advance the date by N days.
- D12: View and edit flags, ratings and records; list available missions and why others are not available.
- D13: Inspect the persistent-entity registry and system memory; spawn or move a persistent entity.

## Persistence model

The galaxy is simulated at three levels of detail, and the day clock is the only thing that moves the two background levels forward.

```
            ┌──────────────────────────────────────────────────────────────┐
            │ 1 · Current system: full simulation                          │
            │   real ships, shots, scenery and AI; only where the player is│
            └──────────────────────────────────────────────────────────────┘
   materialise ▲   │ write back            feeds ambient ▲   │ your crimes,
   when present│   ▼ on leave              traffic       │   ▼ kills, wrecks
 ┌──────────────────────────────────┐   ┌──────────────────────────────────┐
 │ 2 · Persistent entities          │   │ 3 · System memory, per system    │
 │   characters, government and     │   │   alert level, pirate presence,  │
 │   mission fleets, marked ships;  │   │   wrecks left behind; each value │
 │   location or transit, orders,   │   │   recovers toward its baseline   │
 │   summary state; travel by the   │   │   daily; leaving and returning   │
 │   player's rules and day costs   │   │   does not reset a system        │
 └──────────────────────────────────┘   └──────────────────────────────────┘
          ▲ move, meet, resolve                    ▲ recover toward baseline
          └───────────────┬───────────────────────┘
               Day clock (advances only through actions:
               jumps, landings and missions cost days)
```

Persistent entities are the new piece: they turn into real ships when the player shares their system and back into a summary when the player leaves, so a fleet can be followed, met at its destination or fought, and the outcome sticks. Jumping out and back costs two jumps' worth of days, so the player sees a system only partly recovered, which closes the reset exploit.

## Data requirements

Nine new definition types and additions to three existing ones; the loader rules (validation, references, mod override, hot reload) apply unchanged.

| Type | New or changed | Defines | Key fields |
| --- | --- | --- | --- |
| `galaxy` | New | The cluster | systems with map positions, hyperlanes, gate links, start system |
| `system` | Changed | A star system | jump radius, memory baselines and recovery rates, traffic reading memory |
| `stellar` fields | Changed | Planets, stations, gates | market tiers, shipyard and outfitter tech, largest hull size class, refuel price, landing day cost; gate fields: government, min record, fee, open condition |
| `commodity` | New | A trade good | name, base price, mass per unit, illegal to (governments) |
| `price_event` | New | A temporary price change | commodity, where, change, duration, chance per day, condition |
| `outfit` | New | A non-weapon item | mass, price, tech, modifiers, sellable, availability |
| `ship` | Changed | A ship design | hull, price, tech, free mass, cargo, fuel, jump countdown, jump speed, availability, loadout |
| `persistent_entity` | New | A character or fleet | name, government, ships, orders, start location, conditions to exist |
| `mission` | New | A mission or template | availability, offer location, text, objectives, deadline, rewards, failure, time cost, script hook |
| `rank`, `achievement` | New | Progression | conditions, privileges, display text |
| `hull.json` | New | A hull's geometry and identity, made by the art pipeline or the hardpoint editor | schema, id, name, size class, displacement, sprite layers, scale, size_px, hit shapes, hardpoints (id, size, mount, pos, facing, arc override, role, part, cells), engines, built-from parts |

Conditions and set expressions use one shared grammar across missions, gates, ranks, achievements, price events and availability, so a rule written once works everywhere.

## Test cluster content

About ten systems with placeholder names, laid out so every Phase 2 rule has a place to be tested; it is discarded when the setting's first region exists.

| Content | Phase 2 test set |
| --- | --- |
| Systems | About 10: a lawful core of 4 (one gate each), a frontier of 3, a pirate haven, 2 empty transit systems |
| Governments | The prototype three, with the authority owning the gates and the core |
| Hyperlanes | A loop through the core, a single chokepoint to the frontier, two routes to the haven |
| Gates | 4, linking the core systems; one closable by a debug flag |
| Commodities | 6 legal plus 1 illegal to the authority |
| Price events | 4 (a shortage, a glut, a strike, a festival) |
| Hulls for sale | The prototype hulls plus one medium trader and one medium warship |
| Outfits | About 10, covering every OF3 type |
| Persistent entities | One named trader captain on a fixed trade route; one authority patrol fleet on a patrol loop; one pirate captain who holds grudges |
| Missions | One template each for cargo, passenger, bounty and escort; one 5–8 mission arc |
| Ranks and achievements | 2 ranks with the authority; 4–5 achievements |

## Milestones

Eight milestones, each ending in a playtest; persistence comes before saves so the save format is designed around it, and every state added from milestone 1 must be serialisable. Branches follow `p2m<N>-<slug>`.

1. **Galaxy, hyperlanes and the day clock:** galaxy data, the test cluster's systems, hyperlane jumps with edge rule and countdown, arrival, fuel and refuelling, galaxy map with route plotting, day costs. Done when TR1–TR4, TR7–TR8 and TM1–TM3 work (TM3 with nothing yet to step).
2. **Gates:** gate stellars, destination list, fee and record check, closable by flag. Done when TR5–TR6 work and the map shows gate links.
3. **Persistence foundation:** entity registry, travel by the player's rules, materialise and write-back, off-screen encounters, system memory with recovery, news. Done when PS1–PS7 work with the test cluster's three persistent entities.
4. **Pilot and saves:** pilot creation (name, ironman), save/load, autosave, versioned format. Done when SV1–SV4 work and a save made mid-route restores entities in transit.
5. **Economy:** commodities, market tiers, price events, cargo hold, trade screen, cargo jettison. Done when EC1–EC4 work and a pure trading run across four systems turns a profit.
6. **Shipyard and outfitter:** buying hulls with trade-in, fitting by hardpoint, free mass, the modifier system and the trader escape kit. Moves hull geometry into manifests first (OF7). Done when OF1–OF9 work and the shuttle has a visible upgrade path.
7. **Mission engine:** flags, the condition grammar, declarative missions, script hooks, templates, mission log, persistent mission targets and escorts. Done when MS1–MS6 work with the four templates.
8. **Progression and the first arc:** ratings, ranks, achievements, the pilot screen, and a 5–8 mission arc. Done when PR1–PR4 work and the success criteria at the top are met in an hour-long playtest.

Debug tools land with the milestone that needs them: D11 in 1, D13 in 3, D12 in 7.

## Art phase (between Phase 2 and Phase 3)

An art phase follows Phase 2 to build an expanded asset library, so Phase 3 content draws on a stock of hulls, parts and effects instead of placeholders. The pipeline below was agreed on 30 Oct: the manifest refactor and its check land in Phase 2 milestone 6 (OF7), and the hardpoint editor is built ahead of the art phase.

**Asset groups**

| Group | Contents |
| --- | --- |
| Hulls | A size × role grid (shuttle, courier, freighter, fighter, corvette, frigate, cruiser) for each visual family: the SOW civilian and authority line, pirates, and one more family once the setting names it |
| Weapon parts | Turret, pivot and launcher sprites for each size and role; point-defence turrets |
| Shots and effects | Projectiles, beams, missiles, muzzle flashes, explosions in size tiers, shield hits, engine glows |
| Stellars | The star, planet types, stations, and gates (new in Phase 2) |
| Scenery | Asteroid variants and wrecks broken up from the hull library |
| Interface | Outfit and commodity icons, government emblems |

**Pipeline**

1. Each hull ships with a manifest (`hull.json`): sprite, scale, hit shape, hardpoints (ID, size, mount, position, arc), engines and part sprites. The manifest is the single source of truth for geometry.
2. Ship data names a hull and holds only gameplay stats and a loadout by hardpoint ID; the loader reads the geometry from the manifest, so nothing is copied by hand.
3. Readable spec sheets and summaries are generated from the manifest for review; the game never reads them.
4. A check script validates every manifest (schema, files exist, hardpoints inside the sprite, valid sizes and mounts) and every ship loadout against its hull.
5. Art arrives on an `art/*` branch; Claude Code merges it once the check passes, then maps ships to hulls and tunes stats.
6. Generated art comes from one reproducible generator (shared style, one definition per hull, one export); hand-made or AI-made art gets its manifest from the hardpoint editor, so both routes produce the same file.
7. Every part is an asset with its own small manifest: sprite, category (structure, engine, hardpoint, cargo, cosmetic), attachment points, footprint, size class and a paint mask for faction or player colours. Cosmetic parts are flagged as having no stat effect. The generator composes hulls from part manifests, so the art library and a future ship builder share the same building blocks.
8. The hardpoint editor lives in the repo at `tools/hardpoint-editor/index.html` and changes with the manifest format; it gains a compound hit-shape mode when OF7 lands.

## Phase 3, review list and carried-over issues

**Agreed for Phase 3**

- **Jump drive:** a high-tier outfit for point-to-point jumps within a radius, ignoring hyperlanes; fuel cost by distance, a longer countdown usable anywhere, and a misjump chance that grows with distance.
- **Currents:** another faction's travel. One-way subspace streams found with that faction's sensor or knowledge, near-free and fast, with routes that shift with the calendar.
- **War front:** territory control, off-screen battles shaping the galaxy, gates closing in war, government fleets the player can join or follow, built on the Phase 2 persistence foundation.
- **Ownership:** stations, player-built gates, capture keeping the ship.
- **Ship manufacturing and design:** player-owned shipyards with capacity tiers, an in-game ship designer built on the parts library, and stats derived from parts. Phase 2 prepares for it through OF7–OF9, the design-plus-instance save rule (SV1) and part manifests in the art phase.

**To review later**

- Dynamic supply and demand, replacing or layering on fixed tiers.
- Fauna, including leviathans, when fauna is introduced.
- Contraband scanning, escorts, hailing and bribes, AI finishing off disabled ships, point defence (C13).

**Carried over from the prototype devlog**

- Hold-to-aim (F5) leads for the first projectile; mixed shot speeds will need a choice of weapon to lead for.
- Hot reload recolours the radar but not the HUD or target panel.
- The balance report ignores shield regen.
- "Turns hostile" can post twice.
- AI fire uses the widest mount arc; flak is unused.
