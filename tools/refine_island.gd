extends SceneTree
## Controlled offline sculpt pass over the frozen Task 7.2 native heightmap.
## No runtime attachment. Requires an explicit flag; never calls build_island.gd.

const DIRECTORY := "res://scenes/island"
const SOURCE := DIRECTORY + "/backups/task_7_2/terrain3d_00_00.res"
const SOURCE_HASH := "7dac6742d83df7f2513fb124a3514d0cd5102ff7553444b7e91ced417defbc4f"
const WEST_CREST := [Vector3(174, 2, 121), Vector3(162, 5, 147), Vector3(156, 7, 166), Vector3(177, 4, 195), Vector3(165, 5, 219), Vector3(181, 2, 238), Vector3(152, 0, 270)]
const EAST_CREST := [Vector3(365, 0, 226), Vector3(358, 4, 249), Vector3(348, 6, 267), Vector3(368, 3, 286), Vector3(357, 5, 307), Vector3(379, 0, 336)]
const WEST_GULLY := [Vector3(158, 0, 166), Vector3(142, 10, 184), Vector3(132, 13, 212), Vector3(104, 0, 247)]
const VALLEY_GULLY := [Vector3(176, 0, 198), Vector3(195, 11, 211), Vector3(208, 7, 229), Vector3(231, 0, 249)]
const EAST_GULLY := [Vector3(350, 0, 267), Vector3(373, 12, 276), Vector3(390, 8, 303), Vector3(418, 0, 322)]
const NORTH_GULLY := [Vector3(173, 0, 130), Vector3(194, 10, 149), Vector3(208, 6, 170), Vector3(229, 0, 182)]
var source: Image


func _initialize() -> void:
	if not "--refine-island-v3" in OS.get_cmdline_user_args() or FileAccess.get_sha256(SOURCE) != SOURCE_HASH:
		push_error("Requires -- --refine-island-v3 and the verified Task 7.2 backup. Current hand edits will be replaced.")
		quit(1)
		return
	_run.call_deferred()


func _ribbon(p: Vector2, points: Array, width: float) -> float:
	var result := 0.0
	for index in points.size() - 1:
		var a: Vector3 = points[index]
		var b: Vector3 = points[index + 1]
		var start := Vector2(a.x, a.z)
		var segment := Vector2(b.x - a.x, b.z - a.z)
		var t := clampf((p - start).dot(segment) / segment.length_squared(), 0, 1)
		var distance := p.distance_to(start + segment * t)
		result = maxf(result, lerpf(a.y, b.y, t) * exp(-pow(distance / width, 2)))
	return result


func _ellipse(p: Vector2, center: Vector2, size: Vector2) -> float:
	return ((p - center) / size).length()


func _refine(x: int, z: int) -> float:
	var p := Vector2(x, z)
	var original := source.get_pixel(x, z).r
	# Keep the established spawn floor exact, and leave the finite seabed alone.
	if p.distance_to(Vector2(252, 367)) < 22 or x < 24 or z < 24 or x > 487 or z > 487:
		return original
	var h := original
	var mountain := smoothstep(18, 45, original)
	if mountain > 0:
		var blurred := 0.0
		for dz in [-14, 0, 14]:
			for dx in [-14, 0, 14]:
				blurred += source.get_pixel(x + dx, z + dz).r
		h += (original - blurred / 9.0) * 0.25 * mountain
		h += (_ribbon(p, WEST_CREST, 8) + _ribbon(p, EAST_CREST, 7)) * mountain * 0.7
		h -= maxf(0, original - 50) * 0.18 * mountain
		h -= maxf(_ribbon(p, WEST_GULLY, 11), _ribbon(p, VALLEY_GULLY, 10)) * mountain
		h -= maxf(_ribbon(p, EAST_GULLY, 11), _ribbon(p, NORTH_GULLY, 10)) * mountain
	# Distinct low hills and a small drainage valley, rather than global noise.
	var lowland := smoothstep(2, 7, original) * (1.0 - smoothstep(15, 25, original))
	h += 4.2 * exp(-pow(_ellipse(p, Vector2(158, 350), Vector2(43, 29)), 2)) * lowland
	h += 4.8 * exp(-pow(_ellipse(p, Vector2(335, 387), Vector2(27, 39)), 2)) * lowland
	h -= 2.5 * exp(-pow(_ellipse(p, Vector2(187, 335), Vector2(15, 35)), 2)) * lowland
	# New accessible coastal coves; each cut feathers into the existing ground.
	for cove in [Vector4(105, 361, 30, 39), Vector4(375, 402, 28, 35), Vector4(320, 95, 34, 24)]:
		var q := (p - Vector2(cove.x, cove.y)) / Vector2(cove.z, cove.w)
		var angle := atan2(q.y, q.x)
		# Different headlands and an oblique mouth for each inlet, not circular bites.
		var phase: float = cove.x * 0.019
		q.x += sin(q.y * 1.4 + phase) * 0.14
		var distance := q.length() * (1.0 + sin(angle * 3 + phase) * 0.16 + cos(angle * 5 - phase) * 0.065)
		var cut := lerpf(-2.8, 5.5, smoothstep(0.3, 1.4, distance))
		var amount := 1.0 - smoothstep(0.95, 1.6, distance)
		h = lerpf(h, minf(h, cut), amount)
	# Slightly elevated headlands break the remaining continuous beach apron.
	h += 2.2 * exp(-pow(_ellipse(p, Vector2(436, 222), Vector2(16, 24)), 2)) * (1.0 - smoothstep(14, 25, original))
	# A union of offset basins makes coves and a peninsula within the unchanged
	# lake plane, instead of a circular hole. Smooth outer blending preserves hills.
	var lake_mask := 1.0 - smoothstep(0.78, 1.0, _ellipse(p, Vector2(282, 275), Vector2(49, 43)))
	if lake_mask > 0:
		var basin := minf(_ellipse(p, Vector2(280, 274), Vector2(28, 22)), _ellipse(p, Vector2(266, 290), Vector2(16, 13)))
		basin = minf(basin, _ellipse(p, Vector2(302, 270), Vector2(16, 15)))
		var bank := maxf(h, 8.5)
		var lake_height := lerpf(1.7, bank, smoothstep(0.6, 1.5, basin))
		var islet := _ellipse(p, Vector2(285, 273), Vector2(7.5, 5.5))
		lake_height += 6.7 * exp(-pow(islet, 3))
		h = lerpf(h, lake_height, lake_mask)
	return h


func _run() -> void:
	var saved := load(SOURCE) as Terrain3DRegion
	source = saved.get_height_map()
	var height := source.duplicate() as Image
	for z in 512:
		for x in 512:
			height.set_pixel(x, z, Color(_refine(x, z), 0, 0))
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(256, 60, 360)
	camera.current = true
	var terrain := Terrain3D.new()
	world.add_child(terrain)
	terrain.set_camera(camera)
	terrain.region_size = Terrain3D.SIZE_512
	# Preserve the existing colour variation and material definitions. Paint only
	# follows the edited slopes and shore elevations, using the same three assets.
	terrain.data.import_images([height, saved.get_control_map(), saved.get_color_map()], Vector3.ZERO, 0, 1)
	for z in 512:
		for x in 512:
			var h := height.get_pixel(x, z).r
			var dx := height.get_pixel(mini(x + 1, 511), z).r - height.get_pixel(maxi(x - 1, 0), z).r
			var dz := height.get_pixel(x, mini(z + 1, 511)).r - height.get_pixel(x, maxi(z - 1, 0)).r
			var slope := Vector2(dx, dz).length() * 0.5
			var sand := 1.0 - smoothstep(1.8, 5.0, h)
			if x > 235 and x < 330 and z > 230 and z < 320:
				sand = maxf(sand, (1.0 - smoothstep(5.0, 6.7, h)) * 0.9)
			var rock := maxf(smoothstep(0.46, 1.1, slope), smoothstep(42.0, 76.0, h) * 0.8) * smoothstep(3.0, 9.0, h)
			var point := Vector3(x, 0, z)
			terrain.data.set_control_base_id(point, 0)
			terrain.data.set_control_overlay_id(point, 2 if rock > 0.05 else 1)
			terrain.data.set_control_blend(point, rock if rock > 0.05 else sand)
	terrain.data.update_maps()
	terrain.data.save_directory(DIRECTORY + "/data")
	print("SCULPT V3 SAVED: range=", terrain.data.get_height_range(), " spawn=", terrain.data.get_height(Vector3(252, 0, 367)))
	world.queue_free()
	await process_frame
	quit()
