#!/bin/bash

set -euo pipefail
set -x

INTERVAL=5  # Retry interval in seconds for indefinite mode

# Collect NFS mounts from environment variables (NFS1, NFS2, etc.)
declare -A MOUNTS
for var in $(env | grep '^NFS[0-9]*=' | cut -d= -f1); do
    MOUNT_POINT="/mnt/$(echo $var | tr '[:upper:]' '[:lower:]')"  # e.g., NFS1 -> /mnt/nfs1
    MOUNTS["$MOUNT_POINT"]="${!var}"
done

if [ ${#MOUNTS[@]} -eq 0 ]; then
    echo "No NFS mounts defined (expecting NFS1, NFS2, etc.)"
    exit 1
fi

# Extract unique NFS servers for checking
declare -A SERVERS
for NFS_SHARE in "${MOUNTS[@]}"; do
    SERVER="${NFS_SHARE%%:*}"  # Extract host
    SHARE_PATH="${NFS_SHARE#*:}"  # Extract path
    SERVERS["$SERVER"]="${SERVERS[$SERVER]:+$SERVERS[$SERVER],}$SHARE_PATH"
done

# Check availability of all NFS servers and shares
while true; do
    ALL_READY=1
    ELAPSED=0

    # Check each server and its shares
    for SERVER in "${!SERVERS[@]}"; do
        # Verify NFS port is open
        if ! nc -z "$SERVER" 2049 2>/dev/null; then
            echo "NFS server $SERVER:2049 not reachable"
            ALL_READY=0
            break
        fi

        # Get expected shares for this server
        IFS=',' read -ra EXPECTED_SHARES <<< "${SERVERS[$SERVER]}"

        # Verify shares are exported
        if ! SHOWMOUNT_OUTPUT=$(showmount -e "$SERVER" 2>/dev/null); then
            echo "Failed to query exports from $SERVER"
            ALL_READY=0
            break
        fi

        # Check each expected share
        for SHARE_PATH in "${EXPECTED_SHARES[@]}"; do
            if ! echo "$SHOWMOUNT_OUTPUT" | grep -q "^$SHARE_PATH "; then
                echo "Share $SHARE_PATH not found in exports from $SERVER"
                ALL_READY=0
            else
                echo "Share $SHARE_PATH is accessible on $SERVER"
            fi
        done
    done

    # If all shares are ready, proceed
    if [ "$ALL_READY" -eq 1 ]; then
        echo "All NFS shares are ready"
        touch /tmp/shares-ready  # Signal success for health check
        break
    fi

    # Check timeout if set
    if [ -n "$TIMEOUT" ]; then
        ELAPSED=$((ELAPSED + INTERVAL))
        if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
            echo "Timeout ($TIMEOUT seconds) waiting for NFS shares"
            exit 1
        fi
    fi

    echo "Retrying in $INTERVAL seconds..."
    sleep "$INTERVAL"
done

# Signal readiness and keep container running
echo "NFS checker completed successfully"
exec "$@"
