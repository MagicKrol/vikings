## 2D Simplex noise compatible with simplex-noise v2 used by mapgen2.
## Source algorithm: Jonas Wagner/simplex-noise, MIT license.
class_name MapgenSimplexNoise
extends RefCounted

const F2: float = 0.3660254037844386
const G2: float = 0.21132486540518713
var _gradients: PackedFloat32Array = PackedFloat32Array([
	1.0, 1.0, 0.0, -1.0, 1.0, 0.0, 1.0, -1.0, 0.0, -1.0, -1.0, 0.0,
	1.0, 0.0, 1.0, -1.0, 0.0, 1.0, 1.0, 0.0, -1.0, -1.0, 0.0, -1.0,
	0.0, 1.0, 1.0, 0.0, -1.0, 1.0, 0.0, 1.0, -1.0, 0.0, -1.0, -1.0
])

var _permutation: PackedByteArray = PackedByteArray()
var _permutation_mod_12: PackedByteArray = PackedByteArray()

func _init(random: MapgenPrng) -> void:
	var base: PackedByteArray = PackedByteArray()
	base.resize(256)
	for index in range(256):
		base[index] = index
	for index in range(255):
		var swap_index: int = index + int(random.next_float() * float(256 - index))
		var value: int = base[index]
		base[index] = base[swap_index]
		base[swap_index] = value
	_permutation.resize(512)
	_permutation_mod_12.resize(512)
	for index in range(512):
		_permutation[index] = base[index & 255]
		_permutation_mod_12[index] = _permutation[index] % 12

func noise_2d(x_input: float, y_input: float) -> float:
	var skew: float = (x_input + y_input) * F2
	var cell_x: int = floori(x_input + skew)
	var cell_y: int = floori(y_input + skew)
	var unskew: float = float(cell_x + cell_y) * G2
	var origin_x: float = float(cell_x) - unskew
	var origin_y: float = float(cell_y) - unskew
	var x0: float = x_input - origin_x
	var y0: float = y_input - origin_y
	var offset_x: int = 1 if x0 > y0 else 0
	var offset_y: int = 0 if x0 > y0 else 1
	var x1: float = x0 - float(offset_x) + G2
	var y1: float = y0 - float(offset_y) + G2
	var x2: float = x0 - 1.0 + 2.0 * G2
	var y2: float = y0 - 1.0 + 2.0 * G2
	var wrapped_x: int = cell_x & 255
	var wrapped_y: int = cell_y & 255
	var contribution_0: float = _contribution(x0, y0, int(_permutation_mod_12[wrapped_x + _permutation[wrapped_y]]) * 3)
	var contribution_1: float = _contribution(x1, y1, int(_permutation_mod_12[wrapped_x + offset_x + _permutation[wrapped_y + offset_y]]) * 3)
	var contribution_2: float = _contribution(x2, y2, int(_permutation_mod_12[wrapped_x + 1 + _permutation[wrapped_y + 1]]) * 3)
	return 70.0 * (contribution_0 + contribution_1 + contribution_2)

func _contribution(x_value: float, y_value: float, gradient_index: int) -> float:
	var factor: float = 0.5 - x_value * x_value - y_value * y_value
	if factor < 0.0:
		return 0.0
	factor *= factor
	return factor * factor * (_gradients[gradient_index] * x_value + _gradients[gradient_index + 1] * y_value)
