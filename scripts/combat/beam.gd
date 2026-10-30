class_name Beam
extends Node2D
## C4: a beam mount's ray. Child of the ship at the exit point, pointing along
## the heading; while firing it hits the first hitbox along its length every
## physics frame, applying damage per second.

var weapon: WeaponDef
var _length: float = 0.0
## V8: lights the beam's far end while it fires.
var _light: PointLight2D = null


func _init() -> void:
	material = LitSprite.unshaded_material()  # V6: full brightness, not lit or darkened


func _ready() -> void:
	visible = false


## Fires for one physics frame.
func fire(shooter: Node, exclude: Array[RID], delta: float) -> void:
	var from: Vector2 = global_position
	var direction: Vector2 = FlightModel.heading(global_rotation)
	var hit: Dictionary = HitQuery.ray(self, from, from + direction * weapon.beam_length(), exclude)
	if hit.is_empty():
		_length = weapon.beam_length()
	else:
		_length = from.distance_to(hit["position"])
		var scale: float = HitQuery.damage_scale_from(shooter, hit["target"]) * weapon.falloff_at(_length) * delta
		if scale > 0.0:
			hit["target"].health.apply_damage(weapon.damage_shield * scale, weapon.damage_armor * scale, shooter)
	visible = true
	if _light == null:
		_light = DynamicLights.attach(self, weapon.colour, "beam")
	if _light != null:
		_light.position = Vector2.UP * _length
	queue_redraw()


func stop() -> void:
	visible = false
	if _light != null:
		_light.queue_free()
		_light = null


## C12: drawn in segments that thin and fade with the damage falloff.
func _draw() -> void:
	var segments: int = 16
	for i: int in segments:
		var d0: float = _length * i / segments
		var d1: float = _length * (i + 1) / segments
		var strength: float = weapon.falloff_at((d0 + d1) / 2.0)
		var a := Vector2(0.0, -d0)
		var b := Vector2(0.0, -d1)
		draw_line(a, b, Color(weapon.colour, 0.35 * strength), 2.0 + 4.0 * strength)
		draw_line(a, b, Color(weapon.colour, lerpf(0.25, 1.0, strength)), 1.0 + 1.0 * strength)
