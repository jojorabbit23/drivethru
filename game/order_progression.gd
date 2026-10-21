extends RefCounted
const Recipes=preload("res://game/recipes.gd")
static func mixed_chance(wave: int) -> float:
 return 0.0 if wave<3 else (.45 if wave<6 else .7 if wave<9 else .85)
static func _pick(weights: Dictionary,rng: RandomNumberGenerator) -> String:
 var roll: float=rng.randf()
 for kind: String in weights:
  roll-=float(weights[kind])
  if roll<=0:return kind
 return "brown"
static func generate(wave: int,served: int,rng: RandomNumberGenerator) -> Array[String]:
 var weights: Dictionary=Recipes.WEIGHTS_LATER if served>=Recipes.UNLOCK_AFTER or wave>=6 else Recipes.WEIGHTS
 var count: int=rng.randi_range(1,2) if wave<6 else (3 if rng.randf()<(.35 if wave<9 else .6) else 2)
 var mixed: bool=wave>=3 and rng.randf()<mixed_chance(wave)
 if mixed:count=maxi(2,count)
 var first: String=_pick(Recipes.WEIGHTS if mixed and wave<6 else weights,rng)
 var result: Array[String]=[first]
 for i in range(1,count):
  var kind: String=_pick(Recipes.WEIGHTS if wave<6 else weights,rng) if mixed else first
  if mixed and i==1 and kind==first:kind="blue" if first!="blue" else "brown"
  result.append(kind)
 return result
static func patience_bonus(kinds: Array[String],wave: int) -> float:
 var patties: int=0
 for kind: String in kinds:patties+=Recipes.patties(kind).size()
 return clampf((patties-1)*6.0-maxi(0,wave-3)*1.25,-12.0,30.0)
static func gap(wave: int,minimum: float,maximum: float) -> Vector2:
 var cut: float=minf(6.0,maxi(0,wave-2)*.5)
 var low: float=maxf(8.0,minimum-cut)
 return Vector2(low,maxf(low+3.0,maximum-cut*2.0))
