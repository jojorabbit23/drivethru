extends RefCounted
const HOT_SECONDS := 150.0
const Economy = preload("res://game/economy.gd")
const Sfx = preload("res://game/sfx.gd")
static var _next_id: int = 0
static func prepare(item: Dictionary) -> void:
	if not item.has("age_seconds"):item.age_seconds=maxf(0.0,HOT_SECONDS-float(item.get("hot_remaining",HOT_SECONDS)))
	if not item.has("burger_id"):
		_next_id+=1
		item.burger_id=_next_id
static func age(item: Dictionary) -> float:
	prepare(item)
	return float(item.age_seconds)
static func cold(item: Dictionary) -> bool:
	return age(item)>=150.0
static func spoiled(item: Dictionary) -> bool:
	return age(item)>=450.0
static func state(item: Dictionary) -> String:
	var a: float=age(item)
	if a>=450.0:return "SPOILED"
	if a>=300.0:return "VERY COLD"
	if a>=150.0:return "COLD"
	if a>=110.0:return "COOLING"
	if a>=50.0:return "WARM"
	return "FRESH"
static func payment(item: Dictionary) -> Array:
	var pay: Array=Economy.payment(String(item.get("quality","standard")),String(item.get("kind","brown")))
	if item.get("good_flip",false) and String(item.get("quality","")) in ["perfect","good"]:pay[1]+=2
	var scale: float=0.0 if spoiled(item) else (0.25 if age(item)>=300.0 else (0.5 if cold(item) else 1.0))
	return [int(float(pay[0])*scale),int(float(pay[1])*scale)]
static func tick(items: Array,delta: float,heated: bool=false,source: Node=null) -> bool:
	var changed: bool=false
	for item: Dictionary in items:
		var before: float=age(item)
		var slowed: float=minf(delta,maxf(0.0,150.0-before)*2.0) if heated else 0.0
		item.age_seconds=before+delta-slowed*0.5
		item.hot_remaining=maxf(0.0,HOT_SECONDS-float(item.age_seconds))
		if before<150.0 and cold(item) and source!=null:Sfx.play(source,"bell",-22.0)
		changed=changed or floori(before)!=floori(float(item.age_seconds))
	return changed
static func icon(item: Dictionary) -> String:
	var s: String=state(item)
	return "freshness_"+({"FRESH":"fresh","WARM":"warm","COOLING":"cooling"}.get(s,"cold") as String)
static func timer(item: Dictionary) -> String:
	return state(item)
