extends SceneTree
## Grid/equipment integration without scenes, UI, effects or global state.

const E = ItemDefinition.EquipmentSlot

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


func _catalog(shape: Vector2i = Vector2i(2, 3), limit: int = 1) -> ItemCatalog:
	var delta := load("res://data/items/test_delta.tres").duplicate() as ItemDefinition
	delta.grid_size = shape
	delta.max_stack_size = limit
	return ItemCatalog.new([load("res://data/items/test_alpha.tres"), load("res://data/items/test_beta.tres"), load("res://data/items/test_gamma.tres"), delta])


func _anchor(inventory: SlotInventory, id: StringName) -> int:
	for index in range(inventory.get_capacity()):
		var stack := inventory.get_stack(index)
		if stack != null and stack.item_id == id:
			return index
	return -1


func _run() -> void:
	_test_grid()
	_test_transfers()
	_test_equipment()
	_test_mixed_operations()
	print("GRID INVENTORY RESULT: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)


func _test_grid() -> void:
	var catalog := _catalog()
	var grid := SlotInventory.new(catalog)
	_check(grid.get_grid_size() == Vector2i(6, 6) and grid.get_capacity() == 36, "default grid is 6x6 / 36 cells")
	_check(SlotInventory.new(catalog, 3, 2).get_capacity() == 6 and not SlotInventory.new(catalog, 6, 0).is_valid() and not SlotInventory.new(catalog, -1, 6).is_valid(), "grid dimensions are configurable and invalid dimensions rejected")
	_check(grid.cell_to_index(Vector2i(5, 5)) == 35 and grid.index_to_cell(13) == Vector2i(1, 2) and grid.cell_to_index(Vector2i(6, 0)) == -1 and grid.index_to_cell(-1) == Vector2i(-1, -1), "coordinate conversion rejects row wrapping and invalid cells")
	var invalid := catalog.get_definition(&"test_delta")
	invalid.grid_size = Vector2i(0, 2)
	_check(not ItemCatalog.new([invalid]).is_valid(), "nonpositive item dimensions are rejected")
	invalid.grid_size = Vector2i(2, 2)
	invalid.equipment_slots = 64
	_check(not ItemCatalog.new([invalid]).is_valid(), "unknown equipment compatibility bits are rejected")
	var snapshot := catalog.get_definition(&"test_beta")
	snapshot.grid_size = Vector2i(99, 99)
	snapshot.equipment_slots = 0
	_check(catalog.get_item_size(&"test_beta") == Vector2i(1, 2) and catalog.can_equip(&"test_beta", E.HEAD), "catalog protects static footprints and compatibility from returned-copy edits")
	for shape in [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 3)]:
		var shaped_catalog := _catalog(shape)
		var shaped := SlotInventory.new(shaped_catalog)
		var added := shaped.add_at(&"test_delta", 1, Vector2i(1, 1))
		var occupied: int = 0
		for index in range(shaped.get_capacity()):
			occupied += int(shaped.get_anchor_at(index) == 7)
		_check(added == 1 and occupied == shape.x * shape.y and shaped.count_item(&"test_delta") == 1 and shaped.get_stack(7).position == Vector2i(1, 1), "%s footprint occupies exactly its area but counts quantity once" % shape)
	_check(not grid.can_place(&"test_delta", Vector2i(5, 0)) and not grid.can_place(&"test_delta", Vector2i(0, 4)) and not grid.can_place(&"test_delta", Vector2i(-1, 0)) and not grid.can_place(&"unknown", Vector2i.ZERO), "placement rejects edges, negative positions and unknown IDs")
	_check(grid.add_at(&"test_beta", 3, Vector2i(1, 1)) == 3 and grid.get_anchor_at(13) == 7 and grid.get_stack(13) == null, "covered cells resolve their anchor without creating duplicate stacks")
	_check(not grid.can_place(&"test_alpha", Vector2i(1, 2)) and grid.add_at(&"test_alpha", 1, Vector2i(1, 2)) == 0 and grid.add_at(&"test_delta", 1, Vector2i.ZERO) == 0, "all footprint cells block overlapping placements, not only anchors")
	_check(grid.get_transfer_amount(grid, 7, 13) == 3 and grid.move_stack(7, 13) == 3 and grid.get_anchor_at(7) == -1 and grid.get_anchor_at(19) == 13, "whole-stack movement may overlap its own old footprint")
	_check(grid.move_stack(13, 19, 1) == 0 and not grid.split_stack(13, 19, 1) and grid.count_item(&"test_beta") == 3, "partial moves/splits cannot overlap the retained source footprint")
	var changes := [0]
	grid.changed.connect(func() -> void: changes[0] += 1)
	_check(grid.rotate_stack(13) and grid.get_stack(13).rotated and grid.get_anchor_at(14) == 13 and grid.get_anchor_at(19) == -1 and changes[0] == 1, "90-degree rotation updates occupancy and notifies once")
	grid.add_at(&"test_alpha", 1, Vector2i(1, 3))
	var before: int = changes[0]
	_check(not grid.rotate_stack(13) and grid.get_stack(13).rotated and changes[0] == before, "blocked rotation leaves orientation, items and notifications unchanged")
	grid.remove(&"test_alpha", 1)
	_check(grid.rotate_stack(13) and not grid.get_stack(13).rotated and grid.get_anchor_at(14) == -1, "second successful rotation restores original footprint")
	grid.add_at(&"test_beta", 2, Vector2i(5, 0))
	_check(not grid.rotate_stack(5) and grid.get_anchor_at(11) == 5, "rotation at right edge cannot wrap into another row")
	_check(grid.move_stack(5, 0, -1, true) == 2 and grid.get_stack(0).rotated and grid.get_anchor_at(1) == 0 and grid.get_anchor_at(11) == -1, "atomic move-plus-rotation works when rotation at the source would not fit")
	_check(grid.move_stack(13, 0) == 3 and grid.get_stack(0).quantity == 5 and grid.get_stack(0).rotated and grid.get_anchor_at(19) == -1, "merge combines differing orientations without changing target footprint")
	_check(grid.split_stack(0, 6, 2) and grid.get_stack(6).rotated and grid.get_anchor_at(7) == 6 and grid.count_item(&"test_beta") == 5, "split inherits orientation and reserves the complete destination footprint")
	_check(grid.remove_from_slot(1, 1) == 0 and not grid.rotate_stack(1) and not grid.can_place(&"test_alpha", Vector2i(4, 4), false, 35), "covered/nonexistent anchors cannot masquerade as independent stacks")
	var stack := grid.get_stack(6)
	stack.position = Vector2i(5, 5)
	stack.rotated = false
	_check(grid.get_stack(6).position == Vector2i(0, 1) and grid.get_stack(6).rotated, "runtime position/rotation reads are detached snapshots")
	_check(grid.remove(&"test_beta", 100) == 5 and grid.get_anchor_at(0) == -1 and grid.get_anchor_at(7) == -1, "removing last quantities releases all covered cells")
	_check(grid.add(&"test_beta", 12) == 12 and _grid_valid(grid), "automatic stacking allocates valid multi-cell footprints")
	var row := SlotInventory.new(catalog, 2, 1)
	_check(row.add(&"test_beta", 1) == 1 and row.get_stack(0).rotated and row.get_anchor_at(1) == 0, "automatic add tries rotated placement when the base orientation cannot fit")
	_check(row.find_free_position(&"missing") == Vector2i(-1, -1) and row.get_addable_at(&"test_beta", -1, Vector2i.ZERO) == 0, "shared placement/amount queries handle invalid requests safely")


func _test_transfers() -> void:
	var catalog := _catalog(Vector2i(2, 2), 4)
	var source := SlotInventory.new(catalog, 4, 4)
	var destination := SlotInventory.new(catalog, 3, 3)
	source.add_at(&"test_delta", 3, Vector2i.ZERO)
	for y in range(3):
		destination.add_at(&"test_alpha", 1, Vector2i(1, y))
	_check(destination.find_free_position(&"test_delta") == Vector2i(-1, -1) and source.transfer_to(destination, 0, 0) == 0 and source.count_item(&"test_delta") == 3, "fragmented free cells cannot accept an overlapping rectangular footprint")
	destination = SlotInventory.new(catalog, 4, 4)
	destination.add_at(&"test_delta", 3, Vector2i.ZERO)
	_check(source.get_transfer_amount(destination, 0, 0, 3) == 1 and source.transfer_to(destination, 0, 0, 3) == 1 and source.count_item(&"test_delta") == 2 and destination.count_item(&"test_delta") == 4, "preview and partial multi-cell merge agree and conserve quantities")
	source = SlotInventory.new(catalog)
	source.add_at(&"test_beta", 4, Vector2i(5, 0))
	destination = SlotInventory.new(catalog, 2, 1)
	var notifications := [0, 0, true]
	var source_observer := func() -> void:
		notifications[0] += 1
		notifications[2] = source.count_item(&"test_beta") + destination.count_item(&"test_beta") == 4
	source.changed.connect(source_observer)
	destination.changed.connect(func() -> void: notifications[1] += 1)
	_check(source.get_transfer_amount(destination, 5, 0) == 0 and source.get_transfer_amount(destination, 5, 0, -1, true) == 4, "transfer preview uses requested destination orientation")
	_check(source.transfer_to(destination, 5, 0, -1, true) == 4 and destination.get_stack(0).rotated and source.get_anchor_at(11) == -1, "cross-inventory rotated transfer releases old and reserves new footprint")
	_check(notifications[0] == 1 and notifications[1] == 1 and notifications[2], "grid transfer observers see committed conserved state with one signal each")
	source.changed.disconnect(source_observer)
	var incompatible := SlotInventory.new(_catalog())
	_check(destination.transfer_to(incompatible, 0, 0) == 0 and destination.transfer_to(source, 1, 0) == 0 and destination.transfer_to(source, 0, -1) == 0, "incompatible catalogs and non-anchor/invalid transfer indices are rejected")
	_check(_grid_valid(source) and _grid_valid(destination), "transfer destinations retain valid independent occupancy")


func _test_equipment() -> void:
	var catalog := _catalog()
	var grid := SlotInventory.new(catalog)
	var equipment := EquipmentInventory.new(catalog)
	var empty := true
	for slot in range(6):
		empty = empty and equipment.get_stack(slot) == null
	_check(empty and equipment.get_stack(-1) == null and equipment.get_stack(6) == null, "all six equipment slots start empty and invalid reads are safe")
	_check(equipment.is_compatible(&"test_beta", E.HEAD) and equipment.is_compatible(&"test_beta", E.FEET) and equipment.is_compatible(&"test_gamma", E.PRIMARY) and equipment.is_compatible(&"test_gamma", E.SECONDARY) and equipment.is_compatible(&"test_delta", E.CHEST) and equipment.is_compatible(&"test_delta", E.LEGS), "all six slots have simple declared item compatibility")
	_check(not equipment.is_compatible(&"test_alpha", E.HEAD) and not equipment.is_compatible(&"test_beta", E.CHEST) and not equipment.is_compatible(&"missing", 2) and not equipment.is_compatible(&"test_beta", 6), "incompatible and unknown equipment targets are rejected")
	grid.add(&"test_beta", 3)
	grid.add(&"test_gamma", 1)
	grid.add(&"test_delta", 1)
	var notifications := [0, 0, true]
	var observer := func() -> void:
		notifications[0] += 1
		notifications[2] = grid.count_item(&"test_beta") + equipment.count_item(&"test_beta") == 3
	grid.changed.connect(observer)
	equipment.changed.connect(func() -> void: notifications[1] += 1)
	_check(equipment.can_equip(grid, 0, E.HEAD) and equipment.equip_from(grid, 0, E.HEAD) and grid.get_stack(0).quantity == 2 and equipment.get_stack(E.HEAD).quantity == 1, "equip takes one item from a stack without copying the full quantity")
	_check(notifications[0] == 1 and notifications[1] == 1 and notifications[2], "equip commits both data owners before change notifications")
	grid.changed.disconnect(observer)
	var snapshot := equipment.get_stack(E.HEAD)
	snapshot.item_id = &"missing"
	snapshot.quantity = 90
	_check(equipment.get_stack(E.HEAD).item_id == &"test_beta" and equipment.get_stack(E.HEAD).quantity == 1, "equipment reads cannot mutate live state")
	var before: int = notifications[1]
	_check(not equipment.equip_from(grid, 0, E.HEAD) and not equipment.equip_from(grid, _anchor(grid, &"test_delta"), E.HEAD) and notifications[1] == before, "occupied or incompatible slots do not swap, remove or notify")
	_check(not equipment.equip_from(grid, 6, E.FEET) and not equipment.equip_from(grid, -1, E.FEET) and not equipment.equip_from(grid, 0, 6), "covered grid cells and invalid source/gear indices cannot equip")
	_check(not EquipmentInventory.new(_catalog()).equip_from(grid, 0, E.HEAD) and not EquipmentInventory.new(null).equip_from(grid, 0, E.HEAD), "equipment rejects foreign/missing catalogs")
	_check(equipment.equip_from(grid, 0, E.FEET) and equipment.equip_from(grid, _anchor(grid, &"test_gamma"), E.PRIMARY) and equipment.equip_from(grid, _anchor(grid, &"test_delta"), E.CHEST), "head, feet, primary and chest equip through the same validated operation")
	grid.add(&"test_gamma", 1)
	grid.add(&"test_delta", 1)
	_check(equipment.equip_from(grid, _anchor(grid, &"test_gamma"), E.SECONDARY) and equipment.equip_from(grid, _anchor(grid, &"test_delta"), E.LEGS), "secondary and legs equip independently without implicit hand/backpack rules")
	var full := true
	for slot in range(6):
		full = full and equipment.get_stack(slot) != null and equipment.get_stack(slot).quantity == 1
	_check(full and equipment.count_item(&"test_beta") == 2 and equipment.count_item(&"test_gamma") == 2 and equipment.count_item(&"test_delta") == 2, "all six equipped slots contain exactly one real item")
	grid.add(&"test_alpha", 360)
	before = notifications[1]
	_check(not equipment.can_unequip_to(grid, E.CHEST) and not equipment.unequip_to(grid, E.CHEST) and equipment.get_stack(E.CHEST) != null and notifications[1] == before, "full grid prevents unequip without destroying the equipped item")
	_check(not equipment.unequip_to(grid, E.PRIMARY, 6) and not equipment.unequip_to(grid, -1) and not equipment.unequip_to(grid, 6) and not equipment.unequip_to(grid, E.PRIMARY, -2), "covered destinations and invalid equipment/target indices are safe")
	grid.remove(&"test_alpha", 360)
	var grid_count := [0, true]
	var unequip_observer := func() -> void:
		grid_count[0] += 1
		grid_count[1] = grid.count_item(&"test_beta") + equipment.count_item(&"test_beta") == 3
	grid.changed.connect(unequip_observer)
	before = notifications[1]
	_check(equipment.unequip_to(grid, E.HEAD) and grid.get_stack(0).quantity == 2 and equipment.get_stack(E.HEAD) == null, "automatic unequip merges into a compatible existing stack")
	_check(grid_count[0] == 1 and grid_count[1] and notifications[1] == before + 1, "unequip observers see conserved committed state with one signal each")
	grid.changed.disconnect(unequip_observer)
	_check(equipment.unequip_to(grid, E.PRIMARY, 4) and grid.get_stack(4).item_id == &"test_gamma" and grid.get_anchor_at(5) == 4, "explicit unequip reserves the full item footprint")
	var row := SlotInventory.new(catalog, 2, 1)
	_check(not equipment.can_unequip_to(row, E.FEET) and equipment.can_unequip_to(row, E.FEET, 0, true) and equipment.unequip_to(row, E.FEET, 0, true) and row.get_stack(0).rotated, "unequip supports explicit rotation and validates before releasing equipment")
	var rectangle := SlotInventory.new(catalog, 3, 2)
	_check(not equipment.unequip_to(rectangle, E.CHEST) and equipment.unequip_to(rectangle, E.CHEST, 0, true) and rectangle.get_anchor_at(5) == 0, "2x3 equipment can return rotated into a 3x2 grid")
	_check(not equipment.unequip_to(SlotInventory.new(_catalog()), E.LEGS) and not equipment.unequip_to(grid, E.LEGS, 36), "unequip rejects foreign catalogs and out-of-bounds placement")
	_check(grid.count_item(&"test_beta") + row.count_item(&"test_beta") + equipment.count_item(&"test_beta") == 3 and grid.count_item(&"test_delta") + rectangle.count_item(&"test_delta") + equipment.count_item(&"test_delta") == 2, "equip/unequip conserves quantities across differently shaped inventories")


func _grid_valid(grid: SlotInventory) -> bool:
	var owners: Array[int] = []
	owners.resize(grid.get_capacity())
	owners.fill(-1)
	for index in range(grid.get_capacity()):
		var stack := grid.get_stack(index)
		if stack == null:
			continue
		var size := grid.get_catalog().get_item_size(stack.item_id, stack.rotated)
		if stack.quantity < 1 or stack.quantity > grid.get_catalog().get_stack_limit(stack.item_id) or stack.position != grid.index_to_cell(index):
			return false
		for y in range(stack.position.y, stack.position.y + size.y):
			for x in range(stack.position.x, stack.position.x + size.x):
				var cell := grid.cell_to_index(Vector2i(x, y))
				if cell < 0 or owners[cell] != -1:
					return false
				owners[cell] = index
	for index in range(grid.get_capacity()):
		if grid.get_anchor_at(index) != owners[index]:
			return false
	return true


func _test_mixed_operations() -> void:
	var catalog := _catalog()
	var grids: Array[SlotInventory] = [SlotInventory.new(catalog), SlotInventory.new(catalog)]
	var equipment := EquipmentInventory.new(catalog)
	var expected := {&"test_alpha": 17, &"test_beta": 9, &"test_gamma": 3, &"test_delta": 2}
	var seeded := true
	for id in expected:
		seeded = seeded and grids[0].add(id, expected[id]) == expected[id]
	_check(seeded, "mixed grid/equipment fixture is fully seeded without overflow")
	var rng := RandomNumberGenerator.new()
	rng.seed = 4106
	var conserved := true
	var valid := true
	var successful: int = 0
	for step in range(400):
		var source := grids[rng.randi_range(0, 1)]
		var destination := grids[rng.randi_range(0, 1)]
		var from := rng.randi_range(0, 35)
		# Exercise real stacks as well as invalid/empty cells; uniform cell-only
		# sampling mostly misses multi-cell anchors and leaves operations untested.
		if step % 2 == 0:
			var anchors: Array[int] = []
			for index in range(source.get_capacity()):
				if source.get_stack(index) != null:
					anchors.append(index)
			if not anchors.is_empty():
				from = anchors[rng.randi_range(0, anchors.size() - 1)]
		var to := rng.randi_range(0, 35)
		var slot := rng.randi_range(0, 5)
		match step % 5:
			0:
				successful += int(source.rotate_stack(from))
			1:
				successful += int(source.transfer_to(destination, from, to, rng.randi_range(1, 5), rng.randi_range(0, 1) == 1) > 0)
			2:
				successful += int(source.split_stack(from, to, rng.randi_range(1, 4)))
			3:
				successful += int(equipment.equip_from(source, from, slot))
			4:
				successful += int(equipment.unequip_to(destination, slot, -1, rng.randi_range(0, 1) == 1))
		for id in expected:
			conserved = conserved and grids[0].count_item(id) + grids[1].count_item(id) + equipment.count_item(id) == expected[id]
		valid = valid and _grid_valid(grids[0]) and _grid_valid(grids[1])
		for equipment_slot in range(6):
			var stack := equipment.get_stack(equipment_slot)
			if stack != null:
				valid = valid and stack.quantity == 1 and equipment.is_compatible(stack.item_id, equipment_slot)
	print("MIXED OPERATIONS: %d successful changes / 400 attempts" % successful)
	_check(successful > 20, "seeded mixed-operation scenario performs real successful changes")
	_check(conserved and valid, "400 grid/rotation/transfer/equipment operations conserve every item and occupancy invariant")
