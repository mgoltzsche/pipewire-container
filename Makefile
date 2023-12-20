# DO NOT EDIT THIS FILE MANUALLY!
# This file is maintained within the upstream kpt package (see Kptfile).
# Committing manual changes to this file, disables blueprint updates.

KPT_IMAGE ?= mgoltzsche/kpt-docker:1.0.0-beta.32
KPT_PKG_UPDATE_STRATEGY ?= resource-merge
SKAFFOLD_IMAGE ?= gcr.io/k8s-skaffold/skaffold:v2.9.0
SKAFFOLD_OPTS ?=
KUBECONFIG ?= $$HOME/.kube/config

DOCKER ?= docker

# Include a custom Makefile if exists.
sinclude Makefile-ext.mk

.DEFAULT_GOAL := all

.PHONY: all
all: image

##@ Build

.PHONY: image
image: skaffold-build ## Build the image(s) for the host architecture.

##@ Deploy

.PHONY: deploy
deploy: skaffold-run ## Deploy the application into the selected cluster.
.PHONY: undeploy
undeploy: skaffold-delete ## Undeploy the debug application.

.PHONY: debug
debug: SKAFFOLD_OPTS += --auto-build
debug: skaffold-debug ## Deploy the application in debug mode.

##@ Development

.PHONY: render
render: kpt-fn-render ## Run kpt render pipeline, applying setters.yaml.
kpt-fn-render: kpt-fn-%:
	$(DOCKER) run -i --rm -u "`id -u`:`id -g`" --group-add 998 \
		-v "/var/run/docker.sock:/var/run/docker.sock" \
		-v "`pwd`:/workspace" \
		$(KPT_IMAGE) fn $* /workspace --truncate-output=false

.PHONY: blueprint-update
blueprint-update: kpt-pkg-update render ## Apply the latest blueprint updates to this codebase.

kpt-pkg-update:
	mkdir -p $$HOME/.kpt
	$(DOCKER) run --rm -u "`id -u`:`id -g`" -v "$$HOME/.kpt:/.kpt" \
		-v `pwd`:/data -w /data \
		$(KPT_IMAGE) pkg update --strategy=$(KPT_PKG_UPDATE_STRATEGY) .

skaffold-debug skaffold-dev: DOCKER_RUN_OPTS += -ti
skaffold-debug skaffold-dev skaffold-run skaffold-stop skaffold-delete: DOCKER_RUN_OPTS += --mount "type=bind,src=$(KUBECONFIG),dst=/tmp/.kube/config,ro"
skaffold-run skaffold-stop skaffold-build skaffold-dev skaffold-delete skaffold-debug skaffold-survey skaffold-help: skaffold-%:
	mkdir -p $$HOME/.docker
	$(DOCKER) run $(DOCKER_RUN_OPTS) --rm -u "`id -u`:`id -g`" --group-add=998 \
		-v "`pwd`:/workspace" -w /workspace --network=host \
		-v "/var/run/docker.sock:/var/run/docker.sock" \
		--mount "type=bind,src=$$HOME/.docker,dst=/tmp/.docker" \
		-e HOME=/tmp \
		$(SKAFFOLD_IMAGE) skaffold $* $(SKAFFOLD_OPTS)

.PHONY: help
help: ## Display this help.
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Release

.PHONY: push-image
push-image: REGISTRY ?= ghcr.io
push-image: SKAFFOLD_OPTS += --profile=release --default-repo=$(REGISTRY)
push-image: skaffold-build ## Build and push the multi-arch image(s).

.PHONY: binfmt-config
binfmt-config: ## Enable multi-arch support on the host.
	$(DOCKER) run --rm --privileged multiarch/qemu-user-static:7.2.0-1 --reset -p yes

.PHONY: release ## Build and push multi-arch image
release: SKAFFOLD_OPTS += -t '$(VERSION)'
release: require-version require-clean-worktree manifest-image binfmt-config push-image
	make push-image VERSION=latest REGISTRY=$(REGISTRY)

.PHONY: manifest-image
manifest-image: set-version render

.PHONY: set-version
set-version: require-version
	$(DOCKER) run --rm -v "$$PWD":/workdir -u "`id -u`:`id -g`" -e VERSION mikefarah/yq:4.29.2 -i '.data.version = env(VERSION)' setters.yaml

.PHONY: require-version
require-version:
	@[ ! "$(VERSION)" = '' ] || (echo no VERSION specified >&2; false)

.PHONY: require-clean-worktree
require-clean-worktree:
	@[ -z "`git status --untracked-files=no --porcelain`" ] || (\
		echo 'ERROR: the build changed files that are tracked by git:'; \
		git status --untracked-files=no --porcelain | sed -E 's/^/  /'; \
		echo 'Please run `make render` and commit the resulting changes!'; \
		false) >&2
