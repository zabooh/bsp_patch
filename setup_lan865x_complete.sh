#!/bin/bash
#
# LAN865x MQTT Environment Setup - Master Automation Script
# Complete automation of configuration changes
#
# Usage: ./setup_lan865x_complete.sh <build_config_name>
# Example: ./setup_lan865x_complete.sh mybuild_dts
#
# Author: Generated for LAN865x Development Environment  
# Date: 18. January 2026
# Version: 1.1

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRSDK_ROOT="/home/martin/AIoT/lan9662/mchp-brsdk-source-2025.12"

# Parameter validation
if [[ $# -ne 1 ]]; then
    echo "Usage: $0 <build_config_name>"
    echo ""
    echo "Examples:"
    echo "  $0 mybuild_dts          # Standard LAN865x+MQTT config"
    echo "  $0 mybuild_custom       # Custom build configuration"
    echo "  $0 mybuild_production   # Production build"
    echo ""
    echo "This script transforms the standard Buildroot configuration"
    echo "into a LAN865x+MQTT development environment."
    exit 1
fi

BUILD_CONFIG="$1"
TARGET_BUILD_DIR="output/$BUILD_CONFIG"

# Farben
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║               LAN865x MQTT Environment Setup                 ║
║                   Complete Automation                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo "Build Configuration: $BUILD_CONFIG"
    echo "Target Directory: $TARGET_BUILD_DIR"
    echo ""
}

# Function: Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check BRSDK Root
    if [[ ! -d "$BRSDK_ROOT" ]]; then
        log_error "BRSDK Root not found: $BRSDK_ROOT"
        exit 1
    fi
    
    # Check standard config
    if [[ ! -f "$BRSDK_ROOT/output/mybuild/.config" ]]; then
        log_error "Standard configuration not found: output/mybuild/.config"
        exit 1
    fi
    
    # Check required tools
    for tool in zip unzip sed grep; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "Required tool not found: $tool"
            exit 1
        fi
    done
    
    # Expect is optional - warn if not available
    if ! command -v expect &> /dev/null; then
        log_warning "'expect' not installed - using direct configuration method"
        export USE_EXPECT=false
    else
        export USE_EXPECT=true
    fi
    
    log_success "All prerequisites met"
}

# Function: Create backup
create_backup() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="$BRSDK_ROOT/backup_$timestamp"
    
    log_info "Creating backup in: $backup_dir"
    
    mkdir -p "$backup_dir"
    
    # Backup standard config
    if [[ -f "$BRSDK_ROOT/output/mybuild/.config" ]]; then
        cp "$BRSDK_ROOT/output/mybuild/.config" "$backup_dir/mybuild_config.backup"
    fi
    
    # Backup current DTS config (if present)
    if [[ -f "$BRSDK_ROOT/$TARGET_BUILD_DIR/.config" ]]; then
        cp "$BRSDK_ROOT/$TARGET_BUILD_DIR/.config" "$backup_dir/${BUILD_CONFIG}_config.backup"
    fi
    
    # Backup overlay directory (if present)
    if [[ -d "$BRSDK_ROOT/board/mscc/common/rootfs_overlay" ]]; then
        tar -czf "$backup_dir/rootfs_overlay.tgz" -C "$BRSDK_ROOT" board/mscc/common/rootfs_overlay
    fi
    
    log_success "Backup created: $backup_dir"
    echo "$backup_dir" > "$BRSDK_ROOT/.last_backup"
}

# Function: Prepare build environment
prepare_build_environment() {
    log_info "Preparing build environment..."
    
    cd "$BRSDK_ROOT"
    
    # Create target build directory
    mkdir -p "$TARGET_BUILD_DIR"
    
    # Copy standard config as basis
    if [[ ! -f "$TARGET_BUILD_DIR/.config" ]]; then
        log_info "Copying standard configuration as basis..."
        cp "output/mybuild/.config" "$TARGET_BUILD_DIR/.config"
    fi
    
    log_success "Build environment prepared"
}

# Function: Automated configuration
apply_mqtt_configuration() {
    log_info "Applying MQTT configuration..."
    
    # Use direct configuration without expect
    log_info "Configuring MQTT packages directly..."
    
    # Direct .config modification for MQTT packages
    local config_file="$TARGET_BUILD_DIR/.config"
    
    if [[ -f "$config_file" ]]; then
        # Enable MQTT packages
        configure_mqtt_packages_direct "$config_file"
        
        # Refresh Buildroot cache
        cd "$BRSDK_ROOT"
        make O="$TARGET_BUILD_DIR" olddefconfig &>/dev/null
        
        log_success "MQTT configuration applied"
    else
        log_error "Configuration file not found: $config_file"
        exit 1
    fi
}

# Function: Direct MQTT packages configuration
configure_mqtt_packages_direct() {
    local config_file="$1"
    
    log_info "Enabling MQTT packages in $config_file..."
    
    # Set MQTT packages directly in .config
    local mqtt_configs=(
        "BR2_PACKAGE_MOSQUITTO=y"
        "BR2_PACKAGE_MOSQUITTO_BROKER=y"
        "BR2_PACKAGE_MOSQUITTO_BROKER_DYNAMIC_SECURITY_PLUGIN=y"
        "BR2_PACKAGE_PAHO_MQTT_C=y"
        "BR2_PACKAGE_PYTHON_PAHO_MQTT=y"
        "BR2_PACKAGE_PYTHON_AIOMQTT=y"
        "BR2_PACKAGE_CJSON=y"
        "BR2_PACKAGE_OPENSSL=y"
        "BR2_PACKAGE_LIBOPENSSL_BIN=y"
        "BR2_PACKAGE_PYTHON3=y"
        "BR2_PACKAGE_PYTHON3_SSL=y"
        "BR2_TARGET_GENERIC_ROOT_PASSWD=\"microchip\""
    )
    
    for config_option in "${mqtt_configs[@]}"; do
        local config_name=$(echo "$config_option" | cut -d'=' -f1)
        
        # Remove existing entries
        sed -i "/^$config_name=/d" "$config_file"
        sed -i "/^# $config_name is not set/d" "$config_file"
        
        # Add new configuration
        echo "$config_option" >> "$config_file"
    done
    
    log_success "MQTT packages configured"
}

# Function: Create optimized Mosquitto configuration
create_mosquitto_config() {
    local overlay_dir="$1"
    local mosquitto_conf_dir="$overlay_dir/etc/mosquitto"
    local mosquitto_conf="$mosquitto_conf_dir/mosquitto.conf"
    
    log_info "Creating optimized Mosquitto configuration..."
    
    # Create mosquitto configuration directory
    mkdir -p "$mosquitto_conf_dir"
    
    # Create optimized mosquitto.conf
    cat > "$mosquitto_conf" << 'EOF'
# Mosquitto MQTT Broker Configuration
# Generated by setup_lan865x_complete.sh for LAN865x T1S Development

# =================================================================
# Network Configuration
# =================================================================

# Listen on standard MQTT port
port 1883

# Allow connections from any interface
bind_address 0.0.0.0

# Maximum number of client connections
max_connections 100

# =================================================================
# Security Configuration  
# =================================================================

# Allow anonymous connections (for development)
allow_anonymous true

# Disable persistent database (for embedded systems)
persistence false

# =================================================================
# Logging Configuration
# =================================================================

# Log to syslog
log_dest syslog

# Log types
log_type error
log_type warning  
log_type notice
log_type information

# Connection logging
connection_messages true

# =================================================================
# Performance Configuration
# =================================================================

# Keepalive settings
keepalive_interval 60

# Maximum packet size (1MB)
message_size_limit 1048576

# Queue settings
max_queued_messages 1000

# =================================================================
# LAN865x T1S Optimizations
# =================================================================

# Optimize for low-latency T1S networks
max_inflight_messages 20
max_inflight_bytes 65536

EOF

    log_success "Mosquitto configuration created: $mosquitto_conf"
}

# Function: Install overlay files and DTS
install_overlays() {
    log_info "Installing LAN865x overlay files and Device Tree..."
    
    local overlay_dir="$BRSDK_ROOT/board/mscc/common/rootfs_overlay"
    
    # If ZIP file exists, use it
    if [[ -f "$SCRIPT_DIR/lan865x_overlay_files.zip" ]]; then
        log_info "Extracting from ZIP archive..."
        mkdir -p "$overlay_dir"
        unzip -o "$SCRIPT_DIR/lan865x_overlay_files.zip" -d "$BRSDK_ROOT/"
    else
        log_info "Copying existing overlay files..."
        # Overlay directory already exists, no action needed
    fi
    
    # Install LAN865x Device Tree
    install_lan865x_device_tree
    
    # Create optimized Mosquitto configuration
    create_mosquitto_config "$overlay_dir"
    
    # Set correct permissions
    if [[ -f "$overlay_dir/usr/bin/load.sh" ]]; then
        chmod +x "$overlay_dir/usr/bin/load.sh"
    fi
    
    if [[ -f "$overlay_dir/etc/init.d/S99myconfig.sh" ]]; then
        chmod +x "$overlay_dir/etc/init.d/S99myconfig.sh"
    fi
    
    log_success "Overlay files and Device Tree installed"
}

# Function: Create post-build hook for DTS
create_dts_post_build_hook() {
    log_info "Creating post-build hook for Device Tree installation..."
    
    local post_build_script="$BRSDK_ROOT/$TARGET_BUILD_DIR/post_build_dts_install.sh"
    
    cat > "$post_build_script" << EOF
#!/bin/bash
# Automatic LAN865x Device Tree installation after first build
# Generated by setup_lan865x_complete.sh

BRSDK_ROOT="$BRSDK_ROOT"
TARGET_BUILD_DIR="$TARGET_BUILD_DIR"
DTS_STAGING_DIR="\$BRSDK_ROOT/.lan865x_dts_staging"

if [[ -f "\$DTS_STAGING_DIR/lan966x-pcb8291.dts" ]]; then
    echo "Installing LAN865x Device Tree after build..."
    
    DTS_TARGET_DIR="\$BRSDK_ROOT/\$TARGET_BUILD_DIR/build/linux-custom/arch/arm/boot/dts/microchip"
    
    # Backup original if exists
    if [[ -f "\$DTS_TARGET_DIR/lan966x-pcb8291.dts" ]]; then
        cp "\$DTS_TARGET_DIR/lan966x-pcb8291.dts" "\$DTS_TARGET_DIR/lan966x-pcb8291.dts.original"
    fi
    
    # Install LAN865x DTS
    cp "\$DTS_STAGING_DIR/lan966x-pcb8291.dts" "\$DTS_TARGET_DIR/lan966x-pcb8291.dts"
    
    echo "LAN865x Device Tree installed successfully"
    echo "Note: Run 'make O=\$TARGET_BUILD_DIR' again to rebuild with LAN865x DTS"
    
    # Cleanup staging
    rm -rf "\$DTS_STAGING_DIR"
    rm -f "\$0"  # Remove this post-build script
fi
EOF
    
    chmod +x "$post_build_script"
    
    # Configure Buildroot post-build script
    local config_file="$BRSDK_ROOT/$TARGET_BUILD_DIR/.config"
    
    # Check if post-build script is already configured
    if ! grep -q "BR2_ROOTFS_POST_BUILD_SCRIPT.*post_build_dts_install.sh" "$config_file"; then
        # Add post-build script to configuration
        if grep -q "^BR2_ROOTFS_POST_BUILD_SCRIPT=" "$config_file"; then
            # Extend existing post-build scripts
            sed -i "s|^BR2_ROOTFS_POST_BUILD_SCRIPT=.*|& $TARGET_BUILD_DIR/post_build_dts_install.sh|" "$config_file"
        else
            # Add new post-build script line
            echo "BR2_ROOTFS_POST_BUILD_SCRIPT=\"$TARGET_BUILD_DIR/post_build_dts_install.sh\"" >> "$config_file"
        fi
        log_info "Post-build hook for Device Tree installation configured"
    fi
}

# Function: Install LAN865x Device Tree
install_lan865x_device_tree() {
    log_info "Installing LAN865x Device Tree..."
    
    local dts_source_file="$SCRIPT_DIR/lan966x-pcb8291_lan865x.dts"
    local dts_target_dir="$BRSDK_ROOT/$TARGET_BUILD_DIR/build/linux-custom/arch/arm/boot/dts/microchip"
    
    # Check if DTS file exists
    if [[ -f "$dts_source_file" ]]; then
        log_info "LAN865x Device Tree found: $dts_source_file"
        
        # Check if build directory already exists
        if [[ -d "$dts_target_dir" ]]; then
            # Build already performed - install DTS directly
            log_info "Build directory exists - installing DTS directly"
            
            # Create backup of original DTS
            if [[ -f "$dts_target_dir/lan966x-pcb8291.dts" ]]; then
                local timestamp=$(date +%Y%m%d_%H%M%S)
                cp "$dts_target_dir/lan966x-pcb8291.dts" "$dts_target_dir/lan966x-pcb8291.dts.backup.$timestamp"
                log_info "Backup created: lan966x-pcb8291.dts.backup.$timestamp"
            fi
            
            # Install LAN865x DTS
            cp "$dts_source_file" "$dts_target_dir/lan966x-pcb8291.dts"
            log_success "LAN865x Device Tree installed directly"
        else
            # Build not yet performed - prepare DTS for later use
            log_warning "Build directory does not yet exist"
            log_info "Installing DTS for automatic use on first build..."
            
            # Prepare DTS in a temporary directory
            local temp_dts_dir="$BRSDK_ROOT/.lan865x_dts_staging"
            mkdir -p "$temp_dts_dir"
            cp "$dts_source_file" "$temp_dts_dir/lan966x-pcb8291.dts"
            
            # Create post-build hook
            create_dts_post_build_hook
            
            log_success "LAN865x Device Tree prepared for first build"
        fi
    else
        log_warning "LAN865x Device Tree not found: $dts_source_file"
        log_info "Standard Device Tree will be used (without LAN865x support)"
    fi
}

# Function: Validate configuration
validate_final_config() {
    log_info "Validating final configuration..."
    
    local config_file="$BRSDK_ROOT/$TARGET_BUILD_DIR/.config"
    local overlay_dir="$BRSDK_ROOT/board/mscc/common/rootfs_overlay"
    
    # Check Buildroot config
    local required_options=(
        "BR2_PACKAGE_PYTHON3_SSL=y"
        "BR2_PACKAGE_MOSQUITTO=y"
        "BR2_PACKAGE_MOSQUITTO_BROKER=y"
        "BR2_TARGET_GENERIC_ROOT_PASSWD=\"microchip\""
    )
    
    local missing_count=0
    for option in "${required_options[@]}"; do
        if ! grep -q "^$option" "$config_file"; then
            log_error "Missing option: $option"
            ((missing_count++))
        fi
    done
    
    # Check overlay files
    local required_files=(
        "$overlay_dir/usr/bin/load.sh"
        "$overlay_dir/etc/init.d/S99myconfig.sh"
        "$overlay_dir/etc/mosquitto/mosquitto.conf"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Missing overlay file: $file"
            ((missing_count++))
        fi
    done
    
    # Check Device Tree
    local dts_file="$BRSDK_ROOT/$TARGET_BUILD_DIR/build/linux-custom/arch/arm/boot/dts/microchip/lan966x-pcb8291.dts"
    local dts_staging_dir="$BRSDK_ROOT/.lan865x_dts_staging"
    
    if [[ -f "$dts_file" ]]; then
        if grep -q "lan865x" "$dts_file"; then
            log_success "LAN865x Device Tree already installed"
        else
            log_warning "Device Tree without LAN865x configuration"
        fi
    elif [[ -f "$dts_staging_dir/lan966x-pcb8291.dts" ]]; then
        log_info "LAN865x Device Tree prepared for first build"
        if grep -q "lan865x" "$dts_staging_dir/lan966x-pcb8291.dts"; then
            log_success "LAN865x Device Tree staging ready"
        fi
    else
        log_error "Device Tree file not found: $dts_file"
        log_error "Also not in staging directory: $dts_staging_dir"
        ((missing_count++))
    fi
    
    if [[ $missing_count -gt 0 ]]; then
        log_error "Validation failed: $missing_count errors found"
        return 1
    fi
    
    log_success "Validation successful"
    return 0
}

# Function: Execute build (optional)
offer_build() {
    echo ""
    echo "╔════════════════════════════════════════╗"
    echo "║           Build Options                ║"
    echo "╚════════════════════════════════════════╝"
    echo ""
    echo "1) Start full build (30-60 Min)"
    echo "2) Rebuild MQTT packages only (5-10 Min)"
    echo "3) Execute build manually later"
    echo ""
    
    read -p "Choose an option (1-3): " -n 1 -r
    echo ""
    
    cd "$BRSDK_ROOT"
    
    case $REPLY in
        1)
            log_info "Starting full build..."
            make O="$TARGET_BUILD_DIR"
            ;;
        2)
            log_info "Rebuilding MQTT packages..."
            make O="$TARGET_BUILD_DIR" mosquitto-rebuild
            make O="$TARGET_BUILD_DIR" paho-mqtt-c-rebuild
            ;;
        3)
            log_info "Build skipped"
            echo ""
            echo "Manual build commands:"
            echo "  cd $BRSDK_ROOT"
            echo "  make O=$TARGET_BUILD_DIR                    # Full build"
            echo "  make O=$TARGET_BUILD_DIR mosquitto-rebuild  # MQTT only"
            ;;
        *)
            log_warning "Invalid selection, build skipped"
            ;;
    esac
}

# Funktion: Erfolgsmeldung und nächste Schritte
show_completion_info() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                    KONFIGURATION ABGESCHLOSSEN                 ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    
    log_success "LAN865x MQTT Environment erfolgreich konfiguriert!"
    echo ""
    
    echo "📁 Konfiguration:"
    echo "   ├── Buildroot: $TARGET_BUILD_DIR/.config"
    echo "   ├── Overlays: board/mscc/common/rootfs_overlay/"
    echo "   ├── Device Tree: LAN865x-fähige lan966x-pcb8291.dts"
    echo "   └── Backup: $(cat "$BRSDK_ROOT/.last_backup" 2>/dev/null || echo 'Nicht verfügbar')"
    echo ""
    
    echo "🔧 Aktivierte Features:"
    echo "   ├── ✅ MQTT Broker (Eclipse Mosquitto)"
    echo "   ├── ✅ Python3 MQTT Clients (Paho + aiomqtt)"  
    echo "   ├── ✅ C/C++ MQTT Library (Paho)"
    echo "   ├── ✅ JSON Support (cJSON)"
    echo "   ├── ✅ SSL/TLS Support"
    echo "   └── ✅ LAN865x Network Configuration"
    echo ""
    
    # Build-Status prüfen
    if [[ -d "$BRSDK_ROOT/output/$TARGET_BUILD_DIR" ]]; then
        echo "📋 Nächste Schritte (Build-Verzeichnis vorhanden):"
        echo "   1. Build ausführen: make O=$TARGET_BUILD_DIR"
        echo "   2. Image flashen auf LAN865x Hardware"
    else
        echo "📋 Nächste Schritte (Frische Konfiguration):"
        echo "   1. WICHTIG: Erster Build wird Device Tree automatisch installieren"
        echo "   2. Build ausführen: make O=$TARGET_BUILD_DIR"
        echo "   3. Image flashen auf LAN865x Hardware"
    fi
    
    echo "   4. MQTT Services testen:"
    echo "      • mosquitto -d"
    echo "      • mosquitto_pub -t 'test/topic' -m 'Hello'"
    echo "      • mosquitto_sub -t 'test/topic'"
    echo "   5. LAN865x Netzwerk testen:"
    echo "      • /usr/bin/load.sh"
    echo "      • ip addr show eth1 eth2"
    echo ""
    
    echo "📚 Dokumentation:"
    echo "   └── README_CHANGE.md - Detaillierte Anleitung"
    echo ""
}

# Function: Create build information file
create_build_info() {
    log_info "Creating build information..."
    
    local build_timestamp=$(date '+%Y-%m-%d %H:%M:%S %Z')
    local build_date=$(date '+%Y%m%d_%H%M%S')
    local build_host=$(hostname)
    local build_user=$(whoami)
    local buildroot_version=$(grep "BR2_VERSION=" "$BRSDK_ROOT/$TARGET_BUILD_DIR/.config" 2>/dev/null | cut -d'"' -f2 || echo "2025.12")
    
    # Create buildinfo file in target
    local buildinfo_file="$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/buildinfo"
    mkdir -p "$(dirname "$buildinfo_file")"
    
    cat > "$buildinfo_file" << EOF
# LAN865x Build Information
# Generated by: $0
BUILD_TIMESTAMP="$build_timestamp"
BUILD_DATE="$build_date"
BUILD_HOST="$build_host"
BUILD_USER="$build_user"
BUILD_CONFIG="$BUILD_CONFIG"
SETUP_VERSION="LAN865x-MQTT-v1.0"
BUILDROOT_VERSION="$buildroot_version"
LAN865X_VERSION="T1S-Development"
MQTT_VERSION="Eclipse-Mosquitto"
EOF
    
    log_success "Build info created: $build_timestamp"
    log_info "Build info file: $buildinfo_file"
}

# Function: Create MOTD (Message of the Day)
create_motd() {
    log_info "Creating system MOTD..."
    
    local buildinfo_file="$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/buildinfo"
    if [[ -f "$buildinfo_file" ]]; then
        . "$buildinfo_file"
        
        cat > "$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/motd" << EOF

╔════════════════════════════════════════════╗
║        LAN865x T1S Development System      ║
╠════════════════════════════════════════════╣
║  Build: $BUILD_TIMESTAMP                   ║
║  Config: $BUILD_CONFIG                     ║
║  SSH Password: microchip                   ║
╚════════════════════════════════════════════╝

🌐 Network Interfaces:
   • eth0: Standard Ethernet 
   • eth2: T1S Network (LAN865x)
   
📡 MQTT Broker: localhost:1883
🔧 Development Tools: Available

Welcome to the LAN865x T1S Development Environment!

EOF
        log_success "MOTD created for SSH login"
    else
        log_warning "No build info found for MOTD creation"
    fi
}

# Function: Create boot-time build info display
create_boot_info_script() {
    log_info "Creating boot-time build info display..."
    
    local init_script="$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/init.d/S01buildinfo"
    mkdir -p "$(dirname "$init_script")"
    
    cat > "$init_script" << 'EOF'
#!/bin/sh
# S01buildinfo - Display build information at boot

start() {
    if [ -f /etc/buildinfo ]; then
        echo "=================================================="
        echo "    LAN865x T1S Development Image"
        echo "=================================================="
        
        . /etc/buildinfo
        echo "Build Date: $BUILD_TIMESTAMP"
        echo "Build Config: $BUILD_CONFIG"
        echo "Setup Version: $SETUP_VERSION"
        echo "LAN865x Version: $LAN865X_VERSION"
        echo "=================================================="
        echo ""
    fi
}

case "$1" in
    start) start ;;
    stop) ;;
    restart) start ;;
    *) echo "Usage: $0 {start|stop|restart}" ;;
esac
EOF
    
    chmod +x "$init_script"
    log_success "Boot info script created: S01buildinfo"
}

# Function: Create runtime buildinfo command
create_buildinfo_command() {
    log_info "Creating runtime buildinfo command..."
    
    local buildinfo_cmd="$BRSDK_ROOT/$TARGET_BUILD_DIR/target/usr/bin/buildinfo"
    mkdir -p "$(dirname "$buildinfo_cmd")"
    
    cat > "$buildinfo_cmd" << 'EOF'
#!/bin/sh
# Runtime build information display

if [ -f /etc/buildinfo ]; then
    . /etc/buildinfo
    echo "🏗️ LAN865x Build Information:"
    echo "   📅 Date: $BUILD_TIMESTAMP"
    echo "   🏗️ Config: $BUILD_CONFIG"
    echo "   💻 Host: $BUILD_HOST"
    echo "   👤 User: $BUILD_USER"
    echo "   📦 Version: $SETUP_VERSION"
    echo "   🌐 LAN865x: $LAN865X_VERSION"
    echo "   📡 MQTT: $MQTT_VERSION"
    echo "   🔧 Buildroot: $BUILDROOT_VERSION"
else
    echo "❌ No build information available"
    echo "   This image was not created with build info support"
fi
EOF
    
    chmod +x "$buildinfo_cmd"
    log_success "Runtime buildinfo command created"
}

# Main function
main() {
    show_banner
    echo ""
    
    check_prerequisites
    create_backup
    prepare_build_environment
    apply_mqtt_configuration
    install_overlays
    
    # Add build information after overlays are installed
    create_build_info
    create_motd
    create_boot_info_script
    create_buildinfo_command
    
    if validate_final_config; then
        offer_build
        show_completion_info
    else
        log_error "Configuration failed. Check the logs."
        exit 1
    fi
}

# Execute script
main "$@"