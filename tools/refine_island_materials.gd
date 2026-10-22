extends SceneTree
## Explicit offline material pass. Does not write or resample a single height.

const BASE := "res://scenes/island/backups/task_8_0"
const DATA := "res://scenes/island/data"
const STAGE := "res://.godot/island_material_stage"
const SIZE := 768
var height: Image
var rock := PackedFloat32Array()


func _initialize() -> void:
	if not "--materials-v81" in OS.get_cmdline_user_args():
		push_error("Offline only: requires -- --materials-v81 and unchanged Task 8.0 backup.")
		quit(1)
		return
	for file in DirAccess.get_files_at(DATA):
		if file.ends_with(".res") and FileAccess.get_sha256(DATA + "/" + file) != FileAccess.get_sha256(BASE + "/data/" + file):
			push_error("Active region differs from Task 8.0 backup; refusing to overwrite later painting/sculpting.")
			quit(1)
			return
	_run.call_deferred()


func _tile_noise(noise: FastNoiseLite, x: float, y: float) -> float:
	# Periodic crossfade: values and first derivatives agree at tile edges.
	var u := smoothstep(0, 1, x / 128.0)
	var v := smoothstep(0, 1, y / 128.0)
	return lerpf(lerpf(noise.get_noise_2d(x, y), noise.get_noise_2d(x - 128, y), u), lerpf(noise.get_noise_2d(x, y - 128), noise.get_noise_2d(x - 128, y - 128), u), v)


func _textures() -> void:
	var colors := [Color(0.31, 0.37, 0.235), Color(0.38, 0.32, 0.245), Color(0.405, 0.42, 0.405), Color(0.49, 0.455, 0.365)]
	var names := ["grass", "earth", "stone", "sand"]
	var noise := FastNoiseLite.new()
	noise.seed = 8102
	noise.frequency = 0.055
	noise.fractal_octaves = 3
	for i in 4:
		var image := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
		for y in 128:
			for x in 128:
				var variation := _tile_noise(noise, x, y) * 0.025 + _tile_noise(noise, x, y) * 0.004 * sin(TAU * x / 8.0) * sin(TAU * y / 8.0)
				var base: Color = colors[i]
				image.set_pixel(x, y, Color(base.r + variation, base.g + variation, base.b + variation, 0.5))
		image.generate_mipmaps()
		assert(ResourceSaver.save(ImageTexture.create_from_image(image), "res://scenes/island/" + names[i] + ".res") == OK)
	var normal := Image.create_empty(128, 128, false, Image.FORMAT_RGBA8)
	# Terrain3D packs roughness in normal alpha. A matte, flat normal needs no
	# invented high-frequency bump detail and remains stable at oblique angles.
	normal.fill(Color(0.5, 0.5, 1, 0.96))
	normal.generate_mipmaps()
	assert(ResourceSaver.save(ImageTexture.create_from_image(normal), "res://scenes/island/flat_normal.res") == OK)


func _slope(x: int, z: int) -> float:
	return Vector2(height.get_pixel(mini(x + 2, SIZE - 1), z).r - height.get_pixel(maxi(x - 2, 0), z).r, height.get_pixel(x, mini(z + 2, SIZE - 1)).r - height.get_pixel(x, maxi(z - 2, 0)).r).length() * 0.25


func _run() -> void:
	height = Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RF)
	rock.resize(SIZE * SIZE)
	var regions: Array[Terrain3DRegion] = []
	for z in 3:
		for x in 3:
			var region := load(DATA + "/terrain3d_%02d_%02d.res" % [x, z]) as Terrain3DRegion
			assert(region != null)
			# Standalone ResourceLoader does not infer locations from filenames;
			# Terrain3DData.load_directory normally supplies these coordinates.
			region.set_location(Vector2i(x, z))
			regions.append(region)
			height.blit_rect(region.get_height_map(), Rect2i(0, 0, 256, 256), Vector2i(x, z) * 256)
			var bytes := region.get_control_map().get_data()
			for j in 256:
				for i in 256:
					var bits := bytes.decode_u32((j * 256 + i) * 4)
					var blend := float((bits >> 14) & 255) / 255.0
					rock[(z * 256 + j) * SIZE + x * 256 + i] = (1 - blend if (bits >> 27) & 31 == 2 else 0.0) + (blend if (bits >> 22) & 31 == 2 else 0.0)
	# Feather existing rock masks, not the terrain. Preserve mountain identity.
	for pass_index in 6:
		var next := rock.duplicate()
		for z in range(2, SIZE - 2):
			for x in range(2, SIZE - 2):
				var index := z * SIZE + x
				next[index] = (rock[index] * 4 + rock[index - 2] + rock[index + 2] + rock[index - SIZE * 2] + rock[index + SIZE * 2]) / 8.0
		rock = next
	var noise := FastNoiseLite.new()
	noise.seed = 814
	noise.frequency = 0.018
	DirAccess.make_dir_recursive_absolute(STAGE)
	var painted := 0
	for region in regions:
		var origin := region.get_location() * 256
		var bytes := region.get_control_map().get_data()
		for j in 256:
			for i in 256:
				var x := origin.x + i
				var z := origin.y + j
				var h := height.get_pixel(x, z).r
				var slope := _slope(x, z)
				var variation := noise.get_noise_2d(x, z)
				var rock_weight := maxf(rock[z * SIZE + x] * 0.88, smoothstep(0.55, 1.25, slope))
				var water := 5.0 if x >= 309 and x <= 519 and z >= 257 and z <= 447 else 0.0
				var sand_weight := (1 - smoothstep(-0.3, 2.0 + variation * 2.0, h - water)) * (1 - smoothstep(0.18, 0.75, slope))
				var earth_weight := (0.09 + smoothstep(0.16, 0.6, slope) * 0.38 + maxf(variation, 0) * 0.25) * (1 - rock_weight) * (1 - sand_weight)
				var weights := [maxf(0, 1 - rock_weight - sand_weight - earth_weight), earth_weight, rock_weight, sand_weight]
				var first := 0
				var second := 1
				for id in 4:
					if weights[id] > weights[first]:
						first = id
				second = 1 if first == 0 else 0
				for id in 4:
					if id != first and weights[id] > weights[second]:
						second = id
				var fraction := float(weights[second]) / maxf(weights[first] + weights[second], 0.001)
				# The native shader raises height-weighted blends to at least the
				# eighth power even at sharpness=0. Compensate in authored masks,
				# rather than replacing its shader with a second blending system.
				var blend := roundi(255 * (0.5 + (fraction - 0.5) * 0.55)) if fraction > 0.01 else 0
				var offset := (j * 256 + i) * 4
				var old := bytes.decode_u32(offset)
				# Preserve hole/navigation, scale and orientation bits. Disable auto
				# paint: these are persistent editable native base/overlay weights.
				var bits := (old & 0x3ffe) | (first << 27) | (second << 22) | (blend << 14)
				painted += int(bits != old)
				bytes.encode_u32(offset, bits)
		region.set_control_map(Image.create_from_data(256, 256, false, Image.FORMAT_RF, bytes))
		assert(ResourceSaver.save(region, STAGE + "/terrain3d_%02d_%02d.res" % [region.get_location().x, region.get_location().y]) == OK)
	# Staging must reload byte-identical heights before touching active data.
	for region in regions:
		var file := "/terrain3d_%02d_%02d.res" % [region.get_location().x, region.get_location().y]
		var saved := ResourceLoader.load(STAGE + file, "", ResourceLoader.CACHE_MODE_IGNORE) as Terrain3DRegion
		assert(saved.get_height_map().get_data() == region.get_height_map().get_data())
		assert(saved.get_control_map().get_data() == region.get_control_map().get_data())
	_textures()
	for region in regions:
		assert(ResourceSaver.save(region, DATA + "/terrain3d_%02d_%02d.res" % [region.get_location().x, region.get_location().y]) == OK)
	print("MATERIAL PASS: nine regions staged/reloaded, heights unchanged, %d control cells refined, four 128px matte textures." % painted)
	quit()
