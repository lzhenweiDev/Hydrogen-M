#!/bin/bash

set -e

# ─── Configuration ──────────────────────────────────────────────
HYDROGEN_INSTALLER_URL="https://0ai4bbbahf.ufs.sh/f/4fzhZqSSYIjmt8OGDr546yzQVkLwJsKXF8Y7eoi1cUprDjC2"
HYDROGEN_M_URL="https://0ai4bbbahf.ufs.sh/f/4fzhZqSSYIjmwLOYvnLyRu4HmMXkvGhDw8SctAIPEs3BrTpU"
ROBLOX_URL_ARM="https://setup.rbxcdn.com/mac/arm64/version-9e55b34566734c3b-RobloxPlayer.zip"
ROBLOX_URL_X86="https://setup.rbxcdn.com/mac/version-9e55b34566734c3b-RobloxPlayer.zip"

TMP_DIR="/tmp"
INSTALLER_BIN="$TMP_DIR/hydrogen_installer"

# ─── Colors ─────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

# ─── Functions ──────────────────────────────────────────────────

info() {
    echo -e "${BLUE}[*]${NC} $1"
}

success() {
    echo -e "${GREEN}[✔]${NC} $1"
}

error_exit() {
    echo -e "${RED}[✘] Error: $1${NC}" >&2
    exit 1
}

warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Kill process by app path
kill_process() {
    local app_name="$1"
    local app_path="$2"
    
    if [ -d "$app_path" ]; then
        local pids=$(ps aux | grep "$app_path" | grep -v grep | awk '{print $2}')
        if [ -n "$pids" ]; then
            while read pid; do
                kill -9 "$pid" 2>/dev/null || true
            done <<< "$pids"
            success "Killed $app_name processes (PIDs: $(echo $pids | tr '\n' ' '))"
        else
            info "No running $app_name processes found"
        fi
    fi
}

# Remove old installation
remove_app() {
    local app_path="$1"
    local app_name="$2"
    
    if [ -d "$app_path" ]; then
        if rm -rf "$app_path" 2>/dev/null; then
            success "Removed old $app_name installation ($app_path)"
        else
            warning "Could not remove $app_name - please delete manually: $app_path"
        fi
    fi
}

# Clean Roblox preferences
clean_prefs() {
    local domain="$1"
    if defaults delete "$domain" 2>/dev/null; then
        echo -ne " ${DIM}$domain${NC}"
    fi
}

# ─── Main ───────────────────────────────────────────────────────

echo -e "${CYAN}${BOLD}Hydrogen-M Installer v2.0 - macOS Roblox Enhancement${NC}"
echo ""

# ─── Phase 1: Cleanup ───────────────────────────────────────────
info "Killing old processes..."
kill_process "Hydrogen-M" "/Applications/Hydrogen-M.app"
kill_process "Hydrogen" "/Applications/Hydrogen.app"
kill_process "Roblox" "/Applications/Roblox.app"

info "Removing old installations..."
remove_app "/Applications/Hydrogen-M.app" "Hydrogen-M"
remove_app "/Applications/Hydrogen.app" "Hydrogen"
remove_app "/Applications/Roblox.app" "Roblox"

# ─── Phase 2: Download & Install ────────────────────────────────
info "Downloading Hydrogen installer... ($HYDROGEN_INSTALLER_URL -> $INSTALLER_BIN)"
if curl -fsSL --progress-bar "$HYDROGEN_INSTALLER_URL" -o "$INSTALLER_BIN"; then
    success "Downloaded installer ($(du -h "$INSTALLER_BIN" | cut -f1))"
else
    error_exit "Failed to download installer"
fi

chmod +x "$INSTALLER_BIN"

info "Running installer... (this may take a few minutes)"
if "$INSTALLER_BIN" \
    --hydrogen-url "$HYDROGEN_M_URL" \
    --roblox-url-arm "$ROBLOX_URL_ARM" \
    --roblox-url-x86 "$ROBLOX_URL_X86"; then
    success "Installation completed successfully"
else
    error_exit "Installation failed"
fi

# ─── Phase 3: Cleanup ───────────────────────────────────────────
info "Cleaning up temporary files... (removing $INSTALLER_BIN)"
rm -f "$INSTALLER_BIN" && success "Removed installer binary"

info "Resetting Roblox preferences..."
echo -ne "  Cleaned:"
clean_prefs "com.roblox.RobloxPlayer"
clean_prefs "com.roblox.RobloxStudio"
clean_prefs "com.roblox.Retention"
clean_prefs "com.roblox.RobloxStudioChannel"
clean_prefs "com.roblox.RobloxPlayerChannel"
echo ""
killall cfprefsd 2>/dev/null && success "Preferences daemon restarted"

# ─── Done ───────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}[✔] Hydrogen-M installed successfully!${NC}"
echo -e "${DIM}Enjoy the experience! Please provide feedback to help us improve.${NC}"
