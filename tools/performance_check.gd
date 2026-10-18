# Bounded rendered check: 30 FPS, three short stages, then exits.
# godot --path . --rendering-method gl_compatibility --script res://tools/performance_check.gd
extends SceneTree
var main: Node3D
var knife: Node
var viewport_rid: RID
var results: Array[Dictionary] = []
func _initialize() -> void:
	Engine.max_fps = 30
	create_timer(15.0).timeout.connect(_timeout)
	run.call_deferred()
func settle(frames: int) -> void:
	for i in frames:
		Engine.max_fps = 30
		await process_frame
func stats(samples: Array[float]) -> Dictionary:
	samples.sort()
	var total := 0.0
	for sample in samples: total += sample
	return {"mean":total / samples.size(),"p95":samples[mini(samples.size()-1,int(samples.size()*0.95))],"max":samples[-1]}
func measure(label: String, combat: bool = false) -> void:
	var cpu: Array[float] = []
	var gpu: Array[float] = []
	var physics: Array[float] = []
	var frames: Array[float] = []
	var draws := 0.0
	var primitives := 0.0
	var last: int = Time.get_ticks_usec()
	for i in 75:
		Engine.max_fps = 30
		if combat and i % 30 == 0:
			knife.call("request","slash" if i % 60 == 0 else "stab")
		await process_frame
		await RenderingServer.frame_post_draw
		var now: int = Time.get_ticks_usec()
		frames.append(float(now-last)/1000.0)
		last = now
		cpu.append(RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid))
		gpu.append(RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid))
		physics.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000.0)
		draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		primitives += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	var result := {"stage":label,"cpu_render_ms":stats(cpu),"gpu_render_ms":stats(gpu),"physics_ms":stats(physics),"frame_ms":stats(frames),"draw_calls":draws/75.0,"primitives":primitives/75.0,"video_mb":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)/1048576.0,"static_mb":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0}
	results.append(result)
	print("PROFILE ",JSON.stringify(result))
func run() -> void:
	root.size = Vector2i(1280,720)
	viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(viewport_rid,true)
	main = load("res://main.tscn").instantiate()
	main.set("auto_spawn",false)
	root.add_child(main)
	var player: CharacterBody3D = main.get_node("Player")
	player.set_process_unhandled_input(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	player.position = Vector3(1.4,0.05,-1.4)
	player.rotation.y = -PI/2.0
	knife = player.get_node("Head/Camera3D/Knife")
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(Engine.max_fps == 15, "background cap")
	main.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert(Engine.max_fps == 60, "focused cap")
	print("PASS focus caps: 60 focused / 15 background")
	await settle(30)
	await measure("pistol / shop")
	player.call("switch_weapon",1)
	await settle(20)
	await measure("knife / idle and attacks",true)
	var preview: String = OS.get_environment("FPS_PROFILE_PREVIEW")
	if not preview.is_empty():
		root.get_texture().get_image().save_png(preview)
	for i in 12:
		main.call("spawn_zombie")
	var ooze: Node = load("res://core/ooze.gd").get_fx(main)
	for i in 4:
		ooze.call("spray",Vector3(3.0,1.3,-2.0),Vector3.RIGHT,Vector3.LEFT,2.0,true)
	await settle(10)
	await measure("12 zombies / ooze stress",true)
	var destination: String = OS.get_environment("FPS_PROFILE_OUTPUT")
	if not destination.is_empty():
		var file := FileAccess.open(destination,FileAccess.WRITE)
		file.store_string(JSON.stringify(results,"\t"))
	main.queue_free()
	var fx: Node = root.get_node_or_null("OozeFX")
	if fx: fx.queue_free()
	await settle(3)
	quit()

func _timeout() -> void:
	push_error("Performance check exceeded its 15-second time budget")
	quit(1)
