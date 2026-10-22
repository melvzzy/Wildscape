extends SceneTree
## Offline authoring only. V2 requires a preserved V1 backup and explicit flag.
## Never attach this script to the world or invoke it during normal gameplay.

const DIRECTORY := "res://scenes/island"
const BACKUP := DIRECTORY + "/backups/task_7_1/terrain3d_00_00.res"
const SIZE := 512
# Points are (world X, ridge elevation above the lowlands, world Z).
const WEST := [Vector3(154, 22, 85), Vector3(173, 59, 120), Vector3(157, 77, 166), Vector3(179, 56, 213), Vector3(151, 34, 260), Vector3(160, 8, 310)]
const WEST_BRANCH := [Vector3(159, 64, 163), Vector3(128, 32, 198), Vector3(101, 10, 235)]
const VALLEY_BRANCH := [Vector3(177, 47, 213), Vector3(207, 24, 238), Vector3(222, 4, 270)]
const EAST := [Vector3(354, 12, 184), Vector3(365, 38, 226), Vector3(349, 57, 266), Vector3(360, 52, 300), Vector3(377, 24, 334), Vector3(354, 5, 369)]
const EAST_BRANCH := [Vector3(359, 46, 300), Vector3(398, 22, 283), Vector3(425, 3, 307)]
var noise := FastNoiseLite.new()


func _initialize() -> void:
	if not "--write-island-v2" in OS.get_cmdline_user_args() or not FileAccess.file_exists(BACKUP):
		push_error("Rebuild requires -- --write-island-v2 and the preserved Task 7.1 native backup. Existing sculpted data will be replaced.")
		quit(1)
		return
	_build.call_deferred()


func _ridge(p: Vector2, points: Array, width: float) -> float:
	var result := 0.0
	for index in points.size() - 1:
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		var start := Vector2(a.x, a.z)
		var segment := Vector2(b.x, b.z) - start
		var t := clampf((p - start).dot(segment) / segment.length_squared(), 0.0, 1.0)
		var distance := p.distance_to(start + segment * t)
		var elevation := lerpf(a.y, b.y, t)
		var crest := exp(-pow(distance / width, 1.7))
		var apron := exp(-pow(distance / (width * 2.3), 2.0))
		result = maxf(result, elevation * (crest * 0.72 + apron * 0.28))
	return result


func _height(x: float, z: float) -> float:
	var p := Vector2(x - 256.0, z - 256.0)
	var angle := atan2(p.y, p.x)
	var radius := Vector2(p.x * 0.96, p.y * 1.04).length()
	var shore := 205.0 + 11.0 * sin(angle * 3.0 + 0.7) + 7.0 * cos(angle * 5.0 - 0.8)
	shore += noise.get_noise_2d(x * 2.0, z * 2.0) * 10.0
	# Broad embayments, separated by headlands rather than a repeated wave pattern.
	shore -= 28.0 * exp(-pow(wrapf(angle - 0.7, -PI, PI) / 0.22, 2.0))
	shore -= 21.0 * exp(-pow(wrapf(angle - 2.65, -PI, PI) / 0.25, 2.0))
	shore -= 18.0 * exp(-pow(wrapf(angle + 0.95, -PI, PI) / 0.2, 2.0))
	var inland := shore - radius
	var cliffs := exp(-pow(wrapf(angle + 0.2, -PI, PI) / 0.19, 2.0))
	cliffs += exp(-pow(wrapf(angle + 2.2, -PI, PI) / 0.22, 2.0)) * 0.7
	var beach := lerpf(-7.0, 7.0, smoothstep(-35.0, 48.0, inland))
	var cliff := lerpf(-7.0, 11.0, smoothstep(-9.0, 18.0, inland))
	var base := lerpf(beach, cliff, minf(cliffs, 1.0))
	var hills := noise.get_noise_2d(x, z) * 3.5
	# Wide lowland terraces suppress fine noise; small-scale relief belongs to ridges.
	var shelf := exp(-pow((x - 257.0) / 75.0, 2.0) - pow((z - 358.0) / 65.0, 2.0))
	hills *= 1.0 - shelf * 0.85
	var warped := Vector2(x, z) + Vector2(noise.get_noise_2d(x * 2, z * 2), noise.get_noise_2d(x * 2 + 412, z * 2)) * 5.0
	var west := maxf(_ridge(warped, WEST, 29), _ridge(warped, WEST_BRANCH, 23))
	west = maxf(west, _ridge(warped, VALLEY_BRANCH, 21))
	var east := maxf(_ridge(warped, EAST, 30), _ridge(warped, EAST_BRANCH, 23))
	var mountains := maxf(west, east)
	mountains *= 1.0 + noise.get_noise_2d(x * 4, z * 4) * 0.12
	# An incomplete northern rim connects the massifs without enclosing the valley.
	var rim := 9.0 * exp(-pow((Vector2(p.x, p.y * 1.12).length() - 130.0) / 30.0, 2.0))
	rim *= 1.0 - smoothstep(-55.0, 12.0, p.y)
	var height := base + (hills + mountains + rim) * smoothstep(4.0, 65.0, inland)
	# Off-centre lake: gently graded banks, a shallow bed and a small dry islet.
	var lake := Vector2((x - 282.0) / 32.0, (z - 275.0) / 28.0)
	var lake_radius := lake.length() * (1.0 + sin(atan2(lake.y, lake.x) * 3.0) * 0.045)
	height = lerpf(height, 1.7, 1.0 - smoothstep(0.58, 1.4, lake_radius))
	var islet_distance := Vector2(x - 285.0, z - 273.0).length()
	height += 6.7 * exp(-pow(islet_distance / 7.0, 3.0))
	return height


func _build() -> void:
	noise.seed = 72043
	noise.frequency = 0.008
	noise.fractal_octaves = 2
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(256, 50, 370)
	camera.current = true
	var terrain := Terrain3D.new()
	world.add_child(terrain)
	terrain.set_camera(camera)
	terrain.region_size = Terrain3D.SIZE_512
	var height := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RF)
	var color_map := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for z in SIZE:
		for x in SIZE:
			height.set_pixel(x, z, Color(_height(x, z), 0, 0))
			var shade := 0.96 + noise.get_noise_2d(x, z) * 0.035
			color_map.set_pixel(x, z, Color(shade, shade, shade, 0.5))
	terrain.data.import_images([height, null, color_map], Vector3.ZERO, 0.0, 1.0)
	for z in SIZE:
		for x in SIZE:
			var h := height.get_pixel(x, z).r
			var dx := height.get_pixel(mini(x + 1, SIZE - 1), z).r - height.get_pixel(maxi(x - 1, 0), z).r
			var dz := height.get_pixel(x, mini(z + 1, SIZE - 1)).r - height.get_pixel(x, maxi(z - 1, 0)).r
			var slope := Vector2(dx, dz).length() * 0.5
			var pos := Vector3(x, 0, z)
			var lake_bank := x > 235 and x < 330 and z > 230 and z < 320
			var sand := 1.0 - smoothstep(1.8, 5.0, h)
			if lake_bank:
				sand = maxf(sand, (1.0 - smoothstep(5.0, 6.7, h)) * 0.9)
			var rock := maxf(smoothstep(0.46, 1.1, slope), smoothstep(42.0, 76.0, h) * 0.8)
			rock *= smoothstep(3.0, 9.0, h)
			terrain.data.set_control_base_id(pos, 0)
			terrain.data.set_control_overlay_id(pos, 2 if rock > 0.05 else 1)
			terrain.data.set_control_blend(pos, rock if rock > 0.05 else sand)
	terrain.data.update_maps()
	terrain.data.save_directory(DIRECTORY + "/data")
	print("ISLAND V2 SAVED: regions=", terrain.data.get_region_count(), " range=", terrain.data.get_height_range(), " spawn=", terrain.data.get_height(Vector3(252, 0, 367)))
	world.queue_free()
	await process_frame
	quit()
