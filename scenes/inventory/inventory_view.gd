extends Control
## Observes an injected model; owns only selection state, never item quantities.

signal close_requested

@onready var grid: GridContainer = $Center/Panel/Margin/Stack/Scroll/Grid
@onready var status: Label = $Center/Panel/Margin/Stack/Status
@onready var split_button: Button = $Center/Panel/Margin/Stack/Buttons/Split
@onready var deselect_button: Button = $Center/Panel/Margin/Stack/Buttons/Deselect
@onready var close_button: Button = $Center/Panel/Margin/Stack/Buttons/Close

var _inventory: SlotInventory
var _selected: int = -1
var _splitting: bool = false
var _buttons: Array[Button] = []


func _ready() -> void:
	close_button.pressed.connect(func() -> void: close_requested.emit())
	deselect_button.pressed.connect(clear_selection)
	split_button.pressed.connect(_begin_split)


func bind_inventory(inventory: SlotInventory) -> void:
	if _inventory != null and _inventory.changed.is_connected(_refresh):
		_inventory.changed.disconnect(_refresh)
	_inventory = inventory
	for button in _buttons:
		grid.remove_child(button)
		button.queue_free()
	_buttons.clear()
	if _inventory != null:
		_inventory.changed.connect(_refresh)
		grid.columns = _inventory.get_grid_size().x
		for index in range(_inventory.get_capacity()):
			var button := Button.new()
			button.custom_minimum_size = Vector2(145, 110)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", 18)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 32)
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			button.pressed.connect(_slot_pressed.bind(index))
			grid.add_child(button)
			_buttons.append(button)
	clear_selection()


func open() -> void:
	clear_selection()
	show()
	if not _buttons.is_empty():
		_buttons[0].grab_focus()
	else:
		close_button.grab_focus()


func clear_selection() -> void:
	_selected = -1
	_splitting = false
	_refresh()


func _refresh() -> void:
	if _inventory == null:
		return
	var selected_stack := _inventory.get_stack(_selected)
	if selected_stack == null:
		_selected = -1
		_splitting = false
	for index in range(_buttons.size()):
		var anchor := _inventory.get_anchor_at(index)
		var stack := _inventory.get_stack(anchor)
		var button := _buttons[index]
		button.icon = null
		if stack == null:
			button.text = "%02d\n—\nEmpty" % (index + 1)
		else:
			var definition := _inventory.get_definition(stack.item_id)
			if anchor != index:
				button.text = "%02d\nCovered → %02d" % [index + 1, anchor + 1]
			else:
				var marker := "[" + definition.display_name.left(1) + "]"
				button.text = "%02d  %s\n%s\n%d / %d" % [index + 1, marker, definition.display_name, stack.quantity, definition.max_stack_size]
				button.icon = definition.icon
		button.modulate = Color(1.0, 0.85, 0.48) if anchor == _selected and anchor >= 0 else Color.WHITE
	split_button.disabled = selected_stack == null or selected_stack.quantity < 2
	deselect_button.disabled = selected_stack == null
	if _splitting:
		status.text = "Choose an empty slot for half the selected stack."
	elif selected_stack != null:
		status.text = "%s selected — choose an empty or matching slot." % _inventory.get_definition(selected_stack.item_id).display_name
	else:
		status.text = "Select a stack to move, merge or split it."


func _slot_pressed(index: int) -> void:
	if _inventory == null:
		return
	var anchor := _inventory.get_anchor_at(index)
	if anchor >= 0:
		index = anchor
	if _selected < 0:
		if _inventory.get_stack(index) != null:
			_selected = index
		_refresh()
		return
	if index == _selected:
		clear_selection()
		return
	var success: bool
	if _splitting:
		var stack := _inventory.get_stack(_selected)
		success = stack != null and _inventory.split_stack(_selected, index, floori(stack.quantity / 2.0))
	else:
		success = _inventory.move_stack(_selected, index) > 0
	if success:
		clear_selection()
	else:
		status.text = "No change: destination is occupied or the stack is full."


func _begin_split() -> void:
	var stack := _inventory.get_stack(_selected)
	if stack != null and stack.quantity > 1:
		_splitting = true
		_refresh()
