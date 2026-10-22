class_name WorldInteractable
extends StaticBody3D
## Attach to a World-layer body. Override the three small methods as needed.
## The player's interactor owns range/visibility checks, not this world object.

signal interacted(actor: Node3D)

@export var interaction_text: String = "Interact"
@export var interaction_enabled: bool = true


func can_interact(_actor: Node3D) -> bool:
	return interaction_enabled and not is_queued_for_deletion()


func get_prompt() -> String:
	return interaction_text


func interact(actor: Node3D) -> void:
	if can_interact(actor):
		_on_interact(actor)
		interacted.emit(actor)


func _on_interact(_actor: Node3D) -> void:
	pass
