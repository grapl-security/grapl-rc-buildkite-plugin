DOCKER_COMPOSE_CHECK := docker compose run --rm
PANTS_SHELL_FILTER := ./pants --filter-target-type=shell_source,shunit2_test

.DEFAULT_GOAL=all

.PHONY: all
all: format
all: lint
all: test
all: ## Run all operations

.PHONY: help
help: ## Print this help
	@awk 'BEGIN {FS = ":.*##"; printf "Usage: make <target>\n"} \
		 /^[a-zA-Z0-9_-]+:.*?##/ { printf "  %-46s %s\n", $$1, $$2 } \
		 /^##@/ { printf "\n%s\n", substr($$0, 5) } ' \
		 $(MAKEFILE_LIST)
	@printf '\n'

##@ Linting
########################################################################

.PHONY: lint
lint: lint-docker
lint: lint-plugin
lint: lint-shell
lint: ## Perform lint checks on all files

.PHONY: lint-docker
lint-docker: ## Lint Dockerfiles
	./pants --filter-target-type=docker_image lint ::

.PHONY: lint-plugin
lint-plugin: ## Lint the Buildkite plugin metadata
	$(DOCKER_COMPOSE_CHECK) plugin-linter

.PHONY: lint-shell
lint-shell: ## Lint the shell scripts
	$(PANTS_SHELL_FILTER) lint ::

##@ Formatting
########################################################################

.PHONY: format
format: format-shell
format: ## Automatically format all code

.PHONY: format-shell
format-shell: ## Format shell scripts
	$(PANTS_SHELL_FILTER) fmt ::

##@ Testing
########################################################################

.PHONY: test
test: test-shell
test: test-plugin
test: ## Run all tests

.PHONY: test-shell
test-shell: ## Unit test shell scripts
	./pants test ::

.PHONY: test-plugin
test-plugin: ## Test the Buildkite plugin locally (does *not* run a Buildkite pipeline)
# Only running `build` here to ensure we have our latest changes
# to the plugin-tester container; see plugin-tester.Dockerfile for
# more.
	docker compose build && $(DOCKER_COMPOSE_CHECK) plugin-tester
