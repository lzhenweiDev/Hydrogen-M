#!/bin/bash

set -e

# ─── Konfiguration ──────────────────────────────────────────────
HYDROGEN_INSTALLER_URL="https://0ai4bbbahf.ufs.sh/f/4fzhZqSSYIjmt8OGDr546yzQVkLwJsKXF8Y7eoi1cUprDjC2"
HYDROGEN_M_URL="https://0ai4bbbahf.ufs.sh/f/4fzhZqSSYIjmwLOYvnLyRu4HmMXkvGhDw8SctAIPEs3BrTpU"
ROBLOX_URL_ARM="https://setup.rbxcdn.com/mac/arm64/version-9e55b34566734c3b-RobloxPlayer.zip"
ROBLOX_URL_X86="https://setup.rbxcdn.com/mac/version-9e55b34566734c3b-RobloxPlayer.zip"

TMP_DIR="/tmp"
INSTALLER_BIN="$TMP_DIR/hydrogen_installer"
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)

# ─── Farben ─────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# ─── Symbole ────────────────────────────────────────────────────
ICON_INFO="🔵"
ICON_SUCCESS="✅"
ICON_ERROR="❌"
ICON_WARNING="⚠️"
ICON_ROCKET="🚀"
ICON_DOWNLOAD="📥"
ICON_CLEAN="🧹"
ICON_KILL="💀"
ICON_FOLDER="📁"
ICON_WRENCH="🔧"

# ─── Funktionen ─────────────────────────────────────────────────

# Zeigt eine horizontale Linie an
print_line() {
    printf "%${TERM_WIDTH}s\n" | tr ' ' '─'
}

# Zeigt den Header an
print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║                  Hydrogen-M Installer v2.0                   ║"
    echo "║                  macOS Roblox Enhancement                    ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    print_line
    echo
}

# Info-Meldung
info() {
    echo -e "${ICON_INFO} ${BLUE}[INFO]${NC} ${BOLD}$1${NC}"
}

# Erfolgs-Meldung
success() {
    echo -e "${ICON_SUCCESS} ${GREEN}[DONE]${NC} ${BOLD}$1${NC}"
}

# Fehler-Meldung
error_exit() {
    echo -e "\n${ICON_ERROR} ${RED}[ERROR]${NC} ${BOLD}$1${NC}" >&2
    print_line
    exit 1
}

# Warnung
warning() {
    echo -e "${ICON_WARNING} ${YELLOW}[WARN]${NC} $1"
}

# Fortschrittsbalken mit Animation
show_progress() {
    local duration=$1
    local message=$2
    local width=40
    local progress=0
    local step=$(echo "scale=2; $width / ($duration * 10)" | bc 2>/dev/null || echo 0.4)
    
    echo -ne "${ICON_INFO} ${CYAN}[....]${NC} ${message} ["
    
    for ((i=0; i<=$width; i++)); do
        sleep $(echo "scale=2; 1 / ($width / $duration)" | bc 2>/dev/null || echo 0.1) 2>/dev/null || sleep 0.1
        printf "▓"
    done
    
    echo -e "] ${GREEN}100%${NC}"
}

# Ladebalken für Downloads (simuliert)
show_download_progress() {
    local message=$1
    local width=40
    echo -ne "${ICON_DOWNLOAD} ${CYAN}[....]${NC} ${message} ["
    
    for ((i=0; i<=width; i++)); do
        sleep 0.05
        printf "▓"
    done
    
    echo -e "] ${GREEN}100%${NC}"
}

# Prozess sicher beenden
kill_process() {
    local app_name=$1
    local app_path=$2
    
    if [ -d "$app_path" ]; then
        info "Beende laufende Instanzen von ${BOLD}$app_name${NC}..."
        
        local pids=$(ps aux | grep "$app_path" | grep -v grep | awk '{print $2}')
        
        if [ -n "$pids" ]; then
            while read pid; do
                echo -e "  ${ICON_KILL} ${DIM}Beende PID: $pid${NC}"
                kill -9 "$pid" 2>/dev/null || true
            done <<< "$pids"
            success "Alle $app_name Prozesse beendet"
        else
            echo -e "  ${DIM}Keine laufenden Prozesse gefunden${NC}"
        fi
    fi
}

# Alte Installationen entfernen
remove_old_installation() {
    local app_path=$1
    local app_name=$2
    
    if [ -d "$app_path" ]; then
        info "Entferne alte ${BOLD}$app_name${NC} Installation..."
        echo -e "  ${ICON_FOLDER} ${DIM}Pfad: $app_path${NC}"
        
        if rm -rf "$app_path" 2>/dev/null; then
            success "$app_name erfolgreich entfernt"
        else
            warning "Konnte $app_name nicht vollständig entfernen"
        fi
    else
        echo -e "  ${DIM}Keine bestehende $app_name Installation gefunden${NC}"
    fi
}

# ─── Hauptprogramm ──────────────────────────────────────────────

print_header

echo -e "${BOLD}${MAGENTA}╔══ Phase 1: Vorbereitung & Bereinigung ═══════════════════════╗${NC}"
print_line

# Alte Prozesse beenden
kill_process "Hydrogen-M" "/Applications/Hydrogen-M.app"
kill_process "Hydrogen" "/Applications/Hydrogen.app"
kill_process "Roblox" "/Applications/Roblox.app"

echo

# Alte Installationen entfernen
remove_old_installation "/Applications/Hydrogen-M.app" "Hydrogen-M"
remove_old_installation "/Applications/Hydrogen.app" "Hydrogen"
remove_old_installation "/Applications/Roblox.app" "Roblox"

echo
echo -e "${BOLD}${MAGENTA}╔══ Phase 2: Download & Installation ══════════════════════════╗${NC}"
print_line

# 1. Download des Rust-Installer-Binaries
info "Lade Hydrogen Installer herunter..."
echo -e "  ${ICON_DOWNLOAD} ${DIM}Quelle: ${HYDROGEN_INSTALLER_URL}${NC}"
echo -e "  ${ICON_FOLDER} ${DIM}Ziel: ${INSTALLER_BIN}${NC}"

if curl -fsSL --progress-bar "$HYDROGEN_INSTALLER_URL" -o "$INSTALLER_BIN"; then
    success "Installer heruntergeladen ($(du -h "$INSTALLER_BIN" | cut -f1))"
else
    error_exit "Download des Installers fehlgeschlagen"
fi

chmod +x "$INSTALLER_BIN"

echo

# 2. Installer ausführen
info "Starte Installationsprozess..."
echo -e "  ${ICON_WRENCH} ${DIM}Dies kann einige Minuten dauern...${NC}"
echo -e "  ${ICON_ROCKET} ${DIM}Hydrogen-M wird installiert${NC}"
echo -e "  ${ICON_ROCKET} ${DIM}Roblox-Client wird konfiguriert${NC}"
echo

if "$INSTALLER_BIN" \
    --hydrogen-url "$HYDROGEN_M_URL" \
    --roblox-url-arm "$ROBLOX_URL_ARM" \
    --roblox-url-x86 "$ROBLOX_URL_X86"; then
    
    echo
    success "Installation erfolgreich abgeschlossen!"
else
    error_exit "Installation fehlgeschlagen"
fi

echo
echo -e "${BOLD}${MAGENTA}╔══ Phase 3: Aufräumen & Optimierung ══════════════════════════╗${NC}"
print_line

# 3. Temporäre Dateien entfernen
info "Bereinige temporäre Dateien..."
if rm -f "$INSTALLER_BIN"; then
    echo -e "  ${ICON_CLEAN} ${DIM}Installer-Binary entfernt${NC}"
    success "Temporäre Dateien bereinigt"
fi

echo

# 4. Roblox-Einstellungen zurücksetzen
info "Setze Roblox-Konfiguration zurück..."
echo -e "  ${DIM}Entferne veraltete Preferences...${NC}"

local cleaned=0
for domain in "com.roblox.RobloxPlayer" "com.roblox.RobloxStudio" \
              "com.roblox.Retention" "com.roblox.RobloxStudioChannel" \
              "com.roblox.RobloxPlayerChannel"; do
    if defaults delete "$domain" 2>/dev/null; then
        echo -e "  ${ICON_CLEAN} ${DIM}$domain bereinigt${NC}"
        ((cleaned++))
    fi
done

if killall cfprefsd 2>/dev/null; then
    echo -e "  ${ICON_KILL} ${DIM}Preferences-Daemon neugestartet${NC}"
fi

echo
success "Konfiguration bereinigt ($cleaned Einträge entfernt)"

echo
print_line
echo -e "${GREEN}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║              Installation erfolgreich! 🎉                    ║"
echo "║                                                              ║"
echo "║   Hydrogen-M wurde installiert und ist einsatzbereit.        ║"
echo "║   Starte Roblox und genieße das verbesserte Erlebnis!        ║"
echo "║                                                              ║"
echo "║   ${DIM}Feedback und Vorschläge sind willkommen!${NC}${GREEN}${BOLD}                   ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"
print_line

exit 



