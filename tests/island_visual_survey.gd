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


func _capture(name: String, position: Vector3, target: Vector3, orthographic_size: float = 0) -> void:
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
	await _ground("lake_west", Vector2(455, 525), Vector3(550, 5, 525))
	await _ground("lake_east", Vector2(615, 525), Vector3(520, 5, 525))
	await _ground("lake_north", Vector2(535, 450), Vector3(535, 5, 540))
	await _ground("lake_south", Vector2(535, 600), Vector3(535, 5, 510))
	await _ground("coast_north", Vector2(450, 140), Vector3(450, 0, 70))
	await _ground("coast_northeast", Vector2(730, 280), Vector3(830, 0, 270))
	await _ground("coast_east", Vector2(820, 480), Vector3(920, 0, 480))
	await _ground("coast_southeast", Vector2(820, 700), Vector3(900, 0, 760))
	await _ground("coast_south", Vector2(500, 840), Vector3(500, 0, 940))
	await _ground("coast_southwest", Vector2(280, 780), Vector3(210, 0, 850))
	await _ground("coast_west", Vector2(160, 500), Vector3(60, 0, 500))
	await _ground("coast_northwest", Vector2(200, 200), Vector3(100, 0, 100))
	print("ISLAND SURVEY: %d rendered views saved to %s" % [captures, directory])
	world.queue_free()
	layer.queue_free()
	await process_frame
	quit()
