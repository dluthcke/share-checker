#!/bin/bash

set -euo pipefail
if [ "${DEBUG:-false}" = "true" ]; then
  set -x
fi

TIMEOUT=${TIMEOUT:-60}

INTERVAL=${INTERVAL:-5}
if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]]; then
    echo "Error: INTERVAL must be a positive integer, got '$INTERVAL'. Using default of 5."
    INTERVAL=5
fi

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
    echo "Processing: SERVER=$SERVER, SHARE_PATH=$SHARE_PATH"
    # Check if SERVER key exists; append or set accordingly
    if [[ -n "${SERVERS[$SERVER]+set}" ]]; then
        SERVERS["$SERVER"]="${SERVERS[$SERVER]},$SHARE_PATH"
    else
        SERVERS["$SERVER"]="$SHARE_PATH"
    fi
done

# Print the servers and their shares nicely
echo "Preparing to check the following NFS Shares:"
echo "-------------------------------------"
for SERVER in "${!SERVERS[@]}"; do
    echo "Server: $SERVER"
    echo "  Shares: ${SERVERS[$SERVER]}"
done
echo "-------------------------------------"

# Function to check if a server is reachable
check_server() {
    local server="$1"
    local interval="$2"
    local timeout="$3"
    local elapsed=0

    echo "Checking reachability for $server..."
    while [ $elapsed -lt "$timeout" ]; do
        # Replace with your actual server check (e.g., ping, nc, or NFS mount test)
	if nc -z "$server" 2049 2>/dev/null; then
            echo "$server is reachable"
            return 0
        fi
        echo "$server not reachable yet, waiting..."
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done
    echo "$server is not reachable after $timeout seconds"
    return 1
}


# Check availability of all NFS servers and shares
ALL_READY=false
while ! $ALL_READY; do
    # Set all ready to 1, will set back to 0 on any failure
    ALL_READY=true

    # Check each server and its shares
    for SERVER in "${!SERVERS[@]}"; do

        if ! check_server "$SERVER" "$INTERVAL" "$TIMEOUT"; then
            echo "Skipping $SERVER due to unreachability"
            ALL_READY=false
	    continue  # Skip to next share instead of breaking
        fi

        # Get expected shares for this server
        IFS=',' read -ra EXPECTED_SHARES <<< "${SERVERS[$SERVER]}"

        # Verify shares are exported
        if ! SHOWMOUNT_OUTPUT=$(showmount -e "$SERVER" 2>/dev/null); then
            echo "Failed to query exports from $SERVER"
            ALL_READY=false
            break
        fi

        # Check each expected share
        for SHARE_PATH in "${EXPECTED_SHARES[@]}"; do
            if ! echo "$SHOWMOUNT_OUTPUT" | grep -q "^$SHARE_PATH "; then
                echo "Share $SHARE_PATH not found in exports from $SERVER"
                ALL_READY=false
            else
                echo "Share $SHARE_PATH is accessible on $SERVER"
            fi
        done
    done

    # If all shares are ready, proceed
    if [ "$ALL_READY" = "true" ]; then
        echo "All NFS shares are ready"
        touch /tmp/shares-ready  # Signal success for health check
        break
    fi

    echo "Retrying in $INTERVAL seconds..."
    sleep "$INTERVAL"
done

# Signal readiness and keep container running
echo "NFS checker completed successfully"
exec "$@"
