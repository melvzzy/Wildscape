class_name SlotInventory
extends RefCounted
## Grid cells use row-major indices; only top-left anchors store stacks.
## Covered cells are resolved through get_anchor_at(), never counted twice.
## Operations return actual quantities; invalid requests are silent no-ops.

signal changed

var _catalog: ItemCatalog
var _slots: Array[InventoryStack] = []
var _size: Vector2i = Vector2i.ZERO


func _init(catalog: ItemCatalog, width: int = 6, height: int = 6) -> void:
	if catalog != null and catalog.is_valid() and width > 0 and height > 0:
		_catalog = catalog
		_size = Vector2i(width, height)
		_slots.resize(width * height)


func is_valid() -> bool:
	return _catalog != null and not _slots.is_empty()


func get_capacity() -> int:
	return _slots.size()


func get_grid_size() -> Vector2i:
	return _size


func get_catalog() -> ItemCatalog:
	return _catalog


func get_definition(item_id: StringName) -> ItemDefinition:
	return _catalog.get_definition(item_id) if _catalog != null else null


func cell_to_index(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= _size.x or cell.y >= _size.y:
		return -1
	return cell.y * _size.x + cell.x


func index_to_cell(index: int) -> Vector2i:
	if not _valid_index(index):
		return Vector2i(-1, -1)
	return Vector2i(index % _size.x, floori(float(index) / _size.x))


func get_stack(index: int) -> InventoryStack:
	if not _valid_index(index) or _slots[index] == null:
		return null
	var stack := _slots[index]
	return InventoryStack.new(stack.item_id, stack.quantity, index_to_cell(index), stack.rotated)


func get_anchor_at(index: int) -> int:
	if not _valid_index(index):
		return -1
	var cell := index_to_cell(index)
	for anchor in range(_slots.size()):
		var stack := _slots[anchor]
		if stack != null:
			var origin := index_to_cell(anchor)
			var size := _catalog.get_item_size(stack.item_id, stack.rotated)
			if cell.x >= origin.x and cell.y >= origin.y and cell.x < origin.x + size.x and cell.y < origin.y + size.y:
				return anchor
	return -1


func count_item(item_id: StringName) -> int:
	var count: int = 0
	for stack in _slots:
		if stack != null and stack.item_id == item_id:
			count += stack.quantity
	return count


func can_place(item_id: StringName, cell: Vector2i, rotated: bool = false, ignore_anchor: int = -1) -> bool:
	if _catalog == null or not _catalog.has_item(item_id) or cell_to_index(cell) < 0:
		return false
	if ignore_anchor != -1 and (not _valid_index(ignore_anchor) or _slots[ignore_anchor] == null):
		return false
	var size := _catalog.get_item_size(item_id, rotated)
	# Subtract before comparing: huge invalid footprints never iterate or wrap.
	if size.x > _size.x or size.y > _size.y or cell.x > _size.x - size.x or cell.y > _size.y - size.y:
		return false
	for y in range(cell.y, cell.y + size.y):
		for x in range(cell.x, cell.x + size.x):
			var owner := get_anchor_at(cell_to_index(Vector2i(x, y)))
			if owner != -1 and owner != ignore_anchor:
				return false
	return true


func find_free_position(item_id: StringName, rotated: bool = false) -> Vector2i:
	for index in range(_slots.size()):
		var cell := index_to_cell(index)
		if can_place(item_id, cell, rotated):
			return cell
	return Vector2i(-1, -1)


func find_add_position(item_id: StringName, rotated: bool = false) -> Vector2i:
	if _catalog == null or not _catalog.has_item(item_id):
		return Vector2i(-1, -1)
	for index in range(_slots.size()):
		var stack := _slots[index]
		if stack != null and stack.item_id == item_id and stack.quantity < _catalog.get_stack_limit(item_id):
			return index_to_cell(index)
	return find_free_position(item_id, rotated)


func get_addable_at(item_id: StringName, quantity: int, cell: Vector2i, rotated: bool = false) -> int:
	var index := cell_to_index(cell)
	if quantity <= 0 or index < 0 or _catalog == null or not _catalog.has_item(item_id):
		return 0
	var target := _slots[index]
	if target != null:
		if target.item_id != item_id:
			return 0
		return mini(quantity, _catalog.get_stack_limit(item_id) - target.quantity)
	if not can_place(item_id, cell, rotated):
		return 0
	return mini(quantity, _catalog.get_stack_limit(item_id))


func add_at(item_id: StringName, quantity: int, cell: Vector2i, rotated: bool = false) -> int:
	var moved := get_addable_at(item_id, quantity, cell, rotated)
	if moved <= 0:
		return 0
	var index := cell_to_index(cell)
	if _slots[index] == null:
		_slots[index] = InventoryStack.new(item_id, moved, cell, rotated)
	else:
		_slots[index].quantity += moved
	changed.emit()
	return moved


func add(item_id: StringName, quantity: int) -> int:
	if quantity <= 0 or _catalog == null or not _catalog.has_item(item_id):
		return 0
	var remaining := quantity
	var limit := _catalog.get_stack_limit(item_id)
	for stack in _slots:
		if stack != null and stack.item_id == item_id:
			var moved := mini(remaining, limit - stack.quantity)
			stack.quantity += moved
			remaining -= moved
			if remaining == 0:
				break
	while remaining > 0:
		var rotated := false
		var cell := find_free_position(item_id)
		if cell.x < 0:
			rotated = true
			cell = find_free_position(item_id, true)
		if cell.x < 0:
			break
		var moved := mini(remaining, limit)
		_slots[cell_to_index(cell)] = InventoryStack.new(item_id, moved, cell, rotated)
		remaining -= moved
	var added := quantity - remaining
	if added > 0:
		changed.emit()
	return added


func remove_from_slot(index: int, quantity: int) -> int:
	if not _valid_index(index) or _slots[index] == null or quantity <= 0:
		return 0
	var removed := mini(quantity, _slots[index].quantity)
	_slots[index].quantity -= removed
	if _slots[index].quantity == 0:
		_slots[index] = null
	changed.emit()
	return removed


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


func move_stack(from: int, to: int, quantity: int = -1, rotate: bool = false) -> int:
	return transfer_to(self, from, to, quantity, rotate)


func split_stack(from: int, to: int, quantity: int) -> bool:
	var source := self.get_stack(from)
	if source == null or quantity <= 0 or quantity >= source.quantity or get_anchor_at(to) != -1:
		return false
	return transfer_to(self, from, to, quantity) == quantity


func rotate_stack(anchor: int) -> bool:
	var stack := self.get_stack(anchor)
	if stack == null or not can_place(stack.item_id, stack.position, not stack.rotated, anchor):
		return false
	_slots[anchor].rotated = not stack.rotated
	changed.emit()
	return true


func get_transfer_amount(destination: SlotInventory, from: int, to: int, quantity: int = -1, rotate: bool = false) -> int:
	if destination == null or _catalog == null or destination._catalog != _catalog:
		return 0
	if not _valid_index(from) or not destination._valid_index(to) or (destination == self and from == to):
		return 0
	var source := _slots[from]
	if source == null or quantity == 0 or quantity < -1:
		return 0
	var requested := source.quantity if quantity == -1 else mini(quantity, source.quantity)
	var target := destination._slots[to]
	if target != null:
		if target.item_id != source.item_id:
			return 0
		return mini(requested, _catalog.get_stack_limit(source.item_id) - target.quantity)
	# A whole-stack move may overlap its own old footprint. A partial move may not.
	var ignore := from if destination == self and requested == source.quantity else -1
	if not destination.can_place(source.item_id, destination.index_to_cell(to), source.rotated != rotate, ignore):
		return 0
	return requested


func transfer_to(destination: SlotInventory, from: int, to: int, quantity: int = -1, rotate: bool = false) -> int:
	var moved := get_transfer_amount(destination, from, to, quantity, rotate)
	if moved <= 0:
		return 0
	var source := _slots[from]
	var target := destination._slots[to]
	# Commit both sides before observers, preserving existing transactional behavior.
	if target == null:
		destination._slots[to] = InventoryStack.new(source.item_id, moved, destination.index_to_cell(to), source.rotated != rotate)
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
