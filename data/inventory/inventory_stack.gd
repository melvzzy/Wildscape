class_name InventoryStack
extends RefCounted
## Mutable stack data. Public inventory reads return detached snapshots.

var item_id: StringName
var quantity: int


func _init(id: StringName = &"", amount: int = 0) -> void:
	item_id = id
	quantity = amount
