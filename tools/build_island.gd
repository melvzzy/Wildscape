extends SceneTree
## OFFLINE authoring only. Replaces later sculpting; normal play loads saved data.

const DIRECTORY := "res://scenes/island"
const BACKUP := DIRECTORY + "/backups/task_7_4/terrain3d_00_00.res"
const BACKUP_SHA256 := "d3bdc823b65eab7de7fbecc5785a03e6a7d83ed5bff82f117f1688418622c99e"
const SIZE := 1024
const FIELD_SIZE := 513
# Authored coastline, in meters: western coves, northern fingers, eastern
# headlands and broad southern beaches. Not a noisy radial circle.
const COAST := [Vector2(200, 100), Vector2(290, 82), Vector2(352, 130), Vector2(415, 70), Vector2(495, 90), Vector2(550, 152), Vector2(645, 120), Vector2(710, 165), Vector2(712, 238), Vector2(800, 255), Vector2(838, 325), Vector2(775, 385), Vector2(850, 445), Vector2(870, 520), Vector2(815, 582), Vector2(888, 650), Vector2(850, 728), Vector2(775, 745), Vector2(748, 820), Vector2(655, 860), Vector2(594, 825), Vector2(525, 883), Vector2(440, 865), Vector2(395, 810), Vector2(315, 840), Vector2(245, 785), Vector2(220, 715), Vector2(150, 705), Vector2(130, 640), Vector2(190, 578), Vector2(110, 520), Vector2(125, 435), Vector2(205, 393), Vector2(150, 320), Vector2(187, 250), Vector2(155, 185)]
const LAKE := [Vector2(490, 500), Vector2(510, 480), Vector2(543, 485), Vector2(561, 475), Vector2(580, 492), Vector2(574, 515), Vector2(587, 537), Vector2(560, 555), Vector2(535, 550), Vector2(510, 571), Vector2(485, 552), Vector2(497, 531), Vector2(478, 518)]
# (X, elevation above lowland, Z). Uneven crests and branching spurs.
const WEST := [Vector3(320, 0, 180), Vector3(350, 58, 250), Vector3(304, 84, 326), Vector3(342, 69, 382), Vector3(316, 65, 442), Vector3(352, 40, 510), Vector3(330, 0, 585)]
const WEST_OUTER := [Vector3(304, 73, 326), Vector3(255, 41, 366), Vector3(222, 19, 425), Vector3(240, 0, 475)]
const WEST_INNER := [Vector3(342, 57, 382), Vector3(395, 29, 426), Vector3(432, 9, 475), Vector3(462, 0, 510)]
const WEST_SOUTH := [Vector3(316, 42, 442), Vector3(275, 23, 492), Vector3(290, 0, 560)]
const EAST := [Vector3(708, 0, 350), Vector3(734, 39, 412), Vector3(705, 67, 480), Vector3(748, 40, 532), Vector3(708, 56, 586), Vector3(732, 23, 638), Vector3(680, 0, 700)]
const EAST_INNER := [Vector3(705, 58, 480), Vector3(655, 30, 455), Vector3(610, 8, 405), Vector3(576, 0, 378)]
const EAST_OUTER := [Vector3(708, 49, 586), Vector3(777, 22, 610), Vector3(810, 0, 650)]
const NORTH := [Vector3(390, 0, 235), Vector3(435, 14, 255), Vector3(510, 21, 222), Vector3(570, 13, 270), Vector3(635, 0, 320)]
var noise := FastNoiseLite.new()
var coast_field := PackedFloat32Array()
var lake_polygon := PackedVector2Array()
var lake_distances := PackedFloat32Array()


func _initialize() -> void:
	if not "--write-island-v5" in OS.get_cmdline_user_args() or FileAccess.get_sha256(BACKUP) != BACKUP_SHA256:
		push_error("Rebuild requires -- --write-island-v5 and the unchanged Task 7.4 native backup. Later sculpting WILL be replaced.")
		quit(1)
		return
	_build.call_deferred()


func _outline(points: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for i in points.size():
		var a: Vector2 = points[posmod(i - 1, points.size())]
		var b: Vector2 = points[i]
		var c: Vector2 = points[(i + 1) % points.size()]
		var d: Vector2 = points[(i + 2) % points.size()]
		for step in 6:
			var t := step / 6.0
			result.append(0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t * t + (-a + 3 * b - 3 * c + d) * t * t * t))
	return result


func _signed_distance(p: Vector2, polygon: PackedVector2Array) -> float:
	var distance := INF
	var inside := false
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		var segment := b - a
		var t := clampf((p - a).dot(segment) / segment.length_squared(), 0, 1)
		distance = minf(distance, p.distance_squared_to(a + segment * t))
		# Half-open crossings avoid a reproducible native containment false
		# negative at (302, 738), which otherwise creates an isolated 18 m pit
		# when interpolating the coast field. Keep this offline only.
		if (a.y > p.y) != (b.y > p.y):
			if p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x:
				inside = not inside
	return sqrt(distance) * (1 if inside else -1)


func _shore(x: int, z: int) -> float:
	var ix := x / 2
	var iz := z / 2
	return lerpf(lerpf(coast_field[iz * FIELD_SIZE + ix], coast_field[iz * FIELD_SIZE + ix + 1], (x % 2) / 2.0), lerpf(coast_field[(iz + 1) * FIELD_SIZE + ix], coast_field[(iz + 1) * FIELD_SIZE + ix + 1], (x % 2) / 2.0), (z % 2) / 2.0)


func _join(a: float, b: float, smoothing: float = 5.0) -> float:
	# Rounded union removes max() creases at segment/spur intersections. Its
	# support shrinks to zero at the feet, so empty plains are never lifted.
	var k := minf(smoothing, minf(a, b) * 0.7)
	if k <= 0.0001:
		return maxf(a, b)
	return maxf(a, b) + pow(maxf(k - absf(a - b), 0), 2) / (4 * k)


func _ridge(p: Vector2, points: Array, width: float) -> float:
	var result := 0.0
	for i in points.size() - 1:
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var start := Vector2(a.x, a.z)
		var segment := Vector2(b.x, b.z) - start
		var t := clampf((p - start).dot(segment) / segment.length_squared(), 0, 1)
		var distance := p.distance_to(start + segment * t)
		# Sharp crest with long convex flanks ending tangentially in the lowlands.
		# Linear crest interpolation had a derivative jump where the projected
		# segment parameter clamps at either end: large triangular normal patches
		# extended across the northern rim and mountain shoulders. Zero endpoint
		# derivatives remove those planes without blurring the whole heightmap.
		var elevation := lerpf(a.y, b.y, smoothstep(0, 1, t))
		var q := clampf(distance / width, 0, 1)
		# The low northern rim and foothills need rounded tops; only the high
		# mountain crests retain the sharper cross-section of an exposed ridge.
		var profile := lerpf(1.0 - smoothstep(0, 1, q), pow(1 - q, 2.1), smoothstep(25, 50, elevation))
		result = _join(result, elevation * profile)
	return result


func _hill(p: Vector2, center: Vector2, radii: Vector2, height: float) -> float:
	return height * exp(-((p - center) / radii).length_squared() * 1.8)


func _rocky_coast(p: Vector2) -> float:
	var weight := maxf(_hill(p, Vector2(805, 265), Vector2(52, 60), 1), _hill(p, Vector2(155, 320), Vector2(42, 55), 1))
	weight = maxf(weight, _hill(p, Vector2(874, 651), Vector2(42, 62), 1))
	weight = maxf(weight, _hill(p, Vector2(280, 90), Vector2(72, 48), 1))
	return maxf(weight, _hill(p, Vector2(850, 500), Vector2(50, 100), 1))


func _height(x: int, z: int) -> float:
	var p := Vector2(x, z)
	var shore := _shore(x, z)
	if shore < -120:
		return -8.0
	# Authored coastal sectors give narrow northern/eastern beaches and broad
	# western/southern bays, rather than a uniform sandy ribbon around the map.
	var beach_width := 27.0 + _hill(p, Vector2(265, 780), Vector2(160, 130), 35)
	beach_width += _hill(p, Vector2(130, 500), Vector2(100, 160), 30)
	beach_width += _hill(p, Vector2(510, 868), Vector2(150, 60), 38)
	var cliff := _rocky_coast(p)
	beach_width = lerpf(beach_width, 13, cliff)
	# A nonzero shoreline grade prevents near-coplanar sea/terrain strips from
	# flickering or turning into long stair-stepped fingers under native LOD.
	var base := 9.0 * tanh(shore / beach_width) if shore >= 0 else 8.0 * tanh(shore / 25.0)
	base += cliff * 13.0 * smoothstep(0, 42, shore)
	var inland := smoothstep(0, 65, shore)
	var warped := p + Vector2(noise.get_noise_2d(x, z), noise.get_noise_2d(x + 1234, z)) * 4.0
	var west := _join(_ridge(warped, WEST, 155), _ridge(warped, WEST_OUTER, 110))
	west = _join(west, _join(_ridge(warped, WEST_INNER, 110), _ridge(warped, WEST_SOUTH, 100)))
	var east := _join(_ridge(warped, EAST, 147), _join(_ridge(warped, EAST_INNER, 105), _ridge(warped, EAST_OUTER, 104)))
	var mountains := maxf(west, east)
	# Relief belongs to mountain faces, never to the entire valley floor.
	mountains *= 1.0 + noise.get_noise_2d(x * 1.8, z * 1.8) * 0.018
	# Different drainage systems break the broad faces into connected shoulders
	# and shallow gullies. These are local cuts, not an island-wide erosion pass.
	var west_gully := _ridge(p, [Vector3(286, 0, 340), Vector3(263, 7, 400), Vector3(280, 6, 470), Vector3(250, 0, 550)], 24)
	west_gully = maxf(west_gully, _ridge(p, [Vector3(335, 0, 350), Vector3(378, 8, 404), Vector3(408, 5, 455), Vector3(440, 0, 515)], 26))
	var east_gully := _ridge(p, [Vector3(730, 0, 440), Vector3(687, 7, 520), Vector3(665, 5, 570), Vector3(650, 0, 630)], 25)
	east_gully = maxf(east_gully, _ridge(p, [Vector3(750, 0, 480), Vector3(789, 6, 518), Vector3(800, 0, 572)], 22))
	mountains -= maxf(west_gully, east_gully) * smoothstep(3, 20, mountains)
	var hills := _hill(p, Vector2(302, 657), Vector2(100, 115), 11)
	hills += _hill(p, Vector2(720, 747), Vector2(90, 70), 7)
	hills += _hill(p, Vector2(575, 325), Vector2(110, 75), 7)
	hills += _hill(p, Vector2(416, 650), Vector2(52, 90), 4)
	hills += _hill(p, Vector2(450, 600), Vector2(65, 90), 9)
	hills += _hill(p, Vector2(625, 670), Vector2(90, 58), 14)
	hills += _hill(p, Vector2(610, 770), Vector2(65, 75), 8)
	hills += _hill(p, Vector2(460, 385), Vector2(80, 65), 7)
	hills += _hill(p, Vector2(230, 560), Vector2(75, 50), 13)
	hills += _hill(p, Vector2(730, 300), Vector2(65, 95), 17)
	# Northern upland, western fan, southern terraces and eastern side valley.
	hills += _hill(p, Vector2(625, 230), Vector2(125, 80), 8)
	hills += _hill(p, Vector2(440, 155), Vector2(95, 60), 4)
	hills += _hill(p, Vector2(355, 560), Vector2(90, 95), 7)
	hills += _hill(p, Vector2(675, 665), Vector2(115, 85), 6)
	hills += _hill(p, Vector2(455, 772), Vector2(135, 50), 3)
	hills -= _hill(p, Vector2(340, 725), Vector2(100, 65), 3.2)
	hills -= _hill(p, Vector2(719, 705), Vector2(70, 48), 4.0)
	hills -= _hill(p, Vector2(550, 365), Vector2(45, 90), 2.5)
	var h := base + (mountains + _ridge(p, NORTH, 130) + hills) * inland
	if x > 400 and x < 660 and z > 400 and z < 650:
		var d := _signed_distance(p, lake_polygon)
		lake_distances[z * SIZE + x] = d
		var basin := 5.0 - 3.2 * tanh(d / 12) if d >= 0 else 5.0 + 4.0 * tanh(-d / 28)
		var blend := 1.0 - smoothstep(0, 65, -d)
		var islet := _hill(p, Vector2(536, 524), Vector2(12, 6.5), 5.7)
		islet += _hill(p, Vector2(543, 521), Vector2(5, 8), 3.2)
		h = lerpf(h, basin + islet, blend)
	return h


func _build() -> void:
	noise.seed = 74019
	noise.frequency = 0.018
	noise.fractal_octaves = 2
	var polygon := _outline(COAST)
	lake_polygon = _outline(LAKE)
	coast_field.resize(FIELD_SIZE * FIELD_SIZE)
	lake_distances.resize(SIZE * SIZE)
	lake_distances.fill(-INF)
	for z in FIELD_SIZE:
		for x in FIELD_SIZE:
			coast_field[z * FIELD_SIZE + x] = _signed_distance(Vector2(x * 2, z * 2), polygon)
	print("V5 regional quality pass: coastline, mountain shoulders, lowlands, lake")
	var height := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RF)
	var colors := Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	for z in SIZE:
		for x in SIZE:
			height.set_pixel(x, z, Color(_height(x, z), 0, 0))
			var shade := 0.96 + noise.get_noise_2d(x, z) * 0.035
			colors.set_pixel(x, z, Color(shade, shade, shade, 0.5))
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
	terrain.data.import_images([height, null, colors], Vector3.ZERO, 0, 1)
	for z in SIZE:
		for x in SIZE:
			var h := height.get_pixel(x, z).r
			# Broad paint gradients follow landforms, not single-pixel normal noise.
			var slope := Vector2(height.get_pixel(mini(x + 3, SIZE - 1), z).r - height.get_pixel(maxi(x - 3, 0), z).r, height.get_pixel(x, mini(z + 3, SIZE - 1)).r - height.get_pixel(x, maxi(z - 3, 0)).r).length() / 6.0
			var sand := 1.0 - smoothstep(1.8, 5.0, h)
			var lake_distance := lake_distances[z * SIZE + x]
			if is_finite(lake_distance):
				# Signed-distance banks avoid the old rectangular paint mask and
				# avoid painting a sand ring on the grass-topped central islet.
				sand = maxf(sand, (1.0 - smoothstep(5.0, 8.0, h)) * (1.0 - smoothstep(2, 16, lake_distance)))
			var rock := maxf(smoothstep(0.4, 0.95, slope), smoothstep(48, 85, h) * 0.85) * smoothstep(3, 9, h)
			if not is_finite(lake_distance):
				rock = maxf(rock, _rocky_coast(Vector2(x, z)) * (1.0 - smoothstep(10, 40, _shore(x, z))))
			sand *= 1.0 - rock
			var grass := maxf(0, 1.0 - sand - rock)
			var point := Vector3(x, 0, z)
			# Keep the two strongest weights, rather than abruptly changing the
			# overlay ID as soon as rock exceeds 5%, which erased sandy shores.
			if grass <= minf(sand, rock):
				terrain.data.set_control_base_id(point, 1)
				terrain.data.set_control_overlay_id(point, 2)
				terrain.data.set_control_blend(point, rock / maxf(sand + rock, 0.0001))
			else:
				terrain.data.set_control_base_id(point, 0)
				terrain.data.set_control_overlay_id(point, 2 if rock > sand else 1)
				terrain.data.set_control_blend(point, maxf(rock, sand) / maxf(grass + maxf(rock, sand), 0.0001))
	terrain.data.update_maps()
	terrain.data.save_directory(DIRECTORY + "/data")
	print("ISLAND V5 SAVED: regions=", terrain.data.get_region_count(), " range=", terrain.data.get_height_range(), " spawn=", terrain.data.get_height(Vector3(500, 0, 650)))
	world.queue_free()
	await process_frame
	quit()
