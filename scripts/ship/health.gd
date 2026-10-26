class_name Health
extends Node
## Shield and armour for ships and solid scenery (C5–C7, L4). Uses
## DamageModel for the maths. Disabled at `disable_fraction` of max armour
## (never, when 0), destroyed at 0.

signal damaged(source: Node)
signal disabled
signal destroyed

var max_shield: float = 0.0
var max_armor: float = 0.0
var shield: float = 0.0
var armor: float = 0.0
var shield_regen: float = 0.0
var disable_fraction: float = 0.0
## D4: ignores all damage.
var invulnerable: bool = false
var is_disabled: bool = false
var is_destroyed: bool = false


## Resets to full shield and armour.
func setup(p_max_shield: float, p_max_armor: float, p_shield_regen: float = 0.0, p_disable_fraction: float = 0.0) -> void:
	max_shield = p_max_shield
	max_armor = p_max_armor
	shield = p_max_shield
	armor = p_max_armor
	shield_regen = p_shield_regen
	disable_fraction = p_disable_fraction
	is_disabled = false
	is_destroyed = false
	set_physics_process(shield_regen > 0.0 and max_shield > 0.0)


func apply_damage(damage_shield: float, damage_armor: float, source: Node = null) -> void:
	if invulnerable or is_destroyed:
		return
	var result: Vector2 = DamageModel.apply(shield, armor, damage_shield, damage_armor)
	shield = result.x
	armor = result.y
	damaged.emit(source)
	_update_state()


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


## C6: shields recharge, except while disabled.
func _physics_process(delta: float) -> void:
	if not is_disabled and not is_destroyed:
		shield = DamageModel.regen(shield, max_shield, shield_regen, delta)


func _update_state() -> void:
	if armor <= 0.0:
		is_destroyed = true
		destroyed.emit()
	elif not is_disabled and DamageModel.is_disabled(armor, max_armor, disable_fraction):
		is_disabled = true
		disabled.emit()
