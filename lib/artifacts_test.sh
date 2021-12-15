#!/usr/bin/env bash

# mock `buildkite-agent` binary
buildkite-agent() {
    echo "${FUNCNAME[0]} $*" >> "${ALL_COMMANDS}"

    case "$*" in
        artifact\ download\ existing_file.json\ .)
            echo '{"foo": "1.2.3"}' > existing_file.json
            ;;
        artifact\ download\ non_existent_file.json\ .)
            return 1
            ;;
        *)
            return 2
            ;;
    esac
}

recorded_commands() {
    if [ -f "${ALL_COMMANDS}" ]; then
        cat "${ALL_COMMANDS}"
    fi
}

oneTimeSetUp() {
    export BUILDKITE_BUILD_URL="https://buildkite.com/grapl/pipeline-infrastructure-verify/builds/2112"
    export ALL_COMMANDS="${SHUNIT_TMPDIR}/all_commands"

    # shellcheck source-path=SCRIPTDIR
    source "$(dirname "${BASH_SOURCE[0]}")/artifacts.sh"
}

setUp() {
    # Ensure any recorded commands from the last test are removed so
    # we start with a clean slate.
    rm -f "${ALL_COMMANDS}"
}

test_artifact_contents_existing_file() {

    output=$(artifact_contents existing_file.json)
    expected_output=$(
        cat << EOF
{
  "foo": "1.2.3"
}
EOF
    )

    expected_commands=$(
        cat << EOF
buildkite-agent artifact download existing_file.json .
EOF
    )

    assertEquals "The expected output did not match" \
        "${expected_output}" \
        "${output}"

    assertEquals "The expected buildkite-agent commands were not run" \
        "${expected_commands}" \
        "$(recorded_commands)"
}

test_artifact_contents_non_existent_file() {

    output=$(artifact_contents non_existent_file.json)
    expected_output="{}"

    expected_commands=$(
        cat << EOF
buildkite-agent artifact download non_existent_file.json .
EOF
    )

    assertEquals "The expected output did not match" \
        "${expected_output}" \
        "${output}"

    assertEquals "The expected buildkite-agent commands were not run" \
        "${expected_commands}" \
        "$(recorded_commands)"
}
