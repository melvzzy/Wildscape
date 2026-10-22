class_name EquipmentInventory
extends RefCounted
## Six fixed one-item slots, no attributes or effects. Uses the same catalog as
## the grid. Occupied slots are rejected rather than implicitly swapping items.

signal changed

const SLOT_COUNT: int = 6

var _catalog: ItemCatalog
var _slots: Array[InventoryStack] = []


func _init(catalog: ItemCatalog) -> void:
	if catalog != null and catalog.is_valid():
		_catalog = catalog
	_slots.resize(SLOT_COUNT)


func get_stack(slot: int) -> InventoryStack:
	if not _valid_slot(slot) or _slots[slot] == null:
		return null
	var stack := _slots[slot]
	return InventoryStack.new(stack.item_id, 1, Vector2i(-1, -1), stack.rotated)


func count_item(item_id: StringName) -> int:
	var count: int = 0
	for stack in _slots:
		if stack != null and stack.item_id == item_id:
			count += 1
	return count


func is_compatible(item_id: StringName, slot: int) -> bool:
	return _catalog != null and _catalog.can_equip(item_id, slot)


func can_equip(source: SlotInventory, from: int, slot: int) -> bool:
	if source == null or source.get_catalog() != _catalog or not _valid_slot(slot) or _slots[slot] != null:
		return false
	var stack := source.get_stack(from)
	return stack != null and is_compatible(stack.item_id, slot)


func equip_from(source: SlotInventory, from: int, slot: int) -> bool:
	if not can_equip(source, from, slot):
		return false
	var stack := source.get_stack(from)
	# Stage equipment before the validated grid mutation; its signal sees both
	# committed states. No callbacks or awaits occur before that mutation.
	_slots[slot] = InventoryStack.new(stack.item_id, 1, Vector2i(-1, -1), stack.rotated)
	if source.remove_from_slot(from, 1) != 1:
		_slots[slot] = null
		return false
	changed.emit()
	return true


func can_unequip_to(destination: SlotInventory, slot: int, to: int = -1, rotate: bool = false) -> bool:
	return _destination_index(destination, slot, to, rotate) >= 0


func unequip_to(destination: SlotInventory, slot: int, to: int = -1, rotate: bool = false) -> bool:
	var index := _destination_index(destination, slot, to, rotate)
	if index < 0:
		return false
	var stack := _slots[slot]
	_slots[slot] = null
	if destination.add_at(stack.item_id, 1, destination.index_to_cell(index), stack.rotated != rotate) != 1:
		_slots[slot] = stack
		return false
	changed.emit()
	return true


func _destination_index(destination: SlotInventory, slot: int, to: int, rotate: bool) -> int:
	if destination == null or _catalog == null or destination.get_catalog() != _catalog or not _valid_slot(slot):
		return -1
	var stack := _slots[slot]
	if stack == null or to < -1:
		return -1
	var rotated := stack.rotated != rotate
	var cell := destination.find_add_position(stack.item_id, rotated) if to == -1 else destination.index_to_cell(to)
	if destination.get_addable_at(stack.item_id, 1, cell, rotated) != 1:
		return -1
	return destination.cell_to_index(cell)


func _valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT
