extends SceneTree
## Retired entry point: prevents obsolete refinement from overwriting saved data.
## Historical source is archived with the Task 7.3 native terrain backup.


func _initialize() -> void:
	push_error("V3 refinement retired. Use build_island.gd -- --write-island-v5 only for deliberate replacement of saved terrain.")
	quit(1)
