$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    New-Item -ItemType Directory -Force -Path (Join-Path $projectRoot 'build') | Out-Null
    python tools/godot.py --headless --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
    python tools/godot.py --headless --script res://tests/test_simulation.gd
    if ($LASTEXITCODE -ne 0) { throw 'Simulation tests failed' }
    python tools/godot.py --headless --script res://tests/test_ui.gd
    if ($LASTEXITCODE -ne 0) { throw 'UI tests failed' }
    python tools/godot.py --headless --script res://tests/test_controls.gd
    if ($LASTEXITCODE -ne 0) { throw 'Control regression tests failed' }
    python tools/godot.py --headless --script res://tests/test_v03.gd
    if ($LASTEXITCODE -ne 0) { throw 'Animation, drone and ragdoll regression tests failed' }
    python tools/godot.py --headless --script res://tests/test_v04.gd
    if ($LASTEXITCODE -ne 0) { throw 'Speed, collision display and skin import tests failed' }
    python tools/godot.py --headless --script res://tests/test_v05.gd
    if ($LASTEXITCODE -ne 0) { throw 'Skin anchors, camera and wall jump tests failed' }
    python tools/godot.py --headless --script res://tests/test_v051.gd
    if ($LASTEXITCODE -ne 0) { throw 'Run-cycle and forgiving wall-jump tests failed' }
    python tools/godot.py --headless --script res://tests/test_v052.gd
    if ($LASTEXITCODE -ne 0) { throw 'Suicide and death effects tests failed' }
    python tools/godot.py --headless --script res://tests/test_v053.gd
    if ($LASTEXITCODE -ne 0) { throw 'Laser drone timing and targeting tests failed' }
    python tools/godot.py --headless --script res://tests/test_v06.gd
    if ($LASTEXITCODE -ne 0) { throw 'Animation import and background tests failed' }
    python tools/test_prts_resources.py
    if ($LASTEXITCODE -ne 0) { throw 'PRTS resource discovery tests failed' }
    python tools/godot.py --headless --script res://tests/test_v061.gd
    if ($LASTEXITCODE -ne 0) { throw 'Full preset and native resource downloader tests failed' }
    python tools/godot.py --headless --export-release 'Windows Desktop' ../build/NVLink-0.6.1.exe
    if ($LASTEXITCODE -ne 0) { throw 'Windows export failed' }
    python tools/godot.py --headless --script res://tests/write_engine_licenses.gd
    python tools/package_build.py
    if ($LASTEXITCODE -ne 0) { throw 'Packaging failed' }
} finally {
    Pop-Location
}
