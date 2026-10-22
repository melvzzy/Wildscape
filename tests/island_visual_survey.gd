extends SceneTree
## Inspection captures only: visual quality is reviewed, not asserted by pixels.
## -- --survey=before (or after). Never writes terrain or scene resources.

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
	world = (load("res://scenes/island/island.tscn") as PackedScene).instantiate()
	root.add_child(world)
	current_scene = world
	terrain = world.get_node("Terrain3D")
	world.get_node("Menu").visible = false
	# Capture-only camera must keep native LOD updates running if the hidden
	# test window loses focus. Normal gameplay focus/pause behavior is unchanged.
	world.get_node("Menu").gameplay_mode = false
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
	if "--focused" in OS.get_cmdline_user_args():
		await _capture("00_entire_island", Vector3(512, 1100, 512), Vector3(512, 0, 512), 960)
		await _capture("west_foothills", Vector3(470, 115, 555), Vector3(310, 38, 360))
		await _capture("east_foothills", Vector3(550, 115, 650), Vector3(720, 35, 500))
		await _capture("south_transition", Vector3(450, 85, 880), Vector3(340, 24, 715))
		await _player_view("player_lake_shore", Vector2(500, 574), Vector3(538, 5, 488))
		await _player_view("player_northeast", Vector2(650, 260), Vector3(710, 40, 400))
		print("ISLAND SURVEY: %d focused rendered views saved to %s" % [captures, directory])
		world.queue_free()
		layer.queue_free()
		await process_frame
		quit()
		return
	await _capture("00_entire_island", Vector3(512, 1100, 512), Vector3(512, 0, 512), 960)
	await _capture("01_north", Vector3(500, 460, -270), Vector3(500, 18, 490))
	await _capture("02_east", Vector3(1270, 460, 500), Vector3(500, 18, 490))
	await _capture("03_south", Vector3(500, 460, 1280), Vector3(500, 18, 490))
	await _capture("04_west", Vector3(-270, 460, 500), Vector3(500, 18, 490))
	for z in 3:
		for x in 3:
			var center := Vector3(220 + x * 280, 380, 220 + z * 280)
			await _capture("region_%d_%d" % [x, z], center, Vector3(center.x, 0, center.z), 350)
	await _capture("west_foothills", Vector3(470, 115, 555), Vector3(310, 38, 360))
	await _capture("east_foothills", Vector3(550, 115, 650), Vector3(720, 35, 500))
	await _capture("north_upland", Vector3(540, 70, 410), Vector3(530, 16, 220))
	await _capture("south_plains", Vector3(420, 50, 790), Vector3(560, 10, 670))
	await _ground("lake_west", Vector2(444, 480), Vector3(538, 5, 488))
	await _ground("lake_east", Vector2(655, 480), Vector3(538, 5, 488))
	await _ground("lake_north", Vector2(535, 375), Vector3(538, 5, 488))
	await _ground("lake_south", Vector2(535, 580), Vector3(538, 5, 488))
	await _ground("coast_north", Vector2(450, 140), Vector3(450, 0, 70))
	await _ground("coast_northeast", Vector2(870, 250), Vector3(950, 0, 250))
	await _ground("coast_east", Vector2(916, 480), Vector3(1000, 0, 480))
	await _ground("coast_southeast", Vector2(860, 850), Vector3(950, 0, 900))
	await _ground("coast_south", Vector2(500, 930), Vector3(500, 0, 1000))
	await _ground("coast_southwest", Vector2(200, 845), Vector3(100, 0, 900))
	await _ground("coast_west", Vector2(220, 520), Vector3(120, 0, 520))
	await _ground("coast_northwest", Vector2(100, 300), Vector3(0, 0, 260))
	await _player_view("player_southwest", Vector2(330, 795), Vector3(280, 35, 650))
	await _player_view("player_southeast", Vector2(745, 800), Vector3(700, 40, 640))
	await _player_view("player_northeast", Vector2(650, 260), Vector3(710, 40, 400))
	await _player_view("player_west_bay", Vector2(235, 535), Vector3(160, 6, 480))
	await _player_view("player_lake_shore", Vector2(500, 574), Vector3(538, 5, 488))
	await _player_view("player_lake_islet", Vector2(538, 488), Vector3(600, 7, 490))
	print("ISLAND SURVEY: %d rendered views saved to %s" % [captures, directory])
	world.queue_free()
	layer.queue_free()
	await process_frame
	quit()
