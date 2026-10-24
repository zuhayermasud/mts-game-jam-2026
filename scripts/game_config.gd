class_name GameConfig
extends Resource
## Every gameplay number lives here. Tune them by opening
## res://config/game_config.tres in the Inspector. Read them in code through Game.config.

@export_group("Brewing")
## Heat is seconds spent holding the pot. Under this it's raw and can't be served.
@export var weak_from := 0.25
## From this much heat the brew is perfect.
@export var perfect_from := 1.2
## At this much heat the pot boils over and empties itself.
@export var boil_over_at := 1.8
## Pours the pot holds. One more is blocked.
@export var max_pours := 2

@export_group("Patients")
## Seconds a weak (but correct) potion adds to the patient's clock.
@export var borrow_seconds := 10.0
## Seconds a wrong potion takes off the patient's clock.
@export var wrong_serve_penalty := 2.0
## Under this many seconds the patient looks critical and the clock flashes.
@export var critical_seconds := 4.0
## Under this fraction of the clock the patient looks worried.
@export var worried_fraction := 0.5
## A bandaged patient rejoins the queue after this many other patients.
@export var bandage_return_after := 2
## Clock multiplier for a bandaged patient who can't go up a tier.
@export var bandage_clock_multiplier := 0.8
@export var ailments: PackedStringArray = [
	"Quantum hiccups", "Gravity cramps", "Nebula sniffles", "Space jelly knees",
	"Comet cough", "Antenna droop", "Moon pox", "Zero-G gurgles",
]

@export_group("Run")
## Patients who can die before the run ends. Dying costs one.
@export var lives := 3

@export_group("Shifts")
## Index 0 is shift 1. Later shifts extrapolate from the last entry.
@export var shift_patients: PackedInt32Array = [4, 6, 7, 8]
@export var shift_clock: PackedFloat32Array = [25.0, 24.0, 22.0, 20.0]
## Chance that a patient needs a secondary colour.
@export var shift_secondary_chance: PackedFloat32Array = [0.0, 0.4, 0.5, 0.6]
## Chairs open at once (max 3). All their clocks tick together.
@export var shift_chairs: PackedInt32Array = [1, 2, 3, 3]
@export var later_shift_extra_patients := 1
@export var later_shift_clock_drop := 1.0
@export var min_clock := 12.0
## Seconds before the first patient of a shift sits down.
@export var first_arrival_delay := 1.0
## Seconds between two patients sitting down, so they don't all arrive at once.
@export var arrival_gap := 2.5

@export_group("Score")
@export var score_perfect := 100
@export var score_after_borrow := 50
@export var score_per_second_left := 5
@export var score_wrong := -25

@export_group("Potion colours")
@export var red := Color("e8413c")
@export var yellow := Color("f5c731")
@export var blue := Color("3b7de8")
@export var orange := Color("f2872c")
@export var green := Color("4cc552")
@export var purple := Color("9b4fd6")


func potion_color(kind: int) -> Color:
	match kind:
		Potion.Kind.RED: return red
		Potion.Kind.YELLOW: return yellow
		Potion.Kind.BLUE: return blue
		Potion.Kind.ORANGE: return orange
		Potion.Kind.GREEN: return green
		Potion.Kind.PURPLE: return purple
	return Color.WHITE


func patients_in_shift(shift: int) -> int:
	var i := shift - 1
	var last := shift_patients.size() - 1
	if i <= last:
		return shift_patients[i]
	return shift_patients[last] + (i - last) * later_shift_extra_patients


func clock_for_shift(shift: int) -> float:
	var i := shift - 1
	var last := shift_clock.size() - 1
	if i <= last:
		return shift_clock[i]
	return maxf(min_clock, shift_clock[last] - (i - last) * later_shift_clock_drop)


func secondary_chance(shift: int) -> float:
	return shift_secondary_chance[mini(shift - 1, shift_secondary_chance.size() - 1)]


func chairs_for_shift(shift: int) -> int:
	return clampi(shift_chairs[mini(shift - 1, shift_chairs.size() - 1)], 1, 3)
