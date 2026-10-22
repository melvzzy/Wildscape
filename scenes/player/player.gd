extends CharacterBody3D
## Feet are at the origin; one unit is one meter. Camera yaw is independent
## of the replaceable visual model, so TPS can orbit while standing still.

@export_group("Movement")
@export var walk_speed: float = 4.5
@export var sprint_speed: float = 6.2
@export var sprint_acceleration: float = 2.0
@export var acceleration: float = 22.0
@export var deceleration: float = 28.0
@export var air_acceleration: float = 6.0
@export_range(0.1, 5.0, 0.05) var jump_height: float = 1.5
@export_range(0.1, 5.0, 0.05) var gravity_multiplier: float = 1.4
@export var turn_speed: float = 14.0
@export_group("Camera")
## Radians per mouse pixel; independent of frame rate.
@export_range(0.0001, 0.01, 0.0001) var mouse_sensitivity: float = 0.0025
@export var third_person_distance: float = 3.5

@onready var visuals: Node3D = $Visuals
@onready var camera_yaw: Node3D = $CameraYaw
@onready var camera_pitch: Node3D = $CameraYaw/CameraPitch
@onready var spring_arm: SpringArm3D = $CameraYaw/CameraPitch/SpringArm3D
@onready var camera: Camera3D = $CameraYaw/CameraPitch/SpringArm3D/Camera3D

var first_person: bool = false
var controls_active: bool = false
var _spawn_transform: Transform3D
var _move_speed: float = 0.0


func _ready() -> void:
	_spawn_transform = global_transform
	_move_speed = walk_speed
	camera_yaw.global_position = global_position + Vector3.UP * 1.62
	camera_yaw.rotation.y = global_rotation.y
	spring_arm.add_excluded_object(get_rid())
	set_first_person(false)
	# Prime interpolation before the first render frame.
	get_global_transform_interpolated()


func _process(_delta: float) -> void:
	# Render-time follow avoids fixed-physics-tick jitter; look stays immediate.
	camera_yaw.global_position = get_global_transform_interpolated().origin + Vector3.UP * 1.62


func _unhandled_input(event: InputEvent) -> void:
	if not controls_active or get_tree().paused:
		return
	if event is InputEventMouseMotion:
		camera_yaw.rotation.y -= event.screen_relative.x * mouse_sensitivity
		camera_pitch.rotation.x = clampf(
			camera_pitch.rotation.x - event.screen_relative.y * mouse_sensitivity,
			deg_to_rad(-80.0), deg_to_rad(80.0)
		)
	elif event.is_action_pressed("toggle_camera") and not event.is_echo():
		set_first_person(not first_person)
	elif event.is_action_pressed("reset_player") and not event.is_echo():
		reset_to_spawn()


func _physics_process(delta: float) -> void:
	var input_vector := Vector2.ZERO
	if controls_active:
		input_vector = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := camera_yaw.global_basis * Vector3(input_vector.x, 0.0, input_vector.y)
	direction.y = 0.0
	direction = direction.normalized() * minf(input_vector.length(), 1.0)
	var wants_sprint := controls_active and not direction.is_zero_approx() and Input.is_action_pressed("sprint")
	var target_speed := sprint_speed if wants_sprint else walk_speed
	var speed_rate := sprint_acceleration if wants_sprint else deceleration
	_move_speed = move_toward(_move_speed, target_speed, speed_rate * delta)
	var rate := acceleration if not direction.is_zero_approx() else deceleration
	if not is_on_floor():
		rate = air_acceleration
		velocity += get_gravity() * gravity_multiplier * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	velocity.x = move_toward(velocity.x, direction.x * _move_speed, rate * delta)
	velocity.z = move_toward(velocity.z, direction.z * _move_speed, rate * delta)
	if controls_active and Input.is_action_just_pressed("jump") and is_on_floor():
		var gravity_strength := get_gravity().length() * gravity_multiplier
		# Compensate the discrete launch step so configured height stays accurate.
		velocity.y = sqrt(2.0 * gravity_strength * jump_height) - 0.5 * gravity_strength * delta
	move_and_slide()
	camera_yaw.global_position = global_position + Vector3.UP * 1.62
	if first_person:
		visuals.rotation.y = camera_yaw.rotation.y
	elif not direction.is_zero_approx():
		visuals.rotation.y = lerp_angle(visuals.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-turn_speed * delta))
	if global_position.y < -12.0:
		reset_to_spawn()


func set_first_person(enabled: bool) -> void:
	first_person = enabled
	visuals.visible = not enabled
	spring_arm.spring_length = 0.0 if enabled else third_person_distance


func set_mouse_captured(captured: bool) -> void:
	# Input gate retained for controller/tests; MenuController owns the OS cursor.
	controls_active = captured
	if not captured:
		$Interaction.refresh_target()


func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	_move_speed = walk_speed
	camera_yaw.rotation = Vector3(0.0, _spawn_transform.basis.get_euler().y, 0.0)
	camera_pitch.rotation = Vector3(-0.15, 0.0, 0.0)
	reset_physics_interpolation()
	camera_yaw.global_position = global_position + Vector3.UP * 1.62
