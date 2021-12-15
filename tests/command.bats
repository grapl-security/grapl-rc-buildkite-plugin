#!/usr/bin/env bats

load "$BATS_PATH/load.bash"

# Uncomment to enable stub debugging
# export PULUMI_STUB_DEBUG=/dev/tty
# export GIT_STUB_DEBUG=/dev/tty
# export BUILDKITE_AGENT_STUB_DEBUG=/dev/tty

teardown() {
    unset BUILDKITE_PLUGIN_GRAPL_RC_PROJECT_ROOT_DIR
    unset BUILDKITE_PLUGIN_GRAPL_RC_ARTIFACT_FILE
    unset BUILDKITE_PLUGIN_GRAPL_RC_STACKS_0
    unset BUILDKITE_PLUGIN_GRAPL_RC_STACKS_1

    unset GIT_AUTHOR_NAME
    unset GIT_AUTHOR_EMAIL

    unset BUILDKITE_BUILD_URL
    unset BUILDKITE_SOURCE
}

@test "Create an RC" {
    export BUILDKITE_PLUGIN_GRAPL_RC_PROJECT_ROOT_DIR=pulumi
    export BUILDKITE_PLUGIN_GRAPL_RC_ARTIFACT_FILE="foo.json"
    export BUILDKITE_PLUGIN_GRAPL_RC_STACKS_0="myorg/cicd/production"
    export BUILDKITE_PLUGIN_GRAPL_RC_STACKS_1="myorg/cicd/testing"

    export BUILDKITE_BUILD_URL=blahblah
    export BUILDKITE_SOURCE=webhook

    export GIT_AUTHOR_NAME="Testy McTestface"
    export GIT_AUTHOR_EMAIL="tests@example.com"

    artifact_content='{"foo": "1.2.3", "bar": "4.5.6"}'

    stub buildkite-agent \
         "artifact download foo.json . : echo '${artifact_content}' > foo.json"

    stub pulumi \
         "login : echo 'Logged In'" \
         "config get artifacts --cwd=pulumi/cicd --stack=myorg/cicd/production : echo '{}'" \
         "config set --path artifacts.foo 1.2.3 --cwd=pulumi/cicd --stack=myorg/cicd/production : echo 'set foo in production'" \
         "config set --path artifacts.bar 4.5.6 --cwd=pulumi/cicd --stack=myorg/cicd/production : echo 'set bar in production'" \
         "config get artifacts --cwd=pulumi/cicd --stack=myorg/cicd/testing : echo '{}'" \
         "config set --path artifacts.foo 1.2.3 --cwd=pulumi/cicd --stack=myorg/cicd/testing : echo 'set foo in testing'" \
         "config set --path artifacts.bar 4.5.6 --cwd=pulumi/cicd --stack=myorg/cicd/testing : echo 'set bar in testing'"

    stub git "checkout rc : echo 'checking out rc'" \
         "config user.name 'Testy McTestface' : echo 'set user.name'" \
         "config user.email tests@example.com : echo 'set user.email'" \
         "merge --no-ff --no-commit --strategy=recursive --strategy-option=ours main : echo 'begin merge'" \
         "show main:pulumi/cicd/Pulumi.production.yaml : echo 'FAKE PRODUCTION STACK CONFIGURATION'" \
         "add --verbose pulumi/cicd/Pulumi.production.yaml : echo 'add stack file'" \
         "show main:pulumi/cicd/Pulumi.testing.yaml : echo 'FAKE TESTING STACK CONFIGURATION'" \
         "add --verbose pulumi/cicd/Pulumi.testing.yaml : echo 'add stack file'" \
         "commit --message=\"Create new release candidate with updated deployment artifacts\n\nUpdated the following artifact versions:\n\n- foo => 1.2.3\n- bar => 4.5.6\n\nGenerated from blahblah\" : echo 'commit'" \
         "--no-pager show : echo 'show commit'" \
         "push --verbose : echo 'push'"

    # We have to be able to write the downloaded artifact file
    # into the directory; hard to do that when it's mounted read-only
    script="${PWD}/hooks/command"
    cd "${BATS_TMPDIR}"

    # Add some expected directory structure
    mkdir -p pulumi/cicd/

    run "${script}"

    assert_success

    unstub buildkite-agent
    unstub pulumi
    unstub git
}

@test "Ensure that a file is required" {
    export BUILDKITE_PLUGIN_GRAPL_RC_PROJECT_ROOT_DIR=pulumi
    unset BUILDKITE_PLUGIN_GRAPL_RC_ARTIFACT_FILE
    export BUILDKITE_PLUGIN_GRAPL_RC_STACKS_0="myorg/cicd/production"
    export BUILDKITE_PLUGIN_GRAPL_RC_STACKS_1="myorg/cicd/testing"

    run "${PWD}/hooks/command"

    assert_output --partial "You must specify the name of an artifact file to download"
    assert_failure
}

@test "Ensure that a stack is required" {
    export BUILDKITE_PLUGIN_GRAPL_RC_PROJECT_ROOT_DIR=pulumi
    export BUILDKITE_PLUGIN_GRAPL_RC_ARTIFACT_FILE=foo.json

    artifact_content='{"foo": "1.2.3", "bar": "4.5.6"}'

    stub buildkite-agent \
         "artifact download foo.json . : echo '${artifact_content}' > foo.json"

    # We have to be able to write the downloaded artifact file
    # into the directory; hard to do that when it's mounted read-only
    script="${PWD}/hooks/command"
    cd "${BATS_TMPDIR}"
    run $script

    assert_output --partial "You must specify at least one Pulumi stack to operate on"
    assert_failure
}
