extends RefCounted

class_name NoisyEdges

static func apply_noisy_edges_to_polygon(poly: PackedVector2Array, region_data: Dictionary, 
		noisy_edge_seed: int, noisy_edge_length: float, noisy_edge_amplitude: float) -> PackedVector2Array:
	# Apply noisy edge subdivision to all polygon sides using exact JS algorithm
	if poly.size() < 3:
		return poly
		
	var result := PackedVector2Array()
	var rng := RandomNumberGenerator.new()
	rng.seed = noisy_edge_seed
	
	# Get region center for quadrilateral constraints
	var center_data = region_data.get("center", [500, 500])
	var _region_center := Vector2(center_data[0], center_data[1])
	
	# Process each edge of the polygon
	for i in range(poly.size()):
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		
		# For each edge, we need to create a quadrilateral constraint
		# Since we don't have neighboring region data, create a narrow quadrilateral
		# that keeps the subdivision close to the original edge
		
		# Calculate edge midpoint and perpendicular direction  
		var edge_mid := (a + b) * 0.5
		var edge_vec := (b - a)
		var edge_normal := Vector2(-edge_vec.y, edge_vec.x).normalized()
		
		# Create a narrow quadrilateral very close to the edge
		var offset_distance := 2.0  # Keep it close to the original edge
		var p := edge_mid + edge_normal * offset_distance
		var q := edge_mid - edge_normal * offset_distance
		
		# Generate noisy line segment (excluding point a, like JS)
		var noisy_segment := recursive_subdivision(a, b, p, q, rng, noisy_edge_length, noisy_edge_amplitude)
		
		# Add the starting point for this edge
		result.append(a)
		
		# Add intermediate points from the noisy segment (exclude the last point to avoid duplication)
		for j in range(noisy_segment.size() - 1):
			result.append(noisy_segment[j])

	return result

static func recursive_subdivision(a: Vector2, b: Vector2, p: Vector2, q: Vector2, rng: RandomNumberGenerator,
		noisy_edge_length: float, noisy_edge_amplitude: float) -> PackedVector2Array:
	# Direct port of JS recursiveSubdivision function
	# Returns noisy line from a to b, constrained by quadrilateral a-p-b-q
	# Returns array NOT including point a (half-open interval)
	
	var dx := a.x - b.x
	var dy := a.y - b.y
	
	# Stop recursion if segment is too short (JS: dx*dx + dy*dy < length*length)
	# Note: Don't scale noisy_edge_length as coordinates are already scaled
	if (dx*dx + dy*dy) < (noisy_edge_length * noisy_edge_length):
		return PackedVector2Array([b])  # JS: return [b]
	
	# Calculate midpoints (JS: lerpv(a, p, 0.5))
	var ap := a.lerp(p, 0.5)
	var bp := b.lerp(p, 0.5)
	var aq := a.lerp(q, 0.5)
	var bq := b.lerp(q, 0.5)
	
	# Random division along p-q line (JS algorithm)
	var divisor: float = 0x10000000  # JS const divisor
	var rand_val := rng.randi() % int(divisor)
	var division: float = 0.5 * (1.0 - noisy_edge_amplitude) + (rand_val / divisor) * noisy_edge_amplitude
	var center := p.lerp(q, division)
	
	# Recursive calls
	var results1 := recursive_subdivision(a, center, ap, aq, rng, noisy_edge_length, noisy_edge_amplitude)
	var results2 := recursive_subdivision(center, b, bp, bq, rng, noisy_edge_length, noisy_edge_amplitude)
	
	# Concatenate results (JS: results1.concat(results2))
	var combined := PackedVector2Array()
	for point in results1:
		combined.append(point)
	for point in results2:
		combined.append(point)
	
	return combined
