IMAGE ?= tech-study-guide-jekyll
PORT ?= 4030
CONTAINER_PREFIX ?= tech-study-guide
COMPOSE_PROJECT_NAME ?= tech-study-guide

.PHONY: help docker-build build test check serve stop clean

help:
	@printf "Targets:\n"
	@printf "  make docker-build  Build the local Jekyll Docker image\n"
	@printf "  make build         Build the static site into _site\n"
	@printf "  make test          Build and test the generated site HTML\n"
	@printf "  make check         Alias for make test\n"
	@printf "  make serve         Serve locally at http://127.0.0.1:$(PORT)/\n"
	@printf "  make stop          Stop running Docker containers for this site\n"
	@printf "  make clean         Remove generated Jekyll output\n"
	@printf "\nVariables:\n"
	@printf "  PORT=4030          Local host port for make serve\n"
	@printf "  IMAGE=$(IMAGE)     Docker image name\n"
	@printf "  CONTAINER_PREFIX=$(CONTAINER_PREFIX)  Container name prefix to stop\n"
	@printf "  COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME)  Compose project name\n"

docker-build:
	docker build -t $(IMAGE) .

build: docker-build
	docker run --rm -e JEKYLL_ENV=production -v "$(PWD):/site" -w /site $(IMAGE) bundle exec jekyll build

test: build
	docker run --rm -v "$(PWD):/site" -w /site $(IMAGE) ruby test/site_test.rb

check: test

serve: docker-build
	@set +e; \
	PORT=$(PORT) IMAGE=$(IMAGE) CONTAINER_PREFIX=$(CONTAINER_PREFIX) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME) docker compose up --build --remove-orphans; \
	status=$$?; \
	PORT=$(PORT) IMAGE=$(IMAGE) CONTAINER_PREFIX=$(CONTAINER_PREFIX) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME) docker compose down --remove-orphans; \
	if [ $$status -ne 0 ] && [ $$status -ne 1 ] && [ $$status -ne 130 ]; then exit $$status; fi

stop:
	@PORT=$(PORT) IMAGE=$(IMAGE) CONTAINER_PREFIX=$(CONTAINER_PREFIX) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME) docker compose down --remove-orphans
	@containers=$$(docker ps --filter "name=$(CONTAINER_PREFIX)" --format '{{.Names}}'); \
	if [ -n "$$containers" ]; then \
		printf "%s\n" "$$containers" | xargs docker stop; \
	else \
		printf "No running containers found for %s\n" "$(CONTAINER_PREFIX)"; \
	fi

clean: docker-build
	docker run --rm -v "$(PWD):/site" -w /site $(IMAGE) bundle exec jekyll clean
