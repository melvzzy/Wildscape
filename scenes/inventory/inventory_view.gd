extends Control
## View of player-owned models. Drag snapshots never mutate data before drop.

signal close_requested
signal character_close_requested

const Board = preload("res://scenes/inventory/inventory_board.gd")
const SLOT_NAMES := ["Head", "Chest", "Legs", "Feet", "Primary", "Secondary"]
const GEAR_POSITIONS := [Vector2(245, 30), Vector2(25, 180), Vector2(465, 180), Vector2(245, 490), Vector2(25, 390), Vector2(465, 390)]

var inventory_panel: PanelContainer
var character_panel: PanelContainer
var grid: Control
var character_board: Control
var drag_overlay: Control
var status: Label
var close_button: Button
var _inventory: SlotInventory
var _equipment: EquipmentInventory
var _selected: int = -1
var _drag: Dictionary = {}
var _pointer := Vector2.ZERO
var _press_position := Vector2.ZERO
var _dragging: bool = false


func _ready() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.015, 0.018, 0.022, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)
	inventory_panel = _panel("INVENTORY", true)
	character_panel = _panel("CHARACTER", false)
	grid = _board(inventory_panel.get_node("Margin/Stack"), "grid")
	character_board = _board(character_panel.get_node("Margin/Stack"), "equipment")
	status = Label.new()
	status.text = "Drag to move • Shift-drag: half • R: rotate"
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 21)
	inventory_panel.get_node("Margin/Stack").add_child(status)
	var gear_hint := Label.new()
	gear_hint.text = "Drag compatible items to equip • Esc: close all"
	gear_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_hint.add_theme_font_size_override("font_size", 21)
	character_panel.get_node("Margin/Stack").add_child(gear_hint)
	close_button = _close(inventory_panel, "Close [Tab]", func() -> void: close_requested.emit())
	_close(character_panel, "Close [C]", func() -> void: character_close_requested.emit())
	drag_overlay = _board(self, "ghost")
	drag_overlay.custom_minimum_size = Vector2.ZERO
	drag_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inventory_panel.hide()
	character_panel.hide()


func make_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	return style


func _panel(title: String, right: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = "InventoryPanel" if right else "CharacterPanel"
	panel.add_theme_stylebox_override("panel", make_style(Color("202124"), Color("606166")))
	add_child(panel)
	panel.anchor_left = 1.0 if right else 0.0
	panel.anchor_right = panel.anchor_left
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -752 if right else 72
	panel.offset_right = -72 if right else 752
	panel.offset_top = -440
	panel.offset_bottom = 440
	var margin := MarginContainer.new()
	margin.name = "Margin"
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 40)
	panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.name = "Stack"
	stack.add_theme_constant_override("separation", 16)
	margin.add_child(stack)
	var heading := Label.new()
	heading.text = title
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 32)
	heading.add_theme_color_override("font_color", Color("dedbd3"))
	stack.add_child(heading)
	return panel


func _board(parent: Node, kind: String) -> Control:
	var board := Control.new()
	board.set_script(Board)
	board.view = self
	board.kind = kind
	board.custom_minimum_size = Vector2(600, 600)
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(board)
	return board


func _close(panel: Control, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_stylebox_override("normal", make_style(Color("2b2c30"), Color("55565b")))
	button.add_theme_stylebox_override("hover", make_style(Color("3b3c40"), Color("929399")))
	button.add_theme_stylebox_override("pressed", make_style(Color("191a1c"), Color("929399")))
	button.pressed.connect(callback)
	panel.get_node("Margin/Stack").add_child(button)
	return button


func bind_inventory(inventory: SlotInventory, equipment: EquipmentInventory = null) -> void:
	if _inventory != null and _inventory.changed.is_connected(_refresh):
		_inventory.changed.disconnect(_refresh)
	if _equipment != null and _equipment.changed.is_connected(_refresh):
		_equipment.changed.disconnect(_refresh)
	_inventory = inventory
	_equipment = equipment
	if _inventory != null:
		_inventory.changed.connect(_refresh)
	if _equipment != null:
		_equipment.changed.connect(_refresh)
	clear_selection()


func set_windows(inventory_open: bool, character_open: bool) -> void:
	clear_selection()
	inventory_panel.visible = inventory_open
	character_panel.visible = character_open
	visible = inventory_open or character_open
	if visible:
		if inventory_open:
			close_button.grab_focus()
		else:
			character_panel.get_node("Margin/Stack").get_child(-1).grab_focus()


func clear_selection() -> void:
	_selected = -1
	_drag.clear()
	_dragging = false
	_refresh()


func _refresh() -> void:
	if is_instance_valid(grid):
		grid.queue_redraw()
		character_board.queue_redraw()
		drag_overlay.queue_redraw()


func cell_size() -> float:
	var dimensions := _inventory.get_grid_size()
	return minf(600.0 / dimensions.x, 600.0 / dimensions.y)


func equipment_rect(slot: int) -> Rect2:
	return Rect2(GEAR_POSITIONS[slot], Vector2(110, 110))


func grid_line_width() -> float:
	# Retain one physical pixel when the reference canvas is scaled down.
	return 1.0 / minf(1.0, get_viewport().get_stretch_transform().get_scale().x)


func draw_text(canvas: Control, position: Vector2, text: String, font_size: int, width: float) -> void:
	canvas.draw_string(get_theme_default_font(), position, text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size, Color("dedee0"))


func draw_item(canvas: Control, rect: Rect2, stack: InventoryStack, selected: bool) -> void:
	canvas.draw_style_box(make_style(Color("33363b"), Color("c4bea9") if selected else Color("777a80")), rect)
	var definition := _inventory.get_definition(stack.item_id)
	if definition.icon != null:
		canvas.draw_texture_rect(definition.icon, Rect2(rect.get_center() - Vector2(22, 22), Vector2(44, 44)), false)
	else:
		var center := rect.get_center()
		var half_marker := Vector2(12, 12)
		if rect.size.y < 120:
			center.y = rect.end.y - 30
			half_marker = Vector2(6, 6)
		canvas.draw_rect(Rect2(center - half_marker, half_marker * 2), Color("85878b"), false, grid_line_width(), true)
	var label_text := definition.display_name
	if get_theme_default_font().get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x > rect.size.x - 12:
		label_text = label_text.replace(" ", "\n")
	canvas.draw_multiline_string(get_theme_default_font(), rect.position + Vector2(6, 23), label_text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x - 12, 20, 2, Color("dedee0"))
	canvas.draw_string(get_theme_default_font(), Vector2(rect.position.x + 8, rect.end.y - 10), str(stack.quantity), HORIZONTAL_ALIGNMENT_RIGHT, rect.size.x - 16, 22, Color.WHITE)


func _target_at(point: Vector2) -> Dictionary:
	if inventory_panel.visible and Rect2(grid.global_position, Vector2(_inventory.get_grid_size()) * cell_size()).has_point(point):
		var local := point - grid.global_position
		var cell := Vector2i(floori(local.x / cell_size()), floori(local.y / cell_size()))
		if not _drag.is_empty():
			var hovered := _inventory.get_anchor_at(_inventory.cell_to_index(cell))
			var stack := _inventory.get_stack(hovered)
			if stack != null and stack.item_id == _drag.stack.item_id and (_drag.kind != "grid" or hovered != _drag.index):
				return {"kind": "grid", "index": hovered}
			cell -= _drag.grab_cell
		var index := _inventory.cell_to_index(cell)
		if index >= 0:
			return {"kind": "grid", "index": index}
	if character_panel.visible:
		for slot in range(6):
			if equipment_rect(slot).has_point(point - character_board.global_position):
				return {"kind": "equipment", "index": slot}
	return {}


func begin_drag(kind: String, index: int, half: bool = false) -> bool:
	clear_selection()
	var stack: InventoryStack
	var grab_cell := Vector2i.ZERO
	if kind == "grid":
		var pressed_cell := _inventory.index_to_cell(index)
		index = _inventory.get_anchor_at(index)
		stack = _inventory.get_stack(index)
		if stack != null:
			grab_cell = pressed_cell - stack.position
	else:
		stack = _equipment.get_stack(index) if _equipment != null else null
	if stack == null:
		return false
	_selected = index if kind == "grid" else -1
	_drag = {"kind": kind, "index": index, "stack": stack, "quantity": maxi(1, floori(stack.quantity / 2.0)) if half else stack.quantity, "rotate": false, "grab_cell": grab_cell}
	_refresh()
	return true


func _source_unchanged() -> bool:
	if _drag.is_empty():
		return false
	var current: InventoryStack = _inventory.get_stack(_drag.index) if _drag.kind == "grid" else _equipment.get_stack(_drag.index)
	var original: InventoryStack = _drag.stack
	return current != null and current.item_id == original.item_id and current.quantity == original.quantity and current.position == original.position and current.rotated == original.rotated


func can_drop(kind: String, index: int) -> bool:
	if not _source_unchanged():
		return false
	if kind == "equipment":
		return _equipment != null and _drag.kind == "grid" and _equipment.can_equip(_inventory, _drag.index, index)
	if _drag.kind == "equipment":
		return _equipment.can_unequip_to(_inventory, _drag.index, index, _drag.rotate)
	if index == _drag.index:
		return _drag.quantity == _drag.stack.quantity and _inventory.can_place(_drag.stack.item_id, _inventory.index_to_cell(index), _drag.stack.rotated != _drag.rotate, index)
	return _inventory.get_transfer_amount(_inventory, _drag.index, index, _drag.quantity, _drag.rotate) > 0


func commit_drop(kind: String, index: int) -> bool:
	var success := false
	if can_drop(kind, index):
		if kind == "equipment":
			success = _equipment.equip_from(_inventory, _drag.index, index)
		elif _drag.kind == "equipment":
			success = _equipment.unequip_to(_inventory, _drag.index, index, _drag.rotate)
		elif index == _drag.index:
			success = not _drag.rotate or _inventory.rotate_stack(index)
		else:
			success = _inventory.move_stack(_drag.index, index, _drag.quantity, _drag.rotate) > 0
	clear_selection()
	status.text = "Moved • Shift-drag: half • R: rotate" if success else "No change — destination unavailable"
	return success


func _input(event: InputEvent) -> void:
	if not visible or _inventory == null:
		return
	if event.is_action_pressed("reset_player") and not event.is_echo() and not _drag.is_empty():
		_drag.rotate = not _drag.rotate
		var footprint := _inventory.get_catalog().get_item_size(_drag.stack.item_id, _drag.stack.rotated != _drag.rotate)
		_drag.grab_cell = Vector2i(mini(_drag.grab_cell.x, footprint.x - 1), mini(_drag.grab_cell.y, footprint.y - 1))
		_dragging = true
		get_viewport().set_input_as_handled()
		_refresh()
	elif event is InputEventMouseMotion:
		_pointer = event.position
		if not _drag.is_empty() and _pointer.distance_to(_press_position) > 6:
			_dragging = true
		_refresh()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pointer = event.position
		var target := _target_at(_pointer)
		if event.pressed:
			if not target.is_empty() and begin_drag(target.kind, target.index, event.shift_pressed):
				_press_position = _pointer
				get_viewport().set_input_as_handled()
		elif not _drag.is_empty():
			if _dragging and not target.is_empty():
				commit_drop(target.kind, target.index)
			else:
				clear_selection()
			get_viewport().set_input_as_handled()


func draw_drag(canvas: Control) -> void:
	if _drag.is_empty() or not _dragging:
		return
	var target := _target_at(_pointer)
	var valid := not target.is_empty() and can_drop(target.kind, target.index)
	var footprint := _inventory.get_catalog().get_item_size(_drag.stack.item_id, _drag.stack.rotated != _drag.rotate)
	var rect := Rect2(_pointer + Vector2(12, 12), Vector2(footprint) * cell_size())
	if not target.is_empty():
		if target.kind == "grid":
			rect.position = grid.global_position + Vector2(_inventory.index_to_cell(target.index)) * cell_size()
		else:
			rect = equipment_rect(target.index)
			rect.position += character_board.global_position
	var preview := InventoryStack.new(_drag.stack.item_id, 1 if not target.is_empty() and target.kind == "equipment" else _drag.quantity)
	draw_item(canvas, rect.grow(-4), preview, false)
	canvas.draw_rect(rect.grow(-2), Color(0.42, 0.68, 0.5, 0.35) if valid else Color(0.8, 0.3, 0.3, 0.35))
	canvas.draw_rect(rect.grow(-2), Color("8cbd9a") if valid else Color("d87a7a"), false, 2)
