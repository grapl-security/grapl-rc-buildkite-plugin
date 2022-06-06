FROM buildkite/plugin-tester:v2.0.0

# We need `git` for our tests, and it must have the 'ort' merge
# strategy (introduced in 2.33).
RUN apk add --no-cache git=2.34.2-r0

# Add yq to make it easier to manipulate Pulumi stack files during a test.
ARG YQ_VERSION=v4.25.1
# https://github.com/hadolint/hadolint/wiki/DL3047
#
# The `wget` in this image is from busybox, and doesn't support the
# progress-related flags that DL3047 suggests.
#
# This is not a large file, though, so in the end, it's not really
# very important.
# hadolint ignore=DL3047
RUN wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq
