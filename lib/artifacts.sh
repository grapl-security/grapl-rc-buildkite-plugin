#!/usr/bin/env bash

artifact_contents() {
    local -r _artifact_name="${1}"
    if (buildkite-agent artifact download "${_artifact_name}" .); then
        jq -r '.' "${_artifact_name}"
    else
        echo '{}'
    fi
}
