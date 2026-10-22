extends SceneTree
## Offline, bounded local edits to saved Task 7.7 data; never rebuilds the island.

const DATA := "res://scenes/island/data"
const BACKUP := "res://scenes/island/backups/task_7_7/terrain3d_00_00.res"
const HASH := "7b94d6db69e2b98bbfd15b0606906dc723a1a2748c8ed3ceeaa55d6da55a6b68"
# Center X/Z, elliptical extent X/Z, strength. Only these transitions are edited.
const ZONES := [
	[Vector2(420, 520), Vector2(42, 62), 0.65],
	[Vector2(655, 530), Vector2(40, 70), 0.55],
	[Vector2(365, 610), Vector2(75, 90), 0.4],
	[Vector2(700, 695), Vector2(75, 90), 0.4],
	[Vector2(245, 235), Vector2(75, 85), 0.3],
	[Vector2(760, 300), Vector2(75, 85), 0.3],
	[Vector2(275, 720), Vector2(85, 85), 0.35],
	[Vector2(430, 810), Vector2(75, 90), 0.35],
	[Vector2(790, 775), Vector2(80, 85), 0.35],
]
const WEIGHTS := [1.0, 4.0, 6.0, 4.0, 1.0]


func _initialize() -> void:
	if not "--polish-island-v8" in OS.get_cmdline_user_args() or FileAccess.get_sha256(BACKUP) != HASH or FileAccess.get_sha256(DATA + "/terrain3d_00_00.res") != HASH:
		push_error("Requires -- --polish-island-v8 and unchanged Task 7.7 active data and backup. Refuses repeat application or overwriting later sculpting.")
		quit(1)
		return
	_refine.call_deferred()


func _refine() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(500, 60, 650)
	camera.current = true
	var terrain := Terrain3D.new()
	world.add_child(terrain)
	terrain.set_camera(camera)
	terrain.region_size = Terrain3D.SIZE_1024
	terrain.data.load_directory(DATA)
	var region: Terrain3DRegion = terrain.data.get_region(Vector2i.ZERO)
	var original: Image = region.get_height_map().duplicate()
	var revised: Image = original.duplicate()
	var changed := 0
	var largest := 0.0
	for z in range(20, 1004):
		for x in range(20, 1004):
			var h := original.get_pixel(x, z).r
			# Protect both waterlines, low beaches, the islet and dramatic crests.
			if h <= 8 or h >= 58:
				continue
			var p := Vector2(x, z)
			var strength := 0.0
			for zone in ZONES:
				strength = maxf(strength, (1 - smoothstep(0.15, 1, ((p - zone[0]) / zone[1]).length())) * zone[2])
			strength *= smoothstep(8, 12, h) * (1 - smoothstep(48, 58, h))
			if strength <= 0.00001:
				continue
			var average := 0.0
			for j in 5:
				for i in 5:
					average += original.get_pixel(x + (i - 2) * 6, z + (j - 2) * 6).r * WEIGHTS[i] * WEIGHTS[j]
			var delta := clampf(average / 256.0 - h, -2, 2) * strength
			revised.set_pixel(x, z, Color(h + delta, 0, 0))
			if absf(delta) > 0.0001:
				changed += 1
				largest = maxf(largest, absf(delta))
	# Keep control/color maps byte-for-byte; no new paint or material changes.
	region.set_height_map(revised)
	terrain.data.set_region_modified(Vector2i.ZERO, true)
	terrain.data.update_maps()
	terrain.data.save_directory(DATA)
	print("LOCAL POLISH SAVED: changed=", changed, " samples, largest adjustment=", largest, " m; control/color maps retained")
	world.queue_free()
	await process_frame
	quit()
