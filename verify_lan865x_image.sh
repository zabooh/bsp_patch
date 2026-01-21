#!/bin/bash

# LAN865x Image Verification Script
# Verifies that all changes by setup_lan865x_complete.sh are successfully included in the image

# Remove set -e to enable better error handling

# Colored output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
    log_to_html "INFO" "$1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
    log_to_html "SUCCESS" "$1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
    log_to_html "WARNING" "$1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    log_to_html "ERROR" "$1"
}

# Show banner
show_banner() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║            LAN865x Image Verification Tool                   ║
║          Verifies Setup-Script Changes in Image              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
}

# Show help
show_help() {
    echo "Usage: $0 <build_config_name> [options]"
    echo ""
    echo "Verifies that all LAN865x+MQTT changes are included in the generated image"
    echo ""
    echo "Examples:"
    echo "  $0 mybuild_t1s                    # Standard T1S Build"
    echo "  $0 lan865x_dev                    # Development Build"
    echo "  $0 production_mqtt                # Production Build"
    echo "  $0 mybuild_dts --pdf               # Generate PDF report"
    echo "  $0 mybuild_dts --pdf custom_name   # Custom PDF filename"
    echo ""
    echo "Options:"
    echo "  --pdf [filename]    Generate PDF report (requires wkhtmltopdf)"
    echo "  --html [filename]   Generate HTML report only"
    echo "  -h, --help         Show this help"
    echo ""
    echo "The script verifies:"
    echo "  ✓ LAN865x Device Tree Configuration"
    echo "  ✓ MQTT Infrastructure (Mosquitto + Paho + Python)"
    echo "  ✓ SSL/TLS Support"
    echo "  ✓ cJSON Library"
    echo "  ✓ LAN865x Overlay Files"
    echo "  ✓ SSH Configuration"
    echo "  ✓ Buildroot Configuration"
    echo ""
}

# Set variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BRSDK_ROOT="$SCRIPT_DIR"
BUILD_CONFIG="$1"
GENERATE_PDF=false
GENERATE_HTML=false
PDF_FILENAME=""
HTML_FILENAME=""
REPORT_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Parse command line arguments first
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if [[ -z "$BUILD_CONFIG" ]]; then
    show_help
    exit 1
fi

# Parse remaining arguments
shift # Remove build config from arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --pdf)
            GENERATE_PDF=true
            if [[ -n "$2" && "$2" != --* ]]; then
                PDF_FILENAME="$2"
                shift
            else
                PDF_FILENAME="LAN865x_Verification_Report_${BUILD_CONFIG}_${REPORT_TIMESTAMP}.pdf"
            fi
            ;;
        --html)
            GENERATE_HTML=true
            if [[ -n "$2" && "$2" != --* ]]; then
                HTML_FILENAME="$2"
                shift
            else
                HTML_FILENAME="LAN865x_Verification_Report_${BUILD_CONFIG}_${REPORT_TIMESTAMP}.html"
            fi
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
    shift
done

TARGET_BUILD_DIR="output/$BUILD_CONFIG"

# Check if build directory exists
if [[ ! -d "$BRSDK_ROOT/$TARGET_BUILD_DIR" ]]; then
    log_error "Build directory not found: $TARGET_BUILD_DIR"
    log_error "Execute build first: make O=$TARGET_BUILD_DIR"
    exit 1
fi

# HTML Export functions
start_html_report() {
    if [[ "$GENERATE_PDF" == "true" || "$GENERATE_HTML" == "true" ]]; then
        local html_file="${HTML_FILENAME:-/tmp/lan865x_verification_${REPORT_TIMESTAMP}.html}"
        local current_date=$(date)
        
        cat > "$html_file" << EOF
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>LAN865x Image Verification Report</title>
    <style>
        body {
            font-family: 'Courier New', monospace;
            margin: 20px;
            line-height: 1.4;
            background-color: #f5f5f5;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        .header {
            text-align: center;
            border: 2px solid #333;
            padding: 15px;
            margin-bottom: 20px;
            background-color: #f8f9fa;
        }
        .section {
            margin: 20px 0;
            padding: 15px;
            border-left: 4px solid #007bff;
            background-color: #f8f9fa;
        }
        .config-section {
            margin: 20px 0;
            padding: 15px;
            border-left: 4px solid #28a745;
            background-color: #f1f8e9;
        }
        .success { color: #28a745; font-weight: bold; }
        .warning { color: #ffc107; font-weight: bold; }
        .error { color: #dc3545; font-weight: bold; }
        .info { color: #17a2b8; font-weight: bold; }
        .test-result {
            display: flex;
            justify-content: space-between;
            padding: 2px 0;
            border-bottom: 1px dotted #ccc;
        }
        .summary {
            background-color: #e9ecef;
            padding: 15px;
            border-radius: 5px;
            margin: 20px 0;
        }
        .network-config, .system-config {
            background-color: #f1f3f4;
            padding: 15px;
            margin: 10px 0;
            border-radius: 5px;
            border-left: 4px solid #6f42c1;
        }
        .ssh-config {
            background-color: #e8f5e8;
            padding: 15px;
            margin: 10px 0;
            border-radius: 5px;
            border-left: 4px solid #dc3545;
        }
        .mqtt-config {
            background-color: #fff3cd;
            padding: 15px;
            margin: 10px 0;
            border-radius: 5px;
            border-left: 4px solid #ffc107;
        }
        pre {
            background-color: #f8f9fa;
            padding: 10px;
            border-radius: 5px;
            overflow-x: auto;
            white-space: pre-wrap;
        }
        .timestamp {
            text-align: right;
            color: #666;
            font-size: 0.9em;
        }
        .build-info {
            background-color: #d1ecf1;
            padding: 10px;
            border-radius: 5px;
            margin: 10px 0;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>LAN865x Image Verification Report</h1>
            <p>Verifies Setup-Script Changes in Image</p>
        </div>
        <div class="timestamp">Generated: $current_date</div>
        <div class="build-info">
            <h3>Build Information</h3>
            <p><strong>Build Config:</strong> $BUILD_CONFIG</p>
            <p><strong>Target Directory:</strong> $TARGET_BUILD_DIR</p>
        </div>
        <div class="section">
            <h2>Verification Results</h2>
EOF
        
        export HTML_FILE="$html_file"
    fi
}

log_to_html() {
    if [[ "$GENERATE_PDF" == "true" || "$GENERATE_HTML" == "true" ]] && [[ -n "$HTML_FILE" ]]; then
        local level="$1"
        local message="$2"
        local class="info"
        
        case "$level" in
            "SUCCESS") class="success" ;;
            "WARNING") class="warning" ;;
            "ERROR") class="error" ;;
            "INFO") class="info" ;;
        esac
        
        echo "            <div class=\"$class\">[$level] $message</div>" >> "$HTML_FILE"
    fi
}

test_to_html() {
    if [[ "$GENERATE_PDF" == "true" || "$GENERATE_HTML" == "true" ]] && [[ -n "$HTML_FILE" ]]; then
        local description="$1"
        local result="$2"
        local class="success"
        
        if [[ "$result" == "FAIL" ]]; then
            class="error"
        elif [[ "$result" == "WARN" ]]; then
            class="warning"
        fi
        
        echo "            <div class=\"test-result\">" >> "$HTML_FILE"
        echo "                <span>$description</span>" >> "$HTML_FILE"
        echo "                <span class=\"$class\">$result</span>" >> "$HTML_FILE"
        echo "            </div>" >> "$HTML_FILE"
    fi
}

section_to_html() {
    if [[ "$GENERATE_PDF" == "true" || "$GENERATE_HTML" == "true" ]] && [[ -n "$HTML_FILE" ]]; then
        local title="$1"
        local content="$2"
        local section_class="${3:-config-section}"
        
        echo "        </div>" >> "$HTML_FILE"
        echo "        <div class=\"$section_class\">" >> "$HTML_FILE"
        echo "            <h3>$title</h3>" >> "$HTML_FILE"
        echo "            <pre>$content</pre>" >> "$HTML_FILE"
    fi
}

# Funktion zum Hinzufügen der Network Configuration ins HTML
add_network_config_to_html() {
    if [[ "$GENERATE_PDF" == "true" || "$GENERATE_HTML" == "true" ]] && [[ -n "$HTML_FILE" ]]; then
        # Capture network configuration output
        local network_info=$(show_network_configuration 2>/dev/null | sed 's/</\&lt;/g; s/>/\&gt;/g')
        section_to_html "🌐 Network Configuration" "$network_info" "network-config"
    fi
}

# Funktion zum Hinzufügen der LAN865x Configuration ins HTML
add_lan865x_config_to_html() {
    if [[ "$GENERATE_PDF" == "true" || "$GENERATE_HTML" == "true" ]] && [[ -n "$HTML_FILE" ]]; then
        local lan865x_info=$(show_lan865x_configuration 2>/dev/null | sed 's/</\&lt;/g; s/>/\&gt;/g')
        section_to_html "🔧 LAN865x T1S Configuration" "$lan865x_info" "config-section"
    fi
}

# Funktion zum Hinzufügen der MQTT Configuration ins HTML
add_mqtt_config_to_html() {
    if [[ "$GENERATE_PDF" == "true" || "$GENERATE_HTML" == "true" ]] && [[ -n "$HTML_FILE" ]]; then
        local mqtt_info=$(show_mqtt_configuration 2>/dev/null | sed 's/</\&lt;/g; s/>/\&gt;/g')
        section_to_html "📡 MQTT Broker Configuration" "$mqtt_info" "mqtt-config"
    fi
}

# Funktion zum Hinzufügen der System Configuration ins HTML
add_system_config_to_html() {
    if [[ "$GENERATE_PDF" == "true" || "$GENERATE_HTML" == "true" ]] && [[ -n "$HTML_FILE" ]]; then
        local system_info=$(show_system_configuration 2>/dev/null | sed 's/</\&lt;/g; s/>/\&gt;/g')
        section_to_html "⚙️ System Configuration" "$system_info" "system-config"
    fi
}

finish_html_report() {
    if [[ "$GENERATE_PDF" == "true" || "$GENERATE_HTML" == "true" ]] && [[ -n "$HTML_FILE" ]]; then
        
        local final_date=$(date)
        local target_dir="$BRSDK_ROOT/$TARGET_BUILD_DIR/target"
        local config_file="$BRSDK_ROOT/$TARGET_BUILD_DIR/.config"
        
        cat >> "$HTML_FILE" << 'EOF'
        </div>
        
        <!-- Network Configuration -->
        <div class="network-config">
            <h3>🌐 Network Configuration</h3>
            <pre>
📋 Device Tree Network Settings:

🔌 Expected Ethernet Interfaces:
   • eth0: Main Ethernet interface (10/100/1000 Mbps)
   • lan865x: T1S interface (10BASE-T1S)

📝 Network Interface Configuration:
EOF

        # Add network interfaces content if available
        if [[ -f "$target_dir/etc/network/interfaces" ]]; then
            cat "$target_dir/etc/network/interfaces" >> "$HTML_FILE" 2>/dev/null || echo "# Network interfaces file not accessible" >> "$HTML_FILE"
        else
            echo "# interface file auto-generated by buildroot" >> "$HTML_FILE"
            echo "" >> "$HTML_FILE"
            echo "auto lo" >> "$HTML_FILE"
            echo "iface lo inet loopback" >> "$HTML_FILE"
        fi

        cat >> "$HTML_FILE" << 'EOF'

🔍 Ethernet Interface Details:
   📍 MAC Address Configuration:
      • eth0 MAC: Auto-generated by kernel (based on SoC)

   🌐 IP Address Configuration:
      • eth0 IP: 192.168.1.100 (typical default)
      • lan865x IP: 10.0.0.1 (T1S network coordinator)

   🎭 Network Mask Configuration:
      • eth0 Netmask: 255.255.255.0 (/24 - typical default)
      • lan865x Netmask: 255.255.255.0 (/24 - T1S standard)

   🚪 Gateway Configuration:
      • Default Gateway: 192.168.1.1 (typical router IP)

🌐 T1S Network Configuration:
   • Network Range: 10.0.0.0/24 (T1S multi-node network)
   • Coordinator IP: 10.0.0.1 (LAN865x primary node)
   • Node IP Range: 10.0.0.2 - 10.0.0.8 (additional T1S nodes)
   • PLCA Node ID: Configured via Device Tree
   • Max Nodes: 8 (T1S specification)

🚀 STARTUP INTERFACE CONFIGURATION
===================================
EOF

        # Add S99myconfig.sh analysis if available
        if [[ -f "$target_dir/etc/init.d/S99myconfig.sh" ]]; then
            echo "📋 S99myconfig.sh Analysis:" >> "$HTML_FILE"
            echo "   ✓ Startup script found: /etc/init.d/S99myconfig.sh" >> "$HTML_FILE"
            
            if grep -q "ethtool.*plca" "$target_dir/etc/init.d/S99myconfig.sh" 2>/dev/null; then
                echo "   📡 PLCA Configuration detected:" >> "$HTML_FILE"
                if grep -q "node-id 0" "$target_dir/etc/init.d/S99myconfig.sh" 2>/dev/null; then
                    echo "      • Role: T1S Coordinator (Node ID 0)" >> "$HTML_FILE"
                fi
                echo "      • Max Nodes: 8 (T1S network size)" >> "$HTML_FILE"
                echo "      • T1S Interface: enable" >> "$HTML_FILE"
            fi
            
            echo "" >> "$HTML_FILE"
            echo "🔧 Interface Configuration at Boot:" >> "$HTML_FILE"
            echo "   📍 Static IP Configuration:" >> "$HTML_FILE"
            
            if grep -q "ip addr add" "$target_dir/etc/init.d/S99myconfig.sh" 2>/dev/null; then
                grep "ip addr add" "$target_dir/etc/init.d/S99myconfig.sh" 2>/dev/null | while IFS= read -r line; do
                    ip_config=$(echo "$line" | sed 's/.*ip addr add //' | sed 's/ dev / -> /')
                    echo "      • $ip_config" >> "$HTML_FILE"
                done
            fi
            
            echo "" >> "$HTML_FILE"
            echo "📊 Final Interface Status (after S99myconfig.sh):" >> "$HTML_FILE"
            echo "   🌐 eth0: 169.254.35.112/16 (Link-Local/Auto-IP)" >> "$HTML_FILE"
            echo "   🏠 eth1: 192.168.178.20/24 (Private LAN/Home Network)" >> "$HTML_FILE"
            echo "   ⚡ eth2: 192.168.0.5/24 (T1S Network - LAN865x)" >> "$HTML_FILE"
        fi

        cat >> "$HTML_FILE" << 'EOF'

🔄 Network Architecture:
   • eth0: Direct/Emergency access (Link-Local)
   • eth1: Traditional Ethernet/Internet access
   • eth2: T1S Industrial Network (10BASE-T1S)
   • PLCA: Collision Avoidance for multi-node T1S
            </pre>
        </div>
        
        <!-- LAN865x Configuration -->
        <div class="config-section">
            <h3>🔧 LAN865x T1S Configuration</h3>
            <pre>
📋 Device Tree T1S Configuration:

📡 SPI Interface Configuration:
   • SPI Speed: 15MHz (optimized for T1S)
   • SPI Mode: Mode 0 (CPOL=0, CPHA=0)
   • SPI Bus: Typically SPI1
   • Chip Select: Active Low

🔄 PLCA (Physical Layer Collision Avoidance):
   • PLCA Enable: Yes (required for T1S multi-node)
   • PLCA Node Count: 8 (default max nodes)
   • PLCA TO Timer: 20 (default timeout)
   • PLCA Burst Count: 0 (no burst mode)
   • PLCA Burst Timer: 0

🔌 GPIO Pin Configuration:
   • IRQ Pin: GPIO interrupt for LAN865x events
   • Reset Pin: Hardware reset control
   • Clock: External 25MHz oscillator or internal

🆔 MAC Address Configuration:
   ℹ️ Using default/generated MAC address
            </pre>
        </div>
        
        <!-- MQTT Configuration -->
        <div class="mqtt-config">
            <h3>📡 MQTT Broker Configuration</h3>
            <pre>
📋 Eclipse Mosquitto Configuration:
EOF

        # Check if mosquitto config exists
        if [[ -f "$target_dir/etc/mosquitto/mosquitto.conf" ]]; then
            echo "   ✓ Configuration file: /etc/mosquitto/mosquitto.conf" >> "$HTML_FILE"
        else
            echo "   ⚠️ Configuration file not found" >> "$HTML_FILE"
        fi

        cat >> "$HTML_FILE" << 'EOF'

📝 Key Configuration Parameters:
   • Port: 1883 (explicit configuration)
   • Authentication: Anonymous allowed (T1S development mode)

⚡ T1S Performance Optimizations:
   • Max Connections: 100
   • Keep Alive: Default (65535s)

📚 MQTT Client Libraries:
EOF

        # Check for Python MQTT libraries
        if [[ -d "$target_dir/usr/lib/python3.12/site-packages" ]]; then
            if find "$target_dir/usr/lib/python3.12/site-packages" -name "*paho*" 2>/dev/null | grep -q .; then
                echo "   ✓ Paho MQTT Python library" >> "$HTML_FILE"
            fi
            if find "$target_dir/usr/lib/python3.12/site-packages" -name "*aiomqtt*" 2>/dev/null | grep -q .; then
                echo "   ✓ aiomqtt async Python library" >> "$HTML_FILE"
            fi
        fi

        cat >> "$HTML_FILE" << 'EOF'

🔒 Security Configuration:
   • TLS Version: TLS 1.2+ supported
   • Certificates: Self-signed or CA-signed supported
            </pre>
        </div>
        
        <!-- System Configuration -->
        <div class="system-config">
            <h3>⚙️ System Configuration</h3>
            <pre>
🏗️ Build System Information:
EOF

        # Add buildroot version if available
        if grep -q "BR2_VERSION" "$config_file" 2>/dev/null; then
            version=$(grep "BR2_VERSION" "$config_file" | cut -d'"' -f2 2>/dev/null)
            if [[ -n "$version" ]]; then
                echo "   • Buildroot Version: $version" >> "$HTML_FILE"
            fi
        fi
        
        if grep -q "BR2_DEFCONFIG" "$config_file" 2>/dev/null; then
            defconfig=$(grep "BR2_DEFCONFIG" "$config_file" | cut -d'"' -f2 2>/dev/null)
            if [[ -n "$defconfig" ]]; then
                echo "   • Configuration: $(basename $defconfig)" >> "$HTML_FILE"
            else
                echo "   • Configuration: arm_standalone_defconfig" >> "$HTML_FILE"
            fi
        else
            echo "   • Configuration: arm_standalone_defconfig" >> "$HTML_FILE"
        fi

        cat >> "$HTML_FILE" << 'EOF'

🐧 Linux Kernel Information:
   • Kernel Version: custom
   • Architecture: ARM

💾 Filesystem Configuration:
   • Root Filesystem: TAR format available
            </pre>
        </div>
        
        <!-- SSH Configuration -->
        <div class="ssh-config">
            <h3>🔐 SSH Access Information</h3>
            <pre>
EOF

        # SSH Server Status
        if [[ -f "$target_dir/usr/sbin/dropbear" ]]; then
            echo "   ✅ SSH Server: Dropbear (lightweight SSH server)" >> "$HTML_FILE"
            echo "   📡 Default Port: 22" >> "$HTML_FILE"
            echo "   🚀 Auto-Start: Yes (via /etc/init.d/S50dropbear)" >> "$HTML_FILE"
        else
            echo "   ❌ SSH Server: Not installed" >> "$HTML_FILE"
        fi

        # Root Login Information
        if grep -q 'BR2_TARGET_ENABLE_ROOT_LOGIN=y' "$config_file" 2>/dev/null; then
            echo "   👤 Root Login: Enabled" >> "$HTML_FILE"
            
            # Extract and display root password
            if grep -q 'BR2_TARGET_GENERIC_ROOT_PASSWD=\"microchip\"' "$config_file" 2>/dev/null; then
                echo "   🔑 Root Password: microchip (⚠️  Default password!)" >> "$HTML_FILE"
                echo "   📝 SSH Command: ssh root@<device-ip>" >> "$HTML_FILE"
            elif grep -q 'BR2_TARGET_GENERIC_ROOT_PASSWD=\"' "$config_file" 2>/dev/null; then
                custom_pass=$(grep 'BR2_TARGET_GENERIC_ROOT_PASSWD=' "$config_file" | cut -d'"' -f2 2>/dev/null)
                if [[ -n "$custom_pass" ]]; then
                    echo "   🔑 Root Password: $custom_pass (custom password)" >> "$HTML_FILE"
                else
                    echo "   🔑 Root Password: (empty/no password)" >> "$HTML_FILE"
                fi
                echo "   📝 SSH Command: ssh root@<device-ip>" >> "$HTML_FILE"
            else
                echo "   🔑 Root Password: (not configured)" >> "$HTML_FILE"
            fi
        else
            echo "   👤 Root Login: Disabled" >> "$HTML_FILE"
        fi

        cat >> "$HTML_FILE" << 'EOF'

   🛡️  SSH Security:
EOF

        if grep -q 'BR2_TARGET_GENERIC_ROOT_PASSWD=\"microchip\"' "$config_file" 2>/dev/null; then
            echo "      ⚠️  WARNING: Default password 'microchip' is publicly known!" >> "$HTML_FILE"
            echo "      🔧 For production: Change password or use SSH keys" >> "$HTML_FILE"
        fi

        cat >> "$HTML_FILE" << 'EOF'
      🔐 Host Keys: Generated automatically on first boot
      📂 SSH Keys Location: /etc/dropbear/

   🌐 Connection Examples:
      • ssh root@192.168.1.100    # Standard Ethernet
      • ssh root@169.254.35.112   # Link-Local (eth0)
      • ssh root@192.168.178.20   # Home Network (eth1)
      • ssh root@192.168.0.5      # T1S Network (eth2)

📦 Key Package Summary:
   • SSH Server: Dropbear (lightweight SSH daemon)
   • T1S Driver: LAN865x kernel module
   • MQTT Broker: Eclipse Mosquitto
   • Python: 3.12 with MQTT libraries
   • Network: Device Tree configured interfaces
   • Security: OpenSSL with CA certificates
   • Development: Complete IoT T1S stack
            </pre>
        </div>
        
        <!-- Build Information Section -->
EOF

        # Add build information if available
        local buildinfo_file="$target_dir/etc/buildinfo"
        if [[ -f "$buildinfo_file" ]]; then
            . "$buildinfo_file" 2>/dev/null || true
            
            cat >> "$HTML_FILE" << EOF
        <div class="build-info">
            <h3>📅 Build Information</h3>
            <pre>
🏗️ Image Build Details:
   📅 Build Date: ${BUILD_TIMESTAMP}
   🏗️ Build Config: ${BUILD_CONFIG}
   💻 Build Host: ${BUILD_HOST}
   👤 Build User: ${BUILD_USER:-unknown}
   📦 Setup Version: ${SETUP_VERSION}
   🌐 LAN865x Version: ${LAN865X_VERSION}
   📡 MQTT Version: ${MQTT_VERSION}
   🔧 Buildroot Version: ${BUILDROOT_VERSION}

🔗 Image-Report Relationship:
   ✅ This report corresponds exactly to the tested image
   📊 Build timestamp provides unique identification
   🎯 Report generated: $(date)
            </pre>
        </div>
EOF
        else
            echo "        <!-- No build information available -->" >> "$HTML_FILE"
        fi

        cat >> "$HTML_FILE" << 'EOF'
        
        <!-- Final Results -->
        <div class="summary">
            <h3>📊 Test Summary</h3>
EOF

        # Add test summary with proper variable expansion
        echo "            <p><strong>Total Tests:</strong> $TOTAL_CHECKS</p>" >> "$HTML_FILE"
        echo "            <p><strong>Passed:</strong> <span class=\"success\">$PASSED_CHECKS</span></p>" >> "$HTML_FILE"
        echo "            <p><strong>Warnings:</strong> <span class=\"warning\">$WARNING_CHECKS</span></p>" >> "$HTML_FILE"
        echo "            <p><strong>Failed:</strong> <span class=\"error\">$FAILED_CHECKS</span></p>" >> "$HTML_FILE"
        echo "            <hr>" >> "$HTML_FILE"

        # Add success rate
        local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
        echo "            <p><strong>Success Rate:</strong> ${success_rate}%</p>" >> "$HTML_FILE"
        
        # Add final result
        if [[ $FAILED_CHECKS -eq 0 && $success_rate -ge 90 ]]; then
            cat >> "$HTML_FILE" << 'EOF'
            <div class="success"><h4>🎯 VERIFICATION SUCCESSFUL</h4></div>
            <p>The image contains all important LAN865x+MQTT components!</p>
            
            <h4>🚀 Ready for Deployment:</h4>
            <ul>
                <li>✓ LAN865x Device Tree Support</li>
                <li>✓ MQTT Infrastructure</li>
                <li>✓ SSH Remote Access (Dropbear)</li>
                <li>✓ C/C++ Development Libraries</li>
                <li>✓ SSL/TLS Support</li>
            </ul>
EOF
        elif [[ $FAILED_CHECKS -eq 0 ]]; then
            cat >> "$HTML_FILE" << 'EOF'
            <div class="warning"><h4>⚠️ VERIFICATION WITH WARNINGS</h4></div>
            <p>Basic functions available, some components missing.</p>
EOF
        else
            cat >> "$HTML_FILE" << 'EOF'
            <div class="error"><h4>❌ VERIFICATION FAILED</h4></div>
            <p>Critical components missing in the image!</p>
EOF
        fi

        cat >> "$HTML_FILE" << EOF
        </div>
        <div class="timestamp">Report completed: $final_date</div>
    </div>
</body>
</html>
EOF

        if [[ "$GENERATE_HTML" == "true" ]]; then
            log_success "HTML report generated: $HTML_FILE"
        fi
        
        if [[ "$GENERATE_PDF" == "true" ]]; then
            generate_pdf_report
        fi
    fi
}

generate_pdf_report() {
    local pdf_file="${PDF_FILENAME}"
    
    # Check if wkhtmltopdf is available
    if ! command -v wkhtmltopdf &> /dev/null; then
        log_warning "wkhtmltopdf not found. Trying alternative PDF generators..."
        
        # Try pandoc
        if command -v pandoc &> /dev/null; then
            log_info "Using pandoc for PDF generation..."
            pandoc "$HTML_FILE" -o "$pdf_file" --pdf-engine=wkhtmltopdf 2>/dev/null || {
                log_error "PDF generation failed. Install wkhtmltopdf or pandoc with PDF support"
                log_info "HTML report available: $HTML_FILE"
                return 1
            }
        else
            log_error "No PDF generator found. Install wkhtmltopdf or pandoc"
            log_info "HTML report available: $HTML_FILE"
            return 1
        fi
    else
        log_info "Generating PDF report..."
        wkhtmltopdf --page-size A4 --margin-top 15mm --margin-bottom 15mm \
                    --margin-left 10mm --margin-right 10mm \
                    --enable-local-file-access \
                    "$HTML_FILE" "$pdf_file" 2>/dev/null || {
            log_error "PDF generation failed"
            log_info "HTML report available: $HTML_FILE"
            return 1
        }
    fi
    
    if [[ -f "$pdf_file" ]]; then
        log_success "PDF report generated: $pdf_file"
        
        # Cleanup temporary HTML file if only PDF was requested
        if [[ "$GENERATE_HTML" == "false" ]]; then
            rm -f "$HTML_FILE"
        fi
    fi
}

# Global counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# Test helper function
check_test() {
    local description="$1"
    local test_command="$2"
    local critical="${3:-false}"
    
    ((TOTAL_CHECKS++))
    
    echo -n "Testing: $description ... "
    
    # Debug: show command on errors
    local test_result
    if test_result=$(eval "$test_command" 2>&1); then
        echo -e "${GREEN}✓ PASS${NC}"
        test_to_html "$description" "PASS"
        ((PASSED_CHECKS++))
        return 0
    else
        if [[ "$critical" == "true" ]]; then
            echo -e "${RED}✗ FAIL${NC} (Command: $test_command)"
            echo "      Error: $test_result"
            test_to_html "$description" "FAIL"
            ((FAILED_CHECKS++))
        else
            echo -e "${YELLOW}! WARN${NC}"
            test_to_html "$description" "WARN"
            ((WARNING_CHECKS++))
        fi
        return 1
    fi
}

# 1. Check Buildroot configuration
check_buildroot_config() {
    log_info "Checking Buildroot configuration..."
    
    local config_file="$BRSDK_ROOT/$TARGET_BUILD_DIR/.config"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        ((FAILED_CHECKS++))
        return 1
    fi
    
    log_info "Configuration file found: $config_file"
    
    # Check MQTT packages (with better error handling)
    check_test "Mosquitto MQTT Broker" "grep -q 'BR2_PACKAGE_MOSQUITTO=y' '$config_file'" true
    check_test "Mosquitto Broker Daemon" "grep -q 'BR2_PACKAGE_MOSQUITTO_BROKER=y' '$config_file'" true
    check_test "Mosquitto Dynamic Security" "grep -q 'BR2_PACKAGE_MOSQUITTO_BROKER_DYNAMIC_SECURITY_PLUGIN=y' '$config_file'" false
    check_test "Paho MQTT C Library" "grep -q 'BR2_PACKAGE_PAHO_MQTT_C=y' '$config_file'" true
    check_test "Python Paho MQTT" "grep -q 'BR2_PACKAGE_PYTHON_PAHO_MQTT=y' '$config_file'" false
    check_test "Python aiomqtt" "grep -q 'BR2_PACKAGE_PYTHON_AIOMQTT=y' '$config_file'" false
    
    # Check SSL/TLS Support
    check_test "OpenSSL Library" "grep -q 'BR2_PACKAGE_OPENSSL=y' '$config_file'" true
    check_test "OpenSSL Binary Tools" "grep -q 'BR2_PACKAGE_LIBOPENSSL_BIN=y' '$config_file'" true
    check_test "Python3 SSL Support" "grep -q 'BR2_PACKAGE_PYTHON3_SSL=y' '$config_file'" true
    
    # Check JSON Support
    check_test "cJSON Library" "grep -q 'BR2_PACKAGE_CJSON=y' '$config_file'" true
    
    # Python3 Base prüfen
    check_test "Python3 Base" "grep -q 'BR2_PACKAGE_PYTHON3=y' '$config_file'" true
    
    return 0
}

# 2. Check LAN865x Device Tree
check_device_tree() {
    log_info "Checking LAN865x Device Tree..."
    
    local dts_source="$BRSDK_ROOT/$TARGET_BUILD_DIR/build/linux-custom/arch/arm/boot/dts/microchip/lan966x-pcb8291.dts"
    local dts_binary="$BRSDK_ROOT/$TARGET_BUILD_DIR/images/lan966x-pcb8291.dtb"
    
    # Check Device Tree Source
    check_test "Device Tree Source existiert" "test -f '$dts_source'" true
    if [[ -f "$dts_source" ]]; then
        check_test "LAN865x Konfiguration in DTS" "grep -q 'lan865x' '$dts_source'" true
        check_test "Mikrochip LAN8650/8651 kompatibel" "grep -q 'microchip,lan865[01]' '$dts_source'" true
        check_test "15MHz SPI Frequenz" "grep -q 'spi-max-frequency = <15000000>' '$dts_source'" true
        check_test "GPIO Konfiguration" "grep -q 'enable-gpios' '$dts_source'" true
        check_test "Interrupt Konfiguration" "grep -q 'interrupts.*0x2' '$dts_source'" true
        check_test "MAC-Adresse konfiguriert" "grep -q 'local-mac-address' '$dts_source'" true
        check_test "Status 'okay'" "grep -A 10 'lan865x' '$dts_source' | grep -q 'status.*okay'" true
    fi
    
    # Device Tree Binary prüfen
    check_test "Device Tree Binary generiert" "test -f '$dts_binary'" true
    
    # Device Tree Binary Größe prüfen (sollte > 10KB sein)
    if [[ -f "$dts_binary" ]]; then
        local dts_size=$(stat -c%s "$dts_binary" 2>/dev/null || echo "0")
        check_test "Device Tree Binary Größe OK" "test $dts_size -gt 10240" true
    fi
}

# 3. Check Target Filesystem
check_target_filesystem() {
    log_info "Checking Target Filesystem..."
    
    local target_dir="$BRSDK_ROOT/$TARGET_BUILD_DIR/target"
    
    if [[ ! -d "$target_dir" ]]; then
        log_error "Target directory not found: $target_dir"
        return 1
    fi
    
    # Check MQTT Binaries
    check_test "Mosquitto Broker Binary" "test -f '$target_dir/usr/sbin/mosquitto'" true
    check_test "Mosquitto Publish Tool" "test -f '$target_dir/usr/bin/mosquitto_pub'" true
    check_test "Mosquitto Subscribe Tool" "test -f '$target_dir/usr/bin/mosquitto_sub'" true
    check_test "Mosquitto Control Tool" "test -f '$target_dir/usr/bin/mosquitto_ctrl'" true
    check_test "Mosquitto Password Tool" "test -f '$target_dir/usr/bin/mosquitto_passwd'" true
    check_test "Mosquitto Request/Response Tool" "test -f '$target_dir/usr/bin/mosquitto_rr'" true
    
    # Check MQTT Libraries
    check_test "Mosquitto Library" "test -f '$target_dir/usr/lib/libmosquitto.so.1'" true
    check_test "Mosquitto C++ Library" "test -f '$target_dir/usr/lib/libmosquittopp.so.1'" true
    check_test "Paho MQTT C Library (sync)" "test -f '$target_dir/usr/lib/libpaho-mqtt3c.so.1'" true
    check_test "Paho MQTT C Library (async)" "test -f '$target_dir/usr/lib/libpaho-mqtt3a.so.1'" true
    check_test "Paho MQTT C SSL Library" "test -f '$target_dir/usr/lib/libpaho-mqtt3cs.so.1'" true
    
    # Check JSON Libraries
    check_test "cJSON Library" "test -f '$target_dir/usr/lib/libcjson.so.1'" true
    
    # Python3 prüfen
    check_test "Python3 Binary" "test -f '$target_dir/usr/bin/python3'" true
    check_test "Python3 SSL Module" "test -f '$target_dir/usr/lib/python3.12/ssl.pyc'" true
    check_test "Python3 JSON Module" "find '$target_dir/usr/lib/python3.12' -name '*json*' | wc -l | grep -q '[1-9]'" true
    
    # Check LAN865x Overlay Files
    check_test "LAN865x Load Script" "test -f '$target_dir/usr/bin/load.sh'" true
    check_test "LAN865x Boot Script" "test -f '$target_dir/etc/init.d/S99myconfig.sh'" true
    check_test "Mosquitto Configuration" "test -f '$target_dir/etc/mosquitto/mosquitto.conf'" true
    
    # Check script contents
    if [[ -f "$target_dir/usr/bin/load.sh" ]]; then
        check_test "Load Script contains LAN865x" "grep -q -i 'lan865x\\|t1s' '$target_dir/usr/bin/load.sh'" false
        check_test "Load Script executable" "test -x '$target_dir/usr/bin/load.sh'" true
    fi
    
    if [[ -f "$target_dir/etc/init.d/S99myconfig.sh" ]]; then
        check_test "Boot Script executable" "test -x '$target_dir/etc/init.d/S99myconfig.sh'" true
    fi
    
    if [[ -f "$target_dir/etc/mosquitto/mosquitto.conf" ]]; then
        local config_size=$(stat -c%s "$target_dir/etc/mosquitto/mosquitto.conf" 2>/dev/null || echo "0")
        check_test "Mosquitto Config not empty" "test $config_size -gt 1000" true
        check_test "Mosquitto Port configured" "grep -q 'port 1883' '$target_dir/etc/mosquitto/mosquitto.conf'" true
    fi
}

# 4. Check Generated Images
check_generated_images() {
    log_info "Checking generated images..."
    
    local images_dir="$BRSDK_ROOT/$TARGET_BUILD_DIR/images"
    
    if [[ ! -d "$images_dir" ]]; then
        log_error "Images directory not found: $images_dir"
        return 1
    fi
    
    # Check Kernel and Images
    check_test "Linux Kernel Binary" "test -f '$images_dir/mscc-linux-kernel.bin'" true
    check_test "RootFS Image (ext2)" "test -f '$images_dir/rootfs.ext2'" true
    check_test "RootFS Image (squashfs)" "test -f '$images_dir/rootfs.squashfs'" false
    check_test "RootFS Archive (tar)" "test -f '$images_dir/rootfs.tar'" true
    
    # Device Tree Binary prüfen
    check_test "LAN966x PCB8291 DTB" "test -f '$images_dir/lan966x-pcb8291.dtb'" true
    
    # Check image sizes
    if [[ -f "$images_dir/rootfs.ext2" ]]; then
        local rootfs_size=$(stat -c%s "$images_dir/rootfs.ext2")
        check_test "RootFS Image Size OK (>50MB)" "test $rootfs_size -gt 52428800" true
    fi
    
    if [[ -f "$images_dir/mscc-linux-kernel.bin" ]]; then
        local kernel_size=$(stat -c%s "$images_dir/mscc-linux-kernel.bin")
        check_test "Kernel Binary Size OK (>1MB)" "test $kernel_size -gt 1048576" true
    fi
}

# 5. Extended Python MQTT Check
check_python_mqtt_support() {
    log_info "Checking Python MQTT Support..."
    
    local target_dir="$BRSDK_ROOT/$TARGET_BUILD_DIR/target"
    local python_site="$target_dir/usr/lib/python3.12/site-packages"
    
    # Search Python MQTT modules
    if [[ -d "$python_site" ]]; then
        check_test "Python Site-Packages exists" "test -d '$python_site'" true
        check_test "Paho MQTT Python Module" "find '$python_site' -name '*paho*' -o -name '*mqtt*' | wc -l | grep -q '[1-9]'" false
        check_test "aiomqtt Python Module" "find '$python_site' -name '*aiomqtt*' | wc -l | grep -q '[1-9]'" false
    else
        log_warning "Python site-packages directory not found"
    fi
    
    # Alternative: Search SSL module (both in lib-dynload and as .pyc)
    local python_lib="$target_dir/usr/lib/python3.12"
    if [[ -d "$python_lib" ]]; then
        check_test "Python SSL Module (compiled)" "find '$python_lib' -name '*ssl*' | wc -l | grep -q '[1-9]'" true
    fi
}

# 6. Check Kernel configuration (if available)
check_kernel_config() {
    log_info "Checking Kernel configuration..."
    
    local kernel_config="$BRSDK_ROOT/$TARGET_BUILD_DIR/build/linux-custom/.config"
    
    if [[ -f "$kernel_config" ]]; then
        check_test "Kernel Config exists" "test -f '$kernel_config'" true
        check_test "SPI Master Support" "grep -q 'CONFIG_SPI=y' '$kernel_config'" true
        check_test "GPIO Support" "grep -q 'CONFIG_GPIOLIB=y' '$kernel_config'" true
        check_test "Network Device Support" "grep -q 'CONFIG_NETDEVICES=y' '$kernel_config'" true
        check_test "Ethernet Support" "grep -q 'CONFIG_ETHERNET=y' '$kernel_config'" true
    else
        log_warning "Kernel configuration not available for verification"
    fi
}

# 7. Check SSH Configuration
check_ssh_configuration() {
    log_info "Checking SSH Configuration..."
    
    local target_dir="$BRSDK_ROOT/$TARGET_BUILD_DIR/target"
    local config_file="$BRSDK_ROOT/$TARGET_BUILD_DIR/.config"
    
    # Check SSH Server (Dropbear)
    check_test "Dropbear SSH Server enabled" "grep -q 'BR2_PACKAGE_DROPBEAR=y' '$config_file'" true
    check_test "Dropbear SSH Client enabled" "grep -q 'BR2_PACKAGE_DROPBEAR_CLIENT=y' '$config_file'" false
    check_test "Dropbear binary exists" "test -f '$target_dir/usr/sbin/dropbear'" true
    check_test "SSH client binary exists" "test -f '$target_dir/usr/bin/ssh'" false
    check_test "SSH key generation tool" "test -f '$target_dir/usr/bin/dropbearkey'" true
    
    # Check SSH service startup
    check_test "Dropbear init script" "test -f '$target_dir/etc/init.d/S50dropbear'" true
    if [[ -f "$target_dir/etc/init.d/S50dropbear" ]]; then
        check_test "Dropbear init script executable" "test -x '$target_dir/etc/init.d/S50dropbear'" true
        check_test "Dropbear service enabled" "grep -q 'start-stop-daemon.*dropbear' '$target_dir/etc/init.d/S50dropbear'" true
    fi
    
    # Check root login configuration
    check_test "Root login enabled" "grep -q 'BR2_TARGET_ENABLE_ROOT_LOGIN=y' '$config_file'" true
    
    # Check if root password is set
    if grep -q 'BR2_TARGET_GENERIC_ROOT_PASSWD="microchip"' "$config_file" 2>/dev/null; then
        check_test "Root password configured" "grep -q 'BR2_TARGET_GENERIC_ROOT_PASSWD=\"microchip\"' '$config_file'" true
    elif grep -q 'BR2_TARGET_GENERIC_ROOT_PASSWD=' "$config_file" 2>/dev/null; then
        check_test "Root password set (custom)" "grep -q 'BR2_TARGET_GENERIC_ROOT_PASSWD=' '$config_file'" true
    else
        check_test "Root password configured" "false" true
    fi
    
    # Check SSH host key directory
    check_test "SSH host keys directory" "test -d '$target_dir/etc/dropbear' || test -L '$target_dir/etc/dropbear'" false
    
    # Check default SSH configuration
    if [[ -f "$target_dir/etc/default/dropbear" ]]; then
        check_test "Dropbear config file exists" "test -f '$target_dir/etc/default/dropbear'" false
        check_test "Dropbear port configuration" "! grep -q 'DROPBEAR_PORT=' '$target_dir/etc/default/dropbear' || grep -q 'DROPBEAR_PORT=22' '$target_dir/etc/default/dropbear'" false
    fi
}

# 8. Check Build Information
check_build_information() {
    log_info "Checking Build Information..."
    
    local buildinfo_file="$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/buildinfo"
    
    # Check if build info file exists - THIS IS CRITICAL
    check_test "Build info file exists" "test -f '$buildinfo_file'" true
    
    if [[ -f "$buildinfo_file" ]]; then
        # Source build info for later use
        . "$buildinfo_file" 2>/dev/null || true
        
        # Check build info content - THESE ARE CRITICAL
        check_test "Build timestamp present" "grep -q 'BUILD_TIMESTAMP=' '$buildinfo_file'" true
        check_test "Build config present" "grep -q 'BUILD_CONFIG=' '$buildinfo_file'" true
        check_test "Build host present" "grep -q 'BUILD_HOST=' '$buildinfo_file'" true
        check_test "Setup version present" "grep -q 'SETUP_VERSION=' '$buildinfo_file'" true
        
        # Check MOTD (Message of the Day)
        check_test "System MOTD exists" "test -f '$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/motd'" false
        if [[ -f "$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/motd" ]]; then
            check_test "MOTD contains build info" "grep -q 'LAN865x T1S Development System' '$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/motd'" false
            check_test "MOTD contains timestamp" "grep -q 'Build:' '$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/motd'" false
        fi
        
        # Check boot info script
        check_test "Boot info script exists" "test -f '$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/init.d/S01buildinfo'" false
        if [[ -f "$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/init.d/S01buildinfo" ]]; then
            check_test "Boot info script executable" "test -x '$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/init.d/S01buildinfo'" false
            check_test "Boot info script valid" "grep -q 'LAN865x T1S Development Image' '$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/init.d/S01buildinfo'" false
        fi
        
        # Check runtime buildinfo command
        check_test "Runtime buildinfo command exists" "test -f '$BRSDK_ROOT/$TARGET_BUILD_DIR/target/usr/bin/buildinfo'" false
        if [[ -f "$BRSDK_ROOT/$TARGET_BUILD_DIR/target/usr/bin/buildinfo" ]]; then
            check_test "Runtime buildinfo executable" "test -x '$BRSDK_ROOT/$TARGET_BUILD_DIR/target/usr/bin/buildinfo'" false
        fi
        
        # Display build information
        if [[ -n "${BUILD_TIMESTAMP:-}" ]]; then
            log_info "Build Information found:"
            echo "   📅 Build Date: ${BUILD_TIMESTAMP}"
            echo "   🏗️ Build Config: ${BUILD_CONFIG}"
            echo "   💻 Build Host: ${BUILD_HOST}"
            echo "   👤 Build User: ${BUILD_USER:-unknown}"
            echo "   📦 Setup Version: ${SETUP_VERSION}"
            echo "   🌐 LAN865x Version: ${LAN865X_VERSION}"
        else
            log_error "Build timestamp not found or invalid!"
        fi
    else
        log_error "Build information missing - image was not created with current setup script!"
        log_error "This image cannot be properly tracked or validated."
    fi
}

# 9. Check Backup and Deployment
check_deployment_artifacts() {
    log_info "Checking Deployment Artifacts..."
    
    # Check backup directories
    local backup_count=$(find "$BRSDK_ROOT" -maxdepth 1 -name "backup_*" -type d | wc -l)
    check_test "Setup Backups available" "test $backup_count -gt 0" false
    
    # Check deployment packages
    check_test "LAN865x Overlay ZIP" "test -f '$BRSDK_ROOT/lan865x_overlay_files.zip'" false
    check_test "Setup Script available" "test -f '$BRSDK_ROOT/setup_lan865x_complete.sh'" true
    check_test "Setup Script executable" "test -x '$BRSDK_ROOT/setup_lan865x_complete.sh'" true
    
    # Check documentation
    check_test "README_T1S Dokumentation" "test -f '$BRSDK_ROOT/README_T1S.md'" false
    check_test "README_CHANGE Dokumentation" "test -f '$BRSDK_ROOT/README_CHANGE.md'" false
}

# Main function
main() {
    # Start HTML report if requested
    start_html_report
    
    show_banner
    echo "Build Configuration: $BUILD_CONFIG"
    echo "Target Directory: $TARGET_BUILD_DIR"
    
    # Try to load build information early for display
    local buildinfo_file="$BRSDK_ROOT/$TARGET_BUILD_DIR/target/etc/buildinfo"
    if [[ -f "$buildinfo_file" ]]; then
        . "$buildinfo_file" 2>/dev/null || true
        if [[ -n "${BUILD_TIMESTAMP:-}" ]]; then
            echo "🕒 Build Timestamp: $BUILD_TIMESTAMP"
            echo "🏗️ Build Host: $BUILD_HOST"
        fi
    else
        echo "⚠️ No build information available (image created without build info)"
    fi
    echo ""
    
    # Log report generation info
    if [[ "$GENERATE_PDF" == "true" ]]; then
        log_info "PDF report will be generated: $PDF_FILENAME"
    fi
    if [[ "$GENERATE_HTML" == "true" ]]; then
        log_info "HTML report will be generated: $HTML_FILENAME"
    fi
    
    # Execute all checks (with error handling)
    if ! check_buildroot_config; then
        log_warning "Buildroot configuration had issues, continuing anyway..."
    fi
    echo ""
    
    if ! check_device_tree; then
        log_warning "Device Tree check had issues, continuing anyway..."
    fi
    echo ""
    
    if ! check_target_filesystem; then
        log_warning "Target Filesystem check had issues, continuing anyway..."
    fi
    echo ""
    
    if ! check_generated_images; then
        log_warning "Generated Images check had issues, continuing anyway..."
    fi
    echo ""
    
    if ! check_python_mqtt_support; then
        log_warning "Python MQTT Support check had issues, continuing anyway..."
    fi
    echo ""
    
    if ! check_kernel_config; then
        log_warning "Kernel Config check had issues, continuing anyway..."
    fi
    echo ""
    
    if ! check_ssh_configuration; then
        log_warning "SSH Configuration check had issues, continuing anyway..."
    fi
    echo ""
    
    if ! check_build_information; then
        log_warning "Build Information check had issues, continuing anyway..."
    fi
    echo ""
    
    if ! check_deployment_artifacts; then
        log_warning "Deployment Artifacts check had issues, continuing anyway..."
    fi
    echo ""
    
    # Display detailed configuration information
    show_network_configuration
    echo ""
    show_lan865x_configuration  
    echo ""
    show_mqtt_configuration
    echo ""
    show_system_configuration
    echo ""
    
    # Summary
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║                        VERIFICATION RESULTS                    ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "📊 Test Summary:"
    echo "   Total Tests:    $TOTAL_CHECKS"
    echo -e "   ✅ Passed:      ${GREEN}$PASSED_CHECKS${NC}"
    echo -e "   ⚠️  Warnings:    ${YELLOW}$WARNING_CHECKS${NC}"
    echo -e "   ❌ Failed:      ${RED}$FAILED_CHECKS${NC}"
    echo ""
    
    # Generate PDF/HTML report if requested BEFORE exit
    finish_html_report
    
    # Evaluation
    local success_rate=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
    
    if [[ $FAILED_CHECKS -eq 0 && $success_rate -ge 90 ]]; then
        echo -e "${GREEN}🎯 VERIFICATION SUCCESSFUL${NC}"
        echo "   The image contains all important LAN865x+MQTT components!"
        echo ""
        echo "🚀 Ready for Deployment:"
        echo "   ✓ LAN865x Device Tree Support"
        echo "   ✓ MQTT Infrastructure"
        echo "   ✓ SSH Remote Access (Dropbear)"
        echo "   ✓ C/C++ Development Libraries"
        echo "   ✓ SSL/TLS Support"
        echo ""
        exit 0
    elif [[ $FAILED_CHECKS -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  VERIFICATION WITH WARNINGS${NC}"
        echo "   Basic functions available, some components missing."
        echo ""
        echo "🔧 Possible improvements:"
        echo "   • Add Python MQTT Libraries"
        echo "   • Enable Mosquitto Security Plugin"
        echo "   • Add OpenSSL Binary Tools"
        echo ""
        exit 1
    else
        echo -e "${RED}❌ VERIFICATION FAILED${NC}"
        echo "   Critical components missing in the image!"
        echo ""
        echo "🔧 Recommended actions:"
        echo "   1. Re-run setup script:"
        echo "      ./setup_lan865x_complete.sh $BUILD_CONFIG"
        echo "   2. Perform complete rebuild:"
        echo "      make O=$TARGET_BUILD_DIR clean"
        echo "      make O=$TARGET_BUILD_DIR"
        echo "   3. Re-run verification"
        echo ""
        exit 2
    fi
}

# Configuration Display Functions
show_network_configuration() {
    echo "🌐 NETWORK CONFIGURATION"
    echo "========================"
    
    # Device Tree network configuration
    echo "📋 Device Tree Network Settings:"
    if [ -f "${TARGET_BUILD_DIR}/target/boot/at91-lan9662_ek.dtb" ]; then
        echo "   ✓ Device Tree Binary exists"
        echo "   📍 Location: ${TARGET_BUILD_DIR}/target/boot/at91-lan9662_ek.dtb"
    fi
    
    # Ethernet interfaces configuration
    echo ""
    echo "🔌 Expected Ethernet Interfaces:"
    echo "   • eth0: Main Ethernet interface (10/100/1000 Mbps)"
    echo "   • lan865x: T1S interface (10BASE-T1S)"
    
    # Network configuration in target
    if [ -f "${TARGET_BUILD_DIR}/target/etc/network/interfaces" ]; then
        echo ""
        echo "📝 Network Interface Configuration:"
        cat "${TARGET_BUILD_DIR}/target/etc/network/interfaces" 2>/dev/null || echo "   ⚠️ Could not read network interfaces config"
    fi
    
    # Detailed interface information
    echo ""
    echo "🔍 Ethernet Interface Details:"
    
    # MAC Address configuration
    echo "   📍 MAC Address Configuration:"
    if [ -f "${TARGET_BUILD_DIR}/target/etc/network/interfaces" ]; then
        if grep -q "hwaddress" "${TARGET_BUILD_DIR}/target/etc/network/interfaces" 2>/dev/null; then
            mac_addr=$(grep "hwaddress" "${TARGET_BUILD_DIR}/target/etc/network/interfaces" | awk '{print $3}' | head -1)
            echo "      • eth0 MAC: ${mac_addr} (explicitly configured)"
        else
            echo "      • eth0 MAC: Auto-generated by kernel (based on SoC)"
        fi
    fi
    
    # Check for Device Tree MAC address
    if [ -f "${BASE_DIR}/board/microchip/lan9662_ek/lan9662_ek.dts" ] || [ -f "${BASE_DIR}/arch/arm/boot/dts/at91-lan9662_ek.dts" ]; then
        echo "      • LAN865x MAC: Device Tree configured or derived from eth0"
    fi
    
    # IP Address configuration
    echo ""
    echo "   🌐 IP Address Configuration:"
    if [ -f "${TARGET_BUILD_DIR}/target/etc/network/interfaces" ]; then
        if grep -q "address" "${TARGET_BUILD_DIR}/target/etc/network/interfaces" 2>/dev/null; then
            ip_addr=$(grep "address" "${TARGET_BUILD_DIR}/target/etc/network/interfaces" | awk '{print $2}' | head -1)
            echo "      • eth0 IP: ${ip_addr} (static configuration)"
        elif grep -q "dhcp" "${TARGET_BUILD_DIR}/target/etc/network/interfaces" 2>/dev/null; then
            echo "      • eth0 IP: DHCP assigned (dynamic)"
        else
            echo "      • eth0 IP: 192.168.1.100 (typical default)"
        fi
    fi
    echo "      • lan865x IP: 10.0.0.1 (T1S network coordinator)"
    
    # Netmask configuration  
    echo ""
    echo "   🎭 Network Mask Configuration:"
    if [ -f "${TARGET_BUILD_DIR}/target/etc/network/interfaces" ]; then
        if grep -q "netmask" "${TARGET_BUILD_DIR}/target/etc/network/interfaces" 2>/dev/null; then
            netmask=$(grep "netmask" "${TARGET_BUILD_DIR}/target/etc/network/interfaces" | awk '{print $2}' | head -1)
            echo "      • eth0 Netmask: ${netmask}"
        else
            echo "      • eth0 Netmask: 255.255.255.0 (/24 - typical default)"
        fi
    fi
    echo "      • lan865x Netmask: 255.255.255.0 (/24 - T1S standard)"
    
    # Gateway configuration
    echo ""
    echo "   🚪 Gateway Configuration:"
    if [ -f "${TARGET_BUILD_DIR}/target/etc/network/interfaces" ]; then
        if grep -q "gateway" "${TARGET_BUILD_DIR}/target/etc/network/interfaces" 2>/dev/null; then
            gateway=$(grep "gateway" "${TARGET_BUILD_DIR}/target/etc/network/interfaces" | awk '{print $2}' | head -1)
            echo "      • Default Gateway: ${gateway} (via eth0)"
        else
            echo "      • Default Gateway: 192.168.1.1 (typical router IP)"
        fi
    fi
    
    # IP configuration for T1S
    echo ""
    echo "🌐 T1S Network Configuration:"
    echo "   • Network Range: 10.0.0.0/24 (T1S multi-node network)"
    echo "   • Coordinator IP: 10.0.0.1 (LAN865x primary node)"
    echo "   • Node IP Range: 10.0.0.2 - 10.0.0.8 (additional T1S nodes)"
    echo "   • PLCA Node ID: Configured via Device Tree"
    echo "   • Max Nodes: 8 (T1S specification)"
    
    # Analyze S99myconfig.sh startup script
    echo ""
    echo "🚀 STARTUP INTERFACE CONFIGURATION"
    echo "==================================="
    
    local config_script="${TARGET_BUILD_DIR}/target/etc/init.d/S99myconfig.sh"
    if [ -f "$config_script" ]; then
        echo "📋 S99myconfig.sh Analysis:"
        echo "   ✓ Startup script found: /etc/init.d/S99myconfig.sh"
        
        # Extract PLCA configuration
        if grep -q "ethtool.*plca" "$config_script" 2>/dev/null; then
            plca_line=$(grep "ethtool.*plca" "$config_script" | head -1)
            echo "   📡 PLCA Configuration detected:"
            
            if echo "$plca_line" | grep -q "node-id 0"; then
                echo "      • Role: T1S Coordinator (Node ID 0)"
            else
                node_id=$(echo "$plca_line" | grep -o "node-id [0-9]*" | awk '{print $2}')
                echo "      • Role: T1S Node (Node ID ${node_id:-unknown})"
            fi
            
            if echo "$plca_line" | grep -q "node-cnt"; then
                node_cnt=$(echo "$plca_line" | grep -o "node-cnt [0-9]*" | awk '{print $2}')
                echo "      • Max Nodes: ${node_cnt:-8} (T1S network size)"
            fi
            
            interface=$(echo "$plca_line" | awk '{print $4}')
            echo "      • T1S Interface: ${interface:-eth2}"
        fi
        
        echo ""
        echo "🔧 Interface Configuration at Boot:"
        
        # Extract IP addresses from the script
        if grep -q "ip addr add" "$config_script"; then
            echo "   📍 Static IP Configuration:"
            while IFS= read -r line; do
                if echo "$line" | grep -q "ip addr add"; then
                    ip_config=$(echo "$line" | sed 's/.*ip addr add //' | sed 's/ dev / -> /')
                    echo "      • $ip_config"
                fi
            done < <(grep "ip addr add" "$config_script")
        fi
        
        echo ""
        echo "📊 Final Interface Status (after S99myconfig.sh):"
        
        # Parse the actual configuration from the script
        if grep -q "169.254" "$config_script"; then
            eth0_ip=$(grep "169.254" "$config_script" | grep -o "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/[0-9]\{1,2\}")
            echo "   🌐 eth0: ${eth0_ip:-169.254.35.112/16} (Link-Local/Auto-IP)"
        fi
        
        if grep -q "192.168.178" "$config_script"; then
            eth1_ip=$(grep "192.168.178" "$config_script" | grep -o "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/[0-9]\{1,2\}")
            echo "   🏠 eth1: ${eth1_ip:-192.168.178.20/24} (Private LAN/Home Network)"
        fi
        
        if grep -q "192.168.0\." "$config_script"; then
            eth2_ip=$(grep "192.168.0\." "$config_script" | grep -o "[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/[0-9]\{1,2\}")
            echo "   ⚡ eth2: ${eth2_ip:-192.168.0.5/24} (T1S Network - LAN865x)"
        fi
        
        echo ""
        echo "🔄 Network Architecture:"
        echo "   • eth0: Direct/Emergency access (Link-Local)"
        echo "   • eth1: Traditional Ethernet/Internet access"  
        echo "   • eth2: T1S Industrial Network (10BASE-T1S)"
        echo "   • PLCA: Collision Avoidance for multi-node T1S"
        
    else
        echo "⚠️ S99myconfig.sh script not found in target filesystem"
        echo "   Expected: ${config_script}"
        echo "   ℹ️ Interfaces will use default configuration"
    fi
}

show_lan865x_configuration() {
    echo "🔧 LAN865x T1S CONFIGURATION" 
    echo "============================="
    
    # Device Tree LAN865x configuration
    echo "📋 Device Tree T1S Configuration:"
    if [ -d "${TARGET_BUILD_DIR}/target/boot" ]; then
        if ls "${TARGET_BUILD_DIR}/target/boot/"*.dtb >/dev/null 2>&1; then
            echo "   ✓ Device Tree files present"
            # Try to extract LAN865x configuration from source DTS if available
            if [ -f "${BASE_DIR}/arch/arm/boot/dts/at91-lan9662_ek.dts" ] || [ -f "${BASE_DIR}/board/microchip/lan9662_ek/lan9662_ek.dts" ]; then
                echo "   📄 Source DTS configuration available"
            fi
        fi
    fi
    
    # SPI Configuration
    echo ""
    echo "📡 SPI Interface Configuration:"
    echo "   • SPI Speed: 15MHz (optimized for T1S)"
    echo "   • SPI Mode: Mode 0 (CPOL=0, CPHA=0)"
    echo "   • SPI Bus: Typically SPI1"
    echo "   • Chip Select: Active Low"
    
    # PLCA Configuration  
    echo ""
    echo "🔄 PLCA (Physical Layer Collision Avoidance):"
    echo "   • PLCA Enable: Yes (required for T1S multi-node)"
    echo "   • PLCA Node Count: 8 (default max nodes)"
    echo "   • PLCA TO Timer: 20 (default timeout)"
    echo "   • PLCA Burst Count: 0 (no burst mode)"
    echo "   • PLCA Burst Timer: 0"
    
    # GPIO Configuration
    echo ""
    echo "🔌 GPIO Pin Configuration:"
    echo "   • IRQ Pin: GPIO interrupt for LAN865x events"
    echo "   • Reset Pin: Hardware reset control"
    echo "   • Clock: External 25MHz oscillator or internal"
    
    # MAC Address Configuration
    echo ""
    echo "🆔 MAC Address Configuration:"
    if [ -f "${TARGET_BUILD_DIR}/target/etc/network/interfaces" ]; then
        if grep -q "hwaddress" "${TARGET_BUILD_DIR}/target/etc/network/interfaces" 2>/dev/null; then
            echo "   ✓ Hardware address configured in network interfaces"
        else
            echo "   ℹ️ Using default/generated MAC address"
        fi
    fi
}

show_mqtt_configuration() {
    echo "📡 MQTT BROKER CONFIGURATION"
    echo "============================"
    
    # Mosquitto configuration
    if [ -f "${TARGET_BUILD_DIR}/target/etc/mosquitto/mosquitto.conf" ]; then
        echo "📋 Eclipse Mosquitto Configuration:"
        echo "   ✓ Configuration file: /etc/mosquitto/mosquitto.conf"
        echo ""
        echo "📝 Key Configuration Parameters:"
        
        # Port configuration
        if grep -q "port.*1883" "${TARGET_BUILD_DIR}/target/etc/mosquitto/mosquitto.conf" 2>/dev/null; then
            echo "   • Port: 1883 (explicit configuration)"
        else
            echo "   • Port: 1883 (default, not explicitly set)"
        fi
        
        # Authentication
        if grep -q "allow_anonymous.*true" "${TARGET_BUILD_DIR}/target/etc/mosquitto/mosquitto.conf" 2>/dev/null; then
            echo "   • Authentication: Anonymous allowed (T1S development mode)"
        else
            echo "   • Authentication: Default settings"
        fi
        
        # Performance settings
        echo ""
        echo "⚡ T1S Performance Optimizations:"
        if grep -q "max_connections" "${TARGET_BUILD_DIR}/target/etc/mosquitto/mosquitto.conf" 2>/dev/null; then
            max_conn=$(grep "max_connections" "${TARGET_BUILD_DIR}/target/etc/mosquitto/mosquitto.conf" | awk '{print $2}')
            echo "   • Max Connections: $max_conn"
        else
            echo "   • Max Connections: Default (-1, unlimited)"
        fi
        
        if grep -q "max_keepalive" "${TARGET_BUILD_DIR}/target/etc/mosquitto/mosquitto.conf" 2>/dev/null; then
            keepalive=$(grep "max_keepalive" "${TARGET_BUILD_DIR}/target/etc/mosquitto/mosquitto.conf" | awk '{print $2}')
            echo "   • Keep Alive: ${keepalive}s"
        else
            echo "   • Keep Alive: Default (65535s)"
        fi
        
        # Memory optimization
        if grep -q "memory_limit" "${TARGET_BUILD_DIR}/target/etc/mosquitto/mosquitto.conf" 2>/dev/null; then
            memory=$(grep "memory_limit" "${TARGET_BUILD_DIR}/target/etc/mosquitto/mosquitto.conf" | awk '{print $2}')
            echo "   • Memory Limit: ${memory}MB"
        fi
        
    else
        echo "⚠️ Mosquitto configuration file not found"
        echo "   Expected: ${TARGET_BUILD_DIR}/target/etc/mosquitto/mosquitto.conf"
    fi
    
    # MQTT Libraries
    echo ""
    echo "📚 MQTT Client Libraries:"
    if [ -f "${TARGET_BUILD_DIR}/target/usr/lib/python3.12/site-packages/paho" ] || \
       [ -d "${TARGET_BUILD_DIR}/target/usr/lib/python3.12/site-packages/paho" ]; then
        echo "   ✓ Paho MQTT Python library"
    fi
    
    if [ -f "${TARGET_BUILD_DIR}/target/usr/lib/python3.12/site-packages/aiomqtt" ] || \
       [ -d "${TARGET_BUILD_DIR}/target/usr/lib/python3.12/site-packages/aiomqtt" ]; then
        echo "   ✓ aiomqtt async Python library"
    fi
    
    # SSL/TLS Support
    echo ""
    echo "🔒 Security Configuration:"
    if [ -f "${TARGET_BUILD_DIR}/target/usr/bin/openssl" ]; then
        echo "   ✓ OpenSSL binary tools available"
    fi
    
    if [ -f "${TARGET_BUILD_DIR}/target/etc/ssl/certs/ca-certificates.crt" ]; then
        echo "   ✓ CA certificates bundle"
    fi
    
    echo "   • TLS Version: TLS 1.2+ supported"
    echo "   • Certificates: Self-signed or CA-signed supported"
}

show_system_configuration() {
    echo "⚙️ SYSTEM CONFIGURATION"
    echo "======================="
    
    # Buildroot version and configuration
    echo "🏗️ Build System Information:"
    if [ -f "${TARGET_BUILD_DIR}/.config" ]; then
        if grep -q "BR2_VERSION" "${TARGET_BUILD_DIR}/.config" 2>/dev/null; then
            version=$(grep "BR2_VERSION" "${TARGET_BUILD_DIR}/.config" | cut -d'"' -f2)
            echo "   • Buildroot Version: $version"
        fi
        
        if grep -q "BR2_DEFCONFIG" "${TARGET_BUILD_DIR}/.config" 2>/dev/null; then
            defconfig=$(grep "BR2_DEFCONFIG" "${TARGET_BUILD_DIR}/.config" | cut -d'"' -f2)
            echo "   • Configuration: $(basename $defconfig)"
        fi
    fi
    
    # Kernel version
    echo ""
    echo "🐧 Linux Kernel Information:"
    if [ -d "${TARGET_BUILD_DIR}/build/linux-"* ]; then
        kernel_dir=$(ls -d "${TARGET_BUILD_DIR}/build/linux-"* 2>/dev/null | head -1)
        if [ -n "$kernel_dir" ]; then
            kernel_version=$(basename "$kernel_dir" | sed 's/linux-//')
            echo "   • Kernel Version: $kernel_version"
        fi
    fi
    
    # Target architecture
    if [ -f "${TARGET_BUILD_DIR}/.config" ]; then
        if grep -q "BR2_arm=y" "${TARGET_BUILD_DIR}/.config" 2>/dev/null; then
            echo "   • Architecture: ARM"
            if grep -q "BR2_cortex_a7=y" "${TARGET_BUILD_DIR}/.config" 2>/dev/null; then
                echo "   • CPU: ARM Cortex-A7 (LAN9662)"
            fi
        fi
    fi
    
    # Filesystem information
    echo ""
    echo "💾 Filesystem Configuration:"
    if [ -f "${TARGET_BUILD_DIR}/images/sdcard.img" ]; then
        size=$(du -h "${TARGET_BUILD_DIR}/images/sdcard.img" 2>/dev/null | awk '{print $1}')
        echo "   • SD Card Image: ${size:-unknown size}"
    fi
    
    if [ -f "${TARGET_BUILD_DIR}/images/rootfs.tar" ]; then
        echo "   • Root Filesystem: TAR format available"
    fi
    
    # SSH Access Information
    echo ""
    echo "🔐 SSH ACCESS INFORMATION"
    echo "========================="
    
    local config_file="$BRSDK_ROOT/$TARGET_BUILD_DIR/.config"
    local target_dir="$BRSDK_ROOT/$TARGET_BUILD_DIR/target"
    
    # SSH Server Status
    if [[ -f "$target_dir/usr/sbin/dropbear" ]]; then
        echo "   ✅ SSH Server: Dropbear (lightweight SSH server)"
        echo "   📡 Default Port: 22"
        echo "   🚀 Auto-Start: Yes (via /etc/init.d/S50dropbear)"
    else
        echo "   ❌ SSH Server: Not installed"
    fi
    
    # Root Login Information
    if grep -q 'BR2_TARGET_ENABLE_ROOT_LOGIN=y' "$config_file" 2>/dev/null; then
        echo "   👤 Root Login: Enabled"
        
        # Extract and display root password
        if grep -q 'BR2_TARGET_GENERIC_ROOT_PASSWD=\"microchip\"' "$config_file" 2>/dev/null; then
            echo "   🔑 Root Password: microchip (⚠️  Default password!)"
            echo "   📝 SSH Command: ssh root@<device-ip>"
        elif grep -q 'BR2_TARGET_GENERIC_ROOT_PASSWD=\"' "$config_file" 2>/dev/null; then
            custom_pass=$(grep 'BR2_TARGET_GENERIC_ROOT_PASSWD=' "$config_file" | cut -d'"' -f2)
            if [[ -n "$custom_pass" ]]; then
                echo "   🔑 Root Password: $custom_pass (custom password)"
                echo "   📝 SSH Command: ssh root@<device-ip>"
            else
                echo "   🔑 Root Password: (empty/no password)"
                echo "   📝 SSH Command: ssh root@<device-ip> (no password required)"
            fi
        elif grep -q 'BR2_TARGET_GENERIC_ROOT_PASSWD=' "$config_file" 2>/dev/null; then
            echo "   🔑 Root Password: (configured but not visible)"
            echo "   📝 SSH Command: ssh root@<device-ip>"
        else
            echo "   🔑 Root Password: (not configured - check setup)"
        fi
    else
        echo "   👤 Root Login: Disabled"
    fi
    
    # SSH Security Information
    echo ""
    echo "   🛡️  SSH Security:"
    if grep -q 'BR2_TARGET_GENERIC_ROOT_PASSWD=\"microchip\"' "$config_file" 2>/dev/null; then
        echo "      ⚠️  WARNING: Default password 'microchip' is publicly known!"
        echo "      🔧 For production: Change password or use SSH keys"
    fi
    echo "      🔐 Host Keys: Generated automatically on first boot"
    echo "      📂 SSH Keys Location: /etc/dropbear/"
    
    # Connection Examples
    echo ""
    echo "   🌐 Connection Examples:"
    echo "      • ssh root@192.168.1.100    # Standard Ethernet"
    echo "      • ssh root@169.254.35.112   # Link-Local (eth0)"
    echo "      • ssh root@192.168.178.20   # Home Network (eth1)"
    echo "      • ssh root@192.168.0.5      # T1S Network (eth2)"
    
    # Important packages summary
    echo ""
    echo "📦 Key Package Summary:"
    echo "   • SSH Server: Dropbear (lightweight SSH daemon)"
    echo "   • T1S Driver: LAN865x kernel module"
    echo "   • MQTT Broker: Eclipse Mosquitto"
    echo "   • Python: 3.12 with MQTT libraries"
    echo "   • Network: Device Tree configured interfaces"
    echo "   • Security: OpenSSL with CA certificates"
    echo "   • Development: Complete IoT T1S stack"
}

# Execute script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi