# Antigravity Plus Windows Rollback Utility
# Restores Antigravity application to its default state on Windows

$ErrorActionPreference = "Stop"

# ANSI Colors
$ESC = [char]27
$RESET = "$ESC[0m"
$BOLD = "$ESC[1m"
$DIM = "$ESC[2m"
$CYAN = "$ESC[38;5;109m"
$GRAY = "$ESC[38;5;244m"
$LIGHT_GRAY = "$ESC[38;5;250m"
$GREEN = "$ESC[38;5;108m"
$YELLOW = "$ESC[38;5;178m"

Clear-Host
Write-Host "$GRAY──────────────────────────────────────────────────────────$RESET"
Write-Host " $BOLD$LIGHT_GRAY`Antigravity Plus Rollback Utility$RESET"
Write-Host " $DIM`Restores Antigravity application to its default state$RESET"
Write-Host "$GRAY──────────────────────────────────────────────────────────$RESET"

# 1. Locate installation directory
Write-Host "`n$CYAN◆ Locating Deployment Directory:$RESET"
$USER_PROFILE = $env:USERPROFILE
$LOCAL_APPDATA = $env:LOCALAPPDATA

$POSSIBLE_PATHS = @(
    "$LOCAL_APPDATA\Programs\antigravity",
    "$LOCAL_APPDATA\Programs\Antigravity",
    "C:\Program Files\antigravity",
    "C:\Program Files\Antigravity"
)

$BASE_DIR = ""
foreach ($path in $POSSIBLE_PATHS) {
    if (Test-Path $path) {
        $BASE_DIR = $path
        break
    }
}

if ($BASE_DIR -ne "") {
    Write-Host "  $GREEN✓ Found installation directory:$RESET $BASE_DIR"
    $confirm = Read-Host "  Use this directory? [Y/n] (default: Y)"
    if ($confirm -eq "") { $confirm = "Y" }
    if ($confirm -notmatch "^[Yy]$") {
        $BASE_DIR = ""
    }
}

if ($BASE_DIR -eq "") {
    $BASE_DIR = Read-Host "  Please enter the full installation path"
}

# Normalize path
$BASE_DIR = $BASE_DIR.TrimEnd("\")
if (!(Test-Path "$BASE_DIR") -or (!(Test-Path "$BASE_DIR\antigravity.exe") -and !(Test-Path "$BASE_DIR\Antigravity.exe"))) {
    Write-Host "`n$YELLOW𐄂 Error: Invalid Antigravity installation path. Could not find executable.$RESET`n"
    Exit 1
}

$RESOURCES_DIR = "$BASE_DIR\resources"
if (!(Test-Path $RESOURCES_DIR)) {
    Write-Host "`n$YELLOW𐄂 Error: Resources directory not found under '$BASE_DIR'.$RESET`n"
    Exit 1
}

Write-Host "  $GREEN✓ Resolved resources directory:$RESET $RESOURCES_DIR"

# Check write permission
$tempFile = "$RESOURCES_DIR\.write_test"
try {
    [System.IO.File]::WriteAllText($tempFile, "test")
    Remove-Item $tempFile -Force
} catch {
    Write-Host "`n$YELLOW𐄂 Execution denied: Target directory is not writeable. Please run PowerShell as Administrator.$RESET`n"
    Exit 1
}

cd $RESOURCES_DIR

# 2. Check for backups
if (!(Test-Path "app.asar.bak")) {
    Write-Host "`n$YELLOW𐄂 Error: No backup file (app.asar.bak) found in '$RESOURCES_DIR'.$RESET"
    Write-Host "  The application is already in its default state or cannot be restored automatically.`n"
    Exit 1
}

Write-Host "`n$CYAN◆ Confirmation:$RESET"
Write-Host "  This will restore the original app.asar and remove all UI patches."
$confirm = Read-Host "  Proceed with rollback? [Y/n] (default: Y)"
if ($confirm -eq "") { $confirm = "Y" }
if ($confirm -notmatch "^[Yy]$") {
    Write-Host "`n$YELLOW𐄂 Rollback aborted by user.$RESET`n"
    Exit 0
}

# 3. Restore backups
Write-Host "`n$CYAN◆ Restoring assets:$RESET"

if (Test-Path "app") {
    Write-Host "  $DIM`○ Removing patched app folder...$RESET"
    Remove-Item -Recurse -Force "app"
}

if (Test-Path "app.asar.disabled") {
    Remove-Item -Force "app.asar.disabled"
}

Write-Host "  $DIM`○ Restoring original app.asar...$RESET"
Copy-Item "app.asar.bak" "app.asar" -Force
Remove-Item -Force "app.asar.bak"

# Restore unpacked assets if any
if (Test-Path "app.asar.unpacked.disabled") {
    Write-Host "  $DIM`○ Restoring unpacked dependencies...$RESET"
    if (Test-Path "app.asar.unpacked") { Remove-Item -Recurse -Force "app.asar.unpacked" }
    Rename-Item "app.asar.unpacked.disabled" "app.asar.unpacked"
}
if (Test-Path "app.asar.unpacked.bak") {
    Remove-Item -Recurse -Force "app.asar.unpacked.bak"
}

Write-Host "  $GREEN✓ Restoration complete.$RESET"

# 4. Relaunch
$RESTART_APP = $false
$ACTIVE_PROCESS = Get-Process -Name "antigravity" -ErrorAction SilentlyContinue
if ($ACTIVE_PROCESS) {
    Write-Host "`n$CYAN◆ Process Detection:$RESET Antigravity is currently active."
    $chk_kill = Read-Host "  Do you want to restart it now to verify the restoration? [Y/n] (default: Y)"
    if ($chk_kill -eq "") { $chk_kill = "Y" }
    if ($chk_kill -match "^[Yy]$") {
        $RESTART_APP = $true
        Stop-Process -Name "antigravity" -Force
        Start-Sleep -Seconds 1
    }
}

Write-Host "`n$GRAY──────────────────────────────────────────────────────────$RESET"
if ($RESTART_APP) {
    Write-Host " $GREEN✓ Complete:$RESET Relaunching Antigravity..."
    Write-Host "$GRAY──────────────────────────────────────────────────────────$RESET`n"
    
    $EXE_PATH = if (Test-Path "$BASE_DIR\antigravity.exe") { "$BASE_DIR\antigravity.exe" } else { "$BASE_DIR\Antigravity.exe" }
    Start-Process -FilePath $EXE_PATH
} else {
    Write-Host " $GREEN✓ Complete:$RESET Pipeline finished. Launch Antigravity manually to verify."
    Write-Host "$GRAY──────────────────────────────────────────────────────────$RESET`n"
}
