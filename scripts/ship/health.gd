class_name Health
extends Node
## Shield and armour for ships and solid scenery (C5–C7, L4).
## Milestone 2 stub: holds the values and declares the signals; damage,
## recharge, disable and destroy arrive in milestone 3.

signal disabled
signal destroyed

var max_shield: float = 0.0
var max_armor: float = 0.0
var shield: float = 0.0
var armor: float = 0.0


func setup(p_max_shield: float, p_max_armor: float) -> void:
	max_shield = p_max_shield
	max_armor = p_max_armor
	shield = p_max_shield
	armor = p_max_armor
