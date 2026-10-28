class_name WeightedPick
extends RefCounted
## Picks an index by weight. `roll` is uniform in [0, 1).


static func pick(weights: Array[float], roll: float) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += maxf(w, 0.0)
	if total <= 0.0:
		return -1
	var at: float = roll * total
	for i: int in weights.size():
		at -= maxf(weights[i], 0.0)
		if at < 0.0:
			return i
	return weights.size() - 1
