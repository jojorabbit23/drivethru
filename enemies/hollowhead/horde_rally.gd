extends Node
# Temporary, non-stacking agitation for existing enemy types.
var remaining: float=5.0
var original: Dictionary={}
static func apply(enemy: Node,duration: float=5.0) -> void:
	if enemy.has_method("hear_hollowhead"):
		enemy.hear_hollowhead(duration)
		return
	var existing: Node=enemy.get_node_or_null("HollowheadRally")
	if existing:
		existing.remaining=maxf(existing.remaining,duration)
		return
	var effect: Node=load("res://enemies/hollowhead/horde_rally.gd").new()
	effect.name="HollowheadRally"
	effect.remaining=duration
	enemy.add_child(effect)
func _ready() -> void:
	var enemy: Node=get_parent()
	for property: String in ["lane_speed","hunt_speed"]:
		original[property]=enemy.get(property)
		enemy.set(property,float(original[property])*1.2)
	var agent: NavigationAgent3D=enemy.get_node_or_null("NavigationAgent3D")
	if agent:
		original["agent_speed"]=agent.max_speed
		agent.max_speed*=1.2
func _process(delta: float) -> void:
	remaining-=delta
	if remaining>0:return
	var enemy: Node=get_parent()
	for property: String in ["lane_speed","hunt_speed"]:enemy.set(property,original[property])
	var agent: NavigationAgent3D=enemy.get_node_or_null("NavigationAgent3D")
	if agent and original.has("agent_speed"):agent.max_speed=original.agent_speed
	queue_free()
