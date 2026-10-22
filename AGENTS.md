# Wildscape

- Solo-developed 3D sandbox survival RPG using Godot 4 and GDScript.
- Exploration, gathering, crafting, building, inventory, equipment, loot and RPG progression are directions, not finalized requirements. Singleplayer first; co-op may follow later. Art style is undecided.
- Keep the foundation small, stable and expandable. Implement only the requested scope; avoid speculative systems, frameworks, managers and autoloads.
- Current baseline: Godot 4.7.2 stable, Compatibility renderer. Coordinate engine or renderer changes explicitly.
- Use snake_case for files, folders, functions and variables; PascalCase for node and class names. Prefer typed GDScript where practical.
- Keep scenes and their related scripts together under scenes/. Add feature folders and shared resources only when used. Preserve Godot-generated .uid sidecars and resource .import metadata; never version .godot/.
- The empty Main Node3D is only a startup entry point. Do not add gameplay, cameras, UI, worlds or assets unless requested.
- After project/resource changes, run headless import and a bounded startup as documented in README.md. Check output and exit codes; headless success does not validate graphics. Test graphical startup when available and report any untested behavior.
- Add focused behavior tests when gameplay warrants them; no test framework is required for this empty foundation.
- Do not install tools/plugins or create commits, pushes or merges without user authorization.
