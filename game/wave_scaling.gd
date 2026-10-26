# Spawn-time modifiers only; source scenes and debug spawns keep their base stats.
extends RefCounted

static func health_multiplier(wave: int) -> float:
	return 1.0 + minf(0.60, maxf(0.0, float(wave - 6)) * 0.04)

static func speed_multiplier(wave: int) -> float:
	return 1.0 + minf(0.25, maxf(0.0, float(wave - 6)) * 0.02)

static func apply(enemy: Node, wave: int) -> void:
	# Called after setup and before _ready, which initializes health and avoidance.
	enemy.max_health *= health_multiplier(wave)
	enemy.lane_speed *= speed_multiplier(wave)
	enemy.hunt_speed *= speed_multiplier(wave)

static func replacement(wave: int, slot: int) -> String:
	# Only replace ordinary Shambler slots (the caller preserves the old rotation).
	# Deterministic, evenly spread additions: one in four by wave 7, one in two
	# by wave 10, three in four by wave 13. No extra bodies or early introductions.
	var quota: int = clampi(1 + (wave - 7) / 3, 0, 3) if wave >= 7 else 0
	if posmod(slot / 4, 4) >= quota:
		return ""
	return ["scuttler", "scientist", "lancer"][posmod(slot / 16, 3)]
