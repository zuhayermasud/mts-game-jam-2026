class_name PatientInfo
extends RefCounted
## One patient in the shift list. Skin colour is the cure.

var cure: int
var clock: float
var ailment: String
var body_art: String
## Took a weak potion. Borrowing is allowed once per patient, ever.
var borrowed := false
## Ran out of borrowed time once and came back worse. Hitting 0 again kills them.
var bandaged := false
## Arrives on the short emergency clock.
var emergency := false


func duplicate_info() -> PatientInfo:
	var copy := PatientInfo.new()
	copy.cure = cure
	copy.clock = clock
	copy.ailment = ailment
	copy.body_art = body_art
	copy.borrowed = borrowed
	copy.bandaged = bandaged
	copy.emergency = emergency
	return copy
