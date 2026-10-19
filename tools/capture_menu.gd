extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
 root.size=Vector2i(1280,720)
 var menu: Control=load("res://ui/menu/menu.tscn").instantiate()
 root.add_child(menu)
 menu.video.stop()
 menu.video.stream=load("res://ui/menu/bread_loop.ogv")
 menu.video.loop=true
 menu.video.play()
 for i in 30:
  Engine.max_fps=30
  await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/previews/menu.png"))
 menu.free()
 quit()
