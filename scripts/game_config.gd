class_name GameConfig
extends Resource
## Every gameplay number lives here. Tune them by opening
## res://config/game_config.tres in the Inspector. Read them in code through Game.config.

@export_group("Brewing")
## Heat is seconds on the boil since the last pour (the pot boils by itself).
## Clicking the pot before this does nothing: it's still raw.
@export var weak_from := 0.4
## The gold (perfect) band starts anywhere in this range, rolled fresh on every pour.
## It's clamped so it always ends before the warning zone.
@export var band_start_min := 1.0
@export var band_start_max := 3.0
## Band width in seconds of boiling on shift 1. Secondaries get the narrower one.
@export var band_width_primary := 0.5
@export var band_width_secondary := 0.4
## The band narrows this much every shift, down to band_width_min.
@export var band_shrink_per_shift := 0.06
@export var band_width_min := 0.2
## Boiling this long boils the pot over and empties it.
@export var boil_over_at := 4.0
## Seconds before boil_over_at that the pot rattles and the ring flashes red.
@export var boil_warning := 0.8
## Pours the pot holds. One more is blocked.
@export var max_pours := 2

@export_group("Patients")
## Seconds each weak (but correct) potion adds to the patient's clock: the first loan,
## the second, and so on. The last value repeats. Borrowing again buys less (interest).
@export var borrow_steps: PackedFloat32Array = [10.0, 6.0, 3.0]
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
@export var shift_clock: PackedFloat32Array = [22.0, 18.0, 15.0, 13.0]
## Chance that a patient needs a secondary colour.
@export var shift_secondary_chance: PackedFloat32Array = [0.0, 0.4, 0.5, 0.6]
## Chairs open at once (max 3). All their clocks tick together.
@export var shift_chairs: PackedInt32Array = [1, 2, 3, 3]
## Chance that a patient is an emergency, on the short emergency clock.
@export var emergency_chance: PackedFloat32Array = [0.0, 0.15, 0.25, 0.3]
@export var emergency_clock := 7.0
@export var later_shift_extra_patients := 1
@export var later_shift_clock_drop := 1.0
@export var min_clock := 10.0
## Seconds before the first patient of a shift sits down.
@export var first_arrival_delay := 1.0
## Seconds between two patients sitting down, so they don't all arrive at once.
@export var arrival_gap := 1.5

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


func emergency_for_shift(shift: int) -> float:
	return emergency_chance[mini(shift - 1, emergency_chance.size() - 1)]


func chairs_for_shift(shift: int) -> int:
	return clampi(shift_chairs[mini(shift - 1, shift_chairs.size() - 1)], 1, 3)


## Seconds the patient's `count`-th loan buys (0 = first loan).
func borrow_for(count: int) -> float:
	return borrow_steps[clampi(count, 0, borrow_steps.size() - 1)]


## Width of the gold band for a brew of `kind` on `shift`.
func band_width(kind: int, shift: int) -> float:
	var base := band_width_primary if Potion.is_primary(kind) else band_width_secondary
	return maxf(band_width_min, base - band_shrink_per_shift * (shift - 1))
