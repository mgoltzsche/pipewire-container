PLATFORM ?= linux/amd64

PIPEWIRE_IMAGE ?= mgoltzsche/pipewire:latest

PIPEWIRE_BUILD_OPTS ?= -t $(PIPEWIRE_IMAGE)

BUILDX_BUILDER ?= pipewire-builder
BUILDX_OUTPUT ?= type=docker
BUILDX_OPTS ?= --builder=$(BUILDX_BUILDER) --output=$(BUILDX_OUTPUT) --platform=$(PLATFORM)
DOCKER ?= docker
DOCKER_COMPOSE ?= $(if $(shell which podman-compose),podman-compose,docker-compose)

all: pipewire

pipewire:
	$(DOCKER) build --force-rm $(PIPEWIRE_BUILD_OPTS) .

create-builder:
	$(DOCKER) buildx inspect $(BUILDX_BUILDER) >/dev/null 2<&1 || $(DOCKER) buildx create --name=$(BUILDX_BUILDER) >/dev/null

delete-builder:
	$(DOCKER) buildx rm $(BUILDX_BUILDER)

compose-up:
	$(DOCKER_COMPOSE) up --build

compose-down:
	$(DOCKER_COMPOSE) down -v --remove-orphans

compose-stop:
	$(DOCKER_COMPOSE) stop

compose-rm:
	$(DOCKER_COMPOSE) rm -sf
