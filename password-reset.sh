#!/bin/bash
# Usage:
#   ./password-reset.sh                     change all users with UID >= 1000
#   ./password-reset.sh -Users alice,bob    only change these users (any UID)
#   ./password-reset.sh -Exclude blueadmin  change all users with UID >= 1000 except these

#Note: doesn't change passwords for users under UID 1000 as they are typically system accounts and could break services

# Excluded users not changed unless explicitly named with -Users
EXCLUDED="nobody"

if [ "$EUID" -ne 0 ]; then
    echo "Run as root"
    exit 1
fi

USERS=""
EXCLUDE=""
case "$1" in
    -Users)   USERS="$2" ;;
    -Exclude) EXCLUDE="$2" ;;
    "")       ;;
    *)        echo "Usage: $0 [-Users a,b | -Exclude a,b]"; exit 1 ;;
esac

if [ -n "$1" ] && [ -z "$2" ]; then
    echo "$1 needs a comma separated list of users"
    exit 1
fi

read -s -p "New password: " PASS1; echo
read -s -p "Confirm password: " PASS2; echo
if [ "$PASS1" != "$PASS2" ]; then
    echo "Passwords do not match"
    exit 1
fi

while IFS=: read -r name _ uid _; do
    if [ -n "$USERS" ]; then
        # -Users: only the named users
        [[ ",$USERS," == *",$name,"* ]] || continue
    else
        # No args / -Exclude: UID >= 1000, not excluded
        [ "$uid" -ge 1000 ] || continue
        [[ ",$EXCLUDED,$EXCLUDE," == *",$name,"* ]] && continue
    fi

    if echo "$name:$PASS1" | chpasswd; then
        echo "[+] $name"
    else
        echo "[!] $name"
    fi
done < /etc/passwd

echo "Done."
