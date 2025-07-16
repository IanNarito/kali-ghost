<h1 align="center">KALI-GHOST</h1>
<p align="center"><i>Become a digital ghost — cloak your Kali Linux VM with full stealth automation.</i></p>

---

## 🧠 What is KALI-GHOST?

**KALI-GHOST** is an all-in-one **Kali Linux stealth hardening tool** built for ethical hackers, penetration testers, and red teamers who want to operate like a shadow in the matrix.

It automates system anonymization, traffic obfuscation, and cleans up digital footprints — while also giving you a cool **"Stealth Level" score** based on your anonymity state.

> 🔒 For **educational & ethical use only**. Don’t be dumb with it.

---

## 🚀 Features

- 🕵️‍♂️ Randomizes MAC address
- 🖥️ Changes hostname to anonymous alias
- 🌐 Disables IPv6 (to avoid leaks)
- 🔗 Installs & configures **Tor** and **Proxychains**
- 🧠 Auto-configures `proxychains.conf` for dynamic stealth
- 🔐 Locks DNS to Cloudflare (1.1.1.1)
- 🧽 Wipes logs, Bash history, and other traces
- 🧪 Calculates a real-time **Stealth Level Score** (0–100)
- ✅ Works on **Kali Linux (VMs or bare metal)**

---

## ⚙️ How to Use

> 🧑‍💻 Works best when run **as root/sudo** on Kali Linux.

### 🔧 Step-by-Step:

```bash
git clone https://github.com/yourusername/kali-ghost.git
cd kali-ghost
chmod +x ghost.sh
sudo bash ghost.sh


