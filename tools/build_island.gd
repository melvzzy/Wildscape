extends SceneTree
## Offline authoring only. Explicitly overwrites saved terrain; never used at runtime.

const DIRECTORY := "res://scenes/island"
const SIZE := 256
var noise := FastNoiseLite.new()


func _initialize() -> void:
	if not "--write-island" in OS.get_cmdline_user_args():
		push_error("Use -- --write-island only when intentionally replacing sculpted island data.")
		quit(1)
		return
	_build.call_deferred()


func _height(x: float, z: float) -> float:
	var p := Vector2(x - 128.0, z - 128.0)
	var angle := atan2(p.y, p.x)
	var shore := 98.0 + 7.0 * sin(angle * 3.0 + 0.7) + 4.0 * cos(angle * 5.0 - 0.8)
	shore += noise.get_noise_2d(x * 0.65, z * 0.65) * 9.0
	var radius := Vector2(p.x * 0.96, p.y * 1.06).length()
	var inland := shore - radius
	var land := smoothstep(-9.0, 13.0, inland)
	var base := lerpf(-7.0, 4.5, land)
	var hills := noise.get_noise_2d(x, z) * 3.5 + noise.get_noise_2d(x * 2.3, z * 2.3) * 0.7
	# Broken impact rim; open southern breach makes a broad valley approach.
	var rim_radius := Vector2(p.x, p.y * 1.12).length()
	var rim := exp(-pow((rim_radius - 60.0) / 17.0, 2.0))
	var north_weight := 1.0 - smoothstep(0.0, 40.0, p.y)
	var broken_rim := rim * north_weight * (6.0 + noise.get_noise_2d(x * 1.5, z * 1.5) * 3.0)
	var west := 29.0 * exp(-pow((p.x + 43.0) / 20.0, 2.0) - pow((p.y + 24.0) / 31.0, 2.0))
	var east := 24.0 * exp(-pow((p.x - 43.0) / 25.0, 2.0) - pow((p.y + 38.0) / 19.0, 2.0))
	west *= 1.0 + noise.get_noise_2d(x * 1.3, z * 1.3) * 0.25
	east *= 1.0 + noise.get_noise_2d(x * 1.1 + 93.0, z * 1.1) * 0.2
	west += 5.0 * exp(-pow((p.x + 59.0) / 15.0, 2.0) - pow((p.y + 45.0) / 18.0, 2.0))
	# A wider gentle shelf south-west provides comfortable future building ground.
	var shelf := exp(-pow((p.x + 23.0) / 24.0, 2.0) - pow((p.y - 28.0) / 25.0, 2.0))
	return base + (hills * (1.0 - shelf * 0.8) + broken_rim + west + east) * smoothstep(0.0, 22.0, inland)


func _texture(color: Color, filename: String) -> Texture2D:
	var image := Image.create_empty(8, 8, false, Image.FORMAT_RGBA8)
	image.fill(color)
	image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	var path := DIRECTORY + "/" + filename + ".res"
	var error := ResourceSaver.save(texture, path)
	if error != OK:
		push_error("Cannot save terrain color: %s" % error_string(error))
	return load(path) as Texture2D


func _build() -> void:
	noise.seed = 71043
	noise.frequency = 0.025
	noise.fractal_octaves = 3
	var world := Node3D.new()
	root.add_child(world)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(128, 60, 185)
	camera.current = true
	var terrain := Terrain3D.new()
	world.add_child(terrain)
	terrain.set_camera(camera)
	terrain.region_size = Terrain3D.SIZE_256
	var height := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RF)
	var color_map := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for z in SIZE:
		for x in SIZE:
			height.set_pixel(x, z, Color(_height(x, z), 0, 0))
			var shade := 0.93 + noise.get_noise_2d(x * 0.7, z * 0.7) * 0.07
			color_map.set_pixel(x, z, Color(shade, shade, shade, 0.5))
	terrain.data.import_images([height, null, color_map], Vector3.ZERO, 0.0, 1.0)
	var assets := Terrain3DAssets.new()
	var colors := [Color(0.32, 0.43, 0.23, 0.5), Color(0.49, 0.40, 0.27, 0.5), Color(0.43, 0.45, 0.44, 0.5)]
	for index in 3:
		var texture := Terrain3DTextureAsset.new()
		texture.name = ["Grass", "Earth", "Stone"][index]
		texture.albedo_texture = _texture(colors[index], ["grass", "earth", "stone"][index])
		texture.normal_texture = _texture(Color(0.5, 0.5, 1.0, 1.0), "flat_normal")
		texture.uv_scale = 0.25
		assets.set_texture(index, texture)
	DirAccess.make_dir_recursive_absolute(DIRECTORY + "/data")
	var error := ResourceSaver.save(assets, DIRECTORY + "/assets.tres")
	if error != OK:
		push_error("Cannot save island assets: %s" % error_string(error))
		quit(1)
		return
	for z in SIZE:
		for x in SIZE:
			var h := _height(x, z)
			var slope := Vector2((_height(x + 1, z) - _height(x - 1, z)) * 0.5, (_height(x, z + 1) - _height(x, z - 1)) * 0.5).length()
			var pos := Vector3(x, 0, z)
			var beach := 1.0 - smoothstep(1.0, 3.8, h)
			var rock := maxf(smoothstep(0.38, 0.95, slope), smoothstep(24.0, 34.0, h) * 0.7)
			rock *= smoothstep(2.5, 7.0, h)
			terrain.data.set_control_base_id(pos, 0)
			terrain.data.set_control_overlay_id(pos, 2 if rock > 0.05 else 1)
			terrain.data.set_control_blend(pos, rock if rock > 0.05 else beach)
	terrain.data.update_maps()
	terrain.data.save_directory(DIRECTORY + "/data")
	print("ISLAND SAVED: regions=", terrain.data.get_region_count(), " range=", terrain.data.get_height_range(), " spawn=", terrain.data.get_height(Vector3(128, 0, 180)))
	world.queue_free()
	await process_frame
	quit()
