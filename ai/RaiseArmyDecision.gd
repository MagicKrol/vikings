extends RefCounted
class_name RaiseArmyDecision

# KISS: Pure helpers for raise-army decision, testable with plain values.

static func _clamp01(x: float) -> float:
	return clamp(x, 0.0, 1.0)

static func _norm(val: float, lo: float, hi: float) -> float:
	if hi <= lo:
		return 0.0
	return _clamp01((val - lo) / (hi - lo))

static func score(regions: int, armies: int, avg_dist_mp: float, recruits: int, gold: int) -> float:
	# Hard gates mirrored by should_raise_army_simple()
	var gold_after := float(gold - GameParameters.RAISE_ARMY_COST)
	if gold_after < float(GameParameters.AI_RESERVE_GOLD_MIN):
		return 0.0
	if recruits < GameParameters.AI_MIN_RECRUITS_FOR_RAISING:
		return 0.0

	# Ratios and normalizations
	var r2a := float(regions) / float(max(armies, 1))
	var r2a_norm := _norm(r2a, GameParameters.AI_RAISE_R2A_BAND_MIN, GameParameters.AI_RAISE_R2A_BAND_MAX)
	var dist_norm := _norm(avg_dist_mp, GameParameters.AI_RAISE_DIST_MIN, GameParameters.AI_RAISE_DIST_MAX)
	var recruits_norm := _norm(float(recruits), float(GameParameters.AI_RAISE_RECRUITS_MIN), float(GameParameters.AI_RAISE_RECRUITS_MAX))
	var bank_norm := _norm(gold_after, float(GameParameters.AI_RAISE_BANK_RESERVE), float(GameParameters.AI_RAISE_BANK_MAX))

	# Soft support guard: avoid barely-above-min raises
	var support := 0.5 * recruits_norm + 0.5 * bank_norm
	if support < GameParameters.AI_RAISE_SUPPORT_MIN:
		return 0.0

	# Weighted sum
	var s := 0.0
	s += GameParameters.AI_RAISE_W_R2A * r2a_norm
	s += GameParameters.AI_RAISE_W_DIST * dist_norm
	s += GameParameters.AI_RAISE_W_RECRUITS * recruits_norm
	s += GameParameters.AI_RAISE_W_BANK * bank_norm
	return s

static func should_raise_army_simple(regions: int, armies: int, avg_dist_mp: float, recruits: int, gold: int) -> bool:
	var s := score(regions, armies, avg_dist_mp, recruits, gold)
	return s >= GameParameters.AI_RAISE_THRESHOLD_NORM
