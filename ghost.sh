#!/bin/bash

# GHOSTIFY v1.0 - by IanNarito
# Become a ghost. Stay hidden.

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${GREEN} Starting GHOST - Stealth Mode Initiated ${NC}"

## 1. Randomize MAC Address
echo -e "${GREEN}[1/10] Randomizing MAC address...${NC}"
iface=$(ip link | awk -F: '$0 !~ "lo|vir|wl|docker" {print $2;getline}')
macchanger -r "$iface" > /dev/null 2>&1
echo "[+] MAC address randomized on $iface."

## 2. Change Hostname
echo -e "${GREEN}[2/10] Changing hostname...${NC}"
NEW_HOST="ghost-$(shuf -i 1000-9999 -n 1)"
hostnamectl set-hostname "$NEW_HOST"
echo "[+] New hostname: $NEW_HOST"

## 3. Disable IPv6
echo -e "${GREEN}[3/10] Disabling IPv6...${NC}"
echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p > /dev/null 2>&1
echo "[+] IPv6 disabled."

## 4. Install Tor & Proxychains
echo -e "${GREEN}[4/10] Installing Tor and Proxychains...${NC}"
apt update -y > /dev/null && apt install -y tor proxychains4 > /dev/null
echo "[+] Tor & Proxychains installed."

## 5. Configure Proxychains
echo -e "${GREEN}[5/10] Configuring Proxychains...${NC}"
sed -i 's/^strict_chain/#strict_chain/' /etc/proxychains4.conf
sed -i 's/^#dynamic_chain/dynamic_chain/' /etc/proxychains4.conf
sed -i 's/^#proxy_dns/proxy_dns/' /etc/proxychains4.conf
sed -i '$a socks5 127.0.0.1 9050' /etc/proxychains4.conf
echo "[+] Proxychains set to dynamic + Tor."

## 6. DNS Leak Protection
echo -e "${GREEN}[6/10] Setting DNS to prevent leaks...${NC}"
echo "nameserver 1.1.1.1" > /etc/resolv.conf
chattr +i /etc/resolv.conf  # Lock the file to prevent overwrites
echo "[+] DNS locked to Cloudflare (1.1.1.1)."

## 7. Clean Logs & History
echo -e "${GREEN}[7/10] Wiping bash history & logs...${NC}"
history -c && rm -f ~/.bash_history
find /var/log -type f -exec shred -u {} \; > /dev/null 2>&1
echo "[+] Logs and history nuked."

## 8. Launch Tor
echo -e "${GREEN}[8/10] Starting Tor service...${NC}"
systemctl start tor
sleep 3

## 9. Stealth Level Checker
echo -e "${GREEN}[9/10] Analyzing stealth level...${NC}"
score=0

## Score Components
[[ "$(curl -s ifconfig.me)" ]] && ((score+=20))
[[ "$(curl -s ifconfig.me | grep -q 127.0.0.1)" ]] || ((score+=10))
[[ "$(pgrep tor)" ]] && ((score+=20))
[[ "$(grep '9050' /etc/proxychains4.conf)" ]] && ((score+=20))
[[ "$NEW_HOST" == *"ghost"* ]] && ((score+=10))
[[ -z "$(history)" ]] && ((score+=10))
[[ "$(ip a | grep ether | awk '{print $2}' | grep -oE '^..:..')" != "00:00" ]] && ((score+=10))

echo "[*] Stealth Score: $score / 100"

if [ $score -ge 90 ]; then
    echo -e "${GREEN} Stealth Level: GHOST MODE ACTIVATED ${NC}"
elif [ $score -ge 70 ]; then
    echo -e "${GREEN} Stealth Level: Solid, but tighten up...${NC}"
else
    echo -e "${RED} Stealth Level: Weak — you're trackable, fam!${NC}"
fi

echo -e "${GREEN}[10/10] Ghostify complete. Use proxychains or torsocks to stay hidden.${NC}"
echo -e "${GREEN} Stay hidden soldier. ${NC}"
