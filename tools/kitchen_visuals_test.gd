extends SceneTree
var failures: int=0
func _initialize() -> void:run.call_deferred()
func check(ok: bool,message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok:failures+=1
func run() -> void:
 var props: Node3D=load("res://presentation/kitchen/visuals.gd").new()
 root.add_child(props)
 var grinder: Node3D=props.grinder
 var original: int=grinder.get_child_count()
 check(not grinder.play_deposit(0),"empty deposit does not animate")
 check(grinder.play_deposit(2),"valid deposit starts visual")
 grinder.set_process(false)
 check(not grinder.play_deposit(1),"overlapping animation requests are rejected")
 grinder.advance(0.8)
 check(grinder.pellets.any(func(piece: MeshInstance3D):return piece.visible),"mince falls into receiving tray")
 grinder.advance(1.2)
 check(not grinder.busy and not grinder.is_processing(),"effect finishes and stops processing")
 check(grinder.input_caps.all(func(piece: MeshInstance3D):return not piece.visible),"input mushrooms disappear into grinder")
 for i in 20:
  grinder.play_deposit(1)
  grinder.set_process(false)
  grinder.advance(2.0)
 check(grinder.get_child_count()==original,"repeated deposits reuse visual nodes")
 check(get_nodes_in_group("cold_burger_bin_visual").size()==1,"one bin visual is available for gameplay integration")
 props.free()
 print("%d failure(s)" % failures)
 quit(failures)
