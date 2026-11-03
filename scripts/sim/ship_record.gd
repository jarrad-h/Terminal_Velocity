class_name ShipRecord
extends RefCounted
## SV1: every saved ship (the player's, persistent entities', remembered wrecks)
## is a design reference plus instance state:
##   design: String   ship design id (premade designs are the ship definitions;
##                    player-made designs later use the same field)
##   name: String     the ship's own name ("" = none)
##   hull, shield     0–1 fractions of the design's armour and shield
##   fitted: Array    fitted items ([] = the design's own loadout until the
##                    outfitter, milestone 6)
##   cargo: Array     cargo held (economy, milestone 5)
## Other keys (a wreck's position, government…) ride along untouched.


static func make(design: String, hull: float = 1.0, shield: float = 1.0) -> Dictionary:
	return {"design": design, "name": "", "hull": hull, "shield": shield, "fitted": [], "cargo": []}


static func design_of(record: Dictionary) -> String:
	return str(record.get("design", ""))


## A record with every field present; `legacy` milestone 3 records named the
## design "ship" (SV4 migration).
static func normalised(record: Dictionary) -> Dictionary:
	var out: Dictionary = record.duplicate(true)
	if out.has("ship") and not out.has("design"):
		out["design"] = out["ship"]
	out.erase("ship")
	if out.has("armor_pct") and not out.has("hull"):
		out["hull"] = out["armor_pct"]
	out.erase("armor_pct")
	var base: Dictionary = make(design_of(out))
	for key: String in base:
		if not out.has(key):
			out[key] = base[key]
	return out
