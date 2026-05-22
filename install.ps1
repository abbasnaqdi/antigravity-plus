# Antigravity Plus Windows Patcher
# Restores / Patches Antigravity layout and typography on Windows

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
Write-Host " $BOLD$LIGHT_GRAY`Antigravity Plus (Windows Patcher)$RESET"
Write-Host " $DIM`Deep Shadow-DOM CSS Injector & Typographic Engine$RESET"
Write-Host "$GRAY──────────────────────────────────────────────────────────$RESET"

# 1. OS & Dependencies check
if (!(Get-Command node -ErrorAction SilentlyContinue) -or !(Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Host "`n$YELLOW𐄂 Error: Node.js and npm are required to run this script.$RESET"
    Write-Host "  Please install Node.js from https://nodejs.org/ and try again.`n"
    Exit 1
}

# 2. Locate installation directory
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

# 3. Load / Query configuration
$CONFIG_DIR = "$USER_PROFILE\.antigravity-plus"
$CONFIG_FILE = "$CONFIG_DIR\patcher.conf"

$DEFAULT_UI = "Inter, Vazirmatn, Segoe UI, Arial"
$DEFAULT_MONO = "Consolas, Cascadia Code, Fira Code, JetBrains Mono"
$DEFAULT_SIZE = "11"
$DEFAULT_RADIUS = "5"
$DEFAULT_BIDI = "Y"
$DEFAULT_SMOOTH = "Y"
$DEFAULT_CSS = ""

if (Test-Path $CONFIG_FILE) {
    # Read config file
    Get-Content $CONFIG_FILE | ForEach-Object {
        if ($_ -match "^UI_FONT=(.*)") { $DEFAULT_UI = $Matches[1].Trim('"').Trim("'") }
        elseif ($_ -match "^MONO_FONT=(.*)") { $DEFAULT_MONO = $Matches[1].Trim('"').Trim("'") }
        elseif ($_ -match "^FONT_SIZE=(.*)") { $DEFAULT_SIZE = $Matches[1].Trim('"').Trim("'") }
        elseif ($_ -match "^BORDER_RADIUS=(.*)") { $DEFAULT_RADIUS = $Matches[1].Trim('"').Trim("'") }
        elseif ($_ -match "^INPUT_BIDI=(.*)") { $DEFAULT_BIDI = $Matches[1].Trim('"').Trim("'") }
        elseif ($_ -match "^INPUT_SMOOTH=(.*)") { $DEFAULT_SMOOTH = $Matches[1].Trim('"').Trim("'") }
        elseif ($_ -match "^CUSTOM_CSS_PATH=(.*)") { $DEFAULT_CSS = $Matches[1].Trim('"').Trim("'") }
    }
}

Write-Host "`n$CYAN◆ Dynamic Parameter Selection:$RESET"
Write-Host "  $DIM`Note: Type raw names separated by commas. Hit Enter to accept defaults.$RESET"

$INPUT_UI = Read-Host "  Enter UI Font Stack (default: $DEFAULT_UI)"
if ($INPUT_UI -eq "") { $INPUT_UI = $DEFAULT_UI }

$INPUT_MONO = Read-Host "  Enter Monospace Code Font (default: $DEFAULT_MONO)"
if ($INPUT_MONO -eq "") { $INPUT_MONO = $DEFAULT_MONO }

$FONT_SIZE = Read-Host "  Enter Base Font Size in pt (default: $DEFAULT_SIZE)"
if ($FONT_SIZE -eq "") { $FONT_SIZE = $DEFAULT_SIZE }

$BORDER_RADIUS = Read-Host "  Enter Maximum Border Radius in px (0-5) (default: $DEFAULT_RADIUS)"
if ($BORDER_RADIUS -eq "") { $BORDER_RADIUS = $DEFAULT_RADIUS }

$INPUT_BIDI = Read-Host "  Enable Smart Bi-directional Layout (RTL/LTR auto)? [Y/n] (default: $DEFAULT_BIDI)"
if ($INPUT_BIDI -eq "") { $INPUT_BIDI = $DEFAULT_BIDI }

$INPUT_SMOOTH = Read-Host "  Enable Sub-pixel Text Anti-aliasing Optimization? [Y/n] (default: $DEFAULT_SMOOTH)"
if ($INPUT_SMOOTH -eq "") { $INPUT_SMOOTH = $DEFAULT_SMOOTH }

$CUSTOM_CSS_PATH = Read-Host "  Enter path to custom CSS file (optional, default: $DEFAULT_CSS)"
if ($CUSTOM_CSS_PATH -eq "") { $CUSTOM_CSS_PATH = $DEFAULT_CSS }

$CUSTOM_CSS_CONTENT = ""
if ($CUSTOM_CSS_PATH -ne "") {
    if (Test-Path $CUSTOM_CSS_PATH) {
        $CUSTOM_CSS_CONTENT = Get-Content -Raw $CUSTOM_CSS_PATH
        Write-Host "  $GREEN✓ Loaded Custom CSS from:$RESET $CUSTOM_CSS_PATH"
    } else {
        Write-Host "  $YELLOW⚠ Custom CSS file not found at:$RESET $CUSTOM_CSS_PATH"
        $CUSTOM_CSS_PATH = ""
    }
}

# Clean and format font stacks for CSS
$UI_FONT = ""
foreach ($font in $INPUT_UI.Split(',')) {
    $f = $font.Trim()
    if ($f -ne "") {
        if ($UI_FONT -eq "") { $UI_FONT = "'$f'" } else { $UI_FONT = "$UI_FONT, '$f'" }
    }
}
$UI_FONT = "$UI_FONT, sans-serif"

$MONO_FONT = ""
foreach ($font in $INPUT_MONO.Split(',')) {
    $f = $font.Trim()
    if ($f -ne "") {
        if ($MONO_FONT -eq "") { $MONO_FONT = "'$f'" } else { $MONO_FONT = "$MONO_FONT, '$f'" }
    }
}
$MONO_FONT = "$MONO_FONT, 'Consolas', 'Cascadia Code', 'Courier New', monospace"

# 4. Summary Screen
Write-Host "`n$CYAN◆ Configuration Summary:$RESET"
Write-Host "  • Target Path:     $LIGHT_GRAY$BASE_DIR$RESET"
Write-Host "  • UI Font Stack:   $LIGHT_GRAY$UI_FONT$RESET"
Write-Host "  • Monospace Font:  $LIGHT_GRAY$MONO_FONT$RESET"
Write-Host "  • Base Font Size:  $LIGHT_GRAY$FONT_SIZE`pt$RESET"
Write-Host "  • Max Corner Rad:  $LIGHT_GRAY$BORDER_RADIUS`px$RESET"
Write-Host "  • Bi-directional:  $LIGHT_GRAY$INPUT_BIDI$RESET"
Write-Host "  • Anti-aliasing:   $LIGHT_GRAY$INPUT_SMOOTH$RESET"
Write-Host "  • Custom CSS Path: $LIGHT_GRAY$($CUSTOM_CSS_PATH ? $CUSTOM_CSS_PATH : 'None')$RESET"
Write-Host "$GRAY──────────────────────────────────────────────────────────$RESET"

$confirm = Read-Host "  Apply configurations and modify production assets? [Y/n] (default: Y)"
if ($confirm -eq "") { $confirm = "Y" }
if ($confirm -notmatch "^[Yy]$") {
    Write-Host "`n$YELLOW𐄂 Action aborted by user. No modifications applied.$RESET`n"
    Exit 0
}

# 5. Extract and Patch
Write-Host "`n$CYAN◆ Execution Phase:$RESET"
cd $RESOURCES_DIR

if (Test-Path "app.asar.disabled") {
    if (!(Test-Path "app.asar")) {
        Rename-Item "app.asar.disabled" "app.asar"
    }
}
if (Test-Path "app.asar.unpacked.disabled") {
    if (!(Test-Path "app.asar.unpacked")) {
        Rename-Item "app.asar.unpacked.disabled" "app.asar.unpacked"
    }
}

if (!(Test-Path "app.asar.bak")) {
    Copy-Item "app.asar" "app.asar.bak"
    if (Test-Path "app.asar.unpacked") {
        Copy-Item -Recurse "app.asar.unpacked" "app.asar.unpacked.bak"
    }
} else {
    Copy-Item "app.asar.bak" "app.asar" -Force
    if (Test-Path "app.asar.unpacked.bak") {
        if (Test-Path "app.asar.unpacked") { Remove-Item -Recurse -Force "app.asar.unpacked" }
        Copy-Item -Recurse "app.asar.unpacked.bak" "app.asar.unpacked"
    }
}

if (Test-Path "app") { Remove-Item -Recurse -Force "app" }

Write-Host "  $DIM`○ Extracting app.asar...$RESET"
# Run asar extract
npx -y asar extract app.asar app

$PACKAGE_JSON = "$RESOURCES_DIR\app\package.json"
$MAIN_FILE = "index.js"
if (Test-Path $PACKAGE_JSON) {
    $pkgJsonContent = Get-Content -Raw $PACKAGE_JSON | ConvertFrom-Json
    if ($pkgJsonContent.main) {
        $MAIN_FILE = $pkgJsonContent.main
    }
}
$TARGET_PATH = "$RESOURCES_DIR\app\$MAIN_FILE"

$BIDI_OPTS = ""
if ($INPUT_BIDI -match "^[Yy]$") {
    $BIDI_OPTS = "body, p, span, div, h1, h2, h3, h4, h5, h6, li, input, textarea, section, article, td, th, a, label { unicode-bidi: plaintext !important; text-align: start !important; }"
}

$SMOOTHING_OPTS = ""
if ($INPUT_SMOOTH -match "^[Yy]$") {
    $SMOOTHING_OPTS = "-webkit-font-smoothing: antialiased !important; -moz-osx-font-smoothing: grayscale !important; text-rendering: optimizeLegibility !important;"
}

$INJECT_CSS = @"
:root {
    --font-family: $UI_FONT !important;
    --default-font: $UI_FONT !important;
    --font-primary: $UI_FONT !important;
    --font-sans: $UI_FONT !important;
    --font-mono: $MONO_FONT !important;
    --code-font: $MONO_FONT !important;
    --border-radius: $($BORDER_RADIUS)px !important;
    --radius: $($BORDER_RADIUS)px !important;
    --rad: $($BORDER_RADIUS)px !important;
}

$BIDI_OPTS

* {
    font-family: $UI_FONT !important;
    font-size: $($FONT_SIZE)pt !important;
    line-height: 1.65 !important;
    letter-spacing: -0.01em !important;
    $SMOOTHING_OPTS
}

:host, :host *, body, html,
p, span, div, li, a, h1, h2, h3, h4, h5, h6,
.prose, .prose *, .markdown-body, .markdown-body *, .message, .message *, 
.content, .content *, [class*='markdown'], [class*='message'], [class*='response'],
[class*='text'], [class*='bubble'], [class*='chat'] {
    font-family: $UI_FONT !important;
}

pre, code, kbd, samp, xmp, plaintext, listing,
.mono, .code, [class*='mono'], [class*='code'], [class*='monospace'],
.mtk1, .mtk2, .mtk3, .mtk4, .mtk5, .mtk6, .mtk7, .mtk8,
.ace_editor, .monaco-editor, .cm-editor, .code-block, .token {
    font-family: $MONO_FONT !important;
}
pre *, code *, .mono *, .code *, [class*='mono'] *, [class*='code'] *, .ace_editor *, .monaco-editor *, .cm-editor * {
    font-family: $MONO_FONT !important;
}

button:not([class*='circle']):not([class*='avatar']), 
input:not([class*='circle']), 
textarea, select, 
.card, .modal, .dialog, .box, .panel,
[class*='rounded'], [class*='rad-'] {
    border-radius: $($BORDER_RADIUS)px !important;
}

::-webkit-scrollbar { width: 7px !important; height: 7px !important; }
::-webkit-scrollbar-track { background: transparent !important; }
::-webkit-scrollbar-thumb { background: rgba(120, 120, 120, 0.25) !important; border-radius: 10px !important; }
::-webkit-scrollbar-thumb:hover { background: rgba(120, 120, 120, 0.5) !important; }
"@

$CUSTOM_CSS_PATH_JS = ""
if ($CUSTOM_CSS_PATH -ne "") {
    $CUSTOM_CSS_PATH_JS = $CUSTOM_CSS_PATH.Replace('\', '\\')
}

$B64_BYTES = [System.Text.Encoding]::UTF8.GetBytes($INJECT_CSS)
$B64_CSS = [System.Convert]::ToBase64String($B64_BYTES)

$JS_PATCH = @"

// Antigravity Deep UI Patcher - Frame & Webview Level Interceptor
try {
    const { app: electronApp, webContents } = require('electron');
    const fs = require('fs');

    const coreCss = Buffer.from('$B64_CSS', 'base64').toString('utf-8');
    const customCssPath = '$CUSTOM_CSS_PATH_JS';
    let currentCustomCss = '';

    if (customCssPath && fs.existsSync(customCssPath)) {
        try {
            currentCustomCss = fs.readFileSync(customCssPath, 'utf8');
        } catch(e) {}
    }

    function getFullCss() {
        return coreCss + '\n/* --- Custom User CSS Styles --- */\n' + currentCustomCss;
    }

    function broadcastStyleUpdate() {
        const fullCss = getFullCss();
        for (const wc of webContents.getAllWebContents()) {
            try {
                wc.insertCSS(fullCss, { cssOrigin: 'user' }).catch(() => {});
                wc.executeJavaScript("if (typeof window !== 'undefined' && window.updateGravityStyles) window.updateGravityStyles(" + JSON.stringify(fullCss) + ");").catch(() => {});
            } catch(e) {}
        }
    }

    if (customCssPath && fs.existsSync(customCssPath)) {
        let watchTimeout;
        fs.watch(customCssPath, (eventType) => {
            if (eventType === 'change') {
                clearTimeout(watchTimeout);
                watchTimeout = setTimeout(() => {
                    try {
                        currentCustomCss = fs.readFileSync(customCssPath, 'utf8');
                        broadcastStyleUpdate();
                    } catch(e) {}
                }, 250);
            }
        });
    }

    const jsPayload = "(function() {\n" +
        "  const styleText = " + JSON.stringify(getFullCss()) + ";\n" +
        "  let sharedSheet = null;\n" +
        "  const injectedRoots = new Set();\n" +
        "  try {\n" +
        "    sharedSheet = new CSSStyleSheet();\n" +
        "    sharedSheet.replaceSync(styleText);\n" +
        "  } catch(e) {}\n" +
        "  function inject(root) {\n" +
        "    if (!root) return;\n" +
        "    const id = 'gravity-shadow';\n" +
        "    injectedRoots.add(root);\n" +
        "    if (sharedSheet && root.adoptedStyleSheets) {\n" +
        "      try {\n" +
        "        if (!root.adoptedStyleSheets.includes(sharedSheet)) {\n" +
        "          root.adoptedStyleSheets = [...root.adoptedStyleSheets, sharedSheet];\n" +
        "        }\n" +
        "      } catch(err) {\n" +
        "        fallbackInject(root, id);\n" +
        "      }\n" +
        "    } else {\n" +
        "      fallbackInject(root, id);\n" +
        "    }\n" +
        "  }\n" +
        "  function fallbackInject(root, id) {\n" +
        "    if (!root.querySelector || !root.querySelector('#' + id)) {\n" +
        "      const s = document.createElement('style');\n" +
        "      s.id = id;\n" +
        "      s.textContent = styleText;\n" +
        "      root.appendChild(s);\n" +
        "    }\n" +
        "  }\n" +
        "  window.updateGravityStyles = function(newCss) {\n" +
        "    if (sharedSheet) {\n" +
        "      try { sharedSheet.replaceSync(newCss); } catch(e) {}\n" +
        "    }\n" +
        "    for (const root of injectedRoots) {\n" +
        "      try {\n" +
        "        const s = root.querySelector('#gravity-shadow');\n" +
        "        if (s) s.textContent = newCss;\n" +
        "      } catch(e) { injectedRoots.delete(root); }\n" +
        "    }\n" +
        "  };\n" +
        "  if (document.head || document.documentElement) {\n" +
        "    inject(document);\n" +
        "  }\n" +
        "  function observeIframe(iframe) {\n" +
        "    try {\n" +
        "      const doc = iframe.contentDocument || iframe.contentWindow.document;\n" +
        "      if (doc && !doc.gravityHooked) {\n" +
        "        doc.gravityHooked = true;\n" +
        "        inject(doc);\n" +
        "        pierce(doc.documentElement);\n" +
        "        const obs = new MutationObserver((mutations) => {\n" +
        "          for (const mutation of mutations) {\n" +
        "            for (const added of mutation.addedNodes) {\n" +
        "              if (added.nodeType === 1) {\n" +
        "                pierce(added);\n" +
        "              }\n" +
        "            }\n" +
        "          }\n" +
        "        });\n" +
        "        obs.observe(doc.documentElement, { childList: true, subtree: true });\n" +
        "      }\n" +
        "    } catch(e) {}\n" +
        "  }\n" +
        "  function pierce(node) {\n" +
        "    if (!node) return;\n" +
        "    if (node.shadowRoot) {\n" +
        "      inject(node.shadowRoot);\n" +
        "      pierce(node.shadowRoot);\n" +
        "      const obs = new MutationObserver((mutations) => {\n" +
        "        for (const mutation of mutations) {\n" +
        "          for (const added of mutation.addedNodes) {\n" +
        "            if (added.nodeType === 1) pierce(added);\n" +
        "          }\n" +
        "        }\n" +
        "      });\n" +
        "      obs.observe(node.shadowRoot, { childList: true, subtree: true });\n" +
        "    }\n" +
        "    if (node.tagName === 'IFRAME') {\n" +
        "      observeIframe(node);\n" +
        "      node.addEventListener('load', () => observeIframe(node));\n" +
        "    }\n" +
        "    if (node.tagName === 'INPUT' || node.tagName === 'TEXTAREA') {\n" +
        "      if (node.getAttribute('dir') !== 'auto') {\n" +
        "        node.setAttribute('dir', 'auto');\n" +
        "      }\n" +
        "    }\n" +
        "    const children = node.children || node.childNodes;\n" +
        "    if (children) {\n" +
        "      for (let i = 0; i < children.length; i++) {\n" +
        "        if (children[i].nodeType === 1) {\n" +
        "          pierce(children[i]);\n" +
        "        }\n" +
        "      }\n" +
        "    }\n" +
        "  }\n" +
        "  pierce(document.documentElement);\n" +
        "  if (!window.gravityShadowHooked) {\n" +
        "    window.gravityShadowHooked = true;\n" +
        "    const originalAttachShadow = Element.prototype.attachShadow;\n" +
        "    Element.prototype.attachShadow = function(options) {\n" +
        "      const shadowRoot = originalAttachShadow.call(this, options);\n" +
        "      setTimeout(() => {\n" +
        "        try {\n" +
        "          inject(shadowRoot);\n" +
        "          pierce(shadowRoot);\n" +
        "        } catch(e) {}\n" +
        "      }, 0);\n" +
        "      return shadowRoot;\n" +
        "    };\n" +
        "  }\n" +
        "  const observer = new MutationObserver((mutations) => {\n" +
        "    for (const mutation of mutations) {\n" +
        "      for (const node of mutation.addedNodes) {\n" +
        "        if (node.nodeType === 1) {\n" +
        "          pierce(node);\n" +
        "        }\n" +
        "      }\n" +
        "    }\n" +
        "  });\n" +
        "  observer.observe(document.documentElement, { childList: true, subtree: true });\n" +
        "})();";

    electronApp.on('web-contents-created', (createEvent, contents) => {
        contents.on('dom-ready', () => {
            contents.insertCSS(getFullCss(), { cssOrigin: 'user' }).catch(() => {});
            contents.executeJavaScript(jsPayload).catch(() => {});
        });

        contents.on('did-frame-finish-load', (event, isMainFrame, frameProcessId, frameRoutingId) => {
            contents.insertCSS(getFullCss(), { cssOrigin: 'user' }).catch(() => {});
            if (typeof frameRoutingId !== 'undefined' && contents.executeJavaScriptInFrame) {
                contents.executeJavaScriptInFrame(frameRoutingId, jsPayload).catch(() => {});
            } else {
                contents.executeJavaScript(jsPayload).catch(() => {});
            }
        });
    });
} catch (e) {
    console.error('Patcher runtime initiation faulted:', e);
}
"@

Write-Host "  $DIM`○ Injecting styling payloads...$RESET"
Add-Content -Path $TARGET_PATH -Value $JS_PATCH -Encoding UTF8

Rename-Item "app.asar" "app.asar.disabled"
if (Test-Path "app.asar.unpacked") { Rename-Item "app.asar.unpacked" "app.asar.unpacked.disabled" }

Write-Host "  $GREEN✓ Core engine patched successfully.$RESET"

# Save Config
if (!(Test-Path $CONFIG_DIR)) { New-Item -ItemType Directory -Path $CONFIG_DIR | Out-Null }
$CONFIG_PAYLOAD = @"
UI_FONT=$INPUT_UI
MONO_FONT=$INPUT_MONO
FONT_SIZE=$FONT_SIZE
BORDER_RADIUS=$BORDER_RADIUS
INPUT_BIDI=$INPUT_BIDI
INPUT_SMOOTH=$INPUT_SMOOTH
CUSTOM_CSS_PATH=$CUSTOM_CSS_PATH
"@
Set-Content -Path $CONFIG_FILE -Value $CONFIG_PAYLOAD -Encoding UTF8

# 6. Relaunch
$RESTART_APP = $false
$ACTIVE_PROCESS = Get-Process -Name "antigravity" -ErrorAction SilentlyContinue
if ($ACTIVE_PROCESS) {
    Write-Host "`n$CYAN◆ Process Detection:$RESET Antigravity is currently active."
    $chk_kill = Read-Host "  Do you want to restart it now to apply the patch? [Y/n] (default: Y)"
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
