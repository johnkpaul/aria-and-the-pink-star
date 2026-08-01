@echo off
REM Builds Aria and the Pink Star for the web: generates procedural art assets,
REM then exports the HTML5 "Web" preset. Requires the `godot` CLI (Godot
REM 4.2+) to be on your PATH, or set GODOT_BIN to its full path.

setlocal

if "%GODOT_BIN%"=="" set GODOT_BIN=godot
set PROJECT_DIR=%~dp0

echo == Aria and the Pink Star: web build ==

if not exist "%PROJECT_DIR%generated_assets" mkdir "%PROJECT_DIR%generated_assets"

echo -- Generating procedural art assets --
"%GODOT_BIN%" --headless --path "%PROJECT_DIR%" --script scripts/procedural_art.gd
if errorlevel 1 goto :error

if not exist "%PROJECT_DIR%build\web" mkdir "%PROJECT_DIR%build\web"

echo -- Exporting HTML5 build --
"%GODOT_BIN%" --headless --path "%PROJECT_DIR%" --export-release "Web" "%PROJECT_DIR%build\web\index.html"
if errorlevel 1 goto :error

echo == Build complete: %PROJECT_DIR%build\web\index.html ==
goto :eof

:error
echo Build failed.
exit /b 1
