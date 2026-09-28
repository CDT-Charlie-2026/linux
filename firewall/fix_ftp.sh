#!/bin/bash

. ./firewall_config.sh

verify_root

nft add rule inet filter input tcp dport 1024-65535 accept

save_current_ruleset
