#!/usr/bin/env bash

set -euo pipefail

log() {
    echo -e "${@}" >&2
}

raise_error() {
    log "--- :rotating_light:" "${@}"
    # Yes, these numbers are correct :/
    if [ -z "${BASH_SOURCE[2]:-}" ]; then
        # If we're calling raise_error from a script directly, we'll
        # have a shorter call stack.
        log "Failed in ${FUNCNAME[1]}() at [${BASH_SOURCE[1]}:${BASH_LINENO[0]}]"
    else
        log "Failed in ${FUNCNAME[1]}() at [${BASH_SOURCE[1]}:${BASH_LINENO[0]}], called from [${BASH_SOURCE[2]}:${BASH_LINENO[1]}]"
    fi
    exit 1
}
