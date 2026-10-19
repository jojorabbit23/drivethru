extends SceneTree
var main: Node3D
var player: CharacterBody3D
func _initialize() -> void:run.call_deferred()
func look(at: Vector3) -> void:
	var direction: Vector3=at-player.camera.global_position
	player.rotation.y=atan2(-direction.x,-direction.z)
	player.head.rotation.x=atan2(direction.y,Vector2(direction.x,direction.z).length())
	for i in 4:await physics_frame
	player._update_focus()
func snap(label: String) -> void:
	for i in 6:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/"+label+".png"))
func run() -> void:
	Engine.max_fps=30
	root.size=Vector2i(1280,720)
	main=load("res://main.tscn").instantiate()
	main.auto_spawn=false
	root.add_child(main)
	player=main.player
	player.set_physics_process(false)
	player.set_process_unhandled_input(false)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	player.unlock_burger_slots(9)
	player.global_position=Vector3(-3,0.05,-3.10)
	for weapon: Node3D in player.weapons:weapon.hide();weapon.set_physics_process(false)
	for i in 4:
		player.add_burger({"kind":["brown","blue","red","brown"][i],"quality":"perfect","hot_remaining":0.0 if i==1 else 140.0,"patties":["brown"]})
		assert(main.serving_tray.deposit(player,i))
	for kind in ["red","blue","brown"]:player.add_burger({"kind":kind,"quality":"perfect"})
	player.selected_burger=0
	player._sync_burger()
	for i in 4:
		var slot: Node3D=main.serving_tray.get_node("BoxSlot%d" % (i+1))
		await look(slot.global_position+Vector3(0,0.07,0))
		print("RAY slot ",i+1," focus=",player.focus.name if player.focus else "none", " target=",slot.global_position)
		assert(player.focus==slot,"each individual box can be targeted with the actual interaction ray")
	await snap("serving_inventory_tray")
	var before: int=player.burgers.size()
	var cold_slot: Node3D=main.serving_tray.get_node("BoxSlot2")
	await look(cold_slot.global_position+Vector3(0,0.07,0))
	player.use_focus()
	assert(player.burgers.size()==before+1 and player.BurgerItems.cold(player.held_burger),"E retrieves a cold box")
	await look(main.burger_bin.global_position+Vector3(0,0.6,0))
	assert(player.focus==main.burger_bin,"bin is reachable without crossing counter")
	await snap("serving_inventory_bin")
	player.use_focus()
	assert(player.burgers.size()==before and main.burger_bin.discarded==1,"E discards selected cold burger")
	main.economy.cash=1000
	player.focus=main.terminal
	main.terminal.page="weapons"
	player.open_menu(main.terminal,main.terminal.options(player))
	await snap("serving_inventory_shop")
	main.free()
	for i in 3:await process_frame
	print("PASS native tray, pickup, bin and shop interactions")
	quit()
