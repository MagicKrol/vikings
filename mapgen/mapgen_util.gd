## Numeric helpers ported from Red Blob Games mapgen2 (Apache-2.0).
class_name MapgenUtil
extends RefCounted

static func clamp_value(value: float, minimum: float, maximum: float) -> float:
	return clampf(value, minimum, maximum)

static func lerp_value(first: float, second: float, weight: float) -> float:
	return first * (1.0 - weight) + second * weight

static func lerp_vector(first: Vector2, second: Vector2, weight: float) -> Vector2:
	return first.lerp(second, weight)

static func fbm_noise(noise: MapgenSimplexNoise, amplitudes: Array[float], x: float, y: float) -> float:
	var sum: float = 0.0
	var amplitude_sum: float = 0.0
	for octave in range(amplitudes.size()):
		var frequency: float = float(1 << octave)
		sum += amplitudes[octave] * noise.noise_2d(x * frequency, y * frequency)
		amplitude_sum += amplitudes[octave]
	return sum / amplitude_sum

static func random_shuffle(values: Array[int], random: MapgenPrng) -> void:
	for index in range(values.size() - 1, 0, -1):
		var other_index: int = random.next_int(index + 1)
		var value: int = values[index]
		values[index] = values[other_index]
		values[other_index] = value
