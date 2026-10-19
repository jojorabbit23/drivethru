extends SceneTree
var failures: int=0
func check(ok: bool, message: String) -> void:
 print("PASS " if ok else "FAIL ",message)
 if not ok: failures+=1
func _initialize() -> void: run.call_deferred()
func run() -> void:
 var menu: Control=load("res://ui/menu/menu.tscn").instantiate()
 root.add_child(menu)
 check(menu.buttons.size()==6,"six menu actions")
 check(menu.buttons[1].disabled,"Continue disabled without save")
 check(menu.selected==0,"Start selected")
 menu.select(3)
 check(menu.selected==3,"selection changes")
 menu.select(1)
 check(menu.selected==3,"disabled entry skipped")
 for index in [2,3,4]:
  menu.activate(index)
  check(menu.panel.visible and menu.content.get_child_count()>1,"panel %d opens" % index)
 current_scene=menu
 menu.activate(0)
 await process_frame
 await process_frame
 check(current_scene!=null and current_scene.name=="Main","Start Cooking loads game scene")
 var player: Node=current_scene.get_node("Player")
 check(player.weapons.size()==3,"all three weapons loaded from menu")
 current_scene.free()
 print("%d failure(s)" % failures)
 quit(failures)
