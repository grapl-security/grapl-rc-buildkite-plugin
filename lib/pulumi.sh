#!/usr/bin/env bash

# Pulumi Helper Functions

# When managing multiple projects and their stacks, we'll pass around
# qualified names in the form of `organization/project/stack`.
#
# Because of how we are currently organizing the code for our
# projects, they are stored in directories that are valid Python
# module names (specifically, they use underscores rather than
# hyphens). The formal project name in Pulumi, however, uses hyphens
# instead of underscores (mainly for cosmetic purposes, avoiding a
# mixture of hyphens and underscores in various generated names).
#
# We can account for this distinction with helper functions.

# shellcheck source-path=SCRIPTDIR
source "$(dirname "${BASH_SOURCE[0]}")/log.sh"

_split_stack_reference() {
    local -r input="${1}"
    local -r field_num="${2}"

    num_fields="$(awk -F'/' '{print NF; exit}' <<< "${input}")"
    if ((num_fields != 3)); then
        raise_error "Stack reference '${input}' should have 3 segments; it has ${num_fields}!"
    fi

    # Busybox `cut` doesn't recognize long options :(
    # -s == --only-delimited
    # -f == --fields
    # -d == --delimiter
    field="$(cut -s "-f${field_num}" -d/ <<< "${input}")"
    if [ -z "${field}" ]; then
        raise_error "Field '${field_num}' of stack reference '${input}' was empty!"
    else
        echo "${field}"
    fi
}

# Extract the project name from a stack reference.
#
#     split_project "myorg/foo/bar"
#     # => foo
#
split_project() {
    _split_stack_reference "${1}" 2
}

# Extract the stack name from a stack reference.
#
#     split_project "myorg/foo/bar"
#     # => bar
#
split_stack() {
    _split_stack_reference "${1}" 3
}

# Returns the full path (from the repository root) of the directory
# for the given Pulumi stack reference.
#
# Translates `-` to `_` in the project name, in keeping with our
# convention.
#
#     project_directory "myorg/foo-bar/testing" "pulumi"
#     # => pulumi/foo_bar
#
project_directory() {
    local -r stack_ref="${1}"
    local -r root_dir="${2}"

    local -r dir_name="$(split_project "${stack_ref}" | tr - _)"
    echo "${root_dir}/${dir_name}"
}

# Expand a stack reference into the full path (from the root of the
# repository) to its corresponding configuration file.
#
#     stack_file_path "myorg/foo-bar/testing" "pulumi"
#     # => pulumi/foo_bar/Pulumi.testing.yaml
#
stack_file_path() {
    local -r stack_ref="${1}"
    local -r root_dir="${2}"

    local -r project_dir="$(project_directory "${stack_ref}" "${root_dir}")"
    local -r stack="$(split_stack "${stack_ref}")"

    echo "${project_dir}/Pulumi.${stack}.yaml"
}
