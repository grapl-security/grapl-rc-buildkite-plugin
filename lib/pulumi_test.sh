#!/usr/bin/env bash

oneTimeSetUp() {
    # shellcheck source-path=SCRIPTDIR
    source "$(dirname "${BASH_SOURCE[0]}")/pulumi.sh"
}

test_split_project() {
    assertEquals "project" "$(split_project "org/project/stack")"
}

test_split_stack() {
    assertEquals "stack" "$(split_stack "org/project/stack")"
}

test_project_directory() {
    assertEquals "root_dir/project" "$(project_directory "org/project/stack" "root_dir")"
    assertEquals "root_dir/foo_bar" "$(project_directory "org/foo-bar/stack" "root_dir")"
    assertEquals "root_dir/foo_bar_baz_quux" "$(project_directory "org/foo-bar-baz-quux/stack" "root_dir")"
    assertEquals "root_dir/boo_baz" "$(project_directory "org/boo_baz/stack" "root_dir")"
}

test_stack_file_path() {
    assertEquals "root_dir/foo_bar/Pulumi.testing.yaml" "$(stack_file_path "org/foo-bar/testing" "root_dir")"
}
