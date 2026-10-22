extends SceneTree
## OFFLINE authoring only. Replaces later sculpting; normal play loads saved data.

const DIRECTORY := "res://scenes/island"
const BACKUP := DIRECTORY + "/backups/task_7_6/terrain3d_00_00.res"
const BACKUP_SHA256 := "6e384434cfcb55b0d22e4443734e118380cfe48b434742de4323d8fa13a38f9d"
const SIZE := 1024
const FIELD_SIZE := 513
# Uneven landmark spacing: deep northern gulf, sheltered western inlet,
# long eastern coast and broad southern peninsula. No alternating scallops.
const COAST := [Vector2(145, 135), Vector2(265, 62), Vector2(420, 72), Vector2(495, 112), Vector2(515, 205), Vector2(575, 225), Vector2(665, 145), Vector2(760, 125), Vector2(860, 175), Vector2(900, 295), Vector2(875, 390), Vector2(940, 500), Vector2(915, 610), Vector2(865, 690), Vector2(900, 800), Vector2(835, 915), Vector2(695, 940), Vector2(565, 905), Vector2(490, 945), Vector2(335, 920), Vector2(200, 865), Vector2(140, 770), Vector2(110, 660), Vector2(185, 580), Vector2(210, 525), Vector2(165, 490), Vector2(68, 435), Vector2(72, 300), Vector2(115, 230)]
const LAKE := [Vector2(456, 468), Vector2(466, 405), Vector2(489, 385), Vector2(546, 390), Vector2(585, 410), Vector2(630, 440), Vector2(637, 485), Vector2(608, 510), Vector2(575, 520), Vector2(550, 552), Vector2(514, 562), Vector2(478, 540), Vector2(478, 507), Vector2(457, 493)]
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
	if FileAccess.get_sha256(DIRECTORY + "/data/terrain3d_00_00.res") != BACKUP_SHA256:
		push_error("Full-island V7 rebuild refused: active data contains later terrain edits. Use the guarded local refine_island.gd workflow instead.")
		quit(1)
		return
	if not "--write-island-v7" in OS.get_cmdline_user_args() or FileAccess.get_sha256(BACKUP) != BACKUP_SHA256:
		push_error("Rebuild requires -- --write-island-v7 and the unchanged Task 7.6 native backup. Later sculpting WILL be replaced.")
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
		# Round just the exposed crest's central few meters, retaining definition.
		var rounded_distance := sqrt(distance * distance + 36.0) - 6.0
		var q := clampf(rounded_distance / width, 0, 1)
		# The low northern rim and foothills need rounded tops; only the high
		# mountain crests retain the sharper cross-section of an exposed ridge.
		var profile := lerpf(1.0 - smoothstep(0, 1, q), pow(1 - q, 2.1), smoothstep(25, 50, elevation))
		result = _join(result, elevation * profile)
	return result


func _hill(p: Vector2, center: Vector2, radii: Vector2, height: float) -> float:
	return height * exp(-((p - center) / radii).length_squared() * 1.8)


func _plateau(p: Vector2, center: Vector2, radii: Vector2, height: float) -> float:
	return height * (1.0 - smoothstep(0.3, 1.35, ((p - center) / radii).length()))


func _rocky_coast(p: Vector2) -> float:
	var weight := maxf(_hill(p, Vector2(885, 285), Vector2(65, 100), 1), _hill(p, Vector2(72, 380), Vector2(42, 100), 1))
	weight = maxf(weight, _hill(p, Vector2(890, 795), Vector2(50, 65), 1))
	weight = maxf(weight, _hill(p, Vector2(280, 65), Vector2(95, 48), 1))
	return maxf(weight, _hill(p, Vector2(940, 500), Vector2(55, 105), 1))


func _height(x: int, z: int) -> float:
	var p := Vector2(x, z)
	var shore := _shore(x, z)
	if shore < -120:
		return -8.0
	# Authored coastal sectors give narrow northern/eastern beaches and broad
	# western/southern bays, rather than a uniform sandy ribbon around the map.
	var beach_width := 27.0 + _hill(p, Vector2(200, 830), Vector2(140, 100), 58)
	beach_width += _hill(p, Vector2(210, 525), Vector2(70, 115), 55)
	beach_width += _hill(p, Vector2(510, 940), Vector2(150, 75), 70)
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
	# Connected basal uplands carry the massifs into the rest of the island.
	var uplands := _hill(p, Vector2(285, 330), Vector2(190, 245), 18)
	uplands += _hill(p, Vector2(760, 465), Vector2(175, 220), 16)
	uplands += _ridge(p, [Vector3(340, 24, 485), Vector3(350, 19, 585), Vector3(300, 11, 660), Vector3(240, 0, 710)], 165)
	uplands += _ridge(p, [Vector3(730, 25, 610), Vector3(705, 23, 700), Vector3(660, 11, 775), Vector3(625, 0, 830)], 155)
	# Deliberately different medium-scale landscapes, rather than isolated bumps.
	var hills := _plateau(p, Vector2(285, 745), Vector2(145, 110), 15)
	hills += _ridge(p, [Vector3(245, 0, 810), Vector3(355, 23, 835), Vector3(430, 16, 805), Vector3(485, 0, 815)], 125)
	hills += _ridge(p, [Vector3(875, 0, 750), Vector3(805, 27, 810), Vector3(705, 19, 863), Vector3(640, 0, 890)], 125)
	hills += _plateau(p, Vector2(810, 280), Vector2(95, 125), 13)
	hills += _plateau(p, Vector2(645, 255), Vector2(95, 85), 12)
	hills += _hill(p, Vector2(195, 180), Vector2(95, 90), 10)
	hills += _hill(p, Vector2(690, 570), Vector2(115, 85), 10)
	hills += _hill(p, Vector2(435, 600), Vector2(95, 95), 8)
	hills -= _ridge(p, [Vector3(235, 0, 675), Vector3(325, 5, 710), Vector3(400, 4, 745), Vector3(460, 0, 760)], 52)
	hills -= _hill(p, Vector2(810, 720), Vector2(95, 65), 4)
	# Keep a broad, gently meandering valley between the regional uplands.
	var valley_x := 520.0 + 18.0 * sin((z - 400.0) / 210.0)
	var valley := exp(-pow((x - valley_x) / 105.0, 4))
	valley *= smoothstep(300, 400, z) * (1.0 - smoothstep(760, 870, z))
	var regional := (uplands + hills) * (1.0 - valley * 0.82)
	var h := base + (mountains + _ridge(p, NORTH, 140) + regional) * inland
	# The rising outside profile rejoins existing heights before these margins.
	# Unlike blending toward a flat shelf, it does not excavate mountain faces.
	if x > 320 and x < 760 and z > 290 and z < 680:
		var d := _signed_distance(p, lake_polygon)
		lake_distances[z * SIZE + x] = d
		var bank := maxf(-d, 0)
		var basin := 5.0 - 3.2 * tanh(d / 12) if d >= 0 else 5.0 + 0.18 * bank + 0.005 * bank * bank
		var islet := _plateau(p, Vector2(538, 488), Vector2(24, 16), 5.6)
		islet += _hill(p, Vector2(552, 482), Vector2(12, 13), 1.1)
		if d >= 0:
			h = basin + islet
		else:
			# Smooth minimum only lowers the ground where the rising basin cuts
			# into it. Open valley ground and the ridge crests remain untouched.
			var rounding := minf(2.0, bank * 0.2)
			var overlap := maxf(rounding - absf(h - basin), 0)
			var lowered := minf(h, basin) - overlap * overlap / maxf(4 * rounding, 0.0001)
			h = lerpf(h, lowered, 1.0 - smoothstep(18, 65, bank))
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
	print("V7 controlled polish: expanded lake basin and walkable islet; selected broader beaches; preserved massifs and uplands")
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
	print("ISLAND V7 SAVED: regions=", terrain.data.get_region_count(), " range=", terrain.data.get_height_range(), " spawn=", terrain.data.get_height(Vector3(500, 0, 650)))
	world.queue_free()
	await process_frame
	quit()
