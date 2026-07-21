## Deterministic random functions compatible with @redblobgames/prng.
##
## Source algorithm: Red Blob Games mapgen2, Apache-2.0.
class_name MapgenPrng
extends RefCounted

const UINT32_MASK: int = 0xffffffff
const RAND_FLOAT_MODULUS: int = 268435456
const RAND_FLOAT_DIVISOR: float = 268435456.0
const WATER_FLOAT_MODULUS: int = 1073741824
const WATER_FLOAT_DIVISOR: float = 1073741824.0

var _seed: int
var _calls: int = 0

func _init(seed: int) -> void:
	_seed = seed

func next_int(modulus: int) -> int:
	_calls += 1
	return hash_int(_seed + _calls) % modulus

func next_float() -> float:
	return float(next_int(RAND_FLOAT_MODULUS)) / RAND_FLOAT_DIVISOR

func next_water_float() -> float:
	return float(next_int(WATER_FLOAT_MODULUS)) / WATER_FLOAT_DIVISOR

static func hash_int(value: int) -> int:
	var state: int = value & UINT32_MASK
	state = (state - ((state << 6) & UINT32_MASK)) & UINT32_MASK
	state = (state ^ (state >> 17)) & UINT32_MASK
	state = (state - ((state << 9) & UINT32_MASK)) & UINT32_MASK
	state = (state ^ (state << 4)) & UINT32_MASK
	state = (state - ((state << 3) & UINT32_MASK)) & UINT32_MASK
	state = (state ^ (state << 10)) & UINT32_MASK
	state = (state ^ (state >> 15)) & UINT32_MASK
	return state
