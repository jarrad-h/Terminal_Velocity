class_name Health
extends Node
## Shield and armour for ships and solid scenery (C5–C7, L4). Uses
## DamageModel for the maths. Disabled at `disable_fraction` of max armour
## (never, when 0), destroyed at 0.

## `amount`: shield + armour actually lost.
signal damaged(source: Node, amount: float)
signal disabled
signal destroyed

var max_shield: float = 0.0
var max_armor: float = 0.0
var shield: float = 0.0
var armor: float = 0.0
var shield_regen: float = 0.0
## C6: seconds without damage before shields start to recharge.
var recharge_delay: float = 0.0
var _since_damage: float = INF
var disable_fraction: float = 0.0
## D4: ignores all damage.
var invulnerable: bool = false
var is_disabled: bool = false
var is_destroyed: bool = false


## Resets to full shield and armour.
func setup(p_max_shield: float, p_max_armor: float, p_shield_regen: float = 0.0, p_disable_fraction: float = 0.0, p_recharge_delay: float = 0.0) -> void:
	max_shield = p_max_shield
	max_armor = p_max_armor
	shield = p_max_shield
	armor = p_max_armor
	shield_regen = p_shield_regen
	disable_fraction = p_disable_fraction
	recharge_delay = p_recharge_delay
	_since_damage = INF
	is_disabled = false
	is_destroyed = false
	set_physics_process(shield_regen > 0.0 and max_shield > 0.0)


## D8: new maximums and rates from reloaded data, keeping the current shield
## and armour as fractions of max and the disabled/destroyed state.
func retune(p_max_shield: float, p_max_armor: float, p_shield_regen: float, p_disable_fraction: float, p_recharge_delay: float) -> void:
	var shield_fraction: float = shield / max_shield if max_shield > 0.0 else 1.0
	var armor_fraction: float = armor / max_armor if max_armor > 0.0 else 1.0
	max_shield = p_max_shield
	max_armor = p_max_armor
	shield = max_shield * shield_fraction
	armor = max_armor * armor_fraction
	shield_regen = p_shield_regen
	disable_fraction = p_disable_fraction
	recharge_delay = p_recharge_delay
	set_physics_process(shield_regen > 0.0 and max_shield > 0.0)


func apply_damage(damage_shield: float, damage_armor: float, source: Node = null) -> void:
	if invulnerable or is_destroyed:
		return
	var result: Vector2 = DamageModel.apply(shield, armor, damage_shield, damage_armor)
	var lost: float = (shield - result.x) + (armor - result.y)
	shield = result.x
	armor = result.y
	_since_damage = 0.0
	damaged.emit(source, lost)
	_update_state()


## S3: points of shield and armour missing.
func missing_points() -> float:
	return (max_shield - shield) + (max_armor - armor)


## S3: full shield and armour; clears the disabled state.
func repair_full() -> void:
	shield = max_shield
	armor = max_armor
	is_disabled = false


## C9 Assist: patches a disabled ship up to `armor_pct` % of max armour.
func recover(armor_pct: float) -> void:
	if is_destroyed:
		return
	armor = maxf(armor, max_armor * armor_pct / 100.0)
	is_disabled = false


## D5: drops armour to the disable threshold.
func force_disable() -> void:
	if is_destroyed or disable_fraction <= 0.0:
		return
	shield = 0.0
	armor = minf(armor, max_armor * disable_fraction)
	_update_state()


## D5
func force_destroy() -> void:
	if is_destroyed:
		return
	shield = 0.0
	armor = 0.0
	_update_state()


## C6: shields recharge after recharge_delay without damage, except while disabled.
func _physics_process(delta: float) -> void:
	_since_damage += delta
	if not is_disabled and not is_destroyed and DamageModel.can_regen(_since_damage, recharge_delay):
		shield = DamageModel.regen(shield, max_shield, shield_regen, delta)


func _update_state() -> void:
	if armor <= 0.0:
		is_destroyed = true
		destroyed.emit()
	elif not is_disabled and DamageModel.is_disabled(armor, max_armor, disable_fraction):
		is_disabled = true
		disabled.emit()
