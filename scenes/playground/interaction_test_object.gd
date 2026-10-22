extends WorldInteractable
## Playground-only behaviors. No inventory, item data or persistence.

enum Behavior { SWITCH, ACTIVATE, COLLECT }

@export var behavior: Behavior = Behavior.SWITCH

@onready var mesh: MeshInstance3D = $Mesh
@onready var state_label: Label3D = $StateLabel

var active: bool = false


func _ready() -> void:
	# Each instance owns its material so toggling never changes its neighbors.
	mesh.material_override = mesh.get_active_material(0).duplicate()
	_update_display()


func get_prompt() -> String:
	match behavior:
		Behavior.SWITCH:
			return "Switch off" if active else "Switch on"
		Behavior.ACTIVATE:
			return "Activate test beacon"
		Behavior.COLLECT:
			return "Remove test token"
	return interaction_text


func _on_interact(_actor: Node3D) -> void:
	match behavior:
		Behavior.SWITCH:
			active = not active
		Behavior.ACTIVATE:
			active = true
			interaction_enabled = false
		Behavior.COLLECT:
			interaction_enabled = false
			queue_free()
	_update_display()


func _update_display() -> void:
	var material := mesh.material_override as StandardMaterial3D
	material.albedo_color = Color(0.24, 0.72, 0.42) if active else Color(0.76, 0.5, 0.23)
	match behavior:
		Behavior.SWITCH:
			state_label.text = "SWITCH / ON" if active else "SWITCH / OFF"
		Behavior.ACTIVATE:
			state_label.text = "BEACON / ACTIVE" if active else "BEACON / INACTIVE"
		Behavior.COLLECT:
			state_label.text = "TEST TOKEN"
