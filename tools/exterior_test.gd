extends SceneTree
var failures:=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,label: String) -> void:
 print("PASS " if ok else "FAIL ",label)
 if not ok:failures+=1
func run() -> void:
 var main: Node3D=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main)
 var exterior: Node3D=main.get_node("ExteriorSurroundings")
 check(exterior.get_child_count()==8,"eight static scenery batches")
 check(exterior.find_children("*","CollisionObject3D",true,false).is_empty(),"visual scenery has no gameplay collision")
 check(exterior.find_children("*","Light3D",true,false).is_empty(),"no additional shadow or dynamic light cost")
 var counts: Dictionary={}
 for child: Node3D in exterior.get_children():
  check(child.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,child.name+" casts no shadow")
  if child.has_meta("placements"):
   var positions: PackedVector3Array=child.get_meta("placements")
   counts[child.name]=positions.size()
   check(child.mesh.get_surface_count()==1,child.name+" shares one material surface")
   for point: Vector3 in positions:
    check(not(absf(point.x)<20 and point.z>-16 and point.z<20),"outside playable building, lanes and garage")
    check(absf(point.z+8)>5,"outside customer road")
 check(counts.NearbyPines<=390 and counts.ChunkyRocks<=85 and counts.WreckedCars==5,"bounded population")
 check(exterior.has_node("PetrolStationShedsWaterTower") and exterior.has_node("FlatForestAndMountainBackdrops"),"middle and far scenery layers present")
 main.free()
 for i in 3:await process_frame
 print("Exterior: %d failure(s)" % failures)
 quit(1 if failures else 0)
