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
	return 5.0 if x >= 232 and x <= 332 and z >= 228 and z <= 322 else 0.0


func _slope(image: Image, x: int, z: int) -> float:
	return Vector2(image.get_pixel(mini(x + 1, 511), z).r - image.get_pixel(maxi(x - 1, 0), z).r,
		image.get_pixel(x, mini(z + 1, 511)).r - image.get_pixel(x, maxi(z - 1, 0)).r).length() * 0.5


func _check_landscape(terrain: Terrain3D) -> void:
	var height: Image = terrain.data.get_region(Vector2i.ZERO).get_height_map()
	var dry := 0
	var gentle := 0
	var finite := true
	for z in range(1, 511):
		for x in range(1, 511):
			var h := height.get_pixel(x, z).r
			finite = finite and is_finite(h)
			if h > _water_level(x, z):
				dry += 1
				if _slope(height, x, z) < tan(deg_to_rad(20)):
					gentle += 1
	_check(height.get_size() == Vector2i(512, 512) and finite, "saved 512-square heightmap has no invalid heights")
	_check(dry > 100000 and gentle > 50000, "over 100000 square meters dry and 50000 below 20 degrees")
	# A conservative 4 m path grid tests continuous dry routes with <=32 degree
	# local gradients and edge grades. The actual player route is checked below.
	var allowed := PackedByteArray()
	var visited := PackedByteArray()
	allowed.resize(128 * 128)
	visited.resize(128 * 128)
	for z in 128:
		for x in 128:
			if height.get_pixel(x * 4, z * 4).r > _water_level(x * 4, z * 4) + 0.2 and _slope(height, x * 4, z * 4) < tan(deg_to_rad(32)):
				allowed[z * 128 + x] = 1
	var queue: Array[int] = [91 * 128 + 63]
	visited[queue[0]] = 1
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		var p := Vector2i(current % 128, current / 128)
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = p + offset
			if next.x < 1 or next.y < 1 or next.x > 126 or next.y > 126:
				continue
			var index := next.y * 128 + next.x
			if allowed[index] and not visited[index] and absf(height.get_pixel(next.x * 4, next.y * 4).r - height.get_pixel(p.x * 4, p.y * 4).r) < 4 * tan(deg_to_rad(32)):
				visited[index] = 1
				queue.append(index)
	var connected := true
	for point in [Vector2i(256, 352), Vector2i(236, 276), Vector2i(280, 228), Vector2i(244, 216), Vector2i(268, 160), Vector2i(312, 336), Vector2i(252, 420), Vector2i(80, 300), Vector2i(444, 268), Vector2i(256, 80)]:
		connected = connected and visited[(point.y / 4) * 128 + point.x / 4] == 1
	_check(connected and queue.size() * 16 > 65000, "spawn valley lake banks both mountain approaches and four coasts share comfortable dry routes")
	print("MEASURED ISLAND: dry=%d m2, under20deg=%d m2, connected32deg_grid=%d m2, heights=%s" % [dry, gentle, queue.size() * 16, terrain.data.get_height_range()])


func _run() -> void:
	var world := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	var terrain: Terrain3D = world.get_node("Terrain3D")
	var player: CharacterBody3D = world.get_node("Player")
	var menu: CanvasLayer = world.get_node("Menu")
	await _frames(60)
	_check(terrain.region_size == 512 and terrain.vertex_spacing == 1.0 and terrain.data.get_region_count() == 1, "one native 512 m editable region loaded")
	_check(terrain.assets.get_texture_count() == 3, "grass earth stone assets loaded")
	_check(player.is_on_floor() and player.position.y > 3.0, "safe dry spawn settles on terrain")
	_check(player.inventory.get_capacity() == 36 and player.inventory.get_stack(0) == null, "existing empty player inventory retained")
	_check_landscape(terrain)
	var collision_matches := true
	for point in [Vector3(252, 0, 367), Vector3(244, 0, 216), Vector3(157, 0, 166), Vector3(349, 0, 266), Vector3(256, 0, 352), Vector3(236, 0, 276), Vector3(252, 0, 420), Vector3(285, 0, 273)]:
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
	_check(terrain.data.get_height(Vector3(157, 0, 166)) > 65 and terrain.data.get_height(Vector3(349, 0, 266)) > 45 and terrain.data.get_height(Vector3(256, 0, 352)) < 15, "two distinctive massifs flank broad lower land")
	_check(terrain.data.get_height(Vector3(10, 0, 10)) < -5 and terrain.data.get_height(Vector3(500, 0, 500)) < -5, "terrain borders submerged below sea")
	_check(terrain.data.get_height(Vector3(282, 0, 260)) < 5 and terrain.data.get_height(Vector3(285, 0, 273)) > 5 and world.get_node("Lake").position.y == 5, "off-center lake has submerged bed and dry central islet")
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
	player.reset_to_spawn()
	await _frames(25)
	Input.action_press("move_back")
	await _frames(720)
	Input.action_release("move_back")
	await _frames(20)
	_check(player.position.z > 419 and player.is_on_floor() and player.position.y > 0, "actual player reaches southern beach over a gentle coastal route")
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
	var original := terrain.data.get_height(Vector3(256, 0, 352))
	var scratch := "res://.godot/island_roundtrip"
	DirAccess.make_dir_recursive_absolute(scratch)
	terrain.data.set_height(Vector3(256, 0, 352), original + 0.25)
	terrain.data.set_region_modified(Vector2i.ZERO, true)
	terrain.data.save_directory(scratch)
	terrain.data.load_directory(scratch)
	_check(is_equal_approx(terrain.data.get_height(Vector3(256, 0, 352)), original + 0.25), "native terrain edit save reload preserves height")
	terrain.data.load_directory("res://scenes/island/data")
	_check(is_equal_approx(terrain.data.get_height(Vector3(256, 0, 352)), original), "original island data reloads unchanged")
	if "--capture-island" in OS.get_cmdline_user_args():
		player.reset_to_spawn()
		player.set_first_person(false)
		await _frames(40)
		await _capture("ground-tps")
		player.set_first_person(true)
		await _capture("ground-fps")
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(570, 370, 650)
		camera.look_at(Vector3(256, 8, 250))
		camera.fov = 50
		camera.current = true
		terrain.set_camera(camera)
		await _capture("overview")
		camera.position = Vector3(256, 600, 256)
		camera.look_at(Vector3(256, 0, 256), Vector3.FORWARD)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 490
		await _capture("top")
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.position = Vector3(-200, 250, 300)
		camera.look_at(Vector3(256, 20, 245))
		await _capture("west")
		camera.position = Vector3(700, 230, 250)
		camera.look_at(Vector3(256, 20, 250))
		await _capture("east")
		camera.position = Vector3(238, terrain.data.get_height(Vector3(238, 0, 301)) + 1.7, 301)
		camera.look_at(Vector3(282, 5, 275))
		await _capture("lake")
		camera.position = Vector3(252, terrain.data.get_height(Vector3(252, 0, 418)) + 1.7, 418)
		camera.look_at(Vector3(260, 0, 470))
		await _capture("beach")
	world.queue_free()
	await process_frame
	print("ISLAND RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
