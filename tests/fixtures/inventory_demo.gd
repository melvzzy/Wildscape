extends Node
## Deliberately isolated populated fixture. Production gameplay never seeds items.


func _ready() -> void:
	var player: CharacterBody3D = $Gameplay/Player
	player.inventory.add(&"test_alpha", 17)
	player.inventory.add(&"test_beta", 6)
	player.inventory.add(&"test_gamma", 1)
	$Gameplay/Menu.set_inventory_open(true)
