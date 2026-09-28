#!/bin/bash

# firewall_config.sh - This script installs and configures nftables
# Usage: ./firewall_config.sh
#   If the IP address is not found, use:
#   ./firewall_config.sh <ip_addr>

# ===== Colors =====
green='\e[32m'
yellow='\e[33m'
red='\e[31m'
reset='\e[0m'
# ==================

# ===== Files =====
script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
rules_file="$script_dir/default_rules.nft"
backup_dir="/etc/nftables"
iptables_backup_dir="/etc/iptables"
iptables_backup_file=""$iptables_backup_dir"/iptables_ipv4.rules"
# =================

# ===== Detect Host IP =====
host_ip="$(ip -4 -o addr show scope global | awk '$4 ~ /^10\.110\.10\./ {print $4}' | cut -d/ -f1):-"$1""
if [ -z "$host_ip" ]; then
    echo -e "${red}Could not determine competition host IP.${reset}"
    exit 1
fi
echo "Detected host IP: $host_ip"
# ==========================

# ===== Rules File =====
case "$host_ip" in
    10.110.10.11)
        rules_file="$script_dir/rules/geonosis.nft"
        ;;
    10.110.10.12)
        rules_file="$script_dir/rules/mandalore.nft"
        ;;
    10.110.10.13)
        rules_file="$script_dir/rules/kashyyyk.nft"
        ;;
    10.110.10.14)
        rules_file="$script_dir/rules/utapau.nft"
        ;;
    10.110.10.15)
        rules_file="$script_dir/rules/mustafar.nft"
        ;;
    *)
        echo -e "${red}Unknown competition host IP: $host_ip${reset}"
        exit 1
        ;;
esac
# ======================

# verify_root ensures that this script is run with root permissions
#
# Takes no arguments
#
# Returns nothing
verify_root() {
    if [ "$EUID" -ne 0 ]; then
        echo -e "${yellow}This script must be run as ${green}root${yellow}. Exiting...${reset}"
        exit 1
    fi
}

# backup_iptables backs up the iptables configuration in case iptables is used
#
# Takes no arguments
#
# Returns nothing
backup_iptables() {
    mkdir -p "$iptables_backup_dir"
    iptables-save > "$iptables_backup_file"
}

# detect_distro detects the linux distribution and prints the value
# 
# Takes no arguments
#
# Prints the distro in lowercase
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release # source the file
        echo "${ID,,}" # lowercase ID
    else
        echo "unknown"
    fi
}

# uninstall_ufw disables and uninstalls ufw to remove conflicts
#
# Takes no arguments
#
# Returns nothing
uninstall_ufw() {
    case "$distro" in
        *ubuntu*|*debian*)
            systemctl disable --now ufw 2>/dev/null
            apt-get remove -y ufw
        ;;
        *fedora*|*centos*|*rhel*|*rocky*|*almalinux*)
            if command -v dnf > /dev/null 2>&1; then
                systemctl disable --now ufw 2>/dev/null
                dnf remove -y ufw
            else
                systemctl disable --now ufw 2>/dev/null
                yum remove -y ufw
            fi
        ;;
        *arch*)
            systemctl disable --now ufw 2>/dev/null
            pacman -R --noconfirm ufw
        ;;
        *suse*|*opensuse*|*sles*)
            systemctl disable --now ufw 2>/dev/null
            zypper remove -y ufw
        ;;
        *)
            echo "Unsupported distribution: $distro"
        ;;
    esac
}

# update_cache updates the package manager's cache
#
# Takes no arguments
#
# Returns nothing
update_cache() {
    local distro="$(detect_distro)"

    case "$distro" in
        *ubuntu*|*debian*)
            apt-get update
        ;;
        *fedora*|*centos*|*rhel*|*rocky*|*almalinux*)
            if command -v dnf > /dev/null 2>&1; then
                dnf makecache
            else
                yum makecache
            fi
        ;;
        *suse*|*opensuse*|*sles*)
            zypper refresh
        ;;
        *)
            echo "Unsupported distribution: $distro"
        ;;
    esac
}

# install_nftables installs nftables based on os parsed from /etc/release
#
# Takes no arguments
#
# Returns nothing
install_nftables() {
    local distro="$(detect_distro)"

    case "$distro" in
        *ubuntu*|*debian*)
            apt-get install -y nftables
        ;;
        *fedora*|*centos*|*rhel*|*rocky*|*almalinux*)
            if command -v dnf > /dev/null 2>&1; then
                dnf install -y nftables
            else
                yum install -y nftables
            fi
        ;;
        *arch*)
            pacman -S --noconfirm nftables
        ;;
        *suse*|*opensuse*|*sles*)
            zypper install -y nftables
        ;;
        *)
            echo "Unsupported distribution: $distro"
        ;;
    esac
}


# enable_nftables enables and restarts the nftables service
#
# Takes no arguments
#
# Returns nothing
enable_nftables() {
    systemctl enable --now nftables
    systemctl restart nftables
}


# verify_nft_intallation checks that nftables is installed and installs it if not, and enables it regardless
#
# Takes no arguments
#
# Returns nothing
verify_nft_installation() {
    update_cache
    if ! command -v nft > /dev/null 2>&1; then
        install_nftables
    fi
    enable_nftables
}

# create_backup_name generates a name for the backup file
#
# Takes no arguments
#
# Prints the basename of the backup file
create_backup_name() {
   echo "nftables-backup-"$(date +%Y%m%d-%H%M%S)".nft" 
}

# backup_ruleset backs up the current nftables ruleset
#
# Arguments:
#   $1: Name of backup file
#
# Returns nothing
backup_ruleset() {
    if [ ! -d "$backup_dir" ]; then
        mkdir -p "$backup_dir"
    fi
    nft list ruleset > ""$backup_dir"/"$1""
}

# parse_latest_backup returns the most recent nftables ruleset backup
#
# Takes no arguments
#
# Prints the absolute path of the file
parse_latest_backup() {
    local latest_backup=$(ls -t "${backup_dir}"/nftables-backup-*.nft 2>/dev/null | head -n 1)
    if [ -z "$latest_backup" ]; then
        echo "${red}No backups found${reset}"
        exit 1
    else
        echo "$latest_backup"
    fi
}
# restore_backup restores the nft ruleset from a backup. First to the configuration file location, then to memory
#
# Arguments
#   $1: The file to back up from
#
# Returns nothing
restore_backup() {
    echo -e "${yellow}Restoring ruleset from "$1"...${reset}"
    cp "$1" "/etc/nftables.conf"
    nft -f /etc/nftables.conf
    echo -e "${green}Restored successfully.${reset}"
}

# flush_ruleset flushes the current nftables ruleset and backs up existing ones
#
# Arguments:
#   $1: Basename of backup file
#
# Returns nothing
flush_ruleset() {
    local backup_name="$1"
    if nft list ruleset | grep -q 'table'; then
        echo -e "${yellow}Existing nftables rules detected. Backing them up to "$backup_dir"/"$backup_name"${reset}"
        backup_ruleset "$backup_name"
    fi
    echo -e "${yellow}Flushing current nftables ruleset...${reset}"
    nft flush ruleset
}

# save_current_ruleset saves the in-memory nftables ruleset into the config file located at /etc/nftables.conf
#
# Takes no arguments
#
# Returns nothing
save_current_ruleset() {
    echo -e "${green}Saving current ruleset to /etc/nftables.conf...${reset}"
    nft list ruleset > /etc/nftables.conf
}

# normalize_diff normalizes the output of listing nft rulesets for diff to work properly
#
# Takes no arguments; reads from stdin
#
# Prints the normalized text
normalize_diff() {
    sed 's/\s\+/ /g; s/^ *//g; s/ *$//; /^#/d; /^$/d; s/priority filter/priority 0/g; s/;\s*policy/;\npolicy/g' | tr -d '\t'
}

# apply_default_ruleset applies a default nftables ruleset
#
# Arguments:
#   $1: Name of backup file
#
# Returns nothing
apply_default_ruleset() {

    local backup_name="$1"

    # Backup and flush ruleset
    flush_ruleset "$backup_name"

    echo -e "${green}Applying basic default nftables ruleset...${reset}"
    nft -f "$rules_file"

    # Dead man's switch
    if ! read -r -t 15 -p "Press ENTER to persist, or wait 15 seconds to rollback: " _; then
        restore_backup ""$backup_dir"/"$backup_name""
    fi
    save_current_ruleset
    enable_nftables
    
}

main() {
    verify_root

    distro="$(detect_distro)"

    echo "Detected distribution: $distro"

    uninstall_ufw

    verify_nft_installation

    nft -c -f "$rules_file" || {
        echo -e "${red}Ruleset validation failed. Aborting.${reset}"
        exit 1
    }

    local backup_name="$(create_backup_name)"

    apply_default_ruleset "$backup_name"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main
fi
