extends SceneTree
## Inspection captures only: visual quality is reviewed, not asserted by pixels.
## Six focused compact-island views. Never writes terrain or scene resources.

var world: Node3D
var terrain: Terrain3D
var camera: Camera3D
var caption: Label
var directory := "res://.godot/island_survey/after"
var captures := 0
var atlas: Image


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--survey="):
			directory = "res://.godot/island_survey/" + argument.trim_prefix("--survey=").validate_filename()
	_run.call_deferred()


func _capture(name: String, position: Vector3, target: Vector3, orthographic_size: float = 0, live_player: bool = false) -> void:
	if not live_player:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL if orthographic_size > 0 else Camera3D.PROJECTION_PERSPECTIVE
		camera.size = maxf(orthographic_size, 1)
		camera.position = position
		camera.look_at(target, Vector3.FORWARD if orthographic_size > 0 else Vector3.UP)
	caption.text = name
	for frame in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	if picture.save_png(directory + "/" + name + ".png") != OK:
		push_error("Survey capture failed: " + name)
		quit(1)
		return
	picture.convert(Image.FORMAT_RGBA8)
	picture.resize(640, 360, Image.INTERPOLATE_LANCZOS)
	if captures % 16 == 0:
		atlas = Image.create_empty(2560, 1440, false, Image.FORMAT_RGBA8)
		atlas.fill(Color(0.04, 0.04, 0.04))
	var cell := captures % 16
	atlas.blit_rect(picture, Rect2i(0, 0, 640, 360), Vector2i((cell % 4) * 640, (cell / 4) * 360))
	captures += 1
	atlas.save_png(directory + "/sheet_%02d.png" % ((captures - 1) / 16))
	print("SURVEY: ", name)


func _ground(name: String, point: Vector2, target: Vector3) -> void:
	var position := Vector3(point.x, 0, point.y)
	position.y = terrain.data.get_height(position) + 1.7
	await _capture(name, position, target)


func _player_view(name: String, point: Vector2, target: Vector3) -> void:
	var player: CharacterBody3D = world.get_node("Player")
	player.process_mode = Node.PROCESS_MODE_INHERIT
	player.visible = true
	player.position = Vector3(point.x, terrain.data.get_height(Vector3(point.x, 0, point.y)) + 0.12, point.y)
	player.velocity = Vector3.ZERO
	player.set_first_person(true)
	var direction := target - player.position - Vector3.UP * 1.62
	player.camera_yaw.rotation.y = atan2(-direction.x, -direction.z)
	player.camera_pitch.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())
	player.reset_physics_interpolation()
	player.camera.make_current()
	terrain.set_camera(player.camera)
	for frame in 35:
		await physics_frame
	if not player.is_on_floor():
		push_error("Survey player is not grounded: " + name)
		quit(1)
		return
	await _capture(name, Vector3.ZERO, Vector3.ZERO, 0, true)
	print("GROUNDED PLAYER: ", name, " at ", player.position)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player.visible = false
	camera.make_current()
	terrain.set_camera(camera)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Visual survey requires graphical rendering.")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(directory)
	var main_menu := (load("res://scenes/menus/main_menu.tscn") as PackedScene).instantiate()
	root.add_child(main_menu)
	current_scene = main_menu
	main_menu.get_node("Menu")._on_primary_pressed()
	await scene_changed
	world = current_scene
	if world.scene_file_path != "res://scenes/island/island.tscn":
		push_error("Main menu Play did not load the island")
		quit(1)
		return
	print("PLAY TRANSITION: main menu -> ", world.scene_file_path)
	terrain = world.get_node("Terrain3D")
	world.get_node("Menu").visible = false
	# Capture-only camera must keep native LOD updates running if the hidden
	# test window loses focus. Normal gameplay focus/pause behavior is unchanged.
	world.get_node("Menu").gameplay_mode = false
	paused = false
	world.get_node("Player").process_mode = Node.PROCESS_MODE_DISABLED
	world.get_node("Player").visible = false
	camera = Camera3D.new()
	world.add_child(camera)
	camera.far = 3000
	camera.fov = 55
	camera.current = true
	terrain.set_camera(camera)
	var layer := CanvasLayer.new()
	root.add_child(layer)
	caption = Label.new()
	layer.add_child(caption)
	caption.position = Vector2(16, 12)
	caption.add_theme_font_size_override("font_size", 28)
	caption.add_theme_color_override("font_outline_color", Color.BLACK)
	caption.add_theme_constant_override("outline_size", 8)
	await _capture("00_entire_island", Vector3(384, 850, 384), Vector3(384, 0, 384), 800)
	await _capture("west_foothills", Vector3(340, 88, 420), Vector3(220, 28, 275))
	await _capture("east_foothills", Vector3(415, 88, 495), Vector3(548, 26, 386))
	await _capture("south_coast", Vector3(410, 65, 755), Vector3(365, 2, 675))
	# Inspection only: reveal the real seabed once, then restore visual water.
	world.get_node("Sea").visible = false
	await _capture("coastal_shelf", Vector3(385, 60, 765), Vector3(375, -10, 705))
	world.get_node("Sea").visible = true
	await _player_view("player_lake_shore", Vector2(380, 438), Vector3(407, 5, 361))
	print("ISLAND SURVEY: %d focused compact-island views saved to %s" % [captures, directory])
	world.queue_free()
	layer.queue_free()
	await process_frame
	quit()
