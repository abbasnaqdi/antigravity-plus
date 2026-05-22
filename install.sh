#!/bin/bash
set -e

# ANSI typography definitions
RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[2m"
CYAN="\e[38;5;109m"
GRAY="\e[38;5;244m"
LIGHT_GRAY="\e[38;5;250m"
GREEN="\e[38;5;108m"
YELLOW="\e[38;5;178m"

clear
echo -e "${GRAY}──────────────────────────────────────────────────────────${RESET}"
echo -e " ${BOLD}${LIGHT_GRAY}Antigravity Plus${RESET}"
echo -e " ${DIM}Deep Shadow-DOM CSS Injector & Typographic Engine${RESET}"
echo -e "${GRAY}──────────────────────────────────────────────────────────${RESET}"

# OS compatibility & dependencies pre-flight checks
check_compatibility() {
    local os_ok=false
    if command -v apt-get &>/dev/null; then
        os_ok=true
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        if [[ "$ID" =~ debian|ubuntu || "$ID_LIKE" =~ debian|ubuntu ]]; then
            os_ok=true
        fi
    fi

    local deps_ok=true
    if ! command -v node &>/dev/null || ! command -v npm &>/dev/null || ! command -v asar &>/dev/null; then
        deps_ok=false
    fi

    if [ "$os_ok" = false ]; then
        if [ "$deps_ok" = true ]; then
            echo -e "  ${YELLOW}⚠ Warning: Your operating system is not Debian/Ubuntu-based.${RESET}"
            echo -e "             Proceeding since all dependencies (Node.js, npm, asar) are already installed.\n"
        else
            local os_name="Unknown Linux"
            if [ -f /etc/os-release ]; then
                . /etc/os-release
                os_name="${NAME:-$ID}"
            fi
            echo -e "\n${YELLOW}𐄂 Error: Unsupported OS & Missing Dependencies${RESET}"
            echo -e "  Your operating system ($os_name) is not Debian/Ubuntu-based and does not support apt."
            echo -e "  To run this patcher on your system, please manually install the following packages:"
            echo -e "    - Node.js"
            echo -e "    - npm"
            echo -e "    - asar (npm install -g asar)"
            echo -e "  After installing them, run this script again.\n"
            exit 1
        fi
    fi
}
check_compatibility

# 1. Smart Directory Discovery Engine
echo -e "\n${CYAN}◆ Locating Deployment Directory:${RESET}"
echo -e "  ${DIM}Scanning for Antigravity installation under /opt...${RESET}"
PATHS=($(find /opt -maxdepth 2 -type d -iname "*antigravity*" 2>/dev/null || true))

PROPOSED_DIR=""
if [ ${#PATHS[@]} -eq 1 ]; then
    PROPOSED_DIR="${PATHS[0]}"
    echo -e "  ${GREEN}✓ Found installation directory:${RESET} $PROPOSED_DIR"
    echo -ne "  Use this directory? [Y/n] (default: Y): "
    read -r CONFIRM_PATH
    CONFIRM_PATH=${CONFIRM_PATH:-Y}
    if [[ "$CONFIRM_PATH" =~ ^[Yy]$ ]]; then
        BASE_DIR="$PROPOSED_DIR"
    else
        PROPOSED_DIR=""
    fi
elif [ ${#PATHS[@]} -gt 1 ]; then
    echo -e "  ${YELLOW}⚠ Multiple installation directories discovered:${RESET}"
    for i in "${!PATHS[@]}"; do
        echo -e "    [$((i+1))] ${PATHS[$i]}"
    done
    echo -e "    [c] Enter custom path"
    echo -ne "  Select an option [1-${#PATHS[@]} or c] (default: 1): "
    read -r PATH_INDEX
    PATH_INDEX=${PATH_INDEX:-1}
    if [[ "$PATH_INDEX" =~ ^[0-9]+$ ]] && [ "$PATH_INDEX" -le "${#PATHS[@]}" ] && [ "$PATH_INDEX" -gt 0 ]; then
        PROPOSED_DIR="${PATHS[$((PATH_INDEX-1))]}"
        BASE_DIR="$PROPOSED_DIR"
    else
        PROPOSED_DIR=""
    fi
fi

if [ -z "$PROPOSED_DIR" ]; then
    echo -ne "  Please enter the full installation path: "
    read -r BASE_DIR
fi

# Verify path and locate resources
RESOLVED=false
while [ "$RESOLVED" = false ]; do
    BASE_DIR="${BASE_DIR%/}" # Remove trailing slash if any
    
    if [ -n "$BASE_DIR" ] && [ -d "$BASE_DIR" ] && ( [ -f "$BASE_DIR/antigravity" ] || [ -f "$BASE_DIR/Antigravity" ] ); then
        RESOURCES_DIR="$BASE_DIR/resources"
        if [ -d "$RESOURCES_DIR" ] && ( [ -f "$RESOURCES_DIR/app.asar" ] || [ -d "$RESOURCES_DIR/app" ] ); then
            RESOLVED=true
        else
            ASAR_PATH=$(find "$BASE_DIR" -name "app.asar" 2>/dev/null | head -n 1)
            if [ -n "$ASAR_PATH" ]; then
                RESOURCES_DIR=$(dirname "$ASAR_PATH")
                RESOLVED=true
            fi
        fi
    fi

    if [ "$RESOLVED" = false ]; then
        echo -e "  ${YELLOW}⚠ Invalid Antigravity installation: Could not verify executable or resources under '$BASE_DIR'${RESET}"
        echo -ne "  Please enter a valid installation path: "
        read -r BASE_DIR
    fi
done

echo -e "  ${GREEN}✓ Resolved resources directory:${RESET} $RESOURCES_DIR"

if [ ! -w "$RESOURCES_DIR" ] && [ "$EUID" -ne 0 ]; then
    echo -e "\n${YELLOW}𐄂 Execution denied: Target directory is not writeable. Please run using sudo.${RESET}\n"
    exit 1
fi

cd "$RESOURCES_DIR"



# 3. Extract dynamic configurations
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
REAL_UID=$(id -u "$REAL_USER")
USER_HOME=$(eval echo "~$REAL_USER")
DBUS_PATH="unix:path=/run/user/$REAL_UID/bus"

# Helper: Detect system font family and size from DE settings
detect_system_font() {
    local font=""
    local desktop="${XDG_CURRENT_DESKTOP^^}"
    local cmd=""
    
    if [[ "$desktop" =~ GNOME|CINNAMON|MATE|UNITY ]]; then
        local schema="org.gnome.desktop.interface"
        if [[ "$desktop" == *"MATE"* ]]; then schema="org.mate.interface"; fi
        if [[ "$desktop" == *"CINNAMON"* ]]; then schema="org.cinnamon.desktop.interface"; fi
        cmd="gsettings get $schema font-name 2>/dev/null | tr -d \"'\""
    elif [[ "$desktop" =~ KDE ]]; then
        cmd="kreadconfig5 --group \"General\" --key \"font\" 2>/dev/null | cut -d',' -f1"
    elif [[ "$desktop" =~ XFCE ]]; then
        cmd="xfconf-query -c xsettings -p /Gtk/FontName 2>/dev/null | sed -E 's/ [0-9]+$//'"
    fi

    if [ -n "$cmd" ]; then
        if [ "$EUID" -eq 0 ] && [ -n "$REAL_USER" ]; then
            font=$(sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_PATH" bash -c "$cmd" 2>/dev/null)
        else
            font=$(eval "$cmd" 2>/dev/null)
        fi
    fi
    
    # Fallback to standard gsettings check
    if [ -z "$font" ]; then
        if [ "$EUID" -eq 0 ] && [ -n "$REAL_USER" ]; then
            font=$(sudo -u "$REAL_USER" DBUS_SESSION_BUS_ADDRESS="$DBUS_PATH" gsettings get org.gnome.desktop.interface font-name 2>/dev/null | tr -d "'") || true
        else
            font=$(gsettings get org.gnome.desktop.interface font-name 2>/dev/null | tr -d "'") || true
        fi
    fi
    
    echo "$font"
}

# Helper: Check if a font family is installed
check_font_installed() {
    local font_name="$1"
    if [ "$EUID" -eq 0 ] && [ -n "$REAL_USER" ]; then
        if sudo -u "$REAL_USER" fc-list : family 2>/dev/null | cut -d: -f2 | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sort -u | grep -ixq "^$font_name$"; then
            return 0
        fi
    else
        if fc-list : family 2>/dev/null | cut -d: -f2 | tr ',' '\n' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sort -u | grep -ixq "^$font_name$"; then
            return 0
        fi
    fi
    return 1
}

# Helper: Map generic font family name to Debian/Ubuntu package name
map_font_to_apt() {
    local font_name="${1,,}"
    case "$font_name" in
        "vazirmatn"|"vazir") echo "fonts-vazirmatn" ;;
        "jetbrains mono"|"jetbrains") echo "fonts-jetbrains-mono" ;;
        "inter") echo "fonts-inter" ;;
        "fira code"|"firacode") echo "fonts-firacode" ;;
        "hack") echo "fonts-hack" ;;
        "ubuntu") echo "fonts-ubuntu" ;;
        "ubuntu mono") echo "fonts-ubuntu-mono" ;;
        "noto sans"|"notosans") echo "fonts-noto-core" ;;
        "dejavu sans mono"|"dejavu") echo "fonts-dejavu-core" ;;
        *)
            local clean_name=$(echo "$font_name" | tr -d ' ' | tr -d '-')
            local search_res=""
            if [ -n "$clean_name" ]; then
                search_res=$(apt-cache search "^fonts-$clean_name" 2>/dev/null | awk '{print $1}' | head -n1 || true)
            fi
            if [ -n "$search_res" ]; then
                echo "$search_res"
            else
                local fuzzy_res=$(apt-cache search "fonts-" 2>/dev/null | grep -i "font-$clean_name" | awk '{print $1}' | head -n1 || true)
                if [ -n "$fuzzy_res" ]; then
                    echo "$fuzzy_res"
                else
                    echo ""
                fi
            fi
            ;;
    esac
}

# Helper: Ask user to install font package via apt
install_font_via_apt() {
    local pkg="$1"
    echo -e "    ${YELLOW}⚠ Font package '$pkg' is available but not installed.${RESET}"
    echo -ne "    Would you like to install '$pkg' using apt? [Y/n] (default: Y): "
    read -r opt
    opt=${opt:-Y}
    if [[ "$opt" =~ ^[Yy]$ ]]; then
        if [ "$EUID" -eq 0 ]; then
            apt-get update && apt-get install -y "$pkg"
        else
            echo -e "    ${DIM}Requesting privileges to run: sudo apt-get install -y $pkg${RESET}"
            sudo apt-get update && sudo apt-get install -y "$pkg"
        fi
    fi
}

# Helper: Verify list of fonts
verify_and_install_fonts() {
    local font_input="$1"
    local cleaned_input=$(echo "$font_input" | tr -d '"'"'")
    IFS=',' read -ra ADDR <<< "$cleaned_input"
    for i in "${ADDR[@]}"; do
        local font_name=$(echo "$i" | xargs)
        if [ -n "$font_name" ] && [[ "$font_name" != "sans-serif" && "$font_name" != "monospace" && "$font_name" != "serif" ]]; then
            echo -ne "  • Checking font '$font_name'..."
            if check_font_installed "$font_name"; then
                echo -e " ${GREEN}installed${RESET}"
            else
                echo -e " ${YELLOW}not found${RESET}"
                local apt_pkg=$(map_font_to_apt "$font_name")
                if [ -n "$apt_pkg" ]; then
                    install_font_via_apt "$apt_pkg"
                else
                    echo -e "    ${DIM}No matching apt package found for '$font_name'.${RESET}"
                fi
            fi
        fi
    done
}

CONFIG_DIR="$USER_HOME/.config/antigravity-plus"
CONFIG_FILE="$CONFIG_DIR/patcher.conf"

# Read saved configuration if it exists
if [ -f "$CONFIG_FILE" ]; then
    UI_FONT_SAVED=$(grep -E "^UI_FONT=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '"'"'")
    MONO_FONT_SAVED=$(grep -E "^MONO_FONT=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '"'"'")
    FONT_SIZE_SAVED=$(grep -E "^FONT_SIZE=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '"'"'")
    BORDER_RADIUS_SAVED=$(grep -E "^BORDER_RADIUS=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '"'"'")
    INPUT_BIDI_SAVED=$(grep -E "^INPUT_BIDI=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '"'"'")
    INPUT_SMOOTH_SAVED=$(grep -E "^INPUT_SMOOTH=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '"'"'")
    CUSTOM_CSS_PATH_SAVED=$(grep -E "^CUSTOM_CSS_PATH=" "$CONFIG_FILE" | cut -d'=' -f2- | tr -d '"'"'")
fi

# Detect system defaults
SYS_FONT=$(detect_system_font)
SYS_FONT_FAMILY=$(echo "$SYS_FONT" | sed -E 's/ [0-9]+$//' || true)
SYS_FONT_SIZE=$(echo "$SYS_FONT" | grep -oE '[0-9]+' | tail -n1 || true)
SYS_FONT_SIZE=${SYS_FONT_SIZE:-11}

if [ -n "$SYS_FONT_FAMILY" ]; then
    if [[ "$SYS_FONT_FAMILY" == *"Vazir"* ]]; then
        DEFAULT_UI_FALLBACK="$SYS_FONT_FAMILY, Ubuntu, Cantarell, Noto Sans"
    else
        DEFAULT_UI_FALLBACK="$SYS_FONT_FAMILY, Vazirmatn, Ubuntu, Cantarell, Noto Sans"
    fi
else
    DEFAULT_UI_FALLBACK="Inter, Vazirmatn, Ubuntu, Cantarell, Noto Sans"
fi

DEFAULT_UI="${UI_FONT_SAVED:-$DEFAULT_UI_FALLBACK}"
DEFAULT_MONO="${MONO_FONT_SAVED:-"JetBrains Mono, Fira Code, Source Code Pro, Hack, DejaVu Sans Mono"}"
DEFAULT_SIZE="${FONT_SIZE_SAVED:-${SYS_FONT_SIZE}}"
DEFAULT_RADIUS="${BORDER_RADIUS_SAVED:-5}"
DEFAULT_BIDI="${INPUT_BIDI_SAVED:-Y}"
DEFAULT_SMOOTH="${INPUT_SMOOTH_SAVED:-Y}"
DEFAULT_CUSTOM_CSS="${CUSTOM_CSS_PATH_SAVED:-""}"

echo -e "\n${CYAN}◆ Dynamic Parameter Selection:${RESET}"
echo -e "  ${DIM}Note: Type raw names separated by commas. Hit Enter to accept defaults.${RESET}"

echo -ne "  Enter UI Font Stack (default: $DEFAULT_UI): "
read -r INPUT_UI
INPUT_UI=${INPUT_UI:-$DEFAULT_UI}

echo -ne "  Enter Monospace Code Font (default: $DEFAULT_MONO): "
read -r INPUT_MONO
INPUT_MONO=${INPUT_MONO:-$DEFAULT_MONO}

echo -ne "  Enter Base Font Size in pt (default: $DEFAULT_SIZE): "
read -r INPUT_SIZE
FONT_SIZE=${INPUT_SIZE:-$DEFAULT_SIZE}

echo -ne "  Enter Maximum Border Radius in px (0-5) (default: $DEFAULT_RADIUS): "
read -r INPUT_RADIUS
BORDER_RADIUS=${INPUT_RADIUS:-$DEFAULT_RADIUS}

echo -ne "  Enable Smart Bi-directional Layout (RTL/LTR auto)? [Y/n] (default: $DEFAULT_BIDI): "
read -r INPUT_BIDI
INPUT_BIDI=${INPUT_BIDI:-$DEFAULT_BIDI}

echo -ne "  Enable Sub-pixel Text Anti-aliasing Optimization? [Y/n] (default: $DEFAULT_SMOOTH): "
read -r INPUT_SMOOTH
INPUT_SMOOTH=${INPUT_SMOOTH:-$DEFAULT_SMOOTH}

echo -ne "  Enter path to custom CSS file (optional, default: ${DEFAULT_CUSTOM_CSS:-None}): "
read -r CUSTOM_CSS_PATH
CUSTOM_CSS_PATH=${CUSTOM_CSS_PATH:-$DEFAULT_CUSTOM_CSS}

if [ "$CUSTOM_CSS_PATH" = "None" ]; then
    CUSTOM_CSS_PATH=""
fi

# Validate and install fonts if missing
echo -e "\n${CYAN}◆ Validating and Installing Fonts:${RESET}"
verify_and_install_fonts "$INPUT_UI"
verify_and_install_fonts "$INPUT_MONO"

CUSTOM_CSS_CONTENT=""
if [ -n "$CUSTOM_CSS_PATH" ]; then
    CUSTOM_CSS_PATH="${CUSTOM_CSS_PATH/#\~/$USER_HOME}"
    if [ -f "$CUSTOM_CSS_PATH" ]; then
        CUSTOM_CSS_CONTENT=$(cat "$CUSTOM_CSS_PATH")
        echo -e "  ${GREEN}✓ Loaded Custom CSS from:${RESET} $CUSTOM_CSS_PATH (${#CUSTOM_CSS_CONTENT} characters)"
    else
        echo -e "  ${YELLOW}⚠ Custom CSS file not found at:${RESET} $CUSTOM_CSS_PATH"
        CUSTOM_CSS_PATH=""
    fi
fi

# Clean up and normalize font stacks for the injector CSS
INPUT_UI_CLEANED=$(echo "$INPUT_UI" | tr -d '"'"'")
IFS=',' read -ra ADDR <<< "$INPUT_UI_CLEANED"
UI_FONT=""
for i in "${ADDR[@]}"; do
    i=$(echo "$i" | xargs)
    if [ -n "$i" ]; then
        if [ -z "$UI_FONT" ]; then UI_FONT="'$i'"; else UI_FONT="$UI_FONT, '$i'"; fi
    fi
done
UI_FONT="$UI_FONT, sans-serif"

INPUT_MONO_CLEANED=$(echo "$INPUT_MONO" | tr -d '"'"'")
IFS=',' read -ra ADDR <<< "$INPUT_MONO_CLEANED"
MONO_FONT=""
for i in "${ADDR[@]}"; do
    i=$(echo "$i" | xargs)
    if [ -n "$i" ]; then
        if [ -z "$MONO_FONT" ]; then MONO_FONT="'$i'"; else MONO_FONT="$MONO_FONT, '$i'"; fi
    fi
done
MONO_FONT="$MONO_FONT, 'Fira Code', 'DejaVu Sans Mono', 'Ubuntu Mono', 'Courier New', 'Vazirmatn', monospace"

# 4. Verification & Deployment Confirmation Screen
echo -e "\n${CYAN}◆ Configuration Summary:${RESET}"
echo -e "  • Target Path:     ${LIGHT_GRAY}${BASE_DIR}${RESET}"
echo -e "  • UI Font Stack:   ${LIGHT_GRAY}${UI_FONT}${RESET}"
echo -e "  • Monospace Font:  ${LIGHT_GRAY}${MONO_FONT}${RESET}"
echo -e "  • Base Font Size:  ${LIGHT_GRAY}${FONT_SIZE}pt${RESET}"
echo -e "  • Max Corner Rad:  ${LIGHT_GRAY}${BORDER_RADIUS}px${RESET}"
echo -e "  • Bi-directional:  ${LIGHT_GRAY}${INPUT_BIDI}${RESET}"
echo -e "  • Anti-aliasing:   ${LIGHT_GRAY}${INPUT_SMOOTH}${RESET}"
echo -e "  • Custom CSS Path: ${LIGHT_GRAY}${CUSTOM_CSS_PATH:-None}${RESET}"
echo -e "${GRAY}──────────────────────────────────────────────────────────${RESET}"
echo -ne "  Apply configurations and modify production assets? [Y/n] (default: Y): "
read -r CONFIRM
CONFIRM=${CONFIRM:-Y}

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}𐄂 Action aborted by user. No modifications applied.${RESET}\n"
    exit 0
fi

# 5. Process application assets
echo -e "\n${CYAN}◆ Execution Phase:${RESET}"

if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    if [ "$EUID" -ne 0 ]; then
        echo -e "\n${YELLOW}𐄂 Error: Node.js and npm are missing. Please run the script as root (sudo) once to install them.${RESET}\n"
        exit 1
    fi
    echo -e "  ${DIM}○ Installing missing Node.js dependencies...${RESET}"
    apt-get update && apt-get install -y nodejs npm
fi

if ! command -v asar &> /dev/null; then
    if [ "$EUID" -ne 0 ]; then
        echo -e "\n${YELLOW}𐄂 Error: 'asar' utility is missing. Please run the script as root (sudo) once to install it.${RESET}\n"
        exit 1
    fi
    echo -e "  ${DIM}○ Deploying Asar utility...${RESET}"
    npm install -g asar
fi

echo -e "  ${DIM}○ Synchronizing backups & extracting resources...${RESET}"
if [ -f "app.asar.disabled" ] && [ ! -f "app.asar" ]; then mv "app.asar.disabled" "app.asar"; fi
if [ -d "app.asar.unpacked.disabled" ] && [ ! -d "app.asar.unpacked" ]; then mv "app.asar.unpacked.disabled" "app.asar.unpacked"; fi

if [ ! -f "app.asar.bak" ]; then
    cp "app.asar" "app.asar.bak"
    if [ -d "app.asar.unpacked" ]; then cp -r "app.asar.unpacked" "app.asar.unpacked.bak"; fi
else
    cp "app.asar.bak" "app.asar"
    if [ -d "app.asar.unpacked.bak" ]; then rm -rf "app.asar.unpacked"; cp -r "app.asar.unpacked.bak" "app.asar.unpacked"; fi
fi

rm -rf app
asar extract "app.asar" app

MAIN_FILE=$(node -e "try { console.log(require('./app/package.json').main || 'index.js'); } catch(e) { console.log('index.js'); }")
TARGET_PATH="app/$MAIN_FILE"

BIDI_OPTS=""
if [[ "$INPUT_BIDI" =~ ^[Yy]$ ]]; then
    BIDI_OPTS="body, p, span, div, h1, h2, h3, h4, h5, h6, li, input, textarea, section, article, td, th, a, label { unicode-bidi: plaintext !important; text-align: start !important; }"
fi

SMOOTHING_OPTS=""
if [[ "$INPUT_SMOOTH" =~ ^[Yy]$ ]]; then
    SMOOTHING_OPTS="-webkit-font-smoothing: antialiased !important; -moz-osx-font-smoothing: grayscale !important; text-rendering: optimizeLegibility !important;"
fi

INJECT_CSS="
:root {
    --font-family: ${UI_FONT} !important;
    --default-font: ${UI_FONT} !important;
    --font-primary: ${UI_FONT} !important;
    --font-sans: ${UI_FONT} !important;
    --font-mono: ${MONO_FONT} !important;
    --code-font: ${MONO_FONT} !important;
    --border-radius: ${BORDER_RADIUS}px !important;
    --radius: ${BORDER_RADIUS}px !important;
    --rad: ${BORDER_RADIUS}px !important;
}

${BIDI_OPTS}

* {
    font-family: ${UI_FONT} !important;
    font-size: ${FONT_SIZE}pt !important;
    line-height: 1.65 !important;
    letter-spacing: -0.01em !important;
    ${SMOOTHING_OPTS}
}

/* Explicit targeting for Markdown & AI Response wrappers */
.prose, .prose *, .markdown-body, .markdown-body *, .message, .message *, 
.content, .content *, [class*='markdown'], [class*='message'], [class*='response'] {
    font-family: ${UI_FONT} !important;
}

/* Monospace overrides */
pre, code, kbd, samp, xmp, plaintext, listing,
.mono, .code, [class*='mono'], [class*='code'], [class*='monospace'],
.mtk1, .mtk2, .mtk3, .mtk4, .mtk5, .mtk6, .mtk7, .mtk8,
.ace_editor, .monaco-editor, .cm-editor, .code-block, .token {
    font-family: ${MONO_FONT} !important;
}
pre *, code *, .mono *, .code *, [class*='mono'] *, [class*='code'] *, .ace_editor *, .monaco-editor *, .cm-editor * {
    font-family: ${MONO_FONT} !important;
}

/* Intelligent Border Radius Limiter (Ignores perfect circles like avatars) */
button:not([class*='circle']):not([class*='avatar']), 
input:not([class*='circle']), 
textarea, select, 
.card, .modal, .dialog, .box, .panel,
[class*='rounded'], [class*='rad-'] {
    border-radius: ${BORDER_RADIUS}px !important;
}

/* Scrollbars */
::-webkit-scrollbar { width: 7px !important; height: 7px !important; }
::-webkit-scrollbar-track { background: transparent !important; }
::-webkit-scrollbar-thumb { background: rgba(120, 120, 120, 0.25) !important; border-radius: 10px !important; }
::-webkit-scrollbar-thumb:hover { background: rgba(120, 120, 120, 0.5) !important; }
"

if [ -n "$CUSTOM_CSS_CONTENT" ]; then
    INJECT_CSS="
$INJECT_CSS

/* --- Custom User CSS Styles --- */
$CUSTOM_CSS_CONTENT
"
fi

echo -e "  ${DIM}○ Compiling Omnipresent CSS payloads...${RESET}"
cat << EOF >> "$TARGET_PATH"

// Antigravity Deep UI Patcher - Frame & Webview Level Interceptor
try {
    const { app: electronApp } = require('electron');
    const cssString = \`${INJECT_CSS}\`;
    
    const jsPayload = "(function() {\n" +
        "  const styleText = " + JSON.stringify(cssString) + ";\n" +
        "  function inject(root) {\n" +
        "    if (!root) return;\n" +
        "    const id = 'gravity-shadow';\n" +
        "    if (!root.querySelector || !root.querySelector('#' + id)) {\n" +
        "      const s = document.createElement('style');\n" +
        "      s.id = id;\n" +
        "      s.textContent = styleText;\n" +
        "      root.appendChild(s);\n" +
        "    }\n" +
        "  }\n" +
        "  if (document.head || document.documentElement) {\n" +
        "    const id = 'gravity-main-style';\n" +
        "    if (!document.getElementById(id)) {\n" +
        "      const s = document.createElement('style');\n" +
        "      s.id = id;\n" +
        "      s.textContent = styleText;\n" +
        "      (document.head || document.documentElement).appendChild(s);\n" +
        "    }\n" +
        "  }\n" +
        "  function observeIframe(iframe) {\n" +
        "    try {\n" +
        "      const doc = iframe.contentDocument || iframe.contentWindow.document;\n" +
        "      if (doc && !doc.gravityHooked) {\n" +
        "        doc.gravityHooked = true;\n" +
        "        inject(doc.head || doc.documentElement);\n" +
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
            contents.insertCSS(cssString, { cssOrigin: 'user' }).catch(() => {});
            contents.executeJavaScript(jsPayload).catch(() => {});
        });

        contents.on('did-frame-finish-load', (event, isMainFrame, frameProcessId, frameRoutingId) => {
            contents.insertCSS(cssString, { cssOrigin: 'user' }).catch(() => {});
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
EOF

mv "app.asar" "app.asar.disabled"
if [ -d "app.asar.unpacked" ]; then mv "app.asar.unpacked" "app.asar.unpacked.disabled"; fi

echo -e "  ${GREEN}✓ Core engine patched successfully.${RESET}"

# Save configuration for future runs
if [ ! -d "$CONFIG_DIR" ]; then
    if [ "$EUID" -eq 0 ]; then
        sudo -u "$REAL_USER" mkdir -p "$CONFIG_DIR"
    else
        mkdir -p "$CONFIG_DIR"
    fi
fi

cat << EOF > "$CONFIG_FILE"
UI_FONT="$INPUT_UI"
MONO_FONT="$INPUT_MONO"
FONT_SIZE="$FONT_SIZE"
BORDER_RADIUS="$BORDER_RADIUS"
INPUT_BIDI="$INPUT_BIDI"
INPUT_SMOOTH="$INPUT_SMOOTH"
CUSTOM_CSS_PATH="$CUSTOM_CSS_PATH"
EOF

if [ "$EUID" -eq 0 ]; then
    chown "$REAL_USER:$REAL_USER" "$CONFIG_FILE"
fi

# 6. Final cycle state wrap-up
RESTART_APP=false
if pkill -0 -f antigravity 2>/dev/null; then
    echo -e "\n${CYAN}◆ Process Detection:${RESET} Antigravity is currently active."
    echo -ne "  Do you want to restart it now to apply the patch? [Y/n] (default: Y): "
    read -r chk_kill
    chk_kill=${chk_kill:-Y}
    if [[ "$chk_kill" =~ ^[Yy]$ ]]; then
        RESTART_APP=true
        pkill -f antigravity || true
        sleep 1
    fi
fi

echo -e "\n${GRAY}──────────────────────────────────────────────────────────${RESET}"
if [ "$RESTART_APP" = true ]; then
    echo -e " ${GREEN}✔ Complete:${RESET} Relaunching Antigravity..."
    echo -e "${GRAY}──────────────────────────────────────────────────────────${RESET}\n"
    
    # Robust launch mechanism mapping user session bus securely
    if [ "$EUID" -eq 0 ]; then
        [ -z "$DISPLAY" ] && DISPLAY=$(find /proc -maxdepth 2 -user "$REAL_USER" -name environ -exec grep -z '^DISPLAY=' {} + 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\0')
        [ -z "$WAYLAND_DISPLAY" ] && WAYLAND_DISPLAY=$(find /proc -maxdepth 2 -user "$REAL_USER" -name environ -exec grep -z '^WAYLAND_DISPLAY=' {} + 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\0')
        
        sudo -u "$REAL_USER" -i env DISPLAY="$DISPLAY" WAYLAND_DISPLAY="$WAYLAND_DISPLAY" nohup "$BASE_DIR/antigravity" >/dev/null 2>&1 &
    else
        nohup "$BASE_DIR/antigravity" >/dev/null 2>&1 &
    fi
else
    echo -e " ${GREEN}✔ Complete:${RESET} Pipeline finished. Launch Antigravity manually to verify."
    echo -e "${GRAY}──────────────────────────────────────────────────────────${RESET}\n"
fi
