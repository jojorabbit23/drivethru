# Shared hit test for weapons. A zombie's movement capsule is coarse and,
# when it hunches, wraps round its head; so a plain ray would hit the capsule
# and never register a headshot. Instead:
#   1. find the nearest wall / board along the ray (they block everything)
#   2. a head hitbox in front of that wins
#   3. otherwise a zombie body in front of that
#   4. otherwise whatever wall was hit
# Returns the usual intersect_ray dictionary (empty if nothing), plus
# "kind": "head" | "body" | "world".
extends RefCounted

const WORLD := 1 | 2
const ZOMBIES := 8

static func cast(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, exclude: Array[RID] = []) -> Dictionary:
	var wq := PhysicsRayQueryParameters3D.create(from, to, WORLD, exclude)
	var world := space.intersect_ray(wq)
	var limit := INF if world.is_empty() else from.distance_to(world["position"])
	var hq := PhysicsRayQueryParameters3D.create(from, to, ZOMBIES, exclude)
	hq.collide_with_areas = true
	hq.collide_with_bodies = false
	var head := space.intersect_ray(hq)
	if not head.is_empty() and from.distance_to(head["position"]) < limit:
		var z: Variant = (head["collider"] as Object).get_meta("zombie") if (head["collider"] as Object).has_meta("zombie") else null
		if z != null and is_instance_valid(z) and not z.is_dead():
			head["kind"] = "head"
			return head
	var bq := PhysicsRayQueryParameters3D.create(from, to, ZOMBIES, exclude)
	var body := space.intersect_ray(bq)
	if not body.is_empty() and from.distance_to(body["position"]) < limit:
		body["kind"] = "body"
		return body
	if not world.is_empty():
		world["kind"] = "world"
	return world
