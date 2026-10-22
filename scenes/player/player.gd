extends CharacterBody3D
## Feet are at the origin; one unit is one meter. Camera yaw is independent
## of the replaceable visual model, so TPS can orbit while standing still.

@export_group("Movement")
@export var walk_speed: float = 4.5
@export var sprint_speed: float = 7.0
@export var acceleration: float = 22.0
@export var deceleration: float = 28.0
@export var air_acceleration: float = 6.0
@export var jump_speed: float = 6.0
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


func _ready() -> void:
	_spawn_transform = global_transform
	camera_yaw.global_position = global_position + Vector3.UP * 1.62
	camera_yaw.rotation.y = global_rotation.y
	spring_arm.add_excluded_object(get_rid())
	set_first_person(false)
	set_mouse_captured(true)
	# Prime interpolation before the first render frame.
	get_global_transform_interpolated()


func _process(_delta: float) -> void:
	# Render-time follow avoids fixed-physics-tick jitter; look stays immediate.
	camera_yaw.global_position = get_global_transform_interpolated().origin + Vector3.UP * 1.62


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("release_mouse"):
		set_mouse_captured(false)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_mouse_captured(true)
	if not controls_active:
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
	var speed := sprint_speed if Input.is_action_pressed("sprint") else walk_speed
	var rate := acceleration if not direction.is_zero_approx() else deceleration
	if not is_on_floor():
		rate = air_acceleration
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	velocity.x = move_toward(velocity.x, direction.x * speed, rate * delta)
	velocity.z = move_toward(velocity.z, direction.z * speed, rate * delta)
	if controls_active and Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_speed
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
	# Keep intent separate from OS state: headless drivers cannot capture a cursor.
	controls_active = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	camera_yaw.rotation = Vector3(0.0, _spawn_transform.basis.get_euler().y, 0.0)
	camera_pitch.rotation = Vector3(-0.15, 0.0, 0.0)
	reset_physics_interpolation()
	camera_yaw.global_position = global_position + Vector3.UP * 1.62


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		set_mouse_captured(false)
