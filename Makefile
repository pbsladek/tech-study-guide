IMAGE ?= tech-study-guide-jekyll
PORT ?= 4030
CONTAINER_PREFIX ?= tech-study-guide
COMPOSE_PROJECT_NAME ?= tech-study-guide

.PHONY: help docker-build build test e2e check test-all serve stop cleanup clean

help:
	@printf "Targets:\n"
	@printf "  make docker-build  Build the local Jekyll Docker image\n"
	@printf "  make build         Build the static site into _site\n"
	@printf "  make test          Build and test the generated site HTML\n"
	@printf "  make e2e           Run Playwright browser tests\n"
	@printf "  make check         Alias for make test-all\n"
	@printf "  make test-all      Run generated HTML tests and Playwright tests\n"
	@printf "  make serve         Serve locally at http://127.0.0.1:$(PORT)/\n"
	@printf "  make stop          Stop running Docker containers for this site\n"
	@printf "  make cleanup       Alias for make stop\n"
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

e2e:
	@set +e; \
	cleanup() { PORT=$(PORT) IMAGE=$(IMAGE) CONTAINER_PREFIX=$(CONTAINER_PREFIX) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME) docker compose down --remove-orphans; }; \
	trap cleanup EXIT INT TERM; \
	cleanup; \
	PORT=$(PORT) IMAGE=$(IMAGE) CONTAINER_PREFIX=$(CONTAINER_PREFIX) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME) docker compose up -d --build --remove-orphans; \
	status=$$?; \
	if [ $$status -eq 0 ]; then \
		for attempt in $$(seq 1 60); do \
			curl -fs "http://127.0.0.1:$(PORT)/" >/dev/null 2>&1 && break; \
			sleep 1; \
		done; \
		curl -fsS "http://127.0.0.1:$(PORT)/" >/dev/null; \
		status=$$?; \
	fi; \
	if [ $$status -eq 0 ]; then \
		BASE_URL=http://127.0.0.1:$(PORT) npm run test:e2e; \
		status=$$?; \
	fi; \
	exit $$status

check: test-all

test-all: test e2e

serve: docker-build
	@set +e; \
	cleanup() { PORT=$(PORT) IMAGE=$(IMAGE) CONTAINER_PREFIX=$(CONTAINER_PREFIX) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME) docker compose down --remove-orphans; }; \
	trap cleanup EXIT INT TERM; \
	PORT=$(PORT) IMAGE=$(IMAGE) CONTAINER_PREFIX=$(CONTAINER_PREFIX) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME) docker compose up --build --remove-orphans; \
	status=$$?; \
	trap - EXIT INT TERM; \
	cleanup; \
	if [ $$status -ne 0 ] && [ $$status -ne 1 ] && [ $$status -ne 130 ]; then exit $$status; fi

stop:
	@PORT=$(PORT) IMAGE=$(IMAGE) CONTAINER_PREFIX=$(CONTAINER_PREFIX) COMPOSE_PROJECT_NAME=$(COMPOSE_PROJECT_NAME) docker compose down --remove-orphans
	@containers=$$(docker ps --filter "name=$(CONTAINER_PREFIX)" --format '{{.Names}}'); \
	if [ -n "$$containers" ]; then \
		printf "%s\n" "$$containers" | xargs docker stop; \
	else \
		printf "No running containers found for %s\n" "$(CONTAINER_PREFIX)"; \
	fi

cleanup: stop

clean: docker-build
	docker run --rm -v "$(PWD):/site" -w /site $(IMAGE) bundle exec jekyll clean
