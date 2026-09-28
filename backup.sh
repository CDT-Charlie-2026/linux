#!/bin/bash
# basic backup code - backs up select files but just stores in separate file,
# doesn't move it off the machine or anything
# backups also could have red team infiltration, esp cronjobs

# make folder
BACKUP="/root/backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
cp -a /etc "$BACKUP/"

# User data
cp -a /home "$BACKUP/"

# root files
cp -a /root "$BACKUP/"

# Cronjobs and systemd
cp -a /var/spool/cron "$BACKUP/cron" 2>/dev/null
cp -a /etc/systemd/system "$BACKUP/systemd" 2>/dev/null

# Package and account information
dpkg --get-selections > "$BACKUP/packages.txt" 2>/dev/null
cp /etc/passwd /etc/shadow /etc/group /etc/gshadow "$BACKUP/" 2>/dev/null

echo "Backup created at $BACKUP"