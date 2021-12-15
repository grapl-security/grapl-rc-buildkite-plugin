#!/usr/bin/env bash

set -euo pipefail

artifact_contents() {
    local -r _artifact_name="${1}"
    buildkite-agent artifact download "${_artifact_name}" .
    jq -r '.' "${_artifact_name}"
}
