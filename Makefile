# ============================================
# Define Root variables
# ============================================
IGNORE_LINTING ?= true
OS := $(shell uname | tr '[:upper:]' '[:lower:]')
ARCHITECTURE := $(shell uname -m)
ARCHITECTURE_SUBSTITUTED := $(shell uname -m | sed "s/x86_64/amd64/g")
export ENVIRONMENT ?= local
CURRENT_DIR := $(shell pwd)
PROPERTY_FILE := ./property.yaml
ifneq (${ENVIRONMENT},local)
	PROPERTY_FILE := ./deployment/config/property-${ENVIRONMENT}.yaml
endif

SERVICE_NAME := $(shell docker run --rm -v ${CURRENT_DIR}:/workdir mikefarah/yq '.name' ${PROPERTY_FILE})
SERVICE_DESCRIPTION := Solace Consumer
GCP_PROJECT := $(shell docker run --rm -v ${CURRENT_DIR}:/workdir mikefarah/yq '.gcp.project' ${PROPERTY_FILE})

# ===============================================
# Define variables for Git and Versioning
# ===============================================
BRANCH_NAME := $(shell git rev-parse --abbrev-ref HEAD)
CREATED := $(shell date +%Y-%m-%dT%T%z)
GIT_REPO := $(shell git remote get-url origin)
REPO_NAME := $(shell basename -s .git ${GIT_REPO})
export GIT_TOKEN ?= $(shell cat git-token.txt)
REVISION_ID := $(shell git rev-parse HEAD)
SHORT_SHA := $(shell git rev-parse --short HEAD)
TAG_NAME ?= $(shell git describe --exact-match --tags 2> /dev/null)
VERSION ?= $(if ${TAG_NAME},${TAG_NAME},latest)
VERSION_PATH := github.com/ingka-group-digital/${REPO_NAME}/internal/version

# ===============================================
# Define Docker Image name and Artifact Registry
# ===============================================
#export DOCKER_IMAGE := $(shell docker run --rm -v ${CURRENT_DIR}:/workdir mikefarah/yq '.app.image.name' ${PROPERTY_FILE})
ARTIFACT_REGISTRY_URL :=  $(shell docker run --rm -v ${CURRENT_DIR}:/workdir mikefarah/yq '.app.image.repository' ${PROPERTY_FILE})
ifeq ($(ENVIRONMENT),local)
DOCKER_IMAGE := $(shell docker run --rm -v ${CURRENT_DIR}:/workdir mikefarah/yq '.app.image.name' ${PROPERTY_FILE})
else
DOCKER_IMAGE := ${ARTIFACT_REGISTRY_URL}:$(shell docker run --rm -v ${CURRENT_DIR}:/workdir mikefarah/yq '.app.image.name' ${PROPERTY_FILE})
endif

DOCKER_IMAGE_SHA_TAG := ${DOCKER_IMAGE}:${SHORT_SHA}
DOCKER_IMAGE_VERSION_TAG := ${DOCKER_IMAGE}:${VERSION}
DOCKER_IMAGE_LATEST_TAG := ${DOCKER_IMAGE}:latest

# ===============================================================
# Define Variables for Makefile tools versions and dependencies
# ===============================================================
CONTAINER_TOOL := $(shell command -v docker || command -v podman || echo "no-containertool")
GOMOCK_VERSION ?= v1.5.0
SWAGGER_VERSION ?= v0.27.0
GOWRAP_VERSION ?= v1.2.1
GOIMPORTS := $(shell which goimports)

GOLANGCI_LINT_VERSION := 1.55.2
GOLANGCI_LINT := bin/golangci-lint_v$(GOLANGCI_LINT_VERSION)/golangci-lint
GOLINTCI_LINT_URL := https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh

GOTESTSUM_VERSION := 1.11.0
GOTESTSUM := bin/gotestsum_v$(GOTESTSUM_VERSION)/gotestsum
GOTESTSUM_URL := https://github.com/gotestyourself/gotestsum/releases/download/v$(GOTESTSUM_VERSION)/gotestsum_$(GOTESTSUM_VERSION)_$(OS)_$(ARCHITECTURE_SUBSTITUTED).tar.gz


all: help


# ===============================================
# TEST AND BUILD
# ===============================================

## clean: Clean up all build artifacts
.PHONY: clean
clean:
	@echo "🚀 Cleaning up old artifacts for service: ${SERVICE_NAME} and ENVIRONMENT: ${ENVIRONMENT}"
	@rm -f bin/app/*

## test: runs go tests
.PHONY: test
test: ${GOTESTSUM}
	@echo "🚀 running tests"
	@bash -c 'set -o pipefail; CGO_ENABLED=1 ${GOTESTSUM} --format testname --no-color=false -- -race ./internal/... | grep -v "EMPTY"; exit $$?'

# Format target
.PHONY: format
format: ${GOIMPORTS}
	@echo "🚀 Formatting code with goimports"
	@${GOIMPORTS} -w .

## test-benchmark: runs go benchmark tests
.PHONY: test-benchmark
test-benchmark:
	@echo "🚀 running benchmark tests"
	@go test -bench=. -benchmem ./...

## test-coverage: creates a test coverage report in HTML format
.PHONY: test-coverage
test-coverage:
	@echo "🚀 creating coverage report in HTML format"
	@go test -coverprofile=coverage.out ./internal/...
	@go tool cover -html=coverage.out

## test-info: returns information about the current gotestsum executable being used
.PHONY: test-info
test-info:
	@echo ${GOTESTSUM}

## build: Build the application artifacts. Linting can be skipped by setting env variable IGNORE_LINTING.
.PHONY: build
build: clean
	@go mod download
	@go mod tidy
	@echo "🚀 Building artifacts for service: ${SERVICE_NAME} and ENVIRONMENT: ${ENVIRONMENT}"
	@go build -race -ldflags="-s -w -X '${VERSION_PATH}.Version=${VERSION}' -X '${VERSION_PATH}.Commit=${SHORT_SHA}'" -o bin/app/app ./cmd


# ===============================================
# DOCKER
# ===============================================

## docker: builds and publishes the docker image
.PHONY: docker
docker: docker-build docker-publish docker-info-sha

## docker-build: Build the docker file for cloud environment
.PHONY: docker-build
docker-build: ${CONTAINER_TOOL}
	@echo "🚀 Building ${DOCKER_IMAGE} Docker image for ${ENVIRONMENT}"
	@${CONTAINER_TOOL} buildx build \
		-t ${DOCKER_IMAGE} \
		-t ${DOCKER_IMAGE_LATEST_TAG} \
		-t ${DOCKER_IMAGE_SHA_TAG} \
		-t ${DOCKER_IMAGE_VERSION_TAG} \
		--build-arg REPO_NAME=${REPO_NAME} \
		--build-arg GIT_TOKEN=${GIT_TOKEN} \
		--build-arg CREATED=${CREATED} \
		--build-arg REVISION=${SHORT_SHA} \
		--build-arg VERSION=${VERSION} \
		--file ./build/Dockerfile .

## docker-publish: Published the docker image of the App
.PHONY: docker-publish
docker-publish: ${CONTAINER_TOOL}
ifeq ($(ENVIRONMENT),local)
	@echo "Skipping docker-publish in local environment"
else
#	@gcloud auth configure-docker ${ARTIFACT_REGISTRY_BASE_URL}
	@echo
	@echo "🚀 Pushing ${DOCKER_IMAGE} image with tags: ${SHORT_SHA} ${VERSION} ${DOCKER_IMAGE_LATEST_TAG} ${DOCKER_IMAGE_SHA_TAG} ${DOCKER_IMAGE_VERSION_TAG}"
	@echo
	@${CONTAINER_TOOL} image tag ${DOCKER_IMAGE} ${DOCKER_IMAGE_LATEST_TAG}
	@${CONTAINER_TOOL} image tag ${DOCKER_IMAGE} ${DOCKER_IMAGE_SHA_TAG}
	@${CONTAINER_TOOL} image tag ${DOCKER_IMAGE} ${DOCKER_IMAGE_VERSION_TAG}
	@${CONTAINER_TOOL} image push ${DOCKER_IMAGE_LATEST_TAG}
	@${CONTAINER_TOOL} image push ${DOCKER_IMAGE_SHA_TAG}
	@${CONTAINER_TOOL} image push ${DOCKER_IMAGE_VERSION_TAG}
endif

## docker-pull: pulls the docker image
.PHONY: docker-pull
docker-pull: ${CONTAINER_TOOL}
	@echo "🚀 pulling docker image ${DOCKER_IMAGE_SHA_TAG} ${DOCKER_IMAGE_VERSION_TAG}"
	@${CONTAINER_TOOL} pull ${DOCKER_IMAGE_SHA_TAG}
	@${CONTAINER_TOOL} pull ${DOCKER_IMAGE_VERSION_TAG}

## docker-info-sha: returns the name of the image with commit SHA as tag
.PHONY: docker-info-sha
docker-info-sha:
	@echo ${DOCKER_IMAGE_SHA_TAG}

## docker-info-version: returns the name of the image with version as tag
.PHONY: docker-info-version
docker-info-version:
	@echo ${DOCKER_IMAGE_VERSION_TAG}

## docker-inspect: Open a shell to the docker image to inspect it
.PHONY: docker-inspect
docker-inspect:
	@echo "🚀 Inspecting ${DOCKER_IMAGE} Docker image"
	@${CONTAINER_TOOL} run -it --rm -e ENVIRONMENT=$(ENVIRONMENT) --entrypoint /bin/ash ${DOCKER_IMAGE}:${VERSION}

## docker-run: run the docker-image generated for the given ENVIRONMENT
.PHONY: docker-run
docker-run:
	@echo "🚀 Running ${DOCKER_IMAGE} Docker image"
	@${CONTAINER_TOOL} run -it --rm -e ENVIRONMENT=$(ENVIRONMENT) ${DOCKER_IMAGE}:${VERSION}

# ===============================================
# DEPLOYMENT
# ===============================================

# Deploy the app on Google Cloud Run
.PHONY: deploy
deploy:
ifeq ($(ENVIRONMENT),local)
	@echo "🚦 Aborting deployment, environment not set!"
else
	@echo "🚀 Deploying ${SERVICE_NAME} on Cloud Run ${ENVIRONMENT} version: ${VERSION}"
	helm template render ./deployment/helm-render --values ./deployment/config/property-${ENVIRONMENT}.yaml --set version=${VERSION} --show-only templates/service.tpl.yaml > deployment/service-${ENVIRONMENT}.yaml
#   TODO: Deploy to cloud run
#   @gcloud beta run services replace --project=${GCP_PROJECT} ./${SERVICE_NAME}-deployment-config.yaml
endif



# ===============================================
# LINTING
# ===============================================

## go-lint: lints the go code
.PHONY: go-lint
go-lint: ${GOLANGCI_LINT}
	@echo "🚀 linting go code"
	@$(GOLANGCI_LINT) run --timeout=5m -c ./linters/golangci.yml

## go-linter-info: returns information about the current go linter being used
.PHONY: go-linter-info
go-linter-info:
	@echo ${GOLANGCI_LINT}


## git-hooks-install: Install Git hooks
.PHONY: git-hooks-install
git-hooks-install:
	@echo "🚀 Installing Git hooks"
	@cp .github/hooks/pre-push .git/hooks/pre-push


## git-hooks-uninstall: Uninstall Git hooks
.PHONY: git-hooks-uninstall
git-hooks-uninstall:
	@echo "🚀 Uninstalling Git hooks"
	@rm -f .git/hooks/pre-push



## lint: lints everything
.PHONY: go-lint
lint: go-lint

## makefile-check: downloads all binaries if not already present
.PHONY: makefile-check
makefile-check: ${GOLANGCI_LINT} ${GOTESTSUM} ${GOIMPORTS}


help: Makefile
	@echo
	@echo "📗 Choose a command run in "${REPO_NAME}":"
	@echo
	@sed -n 's/^##//p' $< | column -t -s ':' |  sed -e 's/^/ /'
	@echo




# ################################ #
# targets to download the binaries #
# ################################ #
${GOLANGCI_LINT}:
	@echo "📦 installing golangci-lint v${GOLANGCI_LINT_VERSION}"
	@mkdir -p $(dir ${GOLANGCI_LINT})
	@curl -sSL ${GOLINTCI_LINT_URL} | sh -s -- -b ./$(patsubst %/,%,$(dir ${GOLANGCI_LINT})) v${GOLANGCI_LINT_VERSION} > /dev/null 2>&1

${GOTESTSUM}:
	@echo "📦 installing gotestsum v${GOTESTSUM_VERSION}"
	@mkdir -p $(dir ${GOTESTSUM})
	@curl -sSL ${GOTESTSUM_URL} > bin/gotestsum.tar.gz
	@tar -xzf bin/gotestsum.tar.gz -C $(patsubst %/,%,$(dir ${GOTESTSUM}))
	@rm -f bin/gotestsum.tar.gz

# Ensure goimports is installed
${GOIMPORTS}:
	@echo "Installing goimports..."
	@go install golang.org/x/tools/cmd/goimports@latest


# ############## #
# error handling #
# ############## #

${CONTAINER_TOOL}:
	@echo "docker and podman are not installed. please install one."
	@exit 1