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
echo -e " ${BOLD}${LIGHT_GRAY}Antigravity Plus Rollback Utility${RESET}"
echo -e " ${DIM}Restores Antigravity application to its default state${RESET}"
echo -e "${GRAY}──────────────────────────────────────────────────────────${RESET}"

# 1. Smart Directory Discovery Engine
echo -e "\n${CYAN}◆ Locating Deployment Directory:${RESET}"
OS_TYPE=$(uname -s)
PATHS=()

if [ "$OS_TYPE" = "Darwin" ]; then
    echo -e "  ${DIM}Scanning for Antigravity installation under /Applications...${RESET}"
    if [ -d "/Applications/Antigravity.app" ]; then
        PATHS+=("/Applications/Antigravity.app")
    fi
    REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
    USER_HOME=$(eval echo "~$REAL_USER")
    if [ -d "$USER_HOME/Applications/Antigravity.app" ]; then
        PATHS+=("$USER_HOME/Applications/Antigravity.app")
    fi
    if [ ${#PATHS[@]} -eq 0 ]; then
        FIND_PATHS=($(find /Applications "$USER_HOME/Applications" -maxdepth 2 -type d -iname "*antigravity*.app" 2>/dev/null || true))
        for p in "${FIND_PATHS[@]}"; do
            PATHS+=("$p")
        done
    fi
else
    echo -e "  ${DIM}Scanning for Antigravity installation under /opt...${RESET}"
    PATHS=($(find /opt -maxdepth 2 -type d -iname "*antigravity*" 2>/dev/null || true))
fi

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
    
    path_ok=false
    if [ "$OS_TYPE" = "Darwin" ]; then
        if [ -d "$BASE_DIR" ] && [ -d "$BASE_DIR/Contents/Resources" ]; then
            RESOURCES_DIR="$BASE_DIR/Contents/Resources"
            path_ok=true
        fi
    else
        if [ -n "$BASE_DIR" ] && [ -d "$BASE_DIR" ] && ( [ -f "$BASE_DIR/antigravity" ] || [ -f "$BASE_DIR/Antigravity" ] ); then
            RESOURCES_DIR="$BASE_DIR/resources"
            if [ -d "$RESOURCES_DIR" ] && ( [ -f "$RESOURCES_DIR/app.asar.bak" ] || [ -f "$RESOURCES_DIR/app.asar" ] ); then
                path_ok=true
            fi
        fi
    fi

    if [ "$path_ok" = true ]; then
        RESOLVED=true
    else
        if [ -d "$BASE_DIR" ]; then
            ASAR_PATH=$(find "$BASE_DIR" -name "app.asar" -o -name "app.asar.bak" 2>/dev/null | head -n 1)
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

# 2. Check for backups
if [ ! -f "app.asar.bak" ]; then
    echo -e "\n${YELLOW}𐄂 Error: No backup file (app.asar.bak) found in '$RESOURCES_DIR'.${RESET}"
    echo -e "  The application is already in its default state or cannot be restored automatically.\n"
    exit 1
fi

echo -e "\n${CYAN}◆ Confirmation:${RESET}"
echo -e "  This will restore the original app.asar and remove all UI patches."
echo -ne "  Proceed with rollback? [Y/n] (default: Y): "
read -r CONFIRM
CONFIRM=${CONFIRM:-Y}

if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}𐄂 Rollback aborted by user.${RESET}\n"
    exit 0
fi

# 3. Restore backups
echo -e "\n${CYAN}◆ Restoring assets:${RESET}"

# Remove patched app directory and disabled asar
if [ -d "app" ]; then
    echo -e "  ${DIM}○ Removing patched app folder...${RESET}"
    rm -rf "app"
fi

if [ -f "app.asar.disabled" ]; then
    rm -f "app.asar.disabled"
fi

# Restore app.asar
echo -e "  ${DIM}○ Restoring original app.asar...${RESET}"
cp "app.asar.bak" "app.asar"
rm -f "app.asar.bak"

# Restore unpacked assets if any
if [ -d "app.asar.unpacked.disabled" ]; then
    echo -e "  ${DIM}○ Restoring unpacked dependencies...${RESET}"
    rm -rf "app.asar.unpacked"
    mv "app.asar.unpacked.disabled" "app.asar.unpacked"
fi
if [ -d "app.asar.unpacked.bak" ]; then
    rm -rf "app.asar.unpacked.bak"
fi

echo -e "  ${GREEN}✓ Restoration complete.${RESET}"

# 4. Process Detection & Relaunch
REAL_USER="${SUDO_USER:-$(logname 2>/dev/null || whoami)}"
REAL_UID=$(id -u "$REAL_USER")
USER_HOME=$(eval echo "~$REAL_USER")
DBUS_PATH="unix:path=/run/user/$REAL_UID/bus"

RESTART_APP=false
if [ "$OS_TYPE" = "Darwin" ]; then
    if pgrep -x "Antigravity" &>/dev/null || pgrep -f "Antigravity.app" &>/dev/null; then
        echo -e "\n${CYAN}◆ Process Detection:${RESET} Antigravity is currently active."
        echo -ne "  Do you want to restart it now to verify the restoration? [Y/n] (default: Y): "
        read -r chk_kill
        chk_kill=${chk_kill:-Y}
        if [[ "$chk_kill" =~ ^[Yy]$ ]]; then
            RESTART_APP=true
            pkill -f "Antigravity" || killall "Antigravity" 2>/dev/null || true
            sleep 1
        fi
    fi
else
    if pkill -0 -f antigravity 2>/dev/null; then
        echo -e "\n${CYAN}◆ Process Detection:${RESET} Antigravity is currently active."
        echo -ne "  Do you want to restart it now to verify the restoration? [Y/n] (default: Y): "
        read -r chk_kill
        chk_kill=${chk_kill:-Y}
        if [[ "$chk_kill" =~ ^[Yy]$ ]]; then
            RESTART_APP=true
            pkill -f antigravity || true
            sleep 1
        fi
    fi
fi

echo -e "\n${GRAY}──────────────────────────────────────────────────────────${RESET}"
if [ "$RESTART_APP" = true ]; then
    echo -e " ${GREEN}✔ Complete:${RESET} Relaunching default Antigravity..."
    echo -e "${GRAY}──────────────────────────────────────────────────────────${RESET}\n"
    
    if [ "$OS_TYPE" = "Darwin" ]; then
        if [ "$EUID" -eq 0 ] && [ -n "$REAL_USER" ]; then
            sudo -u "$REAL_USER" open -a Antigravity
        else
            open -a Antigravity
        fi
    else
        if [ "$EUID" -eq 0 ]; then
            [ -z "$DISPLAY" ] && DISPLAY=$(find /proc -maxdepth 2 -user "$REAL_USER" -name environ -exec grep -z '^DISPLAY=' {} + 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\0')
            [ -z "$WAYLAND_DISPLAY" ] && WAYLAND_DISPLAY=$(find /proc -maxdepth 2 -user "$REAL_USER" -name environ -exec grep -z '^WAYLAND_DISPLAY=' {} + 2>/dev/null | head -n 1 | cut -d= -f2- | tr -d '\0')
            
            sudo -u "$REAL_USER" -i env DISPLAY="$DISPLAY" WAYLAND_DISPLAY="$WAYLAND_DISPLAY" nohup "$BASE_DIR/antigravity" >/dev/null 2>&1 &
        else
            nohup "$BASE_DIR/antigravity" >/dev/null 2>&1 &
        fi
    fi
else
    echo -e " ${GREEN}✔ Complete:${RESET} Pipeline finished. Launch Antigravity manually to verify."
    echo -e "${GRAY}──────────────────────────────────────────────────────────${RESET}\n"
fi
