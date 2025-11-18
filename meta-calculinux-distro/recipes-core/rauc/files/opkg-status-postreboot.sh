#!/bin/sh
set -eu

LOG_PREFIX="opkg-status-postreboot"
PENDING_REINSTALL_FILE="/var/lib/opkg/opkg-status-hook.pending-reinstalls"
PENDING_UPGRADE_FILE="/var/lib/opkg/opkg-status-hook.pending-upgrades"

log() {
    echo "${LOG_PREFIX}: $*" >&2
}

have_work=0
if [ -s "${PENDING_REINSTALL_FILE}" ] || [ -s "${PENDING_UPGRADE_FILE}" ]; then
    have_work=1
fi

if [ "${have_work}" -eq 0 ]; then
    exit 0
fi

if ! opkg update; then
    log "opkg update failed; will retry on next boot"
    exit 1
fi

process_list() {
    list_file="$1"
    action="$2"
    if [ ! -s "${list_file}" ]; then
        return 0
    fi

    status=0
    while IFS= read -r pkg; do
        [ -z "${pkg}" ] && continue
        if ! ${action} "${pkg}"; then
            log "warning: ${action} ${pkg} failed"
            status=1
        fi
    done < "${list_file}"

    return "${status}"
}

install_pkg() {
    opkg install --force-reinstall "$1"
}

upgrade_pkg() {
    opkg upgrade "$1"
}

reinstall_status=0
upgrade_status=0

if process_list "${PENDING_REINSTALL_FILE}" install_pkg; then
    rm -f "${PENDING_REINSTALL_FILE}"
else
    reinstall_status=1
fi

if process_list "${PENDING_UPGRADE_FILE}" upgrade_pkg; then
    rm -f "${PENDING_UPGRADE_FILE}"
else
    upgrade_status=1
fi

if [ "${reinstall_status}" -eq 0 ] && [ "${upgrade_status}" -eq 0 ]; then
    log "post-reboot package reconciliation complete"
    exit 0
fi

log "post-reboot reconciliation incomplete; will retry on next boot"
exit 1
