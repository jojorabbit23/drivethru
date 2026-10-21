extends SceneTree
var main: Node3D
func _initialize() -> void:
 create_timer(40).timeout.connect(func()->void:quit(1))
 run.call_deferred()
func snap(label: String) -> void:
 for i in 8:await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/delivery_"+label+".png"))
func run() -> void:
 Engine.max_fps=30
 main=load("res://main.tscn").instantiate();main.auto_spawn=false;root.add_child(main)
 var p: Node3D=main.player;p.set_physics_process(false);p.set_process_unhandled_input(false)
 for weapon: Node3D in p.weapons:weapon.hide();weapon.set_physics_process(false)
 Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 var garage: Node=main.shop.get_node("Garage");main.economy.cash=1000;garage.interact(p)
 for i in 22:await process_frame
 var d: Node3D=main.delivery
 p.camera.global_position=Vector3(3.7,1.65,6.3);p.camera.look_at(Vector3(5.7,1.55,6.4));p.camera.fov=76
 await snap("locked")
 d.interact(p)
 for i in 22:await process_frame
 d.next_orders.assign(["double_red","blue"]);var ticket: Node=d.spawn_customer();ticket.set_process(false)
 main.hatch.next_orders.assign(["brown","blue"]);var car: Node=main.hatch.spawn_customer();car.state="waiting";car.set_process(false)
 d.serving_tray.items[0]={"kind":"brown","quality":"perfect","age_seconds":10.0}
 d.serving_tray.items[1]={"kind":"blue","quality":"good","age_seconds":160.0}
 d.serving_tray.refresh();d.set_physics_process(false);d.serving_tray.set_physics_process(false)
 d.interact(p);main.get_node("ClarityHUD").refresh()
 main._hud.toast.text=""
 await snap("active")
 p.camera.global_position=Vector3(3.5,1.8,8.6);p.camera.look_at(Vector3(5.6,1.25,6.5));p.camera.fov=75
 await snap("garage")
 p.camera.global_position=Vector3(1.0,1.6,-2.8);p.camera.look_at(Vector3(1.55,1.25,-4.5));p.camera.fov=75
 await snap("kitchen_tickets")
 main.free();quit()
