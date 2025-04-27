#!/bin/bash

# Script: Advanced System Identity Modifier for Linux in VMware
# Description: A tool for modifying system identifiers, MAC address, hostname, and cleaning artifacts
# Notes: Requires root privileges and is designed for VMware environments
# Warning: May violate some software EULAs, use with caution

# Define variables
BACKUP_DIR="$HOME/system_backup_$(date +%Y%m%d_%H%M%S)"
CHANGES_MADE=false
LOG_FILE="/var/log/system_modifier.log"

# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
    echo "[!] ERROR: This script must be run as root!"
    exit 1
fi

# Check for required tools
command -v dmidecode >/dev/null 2>&1 || { echo "[!] dmidecode is required. Install it using 'apt install dmidecode'."; exit 1; }
command -v virt-what >/dev/null 2>&1 || { echo "[!] virt-what is required. Install it using 'apt install virt-what'."; exit 1; }
command -v ip >/dev/null 2>&1 || { echo "[!] ip command is required."; exit 1; }
command -v hostnamectl >/dev/null 2>&1 || { echo "[!] hostnamectl is required."; exit 1; }

# Verify the system is running in VMware (optional warning)
if ! virt-what | grep -q "vmware"; then
    echo "[!] WARNING: This script is designed for VMware environments. Proceed with caution."
fi

# Function to generate plausible values
get_plausible_value() {
    local type=$1
    case $type in
        "manufacturer")
            local vendors=("Dell Inc." "HP" "LENOVO" "ASUS" "American Megatrends Inc.")
            echo "${vendors[$RANDOM % ${#vendors[@]}]}"
            ;;
        "product_name")
            echo "System-$((RANDOM % 9000 + 1000))"
            ;;
        "mac")
            local prefixes=("00:15:5D" "00:50:56" "00:0C:29" "00:1C:42" "00:1D:0F")
            local prefix=${prefixes[$RANDOM % ${#prefixes[@]}]}
            local suffix=$(printf "%02X:%02X:%02X" $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
            echo "$prefix:$suffix"
            ;;
        "hostname")
            local prefixes=("WS" "PC" "LAP" "SRV" "DEV")
            echo "${prefixes[$RANDOM % ${#prefixes[@]}]}-$((RANDOM % 9000 + 1000))"
            ;;
        *)
            echo "UNKNOWN"
            ;;
    esac
}

# Function to backup system state
backup_system_state() {
    echo "[+] Creating system backup..."
    
    mkdir -p "$BACKUP_DIR" || { echo "[!] Failed to create backup directory"; return 1; }

    # Backup DMI information
    dmidecode > "$BACKUP_DIR/dmidecode.txt" 2>/dev/null
    # Backup network configuration
    ip a > "$BACKUP_DIR/ip_addr.txt" 2>/dev/null
    ip link > "$BACKUP_DIR/ip_link.txt" 2>/dev/null
    # Backup hostname
    hostnamectl > "$BACKUP_DIR/hostname.txt" 2>/dev/null
    # Backup system info
    uname -a > "$BACKUP_DIR/uname.txt" 2>/dev/null
    cat /etc/os-release > "$BACKUP_DIR/os_release.txt" 2>/dev/null

    echo "[√] Backup saved to: $BACKUP_DIR"
}

# Function to modify hardware IDs (mock DMI for testing)
update_hardware_ids() {
    local automatic=$1
    local custom_manufacturer=$2
    local custom_product_name=$3
    
    echo "[+] Modifying hardware identifiers..."
    
    if [[ "$automatic" == "true" ]]; then
        manufacturer=$(get_plausible_value "manufacturer")
        product_name=$(get_plausible_value "product_name")
    else
        manufacturer="$custom_manufacturer"
        product_name="$custom_product_name"
    fi

    # In VMware, DMI modifications are read-only. Mock changes in a test file for demonstration.
    local mock_dir="/tmp/mock_dmi"
    mkdir -p "$mock_dir" || { echo "[!] Failed to create mock directory"; return 1; }
    
    echo "Manufacturer: $manufacturer" > "$mock_dir/system_info"
    echo "Product Name: $product_name" >> "$mock_dir/system_info"
    
    echo "  [→] Mocked System Manufacturer to '$manufacturer'"
    echo "  [→] Mocked System Product Name to '$product_name'"
    CHANGES_MADE=true

    # Note: Real DMI modification requires kernel modules or VMware configuration changes.
    echo "  [!] Note: Real DMI changes are restricted in VMware. Mock data saved to $mock_dir."
}

# Function to update network configuration
update_network_configuration() {
    local change_mac=$1
    local change_ip=$2
    
    echo "[+] Updating network configuration..."
    
    # Get Ethernet interfaces (e.g., eth0, ens33)
    local interfaces=$(ip link | grep -E '^[0-9]+: e' | awk '{print $2}' | tr -d ':')
    if [[ -z "$interfaces" ]]; then
        echo "[!] No Ethernet interfaces found."
        return 1
    fi

    for iface in $interfaces; do
        if [[ "$change_mac" == "true" ]]; then
            local new_mac=$(get_plausible_value "mac")
            # Check if interface supports MAC change
            if ip link set "$iface" down; then
                if ip link set "$iface" address "$new_mac" 2>/dev/null; then
                    ip link set "$iface" up
                    echo "  [→] Changed MAC for $iface to $new_mac"
                    CHANGES_MADE=true
                else
                    echo "  [!] Failed to change MAC for $iface: VMware may restrict this."
                    echo "  [!] Consider changing MAC in VMware VM settings."
                fi
            else
                echo "  [!] Failed to bring $iface down."
            fi
        fi

        if [[ "$change_ip" == "true" ]]; then
            local new_ip="192.168.$((RANDOM % 255)).$((RANDOM % 254 + 1))"
            local gateway="${new_ip%.*}.1"
            if ip addr flush dev "$iface"; then
                ip addr add "$new_ip/24" dev "$iface"
                ip route add default via "$gateway"
                echo "  [→] Changed IP for $iface to $new_ip"
                CHANGES_MADE=true
            else
                echo "  [!] Failed to change IP for $iface."
            fi
        fi
    done
}

# Function to update system information
update_system_information() {
    local change_hostname=$1
    local change_sysinfo=$2
    
    echo "[+] Updating system information..."
    
    if [[ "$change_hostname" == "true" ]]; then
        local new_hostname=$(get_plausible_value "hostname")
        if hostnamectl set-hostname "$new_hostname"; then
            echo "  [→] Changed hostname to $new_hostname"
            CHANGES_MADE=true
        else
            echo "  [!] Failed to change hostname."
        fi
    fi

    if [[ "$change_sysinfo" == "true" ]]; then
        local users=("Admin" "User" "Owner" "Administrator")
        local orgs=("Home" "Private" "Personal" "Business")
        local new_owner=${users[$RANDOM % ${#users[@]}]}
        local new_org=${orgs[$RANDOM % ${#orgs[@]}]}
        
        # Mock system info changes in a file
        echo "Owner: $new_owner" > /tmp/mock_sysinfo
        echo "Organization: $new_org" >> /tmp/mock_sysinfo
        echo "  [→] Mocked system owner to '$new_owner' and organization to '$new_org'"
        CHANGES_MADE=true
    fi
}

# Function to clean system artifacts
clear_system_artifacts() {
    echo "[+] Cleaning system artifacts..."
    
    # Clear logs
    find /var/log -type f -exec truncate -s 0 {} \; 2>/dev/null
    echo "  [→] Cleared system logs"
    
    # Clear temporary files
    rm -rf /tmp/* /var/tmp/* 2>/dev/null
    echo "  [→] Removed temporary files"
    
    # Clear bash history
    history -c
    rm -f ~/.bash_history
    echo "  [→] Cleared bash history"
    
    CHANGES_MADE=true
}

# Function to add decoy information
add_decoy_information() {
    echo "[+] Adding decoy information..."
    
    # Add fake service
    echo -e "[Unit]\nDescription=Fake Service\n[Service]\nExecStart=/bin/true\n[Install]\nWantedBy=multi-user.target" > /etc/systemd/system/fake.service
    systemctl enable fake.service 2>/dev/null
    echo "  [→] Created decoy systemd service: fake.service"
    
    # Add fake file
    echo "Fake Component v1.$((RANDOM % 100))" > /tmp/fake_component.txt
    echo "  [→] Created decoy file: /tmp/fake_component.txt"
    
    CHANGES_MADE=true
}

# Function to protect modifications
protect_modifications() {
    echo "[+] Protecting modifications..."
    
    # Restrict access to mock DMI directory
    if [[ -d /tmp/mock_dmi ]]; then
        chmod 700 /tmp/mock_dmi
        echo "  [→] Restricted permissions for /tmp/mock_dmi"
    fi
    
    # Restrict access to mock sysinfo
    if [[ -f /tmp/mock_sysinfo ]]; then
        chmod 600 /tmp/mock_sysinfo
        echo "  [→] Restricted permissions for /tmp/mock_sysinfo"
    fi
    
    CHANGES_MADE=true
}

# Function to display main menu
show_main_menu() {
    clear
    echo -e "\n=== Advanced System Identity Modifier ===\n"
    echo "1. Automatic Full Modification (Recommended)"
    echo "2. Custom Modification"
    echo "3. Restore Original Settings"
    echo "4. Exit"
}

# Function to display custom menu
show_custom_menu() {
    clear
    echo -e "\n=== Custom Modification Options ===\n"
    echo "1. Modify Hardware IDs"
    echo "2. Change Network Configuration"
    echo "3. Update System Information"
    echo "4. Clean System Artifacts"
    echo "5. Add Anti-Detection Measures"
    echo "6. Return to Main Menu"
}

# Function for automatic mode
invoke_automatic_mode() {
    echo "[!] Starting automatic modification..."
    backup_system_state
    update_hardware_ids "true"
    update_network_configuration "true" "false"
    update_system_information "true" "true"
    clear_system_artifacts
    add_decoy_information
    protect_modifications
    
    if [[ "$CHANGES_MADE" == "true" ]]; then
        echo -e "\n[√] Automatic modifications completed successfully!"
        echo "    Some changes may require a reboot to take effect."
    else
        echo -e "\n[!] No changes were made during automatic mode."
    fi
}

# Function for custom mode
invoke_custom_mode() {
    while true; do
        show_custom_menu
        read -p "Select an option (1-6): " choice
        
        case $choice in
            1)
                backup_system_state
                read -p "Enter custom manufacturer (or leave blank for random): " man
                read -p "Enter custom product name (or leave blank for random): " prod
                if [[ -z "$man" || -z "$prod" ]]; then
                    update_hardware_ids "true"
                else
                    update_hardware_ids "false" "$man" "$prod"
                fi
                ;;
            2)
                read -p "Change MAC addresses? (Y/N): " mac
                read -p "Change IP configuration? (Y/N): " ip
                [[ "$mac" =~ ^[Yy]$ ]] && mac_change="true" || mac_change="false"
                [[ "$ip" =~ ^[Yy]$ ]] && ip_change="true" || ip_change="false"
                update_network_configuration "$mac_change" "$ip_change"
                ;;
            3)
                read -p "Change hostname? (Y/N): " hostname
                read -p "Modify system info? (Y/N): " sysinfo
                [[ "$hostname" =~ ^[Yy]$ ]] && hostname_change="true" || hostname_change="false"
                [[ "$sysinfo" =~ ^[Yy]$ ]] && sysinfo_change="true" || sysinfo_change="false"
                update_system_information "$hostname_change" "$sysinfo_change"
                ;;
            4)
                clear_system_artifacts
                ;;
            5)
                add_decoy_information
                protect_modifications
                ;;
            6)
                return
                ;;
            *)
                echo "Invalid selection"
                ;;
        esac
        
        [[ "$choice" != "6" ]] && read -p "Press Enter to continue..."
    done
}

# Function to restore original settings
restore_original_settings() {
    echo "[!] Restoring original settings..."
    
    if [[ -d "$BACKUP_DIR" ]]; then
        # Restore hostname
        if [[ -f "$BACKUP_DIR/hostname.txt" ]]; then
            local original_hostname=$(grep "Static hostname" "$BACKUP_DIR/hostname.txt" | awk '{print $3}')
            if [[ -n "$original_hostname" ]]; then
                hostnamectl set-hostname "$original_hostname"
                echo "  [→] Restored hostname to $original_hostname"
            fi
        fi
        
        # Note: MAC/IP restoration requires manual VMware configuration
        echo -e "\n[√] Original settings restored from backup where possible"
        echo "    Some restorations (e.g., MAC address) may require manual VMware configuration"
    else
        echo "[!] No backup found to restore from"
    fi
}

# Main execution loop
while true; do
    show_main_menu
    read -p "Select an option (1-4): " main_choice
    
    case $main_choice in
        1)
            invoke_automatic_mode
            ;;
        2)
            invoke_custom_mode
            ;;
        3)
            restore_original_settings
            ;;
        4)
            exit 0
            ;;
        *)
            echo "Invalid selection"
            ;;
    esac
    
    if [[ "$main_choice" != "4" ]]; then
        read -p "Reboot now? (Y/N): " reboot
        if [[ "$reboot" =~ ^[Yy]$ ]]; then
            reboot
        fi
    fi
done