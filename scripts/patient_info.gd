class_name PatientInfo
extends RefCounted
## One patient in the shift list. Skin colour is the cure.

var cure: int
var clock: float
var ailment: String
var body_art: String
## Weak potions taken. Each loan buys less (GameConfig.borrow_steps). The debt follows
## a bandaged patient back.
var borrows := 0
## Ran out of borrowed time once and came back worse. Hitting 0 again kills them.
var bandaged := false
## Arrives on the short emergency clock.
var emergency := false


func has_borrowed() -> bool:
	return borrows > 0


func duplicate_info() -> PatientInfo:
	var copy := PatientInfo.new()
	copy.cure = cure
	copy.clock = clock
	copy.ailment = ailment
	copy.body_art = body_art
	copy.borrows = borrows
	copy.bandaged = bandaged
	copy.emergency = emergency
	return copy
