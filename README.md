# Grapl Release Candidate Buildkite Plugin

Encapsulates logic to create a "release candidate" for Grapl CI/CD
pipelines. This is tailored to how we do releases at Grapl, and no
attempt at generality is made.

## Overview

The second stage of a Grapl CI/CD pipeline runs after a PR merges (the
first stage is to actually verify the code in the PR before the
merge). This stage is responsible for building and uploading any
artifacts necessary, and recording their versions in the Git
repository. We do this by embedding the artifact versions in Pulumi
stack configuration files and then adding these updated files to a
commit on an `rc` ("release candidate") branch. In keeping with
"infrastructure as code" practices, subsequent testing pipelines are
run from this `rc` branch, using the specific artifacts that were
built earlier.

This plugin captures all the necessary logic to perform the Pulumi and
Git manipulations needed to create such release candidates.

## Underlying Assumptions

- This plugin is run on the `main` branch of a repository
- There is an `rc` branch in the repository; merge commits from `main`
  are made to the `rc` branch, and subsequent testing pipelines are
  run from there.
- Artifacts are created in this pipeline and versions are recorded in
  a JSON file uploaded as a Buildkite Artifact. This is an
  intermediate step prior to embedding the artifact versions in a
  Pulumi configuration file.
- Artifacts and versions are "pinned" as Pulumi stack configuration
  (under the `artifacts` key) for some number of Pulumi projects
  within the repository. All projects in the repository do not
  necessarily need to be listed if they require no artifacts.
- All Pulumi projects in the repository are stored in the same
  directory (e.g., `pulumi/project_1`, `pulumi/project_2`, and so on).
- All specified Pulumi stack configurations receive the same artifact pins
  (regardless of whether each stack _needs_ all of them).
- The new Pulumi stack configuration files are written into the merge
  commit to the `rc` branch.

Currently, it is assumed that the creation of a "release candidate"
necessarily requires one or more Pulumi projects. This is more of a
reflection of our existing code and its structure than any
philosophical stance.

Centralizing the logic for our release candidates in a plugin provides
an easy way to centrally update the logic for all our pipelines as our
practices develop over time.

## Usage

```yaml
steps:
  - label: ":medal: Create new release candidate"
    plugins:
      - grapl-security/grapl-rc#v0.1.6:
          project_root_dir: pulumi
          artifact_file: all_artifacts.json
          stacks:
            - grapl/cicd/testing
            - grapl/cicd/production
```

Here, `all_artifacts.json` is a file that can be downloaded via
`buildkite-agent artifact download`, and has a structure like this:

```json
{
    "frontend": "v1.2.3",
    "backend": "v2.3.4"
}
```
These are mappings of artifact names to version identifiers.

## Configuration

### project\_root\_dir (optional, string)

The directory that all Pulumi projects are stored in. Defaults to `pulumi`.

#### artifact_file (required, string)

The name of a file containing a JSON object representing the artifacts
generated during this pipeline run. It is assumed that this file has
been uploaded as a Buildkite artifact, and will thus be automatically
downloaded via `buildkite-agent artifact download`.

#### stacks (required, string array)

A list of the Pulumi stacks whose configuration needs to be updated
with new artifacts. Identifiers must be given in their fully-qualified
`organization/project/stack` form.

(Even though we will generally have the same organization for all
stack references, we do this to make things easy and
non-surprising. This makes it easy to identify the _project_ without
having to add extra plugin configuration, and without having to create
some non-standard Pulumi reference, like `project/stack`.)

## Building

Requires `make`, `docker`, and `docker-compose`.

Running `make` will run all formatting, linting, and testing.
