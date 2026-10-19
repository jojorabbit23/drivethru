# Tests the imported pump module without changing the existing four-slot loadout.
extends SceneTree
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,text: String) -> void:
 print("PASS " if ok else "FAIL ",text)
 if not ok:failures+=1
func run() -> void:
 var main: Node3D=load("res://main.tscn").instantiate()
 main.auto_spawn=false
 root.add_child(main)
 var player: Node3D=main.get_node("Player")
 player.set_physics_process(false)
 for weapon in player.weapons:weapon.set_active(false);weapon.set_physics_process(false)
 var sg: Node3D=load("res://weapons/shotgun/shotgun_weapon.gd").new()
 player.camera.add_child(sg)
 sg.owner=player
 sg.set_physics_process(false)
 sg.set_active(true)
 sg._tick(0.4)
 var right: MeshInstance3D=sg._pivot.get_node("GripSocket/RightHand")
 var left: MeshInstance3D=sg._pivot.get_node("Pump/PumpSocket/LeftHand")
 for entry: Array in [[right,false],[left,true]]:
  var hand: MeshInstance3D=entry[0]
  var is_left: bool=entry[1]
  var vertices: PackedVector3Array=hand.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  var grip := Transform3D.IDENTITY if is_left else Transform3D(Basis(Vector3.RIGHT,deg_to_rad(-20)),Vector3(0,-0.04,0.035))
  var half: Vector3=Vector3(0.029,0.025,0.085) if is_left else Vector3(0.018,0.055,0.025)
  var deep: int=0
  var contacts: int=0
  for vertex: Vector3 in vertices:
   var p: Vector3=grip.affine_inverse()*vertex
   if absf(p.x)<half.x-0.0005 and absf(p.y)<half.y-0.0005 and absf(p.z)<half.z-0.0005:deep+=1
   var radial: float=maxf(absf(p.x)/half.x,absf(p.y)/half.y if is_left else absf(p.z)/half.z)
   if radial>=1.0 and radial<1.2 and absf(p.z if is_left else p.y)<(half.z if is_left else half.y):contacts+=1
  check(deep==0,"%s glove has no vertices inside the handle" % ("left" if is_left else "right"))
  check(contacts>10,"%s glove stays close enough to grasp the handle" % ("left" if is_left else "right"))
  check(hand.mesh.get_surface_count()==3,"glove, black cuff and orange sleeve remain separate regions")
 for entry: Array in [[right,"right"],[left,"left"]]:
  var hand: MeshInstance3D=entry[0]
  var vertices: PackedVector3Array=hand.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  for part_name: String in ["Receiver","Stock"]:
   var part: MeshInstance3D=sg._pivot.get_node(part_name)
   var bounds: AABB=part.get_aabb().grow(-0.001)
   var inside: int=0
   for vertex: Vector3 in vertices:
    if bounds.has_point(part.to_local(hand.to_global(vertex))):inside+=1
   check(inside==0,"%s glove clears the solid %s" % [entry[1],part_name])
 var relative: Transform3D=sg._pump.global_transform.affine_inverse()*left.global_transform
 sg._cycle=0.38
 for i in 8:sg._animate(1.0/60.0)
 check(sg._pump.position.z> -0.34,"pump actually racks backward")
 check((sg._pump.global_transform.affine_inverse()*left.global_transform).is_equal_approx(relative),"support glove stays attached during pump travel")
 check(right.get_parent().get_parent()==sg._pivot,"trigger hand stays independent of the moving pump")
 sg._cycle=0.0
 sg.mag=2
 sg.reserve=4
 sg.reload()
 var worst: int=0
 for phase in [0.05,0.15,0.22,0.30,0.40]:
  sg._shell_t=phase
  sg._animate(1.0)
  var receiver: MeshInstance3D=sg._pivot.get_node("Receiver")
  var bounds: AABB=receiver.get_aabb().grow(-0.001)
  var vertices: PackedVector3Array=left.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
  var inside: int=0
  for vertex: Vector3 in vertices:
   if bounds.has_point(receiver.to_local(left.to_global(vertex))):inside+=1
  worst=maxi(worst,inside)
 check(worst==0,"loading glove clears the receiver throughout the reach")
 sg._shell_t=0.0
 sg._tick(0.46)
 check(sg.mag==3 and sg.reserve==3,"per-shell loading behavior remains intact")
 sg._draw_t=0.0
 sg._cycle=0.0
 sg.shoot()
 check(sg.mag==2 and not sg.is_reloading(),"firing still interrupts shell loading")
 sg.set_active(false)
 check(not sg.visible,"holster still hides the complete weapon")
 check(sg._pivot.find_children("*","CollisionObject3D",true,false).is_empty(),"held weapon introduces no world collision")
 var mat: ShaderMaterial=sg._pivot.get_node("Receiver").mesh.surface_get_material(0)
 check(mat.shader.code.contains("p.xyz*=0.1"),"gun uses the same depth scale as the gloves")
 main.free()
 for i in 3:await process_frame
 print("%d failure(s)" % failures)
 quit(failures)
