#!/bin/bash

set -euo pipefail

GUEST_USER="guest-user"
GUEST_HOME="$(getent passwd "$GUEST_USER" | cut -d: -f6)"
GUEST_HOME_SIZE="1024M"

# Only run if this is the guest user
if [[ "$PAM_USER" != "$GUEST_USER" ]]; then
    exit 0
fi

log() {
    logger -t guest-user-home -- "$*"
}

# Ensure only one session at a time
case "$PAM_TYPE" in
account)
    log "Ensuring this is the only session for $GUEST_USER"
    if loginctl list-sessions --no-legend | awk '{print $3}' | grep -qx "$GUEST_USER"; then
        log "Denied second concurrent login for $GUEST_USER"
        exit 1
    fi
    ;;

# Create the home directory
open_session)
    # Start with a fresh home directory
    mkdir -p "$GUEST_HOME"
    if mountpoint -q "$GUEST_HOME"; then
        log "Cleaning up old $GUEST_USER home $GUEST_HOME"
        rm -rf --one-file-system "$GUEST_HOME"/* "$GUEST_HOME"/.[!.]* "$GUEST_HOME"/..?* 2>/dev/null || true
    else
        log "Creating and mounting $GUEST_USER home tmpfs $GUEST_HOME"
        mount -t tmpfs -o size="$GUEST_HOME_SIZE" tmpfs "$GUEST_HOME"
    fi

    log "Copying /etc/skel and /etc/guest-user/skel into $GUEST_HOME"
    for dir in /etc/skel /etc/guest-user/skel; do
        test -d "$dir" || continue
        cp -a $dir/. "$GUEST_HOME"
    done
    chown -R "$GUEST_USER:$GUEST_USER" "$GUEST_HOME"

    log "Set up ephemeral home for $GUEST_USER at $GUEST_HOME"
    ;;

esac
