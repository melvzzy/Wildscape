extends Node
## Camera aim selects the first World-layer hit. A second ray from the player's
## eye prevents TPS corner peeking from becoming interaction through a wall.

@export_range(0.1, 10.0, 0.1) var interaction_distance: float = 2.5
@export_flags_3d_physics var collision_mask: int = 1

@onready var player: CharacterBody3D = get_parent()
@onready var camera: Camera3D = player.get_node("CameraYaw/CameraPitch/SpringArm3D/Camera3D")
@onready var prompt: Label = $HUD/Root/Prompt
@onready var aim_dot: Label = $HUD/Root/AimDot

var target: WorldInteractable


func _physics_process(_delta: float) -> void:
	refresh_target()
	if player.controls_active and Input.is_action_just_pressed("interact"):
		try_interact()


func refresh_target() -> void:
	var enabled: bool = player.controls_active and not get_tree().paused
	target = _find_target() if enabled else null
	aim_dot.visible = enabled
	prompt.visible = is_instance_valid(target)
	prompt.text = "[E] " + target.get_prompt() if is_instance_valid(target) else ""


func try_interact() -> void:
	# Revalidate on activation; never act on a previously cached prompt.
	refresh_target()
	if is_instance_valid(target):
		target.interact(player)
		refresh_target()


func _find_target() -> WorldInteractable:
	var eye := player.global_position + Vector3.UP * 1.62
	var origin := camera.global_position
	var direction := -camera.global_basis.z
	var ray_length := interaction_distance + origin.distance_to(eye)
	var hit := _ray(origin, origin + direction * ray_length)
	if hit.is_empty() or not hit.collider is WorldInteractable:
		return null
	var candidate := hit.collider as WorldInteractable
	var point: Vector3 = hit.position
	if eye.distance_to(point) > interaction_distance or not candidate.can_interact(player):
		return null
	var eye_direction := eye.direction_to(point)
	var sight := _ray(eye, point + eye_direction * 0.02)
	if sight.is_empty() or sight.collider != candidate:
		return null
	return candidate


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [player.get_rid()])
	query.hit_from_inside = true
	return player.get_world_3d().direct_space_state.intersect_ray(query)
