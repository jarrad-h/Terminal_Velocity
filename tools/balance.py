"""Offline balance report (M7): reads data/ (then mods/) and prints, for each
pair of armed attacker and defender ships, how long the attacker's full
loadout takes to disable and to destroy the defender, plus one-on-one duels.

It replays the game's damage rules (scripts/sim/damage_model.gd): shields
first; a hit that empties the shield carries the unspent share of its armour
damage through; disabled at disable_armor_pct of max armour. Shields don't
recharge (constant fire keeps resetting the C6 delay).

Assumptions, so read the numbers as a guide, not a prediction:
  - every weapon fires on cooldown and lands `--accuracy` of its damage
    (expected value), beams included;
  - fights happen at `--distance` px (damage falloff, C12);
  - guided missiles count if the distance is within their reach.

Usage: python tools/balance.py [--accuracy 0.5] [--distance 400]
"""

import argparse
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STEP = 0.01  # seconds per simulation step
LIMIT = 600.0  # give up after this many seconds


def load(kind):
    defs = {}
    for base in ("data", "mods"):
        folder = os.path.join(ROOT, base, kind)
        if not os.path.isdir(folder):
            continue
        for name in sorted(os.listdir(folder)):
            if name.endswith(".json"):
                with open(os.path.join(folder, name), encoding="utf-8") as f:
                    defs[name[:-5]] = json.load(f)
    return defs


def reach(w):
    if w["kind"] == "beam":
        return w.get("range", 0) or w.get("speed", 600) * w.get("lifetime", 1)
    life = w.get("range", 0) / w.get("speed", 600) if w.get("range", 0) > 0 else w.get("lifetime", 1)
    return w.get("speed", 600) * life


def falloff(w, distance):
    start_pct = w.get("falloff_start_pct", 100)
    min_pct = w.get("falloff_min_pct", 100)
    r = reach(w)
    if r <= 0 or start_pct >= 100:
        return 1.0
    start = r * start_pct / 100
    if distance <= start:
        return 1.0
    t = min(max((distance - start) / (r - start), 0.0), 1.0)
    return 1.0 + (min_pct / 100 - 1.0) * t


def hit(shield, armor, ds, da):
    if shield > 0:
        if ds <= 0:
            return shield, armor
        if ds <= shield:
            return shield - ds, armor
        leftover = 1.0 - shield / ds
        return 0.0, max(armor - da * leftover, 0.0)
    return 0.0, max(armor - da, 0.0)


def guns(ship, weapons, distance, accuracy):
    """[(reload, shield dmg per shot, armour dmg per shot)] that can reach."""
    out = []
    for item in ship.get("loadout", []):
        w = weapons[item["weapon"]]
        if reach(w) < distance:
            continue
        scale = accuracy * falloff(w, distance)
        if w["kind"] == "beam":
            # Damage per second, applied every step.
            out.append((0.0, w.get("damage_shield", 0) * scale * STEP, w.get("damage_armor", 0) * scale * STEP))
        else:
            out.append((w.get("reload", 0.5), w.get("damage_shield", 0) * scale, w.get("damage_armor", 0) * scale))
    return out


def fight(attacker, defender, weapons, distance, accuracy):
    """Seconds to disable and to destroy `defender` (None if never)."""
    loadout = guns(attacker, weapons, distance, accuracy)
    if not loadout:
        return None, None
    shield = float(defender.get("shield", 0))
    max_armor = float(defender.get("armor", 100))
    armor = max_armor
    disable_at = max_armor * defender.get("disable_armor_pct", 33) / 100
    cooldowns = [0.0] * len(loadout)
    t = 0.0
    disabled = None
    while t < LIMIT:
        for i, (reload, ds, da) in enumerate(loadout):
            cooldowns[i] -= STEP
            if cooldowns[i] <= 0:
                shield, armor = hit(shield, armor, ds, da)
                cooldowns[i] += reload if reload > 0 else STEP
        t += STEP
        if disabled is None and 0 < armor <= disable_at:
            disabled = t
        if armor <= 0:
            return disabled if disabled is not None else t, t
    return disabled, None


def fmt(seconds):
    return "  never" if seconds is None else f"{seconds:6.1f}s"


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--accuracy", type=float, default=0.5, help="share of damage that lands (default 0.5)")
    parser.add_argument("--distance", type=float, default=400.0, help="fight distance in px (default 400)")
    args = parser.parse_args()
    ships = load("ships")
    weapons = load("weapons")
    armed = [s for s in ships if ships[s].get("loadout")]
    print(f"Balance report: accuracy {args.accuracy:.0%}, distance {args.distance:.0f} px\n")
    print("Time for the attacker (row) to disable / destroy the defender (column):\n")
    names = list(ships)
    width = max(len(n) for n in names) + 2
    print(" " * width + "".join(n.rjust(18) for n in names))
    for a in armed:
        row = a.ljust(width)
        for d in names:
            dis, kill = fight(ships[a], ships[d], weapons, args.distance, args.accuracy)
            row += f"{fmt(dis)} /{fmt(kill)}".rjust(18)
        print(row)
    print("\nOne on one (both fire from the start; first to disable the other wins):\n")
    for i, a in enumerate(armed):
        for b in armed[i + 1:]:
            ta, _ = fight(ships[a], ships[b], weapons, args.distance, args.accuracy)
            tb, _ = fight(ships[b], ships[a], weapons, args.distance, args.accuracy)
            if ta is None and tb is None:
                verdict = "stalemate"
            elif tb is None or (ta is not None and ta < tb):
                verdict = f"{a} wins ({fmt(ta).strip()} vs {fmt(tb).strip()})"
            else:
                verdict = f"{b} wins ({fmt(tb).strip()} vs {fmt(ta).strip()})"
            print(f"  {a} vs {b}: {verdict}")
    print("\nStrength (AI odds, A5): " + ", ".join(f"{s} {ships[s].get('strength', 1)}" for s in names))


if __name__ == "__main__":
    main()
