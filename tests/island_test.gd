extends SceneTree
## Compact native terrain: seams, shore profiles, collision, routes and persistence.

const SCENE := "res://scenes/island/island.tscn"
const SIZE := 768
var checks := 0
var failures := 0
var elapsed := 0.0


func _initialize() -> void:
	if DisplayServer.get_name() != "headless":
		root.focus_exited.connect(func() -> void: print("TEST WINDOW: focus lost; native menu may pause the graphical run"))
	_run.call_deferred()


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 50:
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


func _water_level(x: int, z: int) -> float:
	return 5.0 if x >= 309 and x <= 519 and z >= 257 and z <= 447 else 0.0


func _slope(image: Image, x: int, z: int) -> float:
	return Vector2(image.get_pixel(mini(x + 1, SIZE - 1), z).r - image.get_pixel(maxi(x - 1, 0), z).r, image.get_pixel(x, mini(z + 1, SIZE - 1)).r - image.get_pixel(x, maxi(z - 1, 0)).r).length() * 0.5


func _map(terrain: Terrain3D) -> Image:
	var result := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RF)
	for z in 3:
		for x in 3:
			var region: Terrain3DRegion = terrain.data.get_region(Vector2i(x, z))
			_check(region != null and region.get_height_map().get_size() == Vector2i(256, 256), "native region (%d,%d) has a 256-square saved map" % [x, z])
			if region != null:
				result.blit_rect(region.get_height_map(), Rect2i(0, 0, 256, 256), Vector2i(x, z) * 256)
	return result


func _landscape(terrain: Terrain3D, height: Image) -> void:
	var finite := true
	var no_holes := true
	var dry := 0
	var gentle := 0
	var southern := 0
	var shelf := 0
	var deep := 0
	var max_step := 0.0
	var shoreline := 0
	var graded := 0
	for z in range(1, SIZE - 1):
		for x in range(1, SIZE - 1):
			var h := height.get_pixel(x, z).r
			finite = finite and is_finite(h)
			no_holes = no_holes and not terrain.data.get_control_hole(Vector3(x, 0, z))
			max_step = maxf(max_step, maxf(absf(h - height.get_pixel(x + 1, z).r), absf(h - height.get_pixel(x, z + 1).r)))
			if h < -1 and h > -8:
				shelf += 1
			if h < -15:
				deep += 1
			if absf(h) < 0.2:
				shoreline += 1
				graded += int(_slope(height, x, z) > 0.05)
			if h > _water_level(x, z):
				dry += 1
				if _slope(height, x, z) < tan(deg_to_rad(20)):
					gentle += 1
					if z >= 526 and z <= 685 and h > 20:
						southern += 1
	_check(finite and no_holes and max_step < 2.5, "all nine regions have finite heights, no painted holes and no adjacent jumps above 2.5 m")
	# Area limits follow the 768²/1024² reduction, rounded upward. Grade,
	# height-step, collision, walking and jump tolerances are not relaxed.
	_check(dry > 310000 and gentle > 175000, "compact world retains over 310000 m2 dry and 175000 m2 below 20 degrees")
	_check(southern > 17000, "southern uplands retain over 17000 m2 above 20 m and below 20 degrees")
	_check(shelf > 20000 and deep > 10000, "actual submerged shelves descend into substantial deeper seabed")
	_check(shoreline > 750 and graded > shoreline * 0.99, "sea intersections retain non-coplanar shoreline grades")
	var submerged := true
	for edge in SIZE:
		submerged = submerged and height.get_pixel(edge, 0).r < -5 and height.get_pixel(edge, SIZE - 1).r < -5 and height.get_pixel(0, edge).r < -5 and height.get_pixel(SIZE - 1, edge).r < -5
	_check(submerged, "all four finite outer boundaries stay submerged below -5 m")
	var buried := true
	for x in range(309, 520):
		buried = buried and height.get_pixel(x, 257).r > 5.25 and height.get_pixel(x, 447).r > 5.25
	for z in range(257, 448):
		buried = buried and height.get_pixel(309, z).r > 5.25 and height.get_pixel(519, z).r > 5.25
	_check(buried, "all lake-plane edges are hidden beneath the actual basin banks")
	var seam_matches := true
	var seam_curvature := 0.0
	for seam in [256, 512]:
		for p in range(1, SIZE - 1):
			for point in [Vector2i(seam, p), Vector2i(p, seam)]:
				seam_matches = seam_matches and absf(terrain.data.get_height(Vector3(point.x, 0, point.y)) - height.get_pixelv(point).r) < 0.001
			seam_curvature = maxf(seam_curvature, absf(height.get_pixel(seam + 1, p).r - 2 * height.get_pixel(seam, p).r + height.get_pixel(seam - 1, p).r))
			seam_curvature = maxf(seam_curvature, absf(height.get_pixel(p, seam + 1).r - 2 * height.get_pixel(p, seam).r + height.get_pixel(p, seam - 1).r))
	_check(seam_matches and seam_curvature < 0.9, "native height queries and smooth slope changes agree across all region joins")
	var allowed := PackedByteArray()
	var visited := PackedByteArray()
	allowed.resize(192 * 192)
	visited.resize(192 * 192)
	for z in 192:
		for x in 192:
			if height.get_pixel(x * 4, z * 4).r > _water_level(x * 4, z * 4) + 0.2 and _slope(height, x * 4, z * 4) < tan(deg_to_rad(32)):
				allowed[z * 192 + x] = 1
	var queue: Array[int] = [123 * 192 + 94]
	visited[queue[0]] = 1
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		var p := Vector2i(current % 192, current / 192)
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = p + offset
			if next.x < 1 or next.y < 1 or next.x > 190 or next.y > 190:
				continue
			var index := next.y * 192 + next.x
			if allowed[index] and not visited[index] and absf(height.get_pixel(next.x * 4, next.y * 4).r - height.get_pixel(p.x * 4, p.y * 4).r) < 4 * tan(deg_to_rad(32)):
				visited[index] = 1
				queue.append(index)
	var connected := true
	# Eastern landmark is the dry approach ten meters inland, not the retained
	# steep headland face. That face receives its own physical collision sample.
	for point in [Vector2i(373, 526), Vector2i(323, 354), Vector2i(405, 262), Vector2i(327, 245), Vector2i(504, 354), Vector2i(409, 446), Vector2i(426, 242), Vector2i(461, 484), Vector2i(373, 706), Vector2i(158, 388), Vector2i(680, 352), Vector2i(330, 74), Vector2i(228, 650), Vector2i(585, 634), Vector2i(503, 185)]:
		if not visited[(point.y / 4) * 192 + point.x / 4]:
			print("UNREACHABLE LANDMARK: ", point, " h=", height.get_pixelv(point).r, " slope=", rad_to_deg(atan(_slope(height, point.x, point.y))))
		connected = connected and visited[(point.y / 4) * 192 + point.x / 4] == 1
	_check(connected and queue.size() * 16 > 255000, "valley lake banks mountain approaches uplands and four coasts share dry routes below 32 degrees")
	var lake_area := 0
	var islet_area := 0
	var islet_flat := 0
	for z in range(257, 448):
		for x in range(309, 520):
			if height.get_pixel(x, z).r < 5:
				lake_area += 1
			elif x > 380 and x < 440 and z > 335 and z < 390:
				islet_area += 1
				islet_flat += int(_slope(height, x, z) < tan(deg_to_rad(10)))
	_check(lake_area > 14000 and lake_area < 22000, "adapted lake remains prominent without crowding the valley")
	_check(islet_area > 500 and islet_area < lake_area * 0.06 and islet_flat > 120, "small lake island retains useful dry walking and flat ground")
	print("COMPACT LANDSCAPE: dry=", dry, " gentle20=", gentle, " southern=", southern, " connected32=", queue.size()*16, " shelf=", shelf, " deep=", deep, " max_step=", max_step, " seam curvature=", seam_curvature, " lake=", lake_area, " islet=", islet_area, " islet_flat=", islet_flat)


func _materials(terrain: Terrain3D) -> void:
	var unchanged := true
	var valid_controls := true
	var blended := 0
	var used := [false, false, false, false]
	for z in 3:
		for x in 3:
			var region := terrain.data.get_region(Vector2i(x, z))
			var baseline := load("res://scenes/island/backups/task_8_0/data/terrain3d_%02d_%02d.res" % [x, z]) as Terrain3DRegion
			unchanged = unchanged and region.get_height_map().get_data() == baseline.get_height_map().get_data() and region.get_color_map().get_data() == baseline.get_color_map().get_data()
			var bytes := region.get_control_map().get_data()
			for index in range(0, 256 * 256, 16):
				var bits := bytes.decode_u32(index * 4)
				var base := (bits >> 27) & 31
				var overlay := (bits >> 22) & 31
				var blend := (bits >> 14) & 255
				valid_controls = valid_controls and base < 4 and overlay < 4
				if base < 4:
					used[base] = true
				if overlay < 4 and blend > 0:
					used[overlay] = true
				blended += int(blend > 5 and blend < 250)
	_check(unchanged, "material pass preserves every native height and color sample from Task 8.0")
	_check(valid_controls and not false in used and blended > 10000, "four valid material IDs and graded native base/overlay weights")
	var textures_valid := true
	for asset in terrain.assets.texture_list:
		var image: Image = asset.albedo_texture.get_image()
		var normal: Image = asset.normal_texture.get_image()
		textures_valid = textures_valid and image.get_size() == Vector2i(128, 128) and image.has_mipmaps() and normal.has_mipmaps() and normal.get_pixel(0, 0).a > 0.9 and asset.normal_depth == 0
	_check(textures_valid, "consistent mipmapped 128px textures use matte roughness and stable flat normals")


func _run() -> void:
	var world := (load(SCENE) as PackedScene).instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	var terrain: Terrain3D = world.get_node("Terrain3D")
	var player: CharacterBody3D = world.get_node("Player")
	var menu: CanvasLayer = world.get_node("Menu")
	await _frames(60)
	_check(terrain.region_size == 256 and terrain.vertex_spacing == 1 and terrain.data.get_region_count() == 9, "nine native 256 m regions form a saved editable 768 m square")
	_check(terrain.assets.get_texture_count() == 4 and player.camera.far >= 1500, "four terrain base materials and long-range player camera available")
	_check(player.is_on_floor() and player.position.y > 3, "safe dry spawn settles on compact terrain")
	_check(player.inventory.get_capacity() == 36 and player.inventory.get_stack(0) == null, "existing initially empty inventory retained")
	var height := _map(terrain)
	_materials(terrain)
	_landscape(terrain, height)
	var collision_matches := true
	for point in [Vector3(376,0,494), Vector3(327,0,280), Vector3(219,0,232), Vector3(541,0,354), Vector3(373,0,526), Vector3(323,0,354), Vector3(373,0,706), Vector3(407,0,361), Vector3(330,0,74), Vector3(559,0,200), Vector3(190,0,592), Vector3(256,0,400), Vector3(512,0,400), Vector3(380,0,512), Vector3(696,0,352)]:
		var expected := terrain.data.get_height(point)
		player.position = point + Vector3.UP * (expected + 2)
		player.velocity = Vector3.ZERO
		await _frames(30)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point + Vector3.UP*(expected+20), point + Vector3.UP*(expected-10), 1))
		collision_matches = collision_matches and not hit.is_empty() and absf(hit.position.y - expected) < 0.15
	_check(collision_matches, "native collision matches fifteen landscape samples including three region seams and a rocky coast")
	_check(terrain.data.get_height(Vector3(219,0,232)) > 60 and terrain.data.get_height(Vector3(541,0,354)) > 45 and terrain.data.get_height(Vector3(373,0,526)) < 15, "two proportioned massifs still flank a broad lower valley")
	_check(terrain.data.get_height(Vector3(385,0,330)) < 5 and terrain.data.get_height(Vector3(407,0,361)) > 5 and world.get_node("Lake").position.y == 5, "native lake basin has submerged bottom and dry islet at unchanged water level")
	player.position = Vector3(407, terrain.data.get_height(Vector3(407,0,361)) + 0.1, 361)
	player.velocity = Vector3.ZERO
	player.set_mouse_captured(true)
	await _frames(20)
	var islet_start := player.position
	Input.action_press("move_right")
	await _frames(90)
	Input.action_release("move_right")
	await _frames(15)
	_check(player.is_on_floor() and player.position.y > 5 and player.position.x - islet_start.x > 5, "actual player walks over five meters on the compact lake island")
	player.reset_to_spawn()
	await _frames(40)
	var start := player.position
	player.set_mouse_captured(true)
	Input.action_press("move_forward")
	await _frames(720)
	Input.action_release("move_forward")
	await _frames(20)
	_check(start.z - player.position.z > 50 and player.is_on_floor() and player.position.y > 0, "twelve second exploration walk reaches dry central valley")
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	await _frames(95)
	_check(player.is_on_floor(), "jump lands on compact island terrain")
	var approach := Vector3(373,0,652)
	player.position = approach + Vector3.UP*(terrain.data.get_height(approach)+0.1)
	player.velocity = Vector3.ZERO
	await _frames(25)
	Input.action_press("move_back")
	await _frames(720)
	Input.action_release("move_back")
	await _frames(20)
	_check(player.position.z > 704 and player.is_on_floor() and player.position.y > 0 and player.position.y < 5, "twelve second physical walk reaches the adapted southern beach")
	menu.set_inventory_open(true)
	menu.set_character_open(true)
	var frozen := player.position
	await _frames(10)
	_check(paused and not player.controls_active and player.position == frozen and menu.inventory_view.inventory_panel.visible and menu.inventory_view.character_panel.visible, "both inventory windows pause island and player")
	menu.set_inventory_open(false)
	_check(paused, "remaining character window keeps island paused")
	menu.set_character_open(false)
	await _frames(4)
	_check(not paused and player.controls_active, "closing both windows resumes island")
	var edit := Vector3(380,0,512)
	var original := terrain.data.get_height(edit)
	var scratch := "res://.godot/compact_island_roundtrip"
	DirAccess.make_dir_recursive_absolute(scratch)
	terrain.data.set_height(edit, original+0.25)
	for location in terrain.data.get_region_locations():
		terrain.data.set_region_modified(location, true)
	terrain.data.save_directory(scratch)
	terrain.data.load_directory(scratch)
	_check(terrain.data.get_region_count() == 9 and is_equal_approx(terrain.data.get_height(edit), original+0.25), "native edit/save/reload preserves all nine regions and a seam-adjacent edit")
	terrain.data.load_directory("res://scenes/island/data")
	_check(terrain.data.get_region_count() == 9 and is_equal_approx(terrain.data.get_height(edit), original), "original compact island reloads without persisting test edits")
	world.queue_free()
	await process_frame
	print("ISLAND RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
