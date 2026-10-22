extends SceneTree
## Native terrain, exploration route, persistence and island UI integration.

const SCENE := "res://scenes/island/island.tscn"
var checks := 0
var failures := 0
var elapsed := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 50.0:
		push_error("FAIL: island test timeout")
		quit(1)
	return false


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _capture(name: String) -> void:
	await _frames(8)
	await RenderingServer.frame_post_draw
	_check(root.get_texture().get_image().save_png("res://.godot/island-" + name + ".png") == OK, "capture " + name)


func _water_level(x: int, z: int) -> float:
	return 5.0 if x >= 455 and x <= 615 and z >= 450 and z <= 600 else 0.0


func _slope(image: Image, x: int, z: int) -> float:
	return Vector2(image.get_pixel(mini(x + 1, 1023), z).r - image.get_pixel(maxi(x - 1, 0), z).r,
		image.get_pixel(x, mini(z + 1, 1023)).r - image.get_pixel(x, maxi(z - 1, 0)).r).length() * 0.5


func _check_landscape(terrain: Terrain3D) -> void:
	var height: Image = terrain.data.get_region(Vector2i.ZERO).get_height_map()
	var dry := 0
	var gentle := 0
	var finite := true
	var max_step := 0.0
	var sea_samples := 0
	var graded_shore := 0
	var no_holes := true
	for z in range(1, 1023):
		for x in range(1, 1023):
			var h := height.get_pixel(x, z).r
			finite = finite and is_finite(h)
			max_step = maxf(max_step, absf(h - height.get_pixel(x + 1, z).r))
			max_step = maxf(max_step, absf(h - height.get_pixel(x, z + 1).r))
			no_holes = no_holes and not terrain.data.get_control_hole(Vector3(x, 0, z))
			if absf(h) < 0.2:
				sea_samples += 1
				if _slope(height, x, z) > 0.05:
					graded_shore += 1
			if h > _water_level(x, z):
				dry += 1
				if _slope(height, x, z) < tan(deg_to_rad(20)):
					gentle += 1
	_check(height.get_size() == Vector2i(1024, 1024) and finite, "saved 1024-square heightmap has no invalid heights")
	_check(dry > 400000 and gentle > 250000, "over 400000 square meters dry and 250000 below 20 degrees")
	_check(no_holes and max_step < 2.5, "entire region has no painted holes or isolated height jumps above 2.5 m per cell")
	_check(sea_samples > 1000 and graded_shore > sea_samples * 0.99, "sea-level shoreline has a positive grade instead of near-coplanar water strips")
	var lake_edges_buried := true
	for x in range(455, 616):
		lake_edges_buried = lake_edges_buried and height.get_pixel(x, 450).r > 5.25 and height.get_pixel(x, 600).r > 5.25
	for z in range(450, 601):
		lake_edges_buried = lake_edges_buried and height.get_pixel(455, z).r > 5.25 and height.get_pixel(615, z).r > 5.25
	_check(lake_edges_buried, "all four lake-plane edges remain buried beneath the native shore")
	print("GEOMETRY QUALITY: max adjacent step=", max_step, " m, graded sea samples=", graded_shore, "/", sea_samples)
	# A conservative 4 m path grid tests continuous dry routes with <=32 degree
	# local gradients and edge grades. The actual player route is checked below.
	var allowed := PackedByteArray()
	var visited := PackedByteArray()
	allowed.resize(256 * 256)
	visited.resize(256 * 256)
	for z in 256:
		for x in 256:
			if height.get_pixel(x * 4, z * 4).r > _water_level(x * 4, z * 4) + 0.2 and _slope(height, x * 4, z * 4) < tan(deg_to_rad(32)):
				allowed[z * 256 + x] = 1
	var queue: Array[int] = [162 * 256 + 125]
	visited[queue[0]] = 1
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		var p := Vector2i(current % 256, current / 256)
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = p + offset
			if next.x < 1 or next.y < 1 or next.x > 254 or next.y > 254:
				continue
			var index := next.y * 256 + next.x
			if allowed[index] and not visited[index] and absf(height.get_pixel(next.x * 4, next.y * 4).r - height.get_pixel(p.x * 4, p.y * 4).r) < 4 * tan(deg_to_rad(32)):
				visited[index] = 1
				queue.append(index)
	var connected := true
	for point in [Vector2i(500, 700), Vector2i(456, 520), Vector2i(536, 444), Vector2i(448, 392), Vector2i(560, 340), Vector2i(600, 640), Vector2i(500, 852), Vector2i(148, 500), Vector2i(832, 480), Vector2i(452, 104)]:
		if visited[(point.y / 4) * 256 + point.x / 4] != 1:
			print("UNREACHABLE LANDMARK: ", point, " height=", height.get_pixelv(point).r, " slope=", rad_to_deg(atan(_slope(height, point.x, point.y))))
		connected = connected and visited[(point.y / 4) * 256 + point.x / 4] == 1
	_check(connected and queue.size() * 16 > 280000, "spawn valley lake banks both mountain approaches and four coasts share comfortable dry routes")
	print("MEASURED ISLAND: dry=%d m2, under20deg=%d m2, connected32deg_grid=%d m2, heights=%s" % [dry, gentle, queue.size() * 16, terrain.data.get_height_range()])


func _run() -> void:
	var world := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	var terrain: Terrain3D = world.get_node("Terrain3D")
	var player: CharacterBody3D = world.get_node("Player")
	var menu: CanvasLayer = world.get_node("Menu")
	await _frames(60)
	_check(terrain.region_size == 1024 and terrain.vertex_spacing == 1.0 and terrain.data.get_region_count() == 1, "one native 1024 m editable region loaded")
	_check(terrain.assets.get_texture_count() == 3, "grass earth stone assets loaded")
	_check(player.camera.far >= 1500, "island camera retains distant mountain silhouettes in FPS and TPS")
	_check(player.is_on_floor() and player.position.y > 3.0, "safe dry spawn settles on terrain")
	_check(player.inventory.get_capacity() == 36 and player.inventory.get_stack(0) == null, "existing empty player inventory retained")
	_check_landscape(terrain)
	var collision_matches := true
	for point in [Vector3(500, 0, 650), Vector3(448, 0, 392), Vector3(304, 0, 326), Vector3(705, 0, 480), Vector3(500, 0, 700), Vector3(456, 0, 520), Vector3(500, 0, 852), Vector3(538, 0, 524), Vector3(452, 0, 104), Vector3(730, 0, 280), Vector3(265, 0, 780)]:
		# Native dynamic collision follows the active camera; test each position
		# inside its generated radius instead of assuming a world-wide collider.
		player.position = point + Vector3.UP * (terrain.data.get_height(point) + 2.0)
		player.velocity = Vector3.ZERO
		await _frames(30)
		var expected_height := terrain.data.get_height(point)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP * (expected_height + 20), point + Vector3.UP * (expected_height - 10), 1))
		collision_matches = collision_matches and not hit.is_empty() and absf(hit.position.y - terrain.data.get_height(point)) < 0.15
	player.reset_to_spawn()
	await _frames(40)
	_check(collision_matches, "native collision matches spawn valley both massifs lake shore islet and beach")
	_check(terrain.data.get_height(Vector3(304, 0, 326)) > 65 and terrain.data.get_height(Vector3(705, 0, 480)) > 45 and terrain.data.get_height(Vector3(500, 0, 700)) < 15, "two distinctive massifs flank broad lower land")
	_check(terrain.data.get_height(Vector3(10, 0, 10)) < -5 and terrain.data.get_height(Vector3(1010, 0, 1010)) < -5, "terrain borders submerged below sea")
	_check(terrain.data.get_height(Vector3(514, 0, 516)) < 5 and terrain.data.get_height(Vector3(538, 0, 524)) > 5 and world.get_node("Lake").position.y == 5, "off-center lake has submerged bed and dry central islet")
	var start := player.position
	player.set_mouse_captured(true)
	Input.action_press("move_forward")
	await _frames(720)
	Input.action_release("move_forward")
	await _frames(20)
	_check(start.z - player.position.z > 50 and player.is_on_floor() and player.position.y > 0, "twelve second exploration walk reaches central valley on dry ground")
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	await _frames(95)
	_check(player.is_on_floor(), "jump lands on island terrain")
	# Start the physical beach walk on the southern coastal approach.
	var approach := Vector3(500, 0, 800)
	player.position = approach + Vector3.UP * (terrain.data.get_height(approach) + 0.1)
	player.velocity = Vector3.ZERO
	await _frames(25)
	Input.action_press("move_back")
	await _frames(720)
	Input.action_release("move_back")
	await _frames(20)
	_check(player.position.z > 852 and player.is_on_floor() and player.position.y > 0, "actual player reaches southern beach over a gentle coastal route")
	menu.set_inventory_open(true)
	menu.set_character_open(true)
	var frozen := player.position
	await _frames(10)
	_check(paused and not player.controls_active and player.position == frozen and menu.inventory_view.inventory_panel.visible and menu.inventory_view.character_panel.visible, "both inventory windows pause island and player")
	menu.set_inventory_open(false)
	_check(paused, "character window keeps island paused")
	menu.set_character_open(false)
	await _frames(4)
	_check(not paused and player.controls_active, "closing both windows resumes island")
	# Native edit/save/reload uses scratch copies only, preserving hand edits.
	var original := terrain.data.get_height(Vector3(500, 0, 700))
	var scratch := "res://.godot/island_roundtrip"
	DirAccess.make_dir_recursive_absolute(scratch)
	terrain.data.set_height(Vector3(500, 0, 700), original + 0.25)
	terrain.data.set_region_modified(Vector2i.ZERO, true)
	terrain.data.save_directory(scratch)
	terrain.data.load_directory(scratch)
	_check(is_equal_approx(terrain.data.get_height(Vector3(500, 0, 700)), original + 0.25), "native terrain edit save reload preserves height")
	terrain.data.load_directory("res://scenes/island/data")
	_check(is_equal_approx(terrain.data.get_height(Vector3(500, 0, 700)), original), "original island data reloads unchanged")
	if "--capture-island" in OS.get_cmdline_user_args():
		player.reset_to_spawn()
		player.set_first_person(false)
		await _frames(40)
		await _capture("ground-tps")
		player.set_first_person(true)
		await _capture("ground-fps")
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(1120, 650, 1200)
		camera.look_at(Vector3(500, 15, 490))
		camera.fov = 50
		camera.current = true
		terrain.set_camera(camera)
		await _capture("overview")
		camera.position = Vector3(512, 1100, 512)
		camera.look_at(Vector3(512, 0, 512), Vector3.FORWARD)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 940
		await _capture("top")
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.position = Vector3(-250, 430, 550)
		camera.look_at(Vector3(500, 25, 490))
		await _capture("west")
		camera.position = Vector3(1250, 430, 520)
		camera.look_at(Vector3(500, 25, 490))
		await _capture("east")
		camera.position = Vector3(469, terrain.data.get_height(Vector3(469, 0, 563)) + 1.7, 563)
		camera.look_at(Vector3(538, 5, 524))
		await _capture("lake")
		camera.position = Vector3(500, terrain.data.get_height(Vector3(500, 0, 852)) + 1.7, 852)
		camera.look_at(Vector3(510, 0, 940))
		await _capture("beach")
	world.queue_free()
	await process_frame
	print("ISLAND RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
