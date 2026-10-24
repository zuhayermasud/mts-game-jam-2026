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
