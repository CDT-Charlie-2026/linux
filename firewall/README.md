# Linux Firewall Configuration - nftables
## IF ALL ELSE FAILS
Run `sudo nft flush ruleset && sudo echo "" > /etc/nftables.conf`, and set up your own firewall

## Usage
Simply run `firewall/firewall_config.sh`. If it can't find the IP address, use the desired IP as the first argument, i.e. `firewall/firewall_config.sh <IP addr>`

## Adding your own rules
For a generic drop/accept rule by port number: \
`sudo nft add rule inet filter <input|output> <tcp|udp> dport <port_number> <accept|drop>` \
To specify a host, simply add `ip saddr <X.X.X.X>` before specifying the transport layer protocol: \
`sudo nft add rule inet filter <input|output> ip saddr <X.X.X.X> <tcp|udp> dport <port_number> <accept|drop>`

### Persisting rules
Persistent rules are stored in `/etc/nftables.conf` \
To persist the current ruleset across reboots, run `sudo nft list ruleset > /etc/nftables.conf` \
\
New rules are additive by default, so you may want to flush them before updating the in-memory rules: `sudo nft flush ruleset` \
To load persisted rules into memory, run `sudo nft -f <path/to/file>`

## Backups
nft ruleset backups are stored in `/etc/nftables/nftables-backup-*.nft`, where * represents a timestamp. \
These rules are backed up any time the `firewall/firewall_config.sh` script is run. \
iptables rules are backed up to `/etc/iptables/iptables_ipv4.rules` upon running `firewall/firewall_config.sh`

## Organization
We are using nftables, with specific rules configured per host. The script checks the host based on IP address, and configures the correct rules for the host.

## FTP
Specifically for FTP, there may be issues with Passive FTP ports if the server is using Passive FTP. In the event that this breaks, you can either run `sudo ./firewall/fix_ftp.sh` from the repo root for an easy fix, or you can find the ftp configuration and look for the Passive ports in use, then run the command `sudo nft inet filter input tcp dport <min_port>-<max_port> accept`, where min_port is the minimum Passive port, and max_port is the maximum Passive port.
