# Wildscape

A solo-developed 3D sandbox survival RPG built with Godot 4 and GDScript.
Gameplay and art direction are still being defined.

## Foundation

- `project.godot`: project entry point; Compatibility renderer for a modest initial baseline.
- `scenes/main.tscn`: empty Main Node3D, allowing project startup with no gameplay or visual content.
- `AGENTS.md`: development rules and validation expectations.

Keep related scenes and scripts together under `scenes/`. Create additional folders only as actual features require them. Renderer and art direction can be reconsidered when visual requirements are known.

## Open and run

Validated engine baseline: Godot **4.7.2 stable** (standard Windows editor; no .NET required).
Import `project.godot` in Godot, then press F6 for the open scene or F5 for the project.
An empty window is expected at this stage.

The executable found on this machine is `C:\Users\scami\Downloads\Godot_v4.7.2-stable_win64.exe`; it is not on PATH. Adjust the following local variable for other installations.

## Validation (PowerShell, from the repository root)

```powershell
$godotExe = 'C:\Users\scami\Downloads\Godot_v4.7.2-stable_win64.exe'
$projectRoot = (Get-Location).Path
New-Item -ItemType Directory -Force -Path .godot | Out-Null
$commonArgs = "--path `"$projectRoot`""
$result = Start-Process -FilePath $godotExe -ArgumentList "$commonArgs --headless --import --log-file `"$projectRoot/.godot/import.log`"" -WindowStyle Hidden -Wait -PassThru
$result.ExitCode # Must be 0; also inspect output/log for errors.
Get-Content .godot/import.log
$result = Start-Process -FilePath $godotExe -ArgumentList "$commonArgs --headless --quit-after 60 --log-file `"$projectRoot/.godot/startup-headless.log`"" -WindowStyle Hidden -Wait -PassThru
$result.ExitCode
Get-Content .godot/startup-headless.log
$result = Start-Process -FilePath $godotExe -ArgumentList "$commonArgs --quit-after 60 --log-file `"$projectRoot/.godot/startup-graphics.log`"" -WindowStyle Hidden -Wait -PassThru
$result.ExitCode
Get-Content .godot/startup-graphics.log
```

The final command requires a graphical desktop and tests renderer initialization.
Headless checks cover import and scene startup, not visual correctness or gameplay.
Logs and editor caches remain in ignored `.godot/`.
No automated test framework, export presets or packaged-build validation are configured yet.

Verified on 2026-10-22: headless import, headless startup and graphical startup
(60 iterations each for the startup checks) exited with code 0 and no logged errors.
The graphical run initialized OpenGL 3.3 Compatibility on an NVIDIA GeForce RTX 5060 Ti.
Restricted sandbox execution initially blocked access to Godot user settings and the
Windows certificate store; validation succeeded with normal OS access. Graphical
initialization was checked via the engine log; no visual UI inspection was performed.
PowerShell uses `Start-Process -Wait -PassThru` here to reliably await the Windows GUI
executable and obtain its actual exit code.
