#!/usr/bin/env bash

flatten_json() {
    # The purpose of this module is to convert something like the following json:
    # {
    #     "some-amis": {
    #         "us-east-1": "ami-111",
    #     },
    #     "periods.in.this.key": 1,
    # }
    # into
    # {
    #     '["some-amis"].["us-east-1"]': "ami-111",
    #     '["periods.in.this.key"]': 1,
    # }

    local -r input_json="${1}"
    # https://stackoverflow.com/a/37557003
    jq -r '
        # Avoids https://github.com/grapl-security/issue-tracker/issues/864
        def escape_key: "[\"" + . + "\"]";

        . as $in
        | reduce paths(scalars) as $path (
            {};
            . + { ($path | map(tostring) | map(escape_key) | join(".")): $in | getpath($path) }
        )
    ' <<< "${input_json}"
}
