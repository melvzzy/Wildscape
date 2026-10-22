class_name SlotInventory
extends RefCounted
## UI/scene-independent data. All mutation goes through validated operations.
## Add/remove/transfer return actual counts; 0 means no change. Split is exact.
## Transfers require the same injected catalog, preventing conflicting ID rules.

signal changed

var _catalog: ItemCatalog
var _slots: Array[InventoryStack] = []


func _init(catalog: ItemCatalog, capacity: int = 20) -> void:
	if catalog != null and catalog.is_valid() and capacity > 0:
		_catalog = catalog
		_slots.resize(capacity)


func is_valid() -> bool:
	return _catalog != null and not _slots.is_empty()


func get_capacity() -> int:
	return _slots.size()


func get_catalog() -> ItemCatalog:
	return _catalog


func get_definition(item_id: StringName) -> ItemDefinition:
	return _catalog.get_definition(item_id) if _catalog != null else null


func get_stack(index: int) -> InventoryStack:
	if not _valid_index(index) or _slots[index] == null:
		return null
	var stack := _slots[index]
	return InventoryStack.new(stack.item_id, stack.quantity)


func count_item(item_id: StringName) -> int:
	var count: int = 0
	for stack in _slots:
		if stack != null and stack.item_id == item_id:
			count += stack.quantity
	return count


func add(item_id: StringName, quantity: int) -> int:
	if quantity <= 0 or _catalog == null or not _catalog.has_item(item_id):
		return 0
	var remaining := quantity
	var limit := _catalog.get_stack_limit(item_id)
	# Fill existing stacks first, then empty slots in deterministic slot order.
	for stack in _slots:
		if stack != null and stack.item_id == item_id:
			var moved := mini(remaining, limit - stack.quantity)
			stack.quantity += moved
			remaining -= moved
			if remaining == 0:
				break
	if remaining > 0:
		for index in range(_slots.size()):
			if _slots[index] == null:
				var moved := mini(remaining, limit)
				_slots[index] = InventoryStack.new(item_id, moved)
				remaining -= moved
				if remaining == 0:
					break
	var added := quantity - remaining
	if added > 0:
		changed.emit()
	return added


func remove(item_id: StringName, quantity: int) -> int:
	if quantity <= 0:
		return 0
	var remaining := quantity
	for index in range(_slots.size()):
		var stack := _slots[index]
		if stack != null and stack.item_id == item_id:
			var removed := mini(remaining, stack.quantity)
			stack.quantity -= removed
			remaining -= removed
			if stack.quantity == 0:
				_slots[index] = null
			if remaining == 0:
				break
	var removed := quantity - remaining
	if removed > 0:
		changed.emit()
	return removed


func move_stack(from: int, to: int, quantity: int = -1) -> int:
	return transfer_to(self, from, to, quantity)


func split_stack(from: int, to: int, quantity: int) -> bool:
	if not _valid_index(from) or not _valid_index(to) or from == to:
		return false
	var source := _slots[from]
	if source == null or _slots[to] != null or quantity <= 0 or quantity >= source.quantity:
		return false
	return transfer_to(self, from, to, quantity) == quantity


func transfer_to(destination: SlotInventory, from: int, to: int, quantity: int = -1) -> int:
	if destination == null or _catalog == null or destination._catalog != _catalog:
		return 0
	if not _valid_index(from) or not destination._valid_index(to) or (destination == self and from == to):
		return 0
	var source := _slots[from]
	if source == null or quantity == 0 or quantity < -1:
		return 0
	var target := destination._slots[to]
	if target != null and target.item_id != source.item_id:
		return 0
	var requested := source.quantity if quantity == -1 else mini(quantity, source.quantity)
	var space := _catalog.get_stack_limit(source.item_id) - (target.quantity if target != null else 0)
	var moved := mini(requested, space)
	if moved <= 0:
		return 0
	# Commit BOTH sides before any observer runs, never notify halfway through.
	if target == null:
		destination._slots[to] = InventoryStack.new(source.item_id, moved)
	else:
		target.quantity += moved
	source.quantity -= moved
	if source.quantity == 0:
		_slots[from] = null
	changed.emit()
	if destination != self:
		destination.changed.emit()
	return moved


func _valid_index(index: int) -> bool:
	return index >= 0 and index < _slots.size()
