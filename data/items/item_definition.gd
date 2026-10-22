class_name ItemDefinition
extends Resource
## Static authoring data. Inventory quantities never live in this resource.

@export var item_id: StringName
@export var display_name: String
@export_multiline var description: String
@export_range(1, 1000000) var max_stack_size: int = 1
@export var icon: Texture2D
@export var world_model: PackedScene


func validation_error() -> String:
	var pattern := RegEx.create_from_string("\\A[a-z][a-z0-9_]*\\z")
	if pattern.search(String(item_id)) == null:
		return "Item ID must be a nonempty lowercase identifier: " + String(item_id)
	if display_name.strip_edges().is_empty():
		return "Item display name must not be empty: " + String(item_id)
	if max_stack_size < 1 or max_stack_size > 1000000:
		return "Item stack size must be between 1 and 1000000: " + String(item_id)
	return ""
