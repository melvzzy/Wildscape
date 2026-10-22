extends SceneTree
## Native world-source/model checks plus real camera rays and E input.

class Collector extends Node3D:
	var inventory: SlotInventory

	func get_inventory() -> SlotInventory:
		return inventory

class InvalidCollector extends Node3D:
	func get_inventory() -> int:
		return 3

var checks: int = 0
var failures: int = 0
var elapsed: float = 0.0
var fixture: Node3D
var actor: Collector
var catalog: ItemCatalog
var player: CharacterBody3D
var interactor: Node


func _initialize() -> void:
	_run.call_deferred()


func _process(delta: float) -> bool:
	elapsed += delta
	if elapsed > 35:
		push_error("FAIL: world collection timeout")
		quit(1)
	return false


func _frames(count: int = 5) -> void:
	for frame in range(count):
		await physics_frame
	await process_frame


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _source(id: StringName, quantity: int, gathering: bool = false) -> WorldItemSource:
	var path := "res://scenes/interaction/gathering_source.tscn" if gathering else "res://scenes/interaction/world_pickup.tscn"
	var source: WorldItemSource = load(path).instantiate()
	source.item_id = id
	source.quantity = quantity
	source.position = Vector3(60, 0, fixture.get_child_count() * 2)
	fixture.add_child(source)
	return source


func _conserved(source: WorldItemSource, before: int, original: int) -> bool:
	return actor.inventory.count_item(source.item_id) - before + source.quantity == original


func _models() -> void:
	fixture = Node3D.new()
	root.add_child(fixture)
	actor = Collector.new()
	fixture.add_child(actor)
	catalog = ItemCatalog.new([load("res://data/items/test_alpha.tres"), load("res://data/items/test_beta.tres"), load("res://data/items/test_gamma.tres"), load("res://data/items/test_delta.tres")])
	actor.inventory = SlotInventory.new(catalog)
	var source := _source(&"test_alpha", 17)
	_check(source.can_interact(actor) and "Test Alpha" in source.get_prompt(), "source resolves stable ID and display name through recipient catalog")
	source.interact(actor)
	_check(actor.inventory.count_item(&"test_alpha") == 17 and source.quantity == 0 and source.is_queued_for_deletion(), "complete pickup adds actual quantity and queues removal")
	_check(actor.inventory.get_stack(0).quantity == 10 and actor.inventory.get_stack(1).quantity == 7, "pickup respects static stack limit")
	_check(_conserved(source, 0, 17), "complete pickup conserves world plus inventory quantity")
	source.interact(actor)
	_check(actor.inventory.count_item(&"test_alpha") == 17 and not source.can_interact(actor), "queued pickup cannot be collected twice in the same frame")
	actor.inventory = SlotInventory.new(catalog, 1, 1)
	source = _source(&"test_alpha", 17)
	source.interact(actor)
	_check(actor.inventory.count_item(&"test_alpha") == 10 and source.quantity == 7 and not source.is_queued_for_deletion(), "partial pickup leaves precisely the unaccepted seven in world")
	_check(_conserved(source, 0, 17), "partial pickup conserves all quantities")
	var notifications := [0]
	actor.inventory.changed.connect(func() -> void: notifications[0] += 1)
	source.interact(actor)
	_check(source.quantity == 7 and actor.inventory.count_item(&"test_alpha") == 10 and notifications[0] == 0, "full inventory leaves source and model unchanged without notification")
	_check(source.can_interact(actor) and "No room" in source.get_prompt(), "no-space feedback remains in existing interaction prompt")
	actor.inventory.remove_from_slot(0, 3)
	source.interact(actor)
	_check(source.quantity == 4 and actor.inventory.get_stack(0).quantity == 10 and not "No room" in source.get_prompt(), "retry fills only available stack space and clears failure feedback")
	actor.inventory.remove_from_slot(0, 10)
	source.interact(actor)
	_check(source.quantity == 0 and actor.inventory.count_item(&"test_alpha") == 4 and source.is_queued_for_deletion(), "remaining pickup completes after space is freed")
	actor.inventory = SlotInventory.new(catalog, 2, 1)
	source = _source(&"test_beta", 6)
	source.interact(actor)
	_check(source.quantity == 1 and actor.inventory.count_item(&"test_beta") == 5 and actor.inventory.get_stack(0).rotated, "multi-cell pickup uses automatic rotation into a 2x1 grid and stack limit five")
	_check(actor.inventory.get_anchor_at(1) == 0 and _conserved(source, 0, 6), "rotated footprint covers both cells and preserves the remainder")
	actor.inventory.remove_from_slot(0, 1)
	source.interact(actor)
	_check(source.quantity == 0 and actor.inventory.get_stack(0).quantity == 5, "pickup merges into an existing rotated multi-cell stack")
	actor.inventory = SlotInventory.new(catalog, 3, 2)
	source = _source(&"test_delta", 1)
	source.interact(actor)
	_check(source.quantity == 0 and actor.inventory.get_stack(0).rotated and actor.inventory.get_anchor_at(5) == 0, "2x3 item rotates to occupy a 3x2 grid without alternate placement rules")
	actor.inventory = SlotInventory.new(catalog, 3, 3)
	for y in range(3):
		actor.inventory.add_at(&"test_alpha", 10, Vector2i(1, y))
	source = _source(&"test_delta", 1)
	source.interact(actor)
	_check(source.quantity == 1 and actor.inventory.count_item(&"test_delta") == 0, "fragmented free cells cannot accept an unfitting large item")
	actor.inventory = SlotInventory.new(catalog)
	for id in [&"", &"unknown_item"]:
		source = _source(id, 4)
		source.interact(actor)
		_check(not source.can_interact(actor) and source.quantity == 4 and not source.is_queued_for_deletion(), "invalid item ID safely rejects: '%s'" % id)
	for amount in [0, -1, -100]:
		source = _source(&"test_alpha", amount)
		source.interact(actor)
		_check(not source.can_interact(actor) and source.quantity == amount and actor.inventory.count_item(&"test_alpha") == 0, "invalid authored quantity safely rejects: %d" % amount)
	source = _source(&"test_alpha", 2)
	var unsupported := Node3D.new()
	fixture.add_child(unsupported)
	source.interact(unsupported)
	source.interact(null)
	_check(source.quantity == 2 and not source.can_interact(unsupported), "missing inventory receiver and null actor fail without mutation")
	var invalid_receiver := InvalidCollector.new()
	fixture.add_child(invalid_receiver)
	source.interact(invalid_receiver)
	_check(source.quantity == 2 and not source.can_interact(invalid_receiver), "wrong inventory getter return type is safely rejected")
	actor.inventory = SlotInventory.new(null)
	source.interact(actor)
	_check(source.quantity == 2 and not source.can_interact(actor), "invalid recipient inventory fails safely")
	actor.inventory = SlotInventory.new(ItemCatalog.new([load("res://data/items/test_beta.tres")]))
	source.interact(actor)
	_check(source.quantity == 2 and not source.can_interact(actor), "item must exist in recipient's catalog")
	actor.inventory = SlotInventory.new(catalog, 1, 1)
	actor.inventory.add(&"test_alpha", 8)
	source = _source(&"test_alpha", 24, true)
	source.interact(actor)
	_check(source.quantity == 22 and actor.inventory.count_item(&"test_alpha") == 10 and not source.is_queued_for_deletion(), "gathering shares safe partial insertion logic")
	var removed := 0
	while source.quantity > 0:
		removed += actor.inventory.remove(&"test_alpha", 10)
		source.interact(actor)
	_check(source.quantity == 0 and not source.interaction_enabled and not source.is_queued_for_deletion(), "finite resource stays in world but disables interaction on depletion")
	_check(actor.inventory.count_item(&"test_alpha") + removed == 32 and source.state_label.text == "DEPLETED", "depletion is visible and resource plus original stack conserve quantity")
	var count := actor.inventory.count_item(&"test_alpha")
	for repeat in range(5):
		source.interact(actor)
	_check(actor.inventory.count_item(&"test_alpha") == count and source.quantity == 0, "depleted resource cannot produce more items")
	actor.inventory = SlotInventory.new(catalog)
	var second := Collector.new()
	second.inventory = SlotInventory.new(catalog)
	fixture.add_child(second)
	source = _source(&"test_alpha", 17)
	var locked_source := source
	var reentries := [0]
	var callback := func() -> void:
		reentries[0] += 1
		locked_source.interact(actor)
		locked_source.interact(second)
	actor.inventory.changed.connect(callback)
	source.interact(actor)
	_check(reentries[0] == 1 and source.quantity == 0 and actor.inventory.count_item(&"test_alpha") == 17 and second.inventory.count_item(&"test_alpha") == 0, "synchronous inventory observers cannot recursively or concurrently collect the same supply")
	actor.inventory.changed.disconnect(callback)
	actor.inventory = SlotInventory.new(catalog, 1, 1)
	source = _source(&"test_alpha", 17)
	var partial_source := source
	var completed_callbacks := [0]
	source.interacted.connect(func(_actor: Node3D) -> void:
		completed_callbacks[0] += 1
		partial_source.interact(actor)
		partial_source.interact(second)
	)
	source.interact(actor)
	_check(completed_callbacks[0] == 1 and source.quantity == 7 and actor.inventory.count_item(&"test_alpha") == 10 and second.inventory.count_item(&"test_alpha") == 0, "partial collection also locks final interaction observers against recursive collection")
	source.interact(second)
	_check(source.quantity == 0 and actor.inventory.count_item(&"test_alpha") + second.inventory.count_item(&"test_alpha") == 17, "a later collector can safely claim the exact remainder after the first interaction finishes")
	# Mixed transfers, limited spaces, removal and repeated attempts across two
	# collectors. Every quantity is accounted for after every operation.
	actor.inventory = SlotInventory.new(catalog, 3, 3)
	second.inventory = SlotInventory.new(catalog, 3, 2)
	var sources: Array[WorldItemSource] = [_source(&"test_alpha", 27, true), _source(&"test_beta", 13, true), _source(&"test_delta", 3, true)]
	var initial := {&"test_alpha": 27, &"test_beta": 13, &"test_delta": 3}
	var taken := {&"test_alpha": 0, &"test_beta": 0, &"test_delta": 0}
	var random := RandomNumberGenerator.new()
	random.seed = 5105
	var conserved := true
	for step in range(180):
		var receiver := actor if random.randi_range(0, 1) == 0 else second
		var supply := sources[random.randi_range(0, 2)]
		if step % 3 == 0:
			taken[supply.item_id] += receiver.inventory.remove(supply.item_id, random.randi_range(1, 4))
		else:
			supply.interact(receiver)
		for entry in sources:
			conserved = conserved and entry.quantity >= 0 and entry.quantity + actor.inventory.count_item(entry.item_id) + second.inventory.count_item(entry.item_id) + taken[entry.item_id] == initial[entry.item_id]
	_check(conserved, "180 deterministic mixed collection/removal attempts conserve every ID across two inventories and world supplies")
	fixture.queue_free()
	await _frames()


func _place(point: Vector3, first_person: bool) -> void:
	player.reset_to_spawn()
	player.global_position = point
	player.reset_physics_interpolation()
	player.set_first_person(first_person)
	await _frames(12)


func _aim(point: Vector3) -> void:
	var direction := point - (player.global_position + Vector3.UP * 1.62)
	player.camera_yaw.rotation.y = atan2(-direction.x, -direction.z)
	player.camera_pitch.rotation.x = atan2(direction.y, Vector2(direction.x, direction.z).length())
	await _frames()


func _press_e() -> void:
	Input.action_press("interact")
	await _frames(2)
	Input.action_release("interact")
	await _frames(2)


func _capture(name: String) -> void:
	if "--capture-world" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/collection-" + name + ".png")


func _integration() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await _frames(15)
	player = current_scene.get_node("Player")
	interactor = player.get_node("Interaction")
	var menu: Node = current_scene.get_node("Menu")
	var area: Node3D = current_scene.get_node("Playground/CollectionArea")
	var alpha: WorldItemSource = area.get_node("AlphaPickup")
	var beta: WorldItemSource = area.get_node("BetaPickup")
	var gathering: WorldItemSource = area.get_node("GatheringSource")
	_check(player.inventory.count_item(&"test_alpha") == 0 and player.inventory.count_item(&"test_beta") == 0, "normal player still starts empty despite populated world sources")
	if "--capture-world" in OS.get_cmdline_user_args():
		var overview := Camera3D.new()
		current_scene.add_child(overview)
		overview.position = Vector3(10, 5, 23)
		overview.look_at(Vector3(10, 0.8, 15))
		overview.current = true
		await _frames()
		await _capture("playground")
		player.camera.current = true
		overview.queue_free()
	await _place(Vector3(6, 0.05, 19), true)
	await _aim(alpha.global_position + Vector3.UP * 0.25)
	await _press_e()
	_check(interactor.target == null and alpha.quantity == 17 and player.inventory.count_item(&"test_alpha") == 0, "world pickup respects existing eye-distance limit")
	await _place(Vector3(6, 0.05, 16.6), true)
	await _aim(alpha.global_position + Vector3.UP * 0.25)
	_check(interactor.target == alpha and "Test Alpha" in interactor.prompt.text and "17" in interactor.prompt.text, "FPS camera targets pickup through existing named E prompt")
	await _capture("fps-prompt")
	Input.action_press("interact")
	await _frames(15)
	Input.action_release("interact")
	_check(player.inventory.count_item(&"test_alpha") == 17 and not area.has_node("AlphaPickup"), "held E collects exactly once and removes fully collected pickup")
	menu.set_inventory_open(true)
	await _frames()
	_check(paused and menu.inventory_view._inventory == player.inventory and player.inventory.get_stack(0).quantity == 10 and player.inventory.get_stack(1).quantity == 7, "collected items appear in the existing player-owned grid model")
	await _capture("inventory")
	menu.set_inventory_open(false)
	await _frames()
	await _place(Vector3(8.5, 0.05, 16.6), false)
	await _aim(beta.global_position + Vector3.UP * 0.25)
	_check(interactor.target == beta and "Test Beta" in interactor.prompt.text, "TPS shares the same pickup targeting and catalog lookup")
	await _capture("tps-prompt")
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.5, 3, 0.15)
	collision.shape = shape
	wall.add_child(collision)
	current_scene.add_child(wall)
	wall.position = Vector3(8.5, 1.5, 15.8)
	await _frames()
	await _press_e()
	_check(interactor.target == null and beta.quantity == 6 and player.inventory.count_item(&"test_beta") == 0, "wall blocks world collection without any quantity changes")
	wall.queue_free()
	await _frames()
	menu.set_paused(true)
	beta.interact(player)
	await _press_e()
	_check(beta.quantity == 6 and player.inventory.count_item(&"test_beta") == 0 and interactor.target == null, "pause blocks E collection and direct source activation")
	menu.set_paused(false)
	await _frames()
	await _press_e()
	_check(player.inventory.count_item(&"test_beta") == 6 and not area.has_node("BetaPickup"), "TPS pickup inserts real multi-cell stacks and removes source")
	await _place(Vector3(13.5, 0.05, 16.8), true)
	await _aim(gathering.global_position + Vector3.UP * 0.7)
	_check(interactor.target == gathering and "Gather" in interactor.prompt.text, "finite gathering uses the same E interaction contract")
	await _press_e()
	_check(gathering.quantity == 0 and not gathering.interaction_enabled and gathering.state_label.text == "DEPLETED" and player.inventory.count_item(&"test_alpha") == 41, "gathering transfers all 24 available units and leaves a depleted placeholder")
	await _press_e()
	_check(player.inventory.count_item(&"test_alpha") == 41 and interactor.target == null, "repeated E cannot gather from depleted resource")
	await _capture("depleted")
	menu.set_inventory_open(true)
	await _frames()
	await _capture("collected-grid")
	menu.set_inventory_open(false)
	await _frames()
	_check(not paused and player.controls_active and current_scene.get_node("Playground/InteractionArea/Switch").interaction_enabled, "inventory resumes normally and original playground interactables remain intact")


func _run() -> void:
	await _models()
	await _integration()
	print("WORLD COLLECTION RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
