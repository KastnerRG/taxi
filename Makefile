SHELL := /bin/bash

USR           := $(shell id -un)
UID           := $(shell id -u)
GID           := $(shell id -g)
HOSTNAME_VAR  := $(shell bash -lc 'echo $${USER:0:3}')

IMAGE         := $(USR)/verilator-gtkwave:5.048
CONTAINER     := verilator-$(USR)
CMD           := verilator --version
WAVE          :=

# Mount the superproject root if this directory is inside a larger git repo.
HOST_SUPERPROJECT := $(shell git -C $(CURDIR) rev-parse --show-superproject-working-tree 2>/dev/null)
HOST_GIT_ROOT     := $(if $(HOST_SUPERPROJECT),$(HOST_SUPERPROJECT),$(CURDIR))
PROJECT_WRT_GIT_ROOT := $(shell realpath --relative-to="$(HOST_GIT_ROOT)" "$(CURDIR)" 2>/dev/null || echo .)

CONT_GIT_ROOT     := /repo
CONT_PROJECT_ROOT := $(if $(filter .,$(PROJECT_WRT_GIT_ROOT)),$(CONT_GIT_ROOT),$(CONT_GIT_ROOT)/$(PROJECT_WRT_GIT_ROOT))
CONT_WS           := $(CONT_PROJECT_ROOT)

.PHONY: image start enter run gtkwave test fresh restart kill clean

fresh: kill image start enter

restart: kill start enter

image:
	docker build \
		-f Dockerfile \
		--build-arg UID=$(UID) \
		--build-arg GID=$(GID) \
		--build-arg USERNAME=$(USR) \
		--build-arg CONT_WS=$(CONT_WS) \
		--build-arg VERILATOR_VERSION=v5.048 \
		-t $(IMAGE) .

start:
	- xhost +Local:docker 2>/dev/null || true
	@echo "HOST_GIT_ROOT     = $(HOST_GIT_ROOT)"
	@echo "CONT_GIT_ROOT     = $(CONT_GIT_ROOT)"
	@echo "CONT_WS           = $(CONT_WS)"
	docker run -d --name $(CONTAINER) \
		-h $(HOSTNAME_VAR) \
		-e DISPLAY=$(DISPLAY) \
		-e CONT_WS=$(CONT_WS) \
		--tty --interactive \
		-v /tmp/.X11-unix:/tmp/.X11-unix \
		-v $(HOST_GIT_ROOT):$(CONT_GIT_ROOT) \
		-w $(CONT_WS) \
		$(IMAGE) tail -f /dev/null

enter:
	docker exec -it $(CONTAINER) bash -i

run:
	docker exec -it $(CONTAINER) /bin/bash -ic 'cd "$$CONT_WS" && $(CMD)'

gtkwave:
	docker exec -it $(CONTAINER) /bin/bash -ic 'cd "$$CONT_WS" && gtkwave $(WAVE)'

test:
	docker exec -it $(CONTAINER) /bin/bash -ic '\
		which verilator && \
		verilator --version && \
		which gtkwave && \
		gtkwave --version | head -n 1 || true'

kill:
	- docker kill $(CONTAINER) || true
	- docker rm $(CONTAINER) || true

clean:
	- rm -rf obj_dir
	- rm -f *.vcd *.fst *.log