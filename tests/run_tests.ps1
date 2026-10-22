param(
    [string]$GodotPath = 'godot',
    [switch]$Graphical,
    [switch]$TerrainOnly,
    [switch]$FocusedViews
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$engine = (Get-Command $GodotPath -CommandType Application -ErrorAction Stop).Source
$logRoot = Join-Path $projectRoot '.godot'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$script:checkTotal = 0

function Invoke-GodotCheck {
    param([string]$Name, [string]$Options, [string]$ExpectedResult = '')

    $logPath = Join-Path $logRoot "$Name.log"
    if (Test-Path -LiteralPath $logPath) { Remove-Item -LiteralPath $logPath }
    $arguments = "--path `"$projectRoot`" --log-file `"$logPath`" $Options"
    $process = Start-Process -FilePath $engine -ArgumentList $arguments -WindowStyle Hidden -PassThru
    if (-not $process.WaitForExit(60000)) {
        $process.Kill()
        throw "$Name exceeded the 60 second timeout."
    }
    $process.Refresh()
    if (-not (Test-Path -LiteralPath $logPath)) { throw "$Name produced no log." }
    $logText = Get-Content -LiteralPath $logPath -Raw
    $logText = $logText -replace '\x1B\[[0-?]*[ -/]*[@-~]', ''
    $errorPattern = '(?im)^\s*(?:SCRIPT ERROR|ERROR|FATAL|FAIL|USER ERROR):|\b(?:Parse Error|Assertion failed|CRASHED)\b'
    if ($process.ExitCode -ne 0 -or $logText -match $errorPattern) {
        Write-Output $logText
        throw "$Name failed (exit $($process.ExitCode)); see $logPath"
    }
    if ($ExpectedResult) {
        $result = [regex]::Match($logText, "(?m)^${ExpectedResult} RESULT: (\d+) checks, 0 failures")
        if (-not $result.Success) { throw "$Name did not report a successful test result; see $logPath" }
        $script:checkTotal += [int]$result.Groups[1].Value
        Write-Output "PASS $Name : $($result.Groups[1].Value) checks"
    } else {
        Write-Output "PASS $Name : exit 0, no logged errors"
    }
}

Invoke-GodotCheck 'import' '--headless --import'
if ($TerrainOnly) {
    Invoke-GodotCheck 'island' '--headless --script res://tests/island_test.gd' 'ISLAND'
    Invoke-GodotCheck 'terrain-preflight' '--headless --script res://tests/terrain_preflight_test.gd' 'TERRAIN PREFLIGHT'
    Invoke-GodotCheck 'startup-headless' '--headless --quit-after 120'
    Invoke-GodotCheck 'gameplay-headless' '--headless --scene res://scenes/main.tscn --quit-after 120'
    if ($Graphical) {
        Invoke-GodotCheck 'startup-graphics' '--quit-after 120'
        if ($FocusedViews) {
            # Native physics/persistence assertions already ran headlessly.
            # Six renders include a real main-menu Play and grounded FPS pose.
            Invoke-GodotCheck 'island-survey' '--script res://tests/island_visual_survey.gd -- --survey=after --focused'
        } else {
            Invoke-GodotCheck 'island-graphics' '--script res://tests/island_test.gd' 'ISLAND'
            Invoke-GodotCheck 'island-survey' '--script res://tests/island_visual_survey.gd -- --survey=after'
        }
    }
    Write-Output "TERRAIN CHECKS PASSED: $script:checkTotal assertions; logs in $logRoot"
    return
}
Invoke-GodotCheck 'smoke' '--headless --script res://tests/player_smoke_test.gd' 'SMOKE'
Invoke-GodotCheck 'interaction-smoke' '--headless --script res://tests/interaction_smoke_test.gd' 'INTERACTION'
Invoke-GodotCheck 'menu-flow' '--headless --script res://tests/menu_flow_test.gd' 'FLOW'
Invoke-GodotCheck 'inventory-model' '--headless --script res://tests/inventory_model_test.gd' 'INVENTORY MODEL'
Invoke-GodotCheck 'grid-inventory' '--headless --script res://tests/grid_inventory_test.gd' 'GRID INVENTORY'
Invoke-GodotCheck 'inventory-ui' '--headless --script res://tests/inventory_ui_test.gd' 'INVENTORY UI'
Invoke-GodotCheck 'world-collection' '--headless --script res://tests/world_collection_test.gd' 'WORLD COLLECTION'
Invoke-GodotCheck 'island' '--headless --script res://tests/island_test.gd' 'ISLAND'
Invoke-GodotCheck 'terrain-preflight' '--headless --script res://tests/terrain_preflight_test.gd' 'TERRAIN PREFLIGHT'
Invoke-GodotCheck 'startup-headless' '--headless --quit-after 120'
Invoke-GodotCheck 'gameplay-headless' '--headless --scene res://scenes/main.tscn --quit-after 120'
if ($Graphical) {
    Invoke-GodotCheck 'startup-graphics' '--quit-after 120'
    Invoke-GodotCheck 'menu-flow-graphics' '--script res://tests/menu_flow_test.gd -- --capture-ui' 'FLOW'
    Invoke-GodotCheck 'inventory-ui-graphics' '--script res://tests/inventory_ui_test.gd -- --capture-ui' 'INVENTORY UI'
    Invoke-GodotCheck 'world-collection-graphics' '--script res://tests/world_collection_test.gd -- --capture-world' 'WORLD COLLECTION'
    Invoke-GodotCheck 'island-graphics' '--script res://tests/island_test.gd' 'ISLAND'
    Invoke-GodotCheck 'island-survey' '--script res://tests/island_visual_survey.gd -- --survey=after'
}
Write-Output "ALL CHECKS PASSED: $script:checkTotal assertions; logs in $logRoot"
