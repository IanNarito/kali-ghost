#!/bin/bash

# GHOSTIFY v2.0 - Enhanced Stealth Tool
# Improvements: Safety checks, Backup/Restore, Safe Log Wiping, Robust Networking
# Author: IanNarito 

# --- Colors ---
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

# --- Configuration ---
BACKUP_DIR="/tmp/ghostify_backup"
LOG_FILES=("/var/log/syslog" "/var/log/auth.log" "/var/log/kern.log" "/var/log/dmesg" "/var/log/wtmp" "/var/log/btmp")

# --- Banner ---
banner() {
    clear
    echo -e "${BLUE}"
    echo "   ________  __  ______  _____________  ________  __"
    echo "  / ___/  / / / / __  / / ___/_  __/ /  _/ __ \/ /"
    echo " / / __/ /_/ / / / / /  \__ \ / /    / // /_/ / / "
    echo "/ /_/ / __  / / /_/ /  ___/ // /   _/ // ____/_/  "
    echo "\____/_/ /_/  \____/  /____//_/   /___/_/   (_)   "
    echo -e "${NC}"
    echo -e "      ${YELLOW}:: v2.0 :: The Professional Stealth Suite ::${NC}\n"
}

# --- Root Check ---
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}[!] This script must be run as root.${NC}" 
   exit 1
fi

# --- Functions ---

check_deps() {
    echo -e "${BLUE}[*] Checking dependencies...${NC}"
    local deps=("macchanger" "tor" "proxychains4" "curl" "shred")
    for pkg in "${deps[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            echo -e "${YELLOW}[!] Installing missing package: $pkg...${NC}"
            apt-get update -y > /dev/null && apt-get install -y "$pkg" > /dev/null
        fi
    done
    echo -e "${GREEN}[+] Dependencies met.${NC}"
}

backup_configs() {
    echo -e "${BLUE}[*] Backing up original configurations...${NC}"
    mkdir -p "$BACKUP_DIR"
    
    # Backup Hostname
    cat /etc/hostname > "$BACKUP_DIR/hostname"
    
    # Backup DNS
    if [ -f /etc/resolv.conf ]; then
        cp /etc/resolv.conf "$BACKUP_DIR/resolv.conf"
    fi

    # Backup Proxychains
    cp /etc/proxychains4.conf "$BACKUP_DIR/proxychains4.conf"
    
    echo -e "${GREEN}[+] Backup saved to $BACKUP_DIR.${NC}"
}

randomize_identity() {
    echo -e "${BLUE}[*] Randomizing Identity...${NC}"
    
    # 1. MAC Address
    # Interactive Interface Selection for safety
    echo -e "${YELLOW}Available Interfaces:${NC}"
    ip -o link show | awk -F': ' '{print $2}' | grep -v "lo"
    read -p "Enter interface to mask (e.g., eth0, wlan0): " IFACE
    
    if [[ -z "$IFACE" ]]; then
        IFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
        echo -e "${YELLOW}[!] No input. Defaulting to active interface: $IFACE${NC}"
    fi

    ip link set "$IFACE" down
    macchanger -r "$IFACE" > /dev/null
    ip link set "$IFACE" up
    echo -e "${GREEN}[+] MAC Address on $IFACE randomized.${NC}"

    # 2. Hostname
    OLD_HOST=$(cat /etc/hostname)
    NEW_HOST="node-$(shuf -i 10000-99999 -n 1)"
    hostnamectl set-hostname "$NEW_HOST"
    sed -i "s/$OLD_HOST/$NEW_HOST/g" /etc/hosts
    echo -e "${GREEN}[+] Hostname changed to: $NEW_HOST${NC}"
}

secure_network() {
    echo -e "${BLUE}[*] Securing Network Layer...${NC}"

    # 3. Disable IPv6
    sysctl -w net.ipv6.conf.all.disable_ipv6=1 > /dev/null
    sysctl -w net.ipv6.conf.default.disable_ipv6=1 > /dev/null
    echo -e "${GREEN}[+] IPv6 Disabled.${NC}"

    # 4. DNS Leaks
    # Remove immutable bit if exists, then overwrite
    chattr -i /etc/resolv.conf 2>/dev/null
    echo "nameserver 1.1.1.1" > /etc/resolv.conf
    # Make immutable to prevent DHCP overwrites
    chattr +i /etc/resolv.conf
    echo -e "${GREEN}[+] DNS locked to 1.1.1.1 (Cloudflare).${NC}"
}

setup_tor() {
    echo -e "${BLUE}[*] Configuring Tor & Proxychains...${NC}"
    
    # Start Tor
    systemctl restart tor
    
    # Configure Proxychains (Idempotent - checks before adding)
    CONF="/etc/proxychains4.conf"
    sed -i 's/^strict_chain/#strict_chain/' "$CONF"
    sed -i 's/^#dynamic_chain/dynamic_chain/' "$CONF"
    sed -i 's/^#proxy_dns/proxy_dns/' "$CONF"
    
    if ! grep -q "socks5 127.0.0.1 9050" "$CONF"; then
        echo "socks5 127.0.0.1 9050" >> "$CONF"
    fi
    
    echo -e "${GREEN}[+] Tor is running and Proxychains configured.${NC}"
}

nuke_logs() {
    echo -e "${BLUE}[*] Wiping Logs (Safe Mode)...${NC}"
    
    # Clear Bash History
    history -c
    rm -f ~/.bash_history
    
    # Safe Log Wiping (Truncate don't delete)
    for log in "${LOG_FILES[@]}"; do
        if [ -f "$log" ]; then
            shred -n 1 "$log" 2>/dev/null # Overwrite once
            > "$log" # Truncate to 0 bytes
        fi
    done
    
    echo -e "${GREEN}[+] Logs scrubbed without breaking system services.${NC}"
}

check_stealth() {
    echo -e "${BLUE}[*] Verifying Stealth Status...${NC}"
    sleep 2
    
    echo -n "Checking Real IP: "
    curl -s --connect-timeout 3 ifconfig.me || echo "Offline"
    
    echo -n "Checking Tor IP (via Proxychains): "
    TOR_IP=$(proxychains4 -q curl -s --connect-timeout 5 ifconfig.me)
    echo "$TOR_IP"

    if [[ -z "$TOR_IP" ]]; then
        echo -e "${RED}[!] Tor connection failed! Check service.${NC}"
    else
        echo -e "${GREEN}[+] Tor Tunnel Active.${NC}"
    fi
}

restore_system() {
    echo -e "${RED}[!] RESTORING SYSTEM TO NORMAL STATE...${NC}"
    
    if [ -d "$BACKUP_DIR" ]; then
        # Restore Hostname
        OLD_NAME=$(cat "$BACKUP_DIR/hostname")
        hostnamectl set-hostname "$OLD_NAME"
        echo "[+] Hostname restored."
        
        # Restore DNS
        chattr -i /etc/resolv.conf
        cp "$BACKUP_DIR/resolv.conf" /etc/resolv.conf
        echo "[+] DNS restored."

        # Restore Proxychains
        cp "$BACKUP_DIR/proxychains4.conf" /etc/proxychains4.conf
        echo "[+] Proxychains config restored."
        
        # Enable IPv6
        sysctl -w net.ipv6.conf.all.disable_ipv6=0 > /dev/null
        sysctl -w net.ipv6.conf.default.disable_ipv6=0 > /dev/null
        echo "[+] IPv6 re-enabled."

        # Restore MAC (Attempt to reset to permanent)
        echo -e "${YELLOW}Note: MAC address will reset to hardware default on reboot.${NC}"
        
        rm -rf "$BACKUP_DIR"
        echo -e "${GREEN}[+] System restored. Reboot recommended.${NC}"
    else
        echo -e "${RED}[!] No backup found! Cannot restore automatically.${NC}"
    fi
}

# --- Main Logic ---
banner

echo "Select Mode:"
echo "1) GHOST MODE (Activate Stealth)"
echo "2) RESTORE (Revert Changes)"
read -p "Choice [1/2]: " CHOICE

case $CHOICE in
    1)
        check_deps
        backup_configs
        randomize_identity
        secure_network
        setup_tor
        nuke_logs
        check_stealth
        echo -e "\n${GREEN}=== GHOSTIFY COMPLETE ===${NC}"
        echo "Use: proxychains4 <command>"
        ;;
    2)
        restore_system
        ;;
    *)
        echo "Invalid choice."
        ;;
esac
