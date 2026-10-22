extends Control
## Drawing only. Placement decisions belong to the injected data models.

var view: Control
var kind: String


func _draw() -> void:
	if view == null or view._inventory == null:
		return
	if kind == "ghost":
		view.draw_drag(self)
		return
	if kind == "grid":
		var dimensions: Vector2i = view._inventory.get_grid_size()
		var cell: float = view.cell_size()
		draw_rect(Rect2(Vector2.ZERO, Vector2(dimensions) * cell), Color("111214"))
		for x in range(dimensions.x + 1):
			draw_line(Vector2(x * cell, 0), Vector2(x * cell, dimensions.y * cell), Color("3a3c40"), view.grid_line_width(), true)
		for y in range(dimensions.y + 1):
			draw_line(Vector2(0, y * cell), Vector2(dimensions.x * cell, y * cell), Color("3a3c40"), view.grid_line_width(), true)
		for index in range(view._inventory.get_capacity()):
			var stack: InventoryStack = view._inventory.get_stack(index)
			if stack != null:
				var footprint: Vector2i = view._inventory.get_catalog().get_item_size(stack.item_id, stack.rotated)
				var rect := Rect2(Vector2(stack.position) * cell, Vector2(footprint) * cell).grow(-4)
				view.draw_item(self, rect, stack, index == view._selected)
	else:
		# One central silhouette, framed by paired equipment columns. The drawn
		# placeholder remains replaceable without changing slots or hit testing.
		draw_circle(Vector2(300, 292), 192, Color("17191d"))
		draw_line(Vector2(204, 552), Vector2(396, 552), Color("3a3d43"), view.grid_line_width(), true)
		draw_set_transform(Vector2(-120, -120), 0, Vector2(1.4, 1.4))
		var shade := Color("555a62")
		draw_circle(Vector2(300, 165), 30, shade)
		draw_style_box(view.make_style(shade, Color("636872")), Rect2(266, 205, 68, 125))
		draw_line(Vector2(267, 218), Vector2(237, 325), shade, 22, true)
		draw_line(Vector2(333, 218), Vector2(363, 325), shade, 22, true)
		draw_line(Vector2(282, 320), Vector2(270, 450), shade, 25, true)
		draw_line(Vector2(318, 320), Vector2(330, 450), shade, 25, true)
		draw_set_transform(Vector2.ZERO)
		for slot in range(6):
			var rect: Rect2 = view.equipment_rect(slot)
			draw_style_box(view.make_style(Color("111214"), Color("46484e")), rect)
			view.draw_text(self, rect.position + Vector2(-24, -10), view.SLOT_NAMES[slot], view.readable_font_size(20, 11), rect.size.x + 48)
			var stack: InventoryStack = view._equipment.get_stack(slot) if view._equipment != null else null
			if stack != null:
				view.draw_item(self, rect.grow(-4), stack, false)
