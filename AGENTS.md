# Wildscape

- Solo-developed 3D sandbox survival RPG using Godot 4 and GDScript.
- Exploration, gathering, crafting, building, inventory, equipment, loot and RPG progression are directions, not finalized requirements. Singleplayer first; co-op may follow later. Art style is undecided.
- Keep the foundation small, stable and expandable. Implement only the requested scope; avoid speculative systems, frameworks, managers and autoloads.
- Current baseline: Godot 4.7.2 stable, Compatibility renderer. Coordinate engine or renderer changes explicitly.
- Use snake_case for files, folders, functions and variables; PascalCase for node and class names. Prefer typed GDScript where practical.
- Use tabs for GDScript indentation and LF line endings (see .gitattributes). One Godot unit is one meter; player scene origin is at the feet. Physics layer 1 is World, layer 2 is Player.
- Keep scenes and their related scripts together under scenes/. Add feature folders and shared resources only when used. Preserve Godot-generated .uid sidecars and resource .import metadata; never version .godot/.
- Main composes the reusable player and development playground. Keep movement/collision in the player script and replaceable geometry under Visuals. Gameplay beyond the controller/playground still requires a specific request.
- After project/resource changes, run headless import and a bounded startup as documented in README.md. Check output and exit codes; headless success does not validate graphics. Test graphical startup when available and report any untested behavior.
- Run tests/player_smoke_test.gd after controller, camera, input or collision changes. It uses native Godot physics and simulated input; no external test framework is required. Interactive camera feel and visual quality still need manual testing.
- Do not install tools/plugins or create commits, pushes or merges without user authorization.
