#!/bin/bash

# SSH Hardening script

if [ "$EUID" -ne 0 ]; then
	echo "This script must be run as root."
	exit 1
fi

# EUID = effective user ID (0 = root), -ne = not equal => if not root, then send echo

# create backup for SSH
 echo "[+] Backing up SSH config..."
 cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
 echo "[+] Backup created."

# Disable root SSH login

echo "[+] Disable root SSH login"

sed -i 's/^[#[:space:]]*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

echo "[+] Root ssh login disabled"

# disable empty passwords

echo " disabling empty password ssh login..."

sed -i 's/^[#[:space:]]*PermitEmptyPasswords.*/PermitEmptyPasswords no/' /etc/ssh/sshd_config

echo " empty password ssh login disabled"

# set ssh port to the comp port (52022)

# echo " setting ssh port to 52022..."

# sed -i 's/^[#[:space:]]*Port.*/Port 52022/' /etc/ssh/sshd_config

# echo "ssh port set to 52022"

# validate ssh config

echo "validate ssh config..."

if sshd -t; then
	echo "ssh config is valid"
else
	echo "ssh config has errors"
	exit 1
fi

# sshd -t tests the server config without restarting or starting ssh 
# should produce no output if nominal
