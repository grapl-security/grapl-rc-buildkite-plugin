FROM buildkite/plugin-tester:latest

# Add the edge repository so we can pick up a git that has the 'ort'
# merge strategy (introduced in 2.33); the version of Alpine the
# `buildkite/plugin-tester` container currently has is too old.
#
# If this ever gets updated, we can remove these two lines
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/main" >> /etc/apk/repositories
RUN apk update && apk add git=2.36.1-r0

# Add yq to make it easier to manipulate Pulumi stack files during a test.
ARG YQ_VERSION=v4.25.1
RUN wget https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64 -O /usr/bin/yq && chmod +x /usr/bin/yq
