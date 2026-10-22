extends SceneTree
## OFFLINE Task 8 adaptation of saved terrain, never a runtime world generator.

const BASE := "res://scenes/island/backups/task_7_8/data/terrain3d_00_00.res"
const BASE_HASH := "d9591a794a001a8fba88b8c7e959699d61a9ab25b033cce14cc255f0b24961b1"
const DATA := "res://scenes/island/data"
const STAGE := "res://.godot/compact_island_stage"
const SIZE := 768
# Inverse, monotone mapping: reserve more width for the valley and lake;
# compact outer highlands more. Cubic tangents prevent slope seams at knots.
const NEW_X := [0.0, 184.0, 284.0, 384.0, 496.0, 584.0, 767.0]
const OLD_X := [0.0, 256.0, 400.0, 512.0, 640.0, 768.0, 1023.0]
const NEW_Z := [0.0, 228.0, 270.0, 354.0, 456.0, 526.0, 650.0, 767.0]
const OLD_Z := [0.0, 320.0, 380.0, 480.0, 600.0, 700.0, 850.0, 1023.0]
var distance := PackedFloat32Array()
var nearest := PackedInt32Array()
var shore_points := PackedVector2Array()


func _initialize() -> void:
	var input_regions := 0
	for file in DirAccess.get_files_at(DATA):
		input_regions += int(file.ends_with(".res"))
	if not "--compact-island-v80" in OS.get_cmdline_user_args() or input_regions != 1 or FileAccess.get_sha256(BASE) != BASE_HASH or FileAccess.get_sha256(DATA + "/terrain3d_00_00.res") != BASE_HASH:
		push_error("Requires -- --compact-island-v80 and hash-matching Task 7.8 active data/backup. Later sculpting and repeated runs are protected.")
		quit(1)
		return
	_build.call_deferred()


func _axis(p: float, positions: Array, samples: Array) -> float:
	var i := 0
	while i < positions.size() - 2 and p > positions[i + 1]:
		i += 1
	var span: float = positions[i + 1] - positions[i]
	var slope: float = (samples[i + 1] - samples[i]) / span
	var left := slope
	var right := slope
	if i > 0:
		var previous: float = (samples[i] - samples[i - 1]) / (positions[i] - positions[i - 1])
		left = 2 * slope * previous / (slope + previous)
	if i < positions.size() - 2:
		var next: float = (samples[i + 2] - samples[i + 1]) / (positions[i + 2] - positions[i + 1])
		right = 2 * slope * next / (slope + next)
	var t := clampf((p - positions[i]) / span, 0, 1)
	return (2*t*t*t - 3*t*t + 1) * samples[i] + (t*t*t - 2*t*t + t) * span * left + (-2*t*t*t + 3*t*t) * samples[i + 1] + (t*t*t - t*t) * span * right


func _sample(image: Image, p: Vector2) -> float:
	var x := clampi(floori(p.x), 0, 1022)
	var z := clampi(floori(p.y), 0, 1022)
	return lerpf(lerpf(image.get_pixel(x, z).r, image.get_pixel(x + 1, z).r, p.x - x), lerpf(image.get_pixel(x, z + 1).r, image.get_pixel(x + 1, z + 1).r, p.x - x), p.y - z)


func _propagate(x: int, z: int, offsets: Array[Vector2i]) -> void:
	var index := z * SIZE + x
	for offset in offsets:
		var nx := x + offset.x
		var nz := z + offset.y
		if nx < 0 or nz < 0 or nx >= SIZE or nz >= SIZE:
			continue
		var neighbor := nz * SIZE + nx
		var candidate := distance[neighbor] + (1.41421356 if offset.x != 0 and offset.y != 0 else 1.0)
		if candidate < distance[index]:
			distance[index] = candidate
			nearest[index] = nearest[neighbor]


func _refine_distance(x: int, z: int, field: PackedFloat32Array, offsets: Array[Vector2i]) -> void:
	var index := z * SIZE + x
	for offset in offsets:
		var nx := x + offset.x
		var nz := z + offset.y
		if nx < 0 or nz < 0 or nx >= SIZE or nz >= SIZE:
			continue
		var seed := nearest[nz * SIZE + nx]
		var candidate := Vector2(x, z).distance_to(shore_points[seed])
		if candidate < field[index]:
			field[index] = candidate
			nearest[index] = seed


func _rocky_coast(p: Vector2) -> float:
	# Smoothly adapted locations of the original five rocky headlands.
	# Nearest-shore labels are unsuitable here: their Voronoi borders make
	# narrow normal/shading streaks even when height jumps stay small.
	var result := 0.0
	for cape in [Vector4(666, 203, 46, 71), Vector4(52, 270, 30, 70), Vector4(670, 605, 36, 46), Vector4(200, 46, 68, 34), Vector4(710, 371, 40, 75)]:
		result = maxf(result, exp(-1.8 * ((p - Vector2(cape.x, cape.y)) / Vector2(cape.z, cape.w)).length_squared()))
	return result


func _build() -> void:
	var baseline: Terrain3DRegion = load(BASE)
	var old_height := baseline.get_height_map()
	var old_control := baseline.get_control_map()
	var old_color := baseline.get_color_map()
	var height := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RF)
	var control := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RF)
	var colors := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for z in SIZE:
		for x in SIZE:
			var source := Vector2(_axis(x, NEW_X, OLD_X), _axis(z, NEW_Z, OLD_Z))
			# Retain the useful islet's physical walking footprint, not 75% of it.
			var delta := Vector2(x, z) - Vector2(407, 361)
			var islet_weight := 1 - smoothstep(25, 45, delta.length())
			source = source.lerp(Vector2(538, 488) + delta, islet_weight)
			var h := _sample(old_height, source)
			if h > 9:
				h = 9 + (h - 9) * lerpf(0.75, 0.70, smoothstep(25, 90, h))
			height.set_pixel(x, z, Color(h, 0, 0))
			var pixel := Vector2i(clampi(roundi(source.x), 0, 1023), clampi(roundi(source.y), 0, 1023))
			# Encoded control bits must never be bilinearly interpolated.
			control.blit_rect(old_control, Rect2i(pixel, Vector2i.ONE), Vector2i(x, z))
			colors.set_pixel(x, z, old_color.get_pixelv(pixel))
	print("Compact source adaptation ready; building coastal distance field")
	distance.resize(SIZE * SIZE)
	distance.fill(INF)
	nearest.resize(SIZE * SIZE)
	shore_points.resize(SIZE * SIZE)
	# Fractional shoreline seeds keep the actual zero crossing rather than
	# quantizing the water edge to a one-meter staircase.
	for z in range(1, SIZE - 1):
		for x in range(1, SIZE - 1):
			var h := height.get_pixel(x, z).r
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var other: float = height.get_pixel(x + offset.x, z + offset.y).r
				if (h > 0) != (other > 0):
					var fraction := absf(h) / maxf(absf(h) + absf(other), 0.00001)
					var index := z * SIZE + x
					if fraction < distance[index]:
						distance[index] = fraction
						nearest[index] = index if h > 0 else (z + offset.y) * SIZE + x + offset.x
						shore_points[index] = Vector2(x, z) + Vector2(offset) * fraction
	for z in SIZE:
		for x in SIZE:
			_propagate(x, z, [Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)])
	for z in range(SIZE - 1, -1, -1):
		for x in range(SIZE - 1, -1, -1):
			_propagate(x, z, [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1)])
	# Euclidean distance to fractional shore points avoids eight-direction
	# wavefronts on both the seabed and the low coastal slopes.
	var coast_distance := distance.duplicate()
	for z in SIZE:
		for x in SIZE:
			coast_distance[z * SIZE + x] = Vector2(x, z).distance_to(shore_points[nearest[z * SIZE + x]])
	for z in SIZE:
		for x in SIZE:
			_refine_distance(x, z, coast_distance, [Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1)])
	for z in range(SIZE - 1, -1, -1):
		for x in range(SIZE - 1, -1, -1):
			_refine_distance(x, z, coast_distance, [Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1)])
	var raw := height.duplicate() as Image
	for z in SIZE:
		for x in SIZE:
			var index := z * SIZE + x
			var rock := _rocky_coast(Vector2(x, z))
			var d := coast_distance[index]
			var h := raw.get_pixel(x, z).r
			if h <= 0:
				# Nearest-shore labels can change across offshore medial axes.
				# Fade their influence before deep water to avoid Voronoi walls.
				var local_rock := rock * (1 - smoothstep(8, 32, d))
				var depth := lerpf(0.13, 0.30, local_rock) * d + 0.0015 * d * d
				h = -38 * tanh(depth / 38)
				h += 0.45 * sin(x / 53.0) * sin(z / 67.0) * smoothstep(15, 50, d) * (1 - smoothstep(110, 180, d))
			else:
				# Wider sandy lowlands stay gentle; elevated rocky shores remain.
				var beach := (1 - rock) * (1 - smoothstep(15, 55, d))
				h = lerpf(h, h * lerpf(0.8, 1, smoothstep(3, 10, h)), beach)
				var rocky_approach := rock * (1 - smoothstep(10, 60, d)) * (1 - smoothstep(12, 28, h))
				h *= 1 - 0.25 * rocky_approach
			height.set_pixel(x, z, Color(h, 0, 0))
	# Bound only resampling overshoots on steep lower faces; never blur peaks
	# or smooth the whole island to conceal a mesh/material issue.
	var limited := 0
	for pass_index in 3:
		var snapshot := height.duplicate() as Image
		for z in range(1, SIZE - 1):
			for x in range(1, SIZE - 1):
				var h := snapshot.get_pixel(x, z).r
				if h < 9 or h > 58:
					continue
				var revised := h
				for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var neighbor: float = snapshot.get_pixel(x + offset.x, z + offset.y).r
					revised = clampf(revised, neighbor - 2.3, neighbor + 2.3)
				if revised != h:
					limited += 1
					height.set_pixel(x, z, Color(revised, 0, 0))
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(376, 60, 494)
	camera.current = true
	var terrain := Terrain3D.new()
	world.add_child(terrain)
	terrain.set_camera(camera)
	terrain.region_size = Terrain3D.SIZE_256
	terrain.data.import_images([height, control, colors], Vector3.ZERO, 0, 1)
	if terrain.data.get_region_count() != 9:
		push_error("Expected precisely nine native 256 m regions; active data was not touched")
		quit(1)
		return
	terrain.data.save_directory(STAGE)
	terrain.data.load_directory(STAGE)
	var valid := terrain.data.get_region_count() == 9
	for region_z in 3:
		for region_x in 3:
			var location := Vector2i(region_x, region_z)
			var region: Terrain3DRegion = terrain.data.get_region(location)
			valid = valid and region != null and region.get_height_map().get_size() == Vector2i(256, 256)
			if region != null:
				valid = valid and region.get_height_map().get_data() == height.get_region(Rect2i(location * 256, Vector2i(256, 256))).get_data()
	if not valid:
		push_error("Native staging save/reload differed from authored heightmap; active data untouched")
		quit(1)
		return
	for location in terrain.data.get_region_locations():
		terrain.data.set_region_modified(location, true)
	terrain.data.save_directory(DATA)
	print("COMPACT SAVED: 768 m, nine 256 m regions; range=", terrain.data.get_height_range(), " spawn=", terrain.data.get_height(Vector3(376, 0, 494)), " bounded overshoot edits=", limited)
	world.queue_free()
	await process_frame
	quit()
