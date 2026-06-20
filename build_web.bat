@echo off
REM Red Alert Web - Build Script
REM Requires Godot 4.x to be installed and in PATH

echo === Red Alert Web Build Script ===
echo.

REM Check if Godot is available
where godot >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo ERROR: Godot not found in PATH
    echo Please install Godot 4.x and add it to your PATH
    echo Download: https://godotengine.org/download
    pause
    exit /b 1
)

echo [1/3] Validating project...
godot --headless --path . --check-only
if %ERRORLEVEL% neq 0 (
    echo ERROR: Project validation failed
    pause
    exit /b 1
)

echo [2/3] Exporting Web build...
if not exist "export\web" mkdir "export\web"
godot --headless --path . --export-release "Web" "export\web\index.html"
if %ERRORLEVEL% neq 0 (
    echo ERROR: Export failed
    pause
    exit /b 1
)

echo [3/3] Done!
echo.
echo Web build exported to: export\web\
echo Open export\web\index.html in a browser to play
echo.
echo To serve locally:
echo   python -m http.server 8000 --directory export\web
echo   Then open http://localhost:8000
pause
