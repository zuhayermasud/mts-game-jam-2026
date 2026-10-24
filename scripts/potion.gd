class_name Potion
## Potion colours, brew quality and the mixing rule.

enum Kind { NONE, RED, YELLOW, BLUE, ORANGE, GREEN, PURPLE }
## RAW: poured but not boiled yet, can't be served. The pot never holds a burnt brew:
## boiling past perfect empties it.
enum Quality { RAW, WEAK, PERFECT }

const PRIMARIES: Array[int] = [Kind.RED, Kind.YELLOW, Kind.BLUE]
const SECONDARIES: Array[int] = [Kind.ORANGE, Kind.GREEN, Kind.PURPLE]
const RECIPES := {
	Kind.ORANGE: [Kind.RED, Kind.YELLOW],
	Kind.GREEN: [Kind.YELLOW, Kind.BLUE],
	Kind.PURPLE: [Kind.RED, Kind.BLUE],
}
const NAMES := {
	Kind.NONE: "None", Kind.RED: "Red", Kind.YELLOW: "Yellow", Kind.BLUE: "Blue",
	Kind.ORANGE: "Orange", Kind.GREEN: "Green", Kind.PURPLE: "Purple",
}
const QUALITY_NAMES := {
	Quality.RAW: "Raw", Quality.WEAK: "Weak", Quality.PERFECT: "Perfect!",
}


## 1 pour = that colour. Same colour twice = that colour. Two primaries = their secondary.
static func mix(pours: Array[int]) -> int:
	if pours.is_empty():
		return Kind.NONE
	if pours.size() == 1 or pours[0] == pours[1]:
		return pours[0]
	for kind in RECIPES:
		if pours[0] in RECIPES[kind] and pours[1] in RECIPES[kind]:
			return kind
	return Kind.NONE


## Secondaries one tier above a primary, e.g. RED -> [ORANGE, PURPLE].
static func secondaries_with(primary: int) -> Array[int]:
	var result: Array[int] = []
	for kind in RECIPES:
		if primary in RECIPES[kind]:
			result.append(kind)
	return result


static func is_primary(kind: int) -> bool:
	return kind in PRIMARIES


static func display_name(kind: int) -> String:
	return NAMES[kind] + " Potion"


## Lowercase name used in art file names, e.g. "critter_red", "icon_green".
static func art_suffix(kind: int) -> String:
	return NAMES[kind].to_lower()
