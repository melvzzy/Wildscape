class_name WorldItemSource
extends WorldInteractable
## Shared finite supply for loose pickups and gathering placeholders.
## Range, sight and E dispatch remain the player's interactor's responsibility.

@export var item_id: StringName = &"test_alpha"
## Authoring value becomes the remaining world quantity at runtime.
@export_range(1, 1000000, 1, "or_greater") var quantity: int = 1
@export var remove_when_depleted: bool = true

@onready var mesh: MeshInstance3D = $Mesh
@onready var state_label: Label3D = $StateLabel

var _collecting: bool = false
var _item_name: String = ""
var _feedback: String = ""


func _ready() -> void:
	mesh.material_override = mesh.get_active_material(0).duplicate()
	_update_display()


func can_interact(actor: Node3D) -> bool:
	if not super.can_interact(actor) or _collecting or quantity <= 0 or not is_inside_tree() or not can_process():
		return false
	var inventory := _inventory_for(actor)
	if inventory == null or not inventory.is_valid():
		return false
	var definition := inventory.get_definition(item_id)
	if definition == null:
		return false
	_item_name = definition.display_name
	return true


func get_prompt() -> String:
	var item_name := _item_name if not _item_name.is_empty() else String(item_id)
	var text := "%s %s ×%d" % [interaction_text, item_name, quantity]
	return text if _feedback.is_empty() else text + " — " + _feedback


func interact(actor: Node3D) -> void:
	if not can_interact(actor):
		return
	# Override the small contract entry point to hold the lock through both
	# Inventory.changed and the final interacted signal's synchronous observers.
	_collecting = true
	var accepted := _inventory_for(actor).add(item_id, quantity)
	quantity -= accepted
	_feedback = "No room; make space and retry" if accepted == 0 else ""
	if quantity == 0:
		interaction_enabled = false
		if remove_when_depleted:
			queue_free()
	_update_display()
	interacted.emit(actor)
	_collecting = false


func _inventory_for(actor: Node3D) -> SlotInventory:
	if not is_instance_valid(actor) or not actor.has_method("get_inventory"):
		return null
	var value: Variant = actor.call("get_inventory")
	return value if value is SlotInventory else null


func _update_display() -> void:
	if quantity <= 0:
		state_label.text = "DEPLETED" if quantity == 0 else "INVALID QUANTITY"
		(mesh.material_override as StandardMaterial3D).albedo_color = Color("41474a")
	else:
		state_label.text = "%s\n%s ×%d" % [interaction_text.to_upper(), String(item_id), quantity]
