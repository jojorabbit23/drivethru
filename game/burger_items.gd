extends RefCounted
const HOT_SECONDS := 150.0
const Economy = preload("res://game/economy.gd")
static func cold(item: Dictionary) -> bool:
	return float(item.get("hot_remaining", HOT_SECONDS)) <= 0.0
static func payment(item: Dictionary) -> Array:
	var pay: Array = Economy.payment(String(item.get("quality", "standard")), String(item.get("kind", "brown")))
	if cold(item): return [int(pay[0]) / 2, int(pay[1]) / 2]
	return pay
static func tick(items: Array, delta: float) -> bool:
	var changed := false
	for item: Dictionary in items:
		var before: float = float(item.get("hot_remaining", HOT_SECONDS))
		item.hot_remaining = maxf(0.0, before - delta)
		changed = changed or ceili(before) != ceili(item.hot_remaining)
	return changed
static func timer(item: Dictionary) -> String:
	if cold(item): return "COLD"
	var seconds: int = ceili(float(item.get("hot_remaining", HOT_SECONDS)))
	return "%d:%02d" % [seconds / 60, seconds % 60]
