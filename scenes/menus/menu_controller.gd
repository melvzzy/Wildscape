extends CanvasLayer
## Scene-local owner of menu transitions, pause and OS mouse capture.
## Shared by main_menu.tscn and the independently launchable gameplay scene.

const MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const GAMEPLAY := "res://scenes/main.tscn"

@export var gameplay_mode: bool = false

@onready var overlay: Control = $Overlay
@onready var backdrop: ColorRect = $Overlay/Backdrop
@onready var heading: Label = $Overlay/Center/Panel/Margin/Stack/Heading
@onready var subtitle: Label = $Overlay/Center/Panel/Margin/Stack/Subtitle
@onready var primary_button: Button = $Overlay/Center/Panel/Margin/Stack/Buttons/Primary
@onready var main_menu_button: Button = $Overlay/Center/Panel/Margin/Stack/Buttons/MainMenu
@onready var quit_button: Button = $Overlay/Center/Panel/Margin/Stack/Buttons/Quit

var player: CharacterBody3D
var _transitioning: bool = false
var _resume_version: int = 0


func _ready() -> void:
	get_tree().paused = false
	primary_button.pressed.connect(_on_primary_pressed)
	main_menu_button.pressed.connect(return_to_main_menu)
	quit_button.pressed.connect(quit_game)
	main_menu_button.visible = gameplay_mode
	if gameplay_mode:
		player = get_parent().get_node("Player")
		heading.text = "PAUSED"
		subtitle.text = "The wild can wait."
		primary_button.text = "Resume"
		backdrop.color.a = 0.88
		overlay.hide()
		_resume_input_when_safe()
	else:
		_apply_input(false)
		primary_button.grab_focus()


func _input(event: InputEvent) -> void:
	if gameplay_mode and event.is_action_pressed("pause") and not event.is_echo():
		get_viewport().set_input_as_handled()
		set_paused(not get_tree().paused)


func set_paused(paused: bool) -> void:
	if not gameplay_mode or _transitioning:
		return
	_resume_version += 1
	get_tree().paused = paused
	overlay.visible = paused
	_apply_input(false)
	if paused:
		primary_button.grab_focus()
	else:
		get_viewport().gui_release_focus()
		_resume_input_when_safe()


func _resume_input_when_safe() -> void:
	# Let the menu's Enter/Space/E press expire before gameplay can see it.
	var version := _resume_version
	await get_tree().physics_frame
	await get_tree().process_frame
	if is_inside_tree() and not _transitioning and not get_tree().paused and version == _resume_version:
		_apply_input(true)


func _apply_input(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(player):
		player.set_mouse_captured(captured)


func _on_primary_pressed() -> void:
	if gameplay_mode:
		set_paused(false)
	else:
		_change_scene(GAMEPLAY)


func return_to_main_menu() -> void:
	_change_scene(MAIN_MENU)


func _change_scene(path: String) -> void:
	if _transitioning:
		return
	_transitioning = true
	_resume_version += 1
	_apply_input(false)
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		_transitioning = false
		if gameplay_mode:
			set_paused(true)
		push_error("Cannot load scene %s (error %d)" % [path, error])


func quit_game() -> void:
	_resume_version += 1
	_apply_input(false)
	get_tree().paused = false
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready():
		if gameplay_mode:
			set_paused(true)
		else:
			_apply_input(false)
	# Focus return deliberately keeps the pause menu open until Resume/Escape.
