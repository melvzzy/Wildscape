extends SceneTree
## Pure data tests: no player, UI or world required.

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	checks += 1
	if condition:
		print("PASS: ", message)
	else:
		failures += 1
		push_error("FAIL: " + message)


func _definitions() -> Array[ItemDefinition]:
	# Preserve all original quantity/notification assertions as the 1x1 grid case.
	# Production footprints are tested separately in grid_inventory_test.gd.
	var fixtures: Array[ItemDefinition] = []
	for path in ["res://data/items/test_alpha.tres", "res://data/items/test_beta.tres", "res://data/items/test_gamma.tres"]:
		var definition := load(path).duplicate() as ItemDefinition
		definition.grid_size = Vector2i.ONE
		fixtures.append(definition)
	return fixtures


func _run() -> void:
	var definitions := _definitions()
	var catalog := ItemCatalog.new(definitions)
	_check(catalog.is_valid() and catalog.has_item(&"test_alpha") and catalog.has_item(&"test_beta") and catalog.has_item(&"test_gamma"), "three neutral item resources have valid unique IDs")
	for id in ["", "UPPER", "two words", "x-y", "test\n", "_test", "ümlaut", "2item"]:
		var invalid := definitions[0].duplicate() as ItemDefinition
		invalid.item_id = StringName(id)
		_check(not invalid.validation_error().is_empty(), "invalid item ID rejected: " + id.c_escape())
	var invalid := definitions[0].duplicate() as ItemDefinition
	invalid.max_stack_size = 0
	_check(not ItemCatalog.new([invalid]).is_valid(), "zero stack limit rejected")
	invalid.max_stack_size = 1000001
	_check(not ItemCatalog.new([invalid]).is_valid(), "unsafe stack limit rejected")
	invalid.max_stack_size = 10
	invalid.display_name = "  "
	_check(not ItemCatalog.new([invalid]).is_valid(), "blank display name rejected")
	var duplicate := ItemCatalog.new([definitions[0], definitions[0]])
	_check(not duplicate.is_valid() and not duplicate.has_item(&"test_alpha") and not duplicate.validation_error().is_empty(), "duplicate IDs reject the whole catalog atomically")
	_check(not ItemCatalog.new([null]).is_valid(), "null item definition rejected")
	_check(catalog.get_definition(&"missing") == null and catalog.get_stack_limit(&"missing") == 0, "unknown item lookup returns no definition")
	var authoring := definitions[0].duplicate() as ItemDefinition
	var protected_catalog := ItemCatalog.new([authoring])
	authoring.max_stack_size = 999
	protected_catalog.get_definition(&"test_alpha").max_stack_size = 888
	_check(protected_catalog.get_stack_limit(&"test_alpha") == 10, "catalog snapshots isolate authoring and returned definitions")
	var inventory := SlotInventory.new(catalog, 3, 1)
	_check(inventory.is_valid() and inventory.get_capacity() == 3 and inventory.get_stack(0) == null, "configurable inventory starts empty")
	_check(not SlotInventory.new(catalog, 0, 1).is_valid() and not SlotInventory.new(catalog, -1, 1).is_valid() and not SlotInventory.new(null, 2, 1).is_valid(), "invalid inventory configuration rejected safely")
	var changes := [0]
	inventory.changed.connect(func() -> void: changes[0] += 1)
	_check(inventory.add(&"missing", 5) == 0 and inventory.add(&"test_alpha", 0) == 0 and inventory.add(&"test_alpha", -1) == 0 and changes[0] == 0, "invalid adds neither mutate nor notify")
	_check(inventory.add(&"test_alpha", 17) == 17 and inventory.get_stack(0).quantity == 10 and inventory.get_stack(1).quantity == 7 and changes[0] == 1, "add fills stacks up to their limits with one notification")
	_check(inventory.add(&"test_alpha", 10) == 10 and inventory.get_stack(1).quantity == 10 and inventory.get_stack(2).quantity == 7, "add merges existing stacks before allocating slots")
	_check(inventory.add(&"test_alpha", 9) == 3 and inventory.count_item(&"test_alpha") == 30, "overflow returns only the accepted amount")
	var before: int = changes[0]
	_check(inventory.add(&"test_alpha", 1) == 0 and inventory.add(&"test_beta", 1) == 0 and changes[0] == before, "full inventories reject additions without notifications")
	var snapshot := inventory.get_stack(0)
	snapshot.quantity = 999
	snapshot.item_id = &"missing"
	_check(inventory.get_stack(0).quantity == 10 and inventory.get_stack(0).item_id == &"test_alpha", "slot reads return detached snapshots")
	_check(inventory.get_stack(-1) == null and inventory.get_stack(3) == null, "out-of-range reads are safe")
	_check(inventory.remove(&"test_alpha", 12) == 12 and inventory.count_item(&"test_alpha") == 18 and inventory.get_stack(0) == null, "remove spans stacks and frees empty slots")
	_check(inventory.remove(&"test_alpha", 100) == 18 and inventory.count_item(&"test_alpha") == 0, "remove reports actual quantity when fewer items exist")
	before = changes[0]
	_check(inventory.remove(&"missing", 1) == 0 and inventory.remove(&"test_alpha", 0) == 0 and inventory.remove(&"test_alpha", -5) == 0 and changes[0] == before, "invalid or unavailable removals do not notify")
	var huge := SlotInventory.new(catalog, 2, 1)
	_check(huge.add(&"test_alpha", 9223372036854775807) == 20 and huge.count_item(&"test_alpha") == 20, "huge requested quantities cannot overflow bounded slot arithmetic")
	inventory = SlotInventory.new(catalog, 4, 1)
	inventory.add(&"test_alpha", 17)
	_check(inventory.move_stack(0, 2, 3) == 3 and inventory.get_stack(0).quantity == 7 and inventory.get_stack(2).quantity == 3, "move supports partial amounts into an empty slot")
	_check(inventory.move_stack(2, 1) == 3 and inventory.get_stack(1).quantity == 10 and inventory.get_stack(2) == null, "move merges matching stacks and clears exhausted source")
	_check(inventory.move_stack(0, 1) == 0 and inventory.count_item(&"test_alpha") == 17, "merge into a full stack cannot overwrite or destroy items")
	_check(inventory.split_stack(1, 3, 4) and inventory.get_stack(1).quantity == 6 and inventory.get_stack(3).quantity == 4, "split creates an exact separate stack")
	_check(not inventory.split_stack(3, 2, 4) and not inventory.split_stack(3, 0, 1) and not inventory.split_stack(3, 2, 0) and not inventory.split_stack(3, 2, -1), "invalid splits reject whole, occupied and nonpositive amounts")
	_check(inventory.split_stack(3, 2, 2) and inventory.count_item(&"test_alpha") == 17, "successful split conserves total quantity")
	_check(inventory.move_stack(-1, 0) == 0 and inventory.move_stack(0, 4) == 0 and inventory.move_stack(0, 0) == 0 and inventory.move_stack(0, 1, -2) == 0 and inventory.move_stack(0, 1, 0) == 0, "invalid move indices, self-target and quantities are safe")
	inventory = SlotInventory.new(catalog, 3, 1)
	inventory.add(&"test_alpha", 3)
	inventory.add(&"test_beta", 4)
	_check(inventory.move_stack(0, 1) == 0 and inventory.get_stack(1).item_id == &"test_beta" and inventory.count_item(&"test_alpha") == 3, "different items never overwrite one another")
	_check(inventory.move_stack(0, 2, 100) == 3 and inventory.get_stack(0) == null, "oversized move requests clamp to available quantity")
	_test_transfers(catalog)
	_test_conservation(catalog)
	print("INVENTORY MODEL RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_transfers(catalog: ItemCatalog) -> void:
	var source := SlotInventory.new(catalog, 3, 1)
	var destination := SlotInventory.new(catalog, 2, 1)
	source.add(&"test_alpha", 17)
	source.add(&"test_beta", 3)
	destination.add(&"test_alpha", 8)
	destination.add(&"test_gamma", 1)
	var notifications := [0, 0, true]
	var observer := func() -> void:
		notifications[0] += 1
		notifications[2] = notifications[2] and source.count_item(&"test_alpha") + destination.count_item(&"test_alpha") == 25
	source.changed.connect(observer)
	destination.changed.connect(func() -> void: notifications[1] += 1)
	_check(source.transfer_to(destination, 0, 0, 7) == 2 and source.get_stack(0).quantity == 8 and destination.get_stack(0).quantity == 10, "partial transfer respects destination capacity and leaves remainder at source")
	_check(notifications[0] == 1 and notifications[1] == 1 and notifications[2], "both inventories notify once only after the complete transfer is committed")
	_check(source.transfer_to(destination, 0, 1) == 0 and destination.count_item(&"test_gamma") == 1, "transfer cannot replace a different target item")
	_check(source.transfer_to(destination, 0, 0) == 0 and notifications[0] == 1 and notifications[1] == 1, "full target transfer is a silent no-op")
	var empty := SlotInventory.new(source.get_catalog(), 2, 1)
	_check(source.transfer_to(empty, 1, 0, 100) == 7 and source.get_stack(1) == null and empty.get_stack(0).quantity == 7, "cross-inventory transfer moves only available source items")
	var before: int = notifications[0]
	_check(source.transfer_to(source, 0, 1, 3) == 3 and notifications[0] == before + 1, "same-inventory transfer emits just one change notification")
	var incompatible := SlotInventory.new(ItemCatalog.new(_definitions()), 2, 1)
	_check(source.transfer_to(incompatible, 0, 0) == 0 and source.transfer_to(null, 0, 0) == 0, "missing or incompatible destination catalog rejected")
	_check(source.transfer_to(empty, -1, 0) == 0 and source.transfer_to(empty, 0, 2) == 0 and source.transfer_to(empty, 0, 0, 0) == 0 and source.transfer_to(empty, 0, 0, -4) == 0, "invalid transfer indices and quantities are safe")
	_check(source.count_item(&"test_alpha") + destination.count_item(&"test_alpha") + empty.count_item(&"test_alpha") == 25 and source.count_item(&"test_beta") == 3, "all transfers conserve each item type")
	source.changed.disconnect(observer)


func _test_conservation(catalog: ItemCatalog) -> void:
	var inventories: Array[SlotInventory] = [SlotInventory.new(catalog, 8, 1), SlotInventory.new(catalog, 8, 1)]
	inventories[0].add(&"test_alpha", 27)
	inventories[0].add(&"test_beta", 11)
	inventories[0].add(&"test_gamma", 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 4372
	var conserved := true
	var valid_slots := true
	var successful: int = 0
	for step in range(250):
		var source := inventories[rng.randi_range(0, 1)]
		var destination := inventories[rng.randi_range(0, 1)]
		var from := rng.randi_range(0, 7)
		var to := rng.randi_range(0, 7)
		var quantity := rng.randi_range(1, 12)
		if step % 3 == 0:
			successful += int(source.split_stack(from, to, quantity))
		else:
			successful += int(source.transfer_to(destination, from, to, quantity) > 0)
		for id in {&"test_alpha": 27, &"test_beta": 11, &"test_gamma": 2}:
			var expected: int = {&"test_alpha": 27, &"test_beta": 11, &"test_gamma": 2}[id]
			conserved = conserved and inventories[0].count_item(id) + inventories[1].count_item(id) == expected
		for inventory in inventories:
			for index in range(inventory.get_capacity()):
				var stack := inventory.get_stack(index)
				if stack != null:
					valid_slots = valid_slots and catalog.has_item(stack.item_id) and stack.quantity > 0 and stack.quantity <= catalog.get_stack_limit(stack.item_id)
	_check(successful > 10, "seeded mixed-operation scenario exercises successful moves and transfers")
	_check(conserved and valid_slots, "250 mixed operations preserve per-item totals and all slot invariants")
