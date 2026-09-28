#!/bin/bash

script_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

. ""$script_dir"/firewall_config.sh"

verify_root

nft add rule inet filter input tcp dport 1024-65535 accept

save_current_ruleset
