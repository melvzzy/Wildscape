extends SceneTree
## Isolated native Terrain3D persistence, collision and player integration check.

const SCENE := "res://scenes/terrain_preflight/terrain_preflight.tscn"
var checks := 0
var failures := 0
var elapsed := 0.0


func _initialize() -> void:
	_run.call_deferred()


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 40.0:
		push_error("FAIL: terrain preflight timeout")
		quit(1)
	return false


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)
	else:
		print("PASS: ", message)


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame
	await process_frame


func _run() -> void:
	var scene := load(SCENE) as PackedScene
	var world := scene.instantiate() as Node3D
	root.add_child(world)
	current_scene = world
	var terrain: Terrain3D = world.get_node("Terrain3D")
	var player: CharacterBody3D = world.get_node("Player")
	await _frames(60)
	_check(terrain.get_version() == "1.0.2", "native Terrain3D 1.0.2 loaded")
	_check(terrain.region_size == 128 and terrain.vertex_spacing == 1.0, "128 m region at 1 m spacing")
	_check(terrain.data.get_region_count() == 1, "one saved region reloads")
	_check(is_equal_approx(terrain.data.get_height(Vector3(64, 0, 64)), 2.0), "saved heightmap center is 2 m")
	_check(is_equal_approx(terrain.data.get_height(Vector3(64, 0, 88)), 0.0), "flat spawn reloads")
	_check(player.is_on_floor() and absf(player.position.y) < 0.05, "existing player lands on native terrain")
	var hit := world.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(Vector3(64, 10, 64), Vector3(64, -2, 64), 1))
	_check(not hit.is_empty() and absf(hit.position.y - 2.0) < 0.05, "World-layer collision matches heightmap")
	player.set_mouse_captured(true)
	Input.action_press("move_forward")
	await _frames(100)
	Input.action_release("move_forward")
	await _frames(20)
	_check(player.position.z < 82 and player.position.y > 0.05 and player.is_on_floor(), "player walks uphill without falling through")
	Input.action_press("jump")
	await _frames(1)
	Input.action_release("jump")
	await _frames(100)
	_check(player.is_on_floor(), "player jumps and lands on terrain")
	# Exercise editing/save on an isolated copy; never mutate the checked-in fixture.
	terrain.data.set_height(Vector3(10, 0, 10), 0.75)
	terrain.data.set_region_modified(Vector2i.ZERO, true)
	var scratch := "res://.godot/terrain_preflight_roundtrip"
	DirAccess.make_dir_recursive_absolute(scratch)
	terrain.data.save_directory(scratch)
	var saved := ResourceLoader.load(scratch + "/terrain3d_00_00.res", "", ResourceLoader.CACHE_MODE_IGNORE) as Terrain3DRegion
	_check(saved != null and is_equal_approx(saved.get_height_map().get_pixel(10, 10).r, 0.75), "native edit/save/resource reload preserves height")
	if "--capture-terrain" in OS.get_cmdline_user_args():
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(100, 46, 112)
		camera.look_at(Vector3(64, 0, 64))
		camera.current = true
		terrain.set_camera(camera)
		await _frames(10)
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		_check(image.save_png("res://.godot/terrain-preflight.png") == OK, "rendered terrain capture saved")
	world.queue_free()
	await process_frame
	# A fresh instance must still load the original scene data, not scratch edits.
	world = scene.instantiate()
	root.add_child(world)
	current_scene = world
	await _frames(20)
	terrain = world.get_node("Terrain3D")
	_check(is_equal_approx(terrain.data.get_height(Vector3(10, 0, 10)), 0.0), "fresh scene reloads original data directory")
	world.queue_free()
	await process_frame
	print("TERRAIN PREFLIGHT RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
