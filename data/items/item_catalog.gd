class_name ItemCatalog
extends RefCounted
## Explicitly injected, scene-local lookup. Takes snapshots so editing an authoring
## resource or a returned definition cannot change live inventory stack rules.

var _items: Dictionary[StringName, ItemDefinition] = {}
var _error: String = ""


func _init(definitions: Array[ItemDefinition] = []) -> void:
	for definition in definitions:
		if definition == null:
			_error = "Null item definition"
			break
		_error = definition.validation_error()
		if not _error.is_empty():
			break
		if _items.has(definition.item_id):
			_error = "Duplicate item ID: " + String(definition.item_id)
			break
		_items[definition.item_id] = definition.duplicate() as ItemDefinition
	if not _error.is_empty():
		_items.clear()


func is_valid() -> bool:
	return _error.is_empty()


func validation_error() -> String:
	return _error


func has_item(item_id: StringName) -> bool:
	return _items.has(item_id)


func get_definition(item_id: StringName) -> ItemDefinition:
	var definition: ItemDefinition = _items.get(item_id)
	return definition.duplicate() as ItemDefinition if definition != null else null


func get_stack_limit(item_id: StringName) -> int:
	var definition: ItemDefinition = _items.get(item_id)
	return definition.max_stack_size if definition != null else 0


func get_item_size(item_id: StringName, rotated: bool = false) -> Vector2i:
	var definition: ItemDefinition = _items.get(item_id)
	if definition == null:
		return Vector2i.ZERO
	return Vector2i(definition.grid_size.y, definition.grid_size.x) if rotated else definition.grid_size


func can_equip(item_id: StringName, slot: int) -> bool:
	var definition: ItemDefinition = _items.get(item_id)
	return definition != null and slot >= 0 and slot < 6 and (definition.equipment_slots & (1 << slot)) != 0
