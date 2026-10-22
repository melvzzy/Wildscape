class_name InventoryStack
extends RefCounted
## Mutable stack data. Public inventory reads return detached snapshots.

var item_id: StringName
var quantity: int
var position: Vector2i
var rotated: bool


func _init(id: StringName = &"", amount: int = 0, cell: Vector2i = Vector2i(-1, -1), rotation: bool = false) -> void:
	item_id = id
	quantity = amount
	position = cell
	rotated = rotation
