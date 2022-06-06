#!/usr/bin/env bats

load "$BATS_PLUGIN_PATH/load.bash"

# Uncomment to enable stub debugging
# export PULUMI_STUB_DEBUG=/dev/tty
# export MKTEMP_STUB_DEBUG=/dev/tty
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

# Create a (local only) git repository with enough history and
# structure to simulate a real repository that this plugin might
# operate on.
#
# Create an empty directory, change into it, and then execute this
# function.
simulate_git() {
    git init .
    mkdir -p pulumi/cicd
    cat << EOF > pulumi/cicd/Pulumi.yaml
name: cicd
runtime: python
description: Cicd Infrastructure
EOF

    cat << EOF > pulumi/cicd/Pulumi.production.yaml
config:
  aws:region: us-east-1
EOF

    cat << EOF > pulumi/cicd/Pulumi.testing.yaml
config:
  aws:region: us-east-1
EOF

    git add .
    git commit -m "initial commit"
    git branch -m "main"
    git branch rc # Create an RC branch, but don't check it out

    # Make another change to `main`. Pretend this is a PR that has merged
    echo "Hello World" > README.md
    git add README.md
    git commit -m "hello"

    # Make another commit adding another file. We will ultimately
    # delete this, in order to ensure that it doesn't persiste in the
    # rc branch.
    echo "This is a message you shouldn't be seeing" > some_other_file.txt
    git add some_other_file.txt

    mkdir -p a/deeply/nested/directory
    echo "This is another message you shouldn't see" > a/deeply/nested/directory/yet_another_file.txt
    git add a/deeply/nested/directory/yet_another_file.txt
    git commit -m "Add yet_another_file.txt"

    # Simulate a new release candidate with some artifact versions
    # added to the configuration files.
    git checkout rc
    git merge --no-commit --no-ff --strategy=ort --strategy-option=theirs --allow-unrelated-histories main
    yq eval --inplace '.config."cicd:artifacts".foo = "1.2.2"' pulumi/cicd/Pulumi.production.yaml
    yq eval --inplace '.config."cicd:artifacts".foo = "1.2.2"' pulumi/cicd/Pulumi.testing.yaml
    git add .
    git commit -m "Updated artifacts"

    # Create an "out of band" commit to rc directly. In general, this
    # shouldn't be needed, but we've had to do it on occasion to fix
    # up issues. The point of this is to ensure that no matter what is
    # on the rc branch, the content from main should take
    # priority. We'll make a change that conflicts with what's on
    # main, and then assert that it ultimately gets fixed up properly.
    echo "Hola Mundo" > README.md  # Conflict with main!
    git add README.md
    git commit -m "Spanish is cool"

    # Make another change to main
    git checkout main
    echo "===" >> README.md
    git add README.md
    git commit -m "fix markdown formatting"

    # Make another change to main to delete the files we added earlier
    git rm some_other_file.txt
    git rm a/deeply/nested/directory/yet_another_file.txt
    git commit -m "remove some files"

    # At this point, we have a main and an rc branch, are checked out
    # on main, and have a change that has not yet been merged to the
    # rc branch. This is the state this plugin will expect the
    # repository to be in when it runs.
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

    artifact_content='{"foo": "1.2.3", "bar": "4.5.6", "periods.in_key": 1}'

    stub buildkite-agent \
         "artifact download foo.json . : echo '${artifact_content}' > foo.json"

    stub mktemp \
         ": touch /tmp/tmp.000000 && echo '/tmp/tmp.000000'" \
         ": touch /tmp/tmp.000001 && echo '/tmp/tmp.000001'"

    # We use yq (installed in the testing container) to simulate
    # Pulumi... might be worth just using yq in the real code, as
    # well.

    # Each plan line represents an expected invocation, with a list of expected
    # arguments followed by a command to execute in case the arguments matched,
    # separated with a colon.
    # So, in this case, we mock out the changes that each `config set` would perform
    # on the given Pulumi stack file.
    stub pulumi \
         "login : echo 'Logged In'" \
         "config get artifacts --cwd=pulumi/cicd --config-file=/tmp/tmp.000000.yaml --stack=myorg/cicd/production : yq eval '.config.\"cicd:artifacts\"' --output-format=json /tmp/tmp.000000.yaml" \
         "config set --path artifacts.[\\\"foo\\\"] 1.2.2 --cwd=pulumi/cicd --stack=myorg/cicd/production : yq eval --inplace '.config.\"cicd:artifacts\".foo = \"1.2.2\"' pulumi/cicd/Pulumi.production.yaml" \
         "config set --path artifacts.[\\\"foo\\\"] 1.2.3 --cwd=pulumi/cicd --stack=myorg/cicd/production : yq eval --inplace '.config.\"cicd:artifacts\".foo = \"1.2.3\"' pulumi/cicd/Pulumi.production.yaml" \
         "config set --path artifacts.[\\\"bar\\\"] 4.5.6 --cwd=pulumi/cicd --stack=myorg/cicd/production : yq eval --inplace '.config.\"cicd:artifacts\".bar = \"4.5.6\"' pulumi/cicd/Pulumi.production.yaml" \
         "config set --path artifacts.[\\\"periods.in_key\\\"] 1 --cwd=pulumi/cicd --stack=myorg/cicd/production : yq eval --inplace '.config.\"cicd:artifacts\".\"periods.in_key\" = 1' pulumi/cicd/Pulumi.production.yaml" \
         "config get artifacts --cwd=pulumi/cicd --config-file=/tmp/tmp.000001.yaml --stack=myorg/cicd/testing : yq eval '.config.\"cicd:artifacts\"' --output-format=json /tmp/tmp.000001.yaml" \
         "config set --path artifacts.[\\\"foo\\\"] 1.2.2 --cwd=pulumi/cicd --stack=myorg/cicd/testing : yq eval --inplace '.config.\"cicd:artifacts\".foo = \"1.2.2\"' pulumi/cicd/Pulumi.testing.yaml" \
         "config set --path artifacts.[\\\"foo\\\"] 1.2.3 --cwd=pulumi/cicd --stack=myorg/cicd/testing : yq eval --inplace '.config.\"cicd:artifacts\".foo = \"1.2.3\"' pulumi/cicd/Pulumi.testing.yaml" \
         "config set --path artifacts.[\\\"bar\\\"] 4.5.6 --cwd=pulumi/cicd --stack=myorg/cicd/testing : yq eval --inplace '.config.\"cicd:artifacts\".bar = \"4.5.6\"' pulumi/cicd/Pulumi.testing.yaml" \
         "config set --path artifacts.[\\\"periods.in_key\\\"] 1 --cwd=pulumi/cicd --stack=myorg/cicd/testing : yq eval --inplace '.config.\"cicd:artifacts\".\"periods.in_key\" = 1' pulumi/cicd/Pulumi.testing.yaml"

    # We have to be able to write the downloaded artifact file
    # into the directory; hard to do that when it's mounted read-only
    script="${PWD}/hooks/command"
    cd "${BATS_TMPDIR}"

    git config --global user.name "${GIT_AUTHOR_NAME}"
    git config --global user.email "${GIT_AUTHOR_EMAIL}"

    # Create a repository to work on
    mkdir fake_repo
    (
        cd fake_repo
        simulate_git
    )

    # Create a shallow clone of that repository; we'll operate out of
    # this checkout for the remainder of the test
    git clone --depth=1 "file://$(pwd)/fake_repo" fake_checkout
    cd fake_checkout

    # Assert that the checked-out branch is a "grafted" commit
    # (because we're using a shallow clone)
    run git log --oneline --decorate --max-count=1
    assert_output --partial "grafted"

    # Now, actually run the command
    run "${script}"
    assert_success

expected_stack_config=$(
        cat << EOF
config:
  aws:region: us-east-1
  cicd:artifacts:
    foo: 1.2.3
    bar: 4.5.6
    periods.in_key: 1
EOF
                 )

    # Basic sanity check to ensure that our configuration files look
    # like we expect.
    assert_equal "$(cat pulumi/cicd/Pulumi.production.yaml)" "${expected_stack_config}"
    assert_equal "$(cat pulumi/cicd/Pulumi.testing.yaml)" "${expected_stack_config}"

    expected_readme=$(cat << EOF
Hello World
===
EOF
                   )

    # Basic sanity check to ensure that changes from the main branch
    # are preferred.
    assert_equal "$(cat README.md)" "${expected_readme}"

    # The files we deleted on `main` shouldn't be there anymore in `rc`
    run cat some_other_file.txt
    assert_failure

    run cat a/deeply/nested/directory/yet_another_file.txt
    assert_failure

    unstub buildkite-agent
    unstub mktemp
    unstub pulumi
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
