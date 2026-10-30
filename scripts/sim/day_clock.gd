class_name DayClock
extends RefCounted
## TM1, TM3: the game date as a day count. It never moves in real time; actions
## advance it, one day at a time, so each day's galaxy step (persistent
## entities, system memory, price events, deadlines: later milestones) runs
## in order from `day_passed`.

signal day_passed(day: int)

var day: int = 0


func advance(days: int) -> void:
	for i: int in maxi(days, 0):
		day += 1
		day_passed.emit(day)
