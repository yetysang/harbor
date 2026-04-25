# Makefile for Harbor build system
# Forked from goharbor/harbor

GOPATH ?= $(shell go env GOPATH)
GOROOT ?= $(shell go env GOROOT)
GOOS ?= $(shell go env GOOS)
GOARCH ?= $(shell go env GOARCH)

HARBOR_VERSION ?= $(shell cat VERSION 2>/dev/null || echo "dev")
GIT_COMMIT ?= $(shell git rev-parse --short HEAD 2>/dev/null || echo "unknown")
BUILD_DATE ?= $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")

# Use personal registry by default instead of goharbor
REGISTRY ?= myusername
IMAGE_TAG ?= $(HARBOR_VERSION)

# Build output directory
BIN_DIR := bin
DIST_DIR := dist

# Go build flags
LD_FLAGS := -X github.com/goharbor/harbor/src/pkg/version.ReleaseVersion=$(HARBOR_VERSION) \
	-X github.com/goharbor/harbor/src/pkg/version.GitCommit=$(GIT_COMMIT) \
	-X github.com/goharbor/harbor/src/pkg/version.BuildDate=$(BUILD_DATE)

# Added -trimpath to remove local build paths from binaries (better for reproducible builds)
# Added -race detector flag during development; remove for production builds
GO_BUILD_FLAGS := -trimpath -ldflags "$(LD_FLAGS)"

# Use -p to run package tests in parallel; set to number of CPU cores available
# Removed -race from default test flags since it slows things down noticeably on my machine;
# use `make test-race` if you want race detection explicitly.
# Bumped -p from 4 to 8 to better utilize my dev machine (16-core CPU)
# Added -timeout 5m to prevent runaway tests from hanging the terminal indefinitely
GO_TEST_FLAGS := -v -count=1 -p 8 -timeout 5m -coverprofile=coverage.out

.PHONY: all build test lint clean docker-build docker-push help

## all: Build all components
all: build

## build: Compile all Go binaries
build:
	@echo "Building Harbor components..."
	@mkdir -p $(BIN_DIR)
	go build $(GO_BUILD_FLAGS) -o $(BIN_DIR)/harbor-core ./src/core/...
	go build $(GO_BUILD_FLAGS) -o $(BIN_DIR)/harbor-jobservice ./src/jobservice/...
	go build $(GO_BUILD_FLAGS) -o $(BIN_DIR)/harbor-registryctl ./src/registryctl/...
	@echo "Build complete."

## test: Run unit tests
test:
	@echo "Running unit tests..."
	go test $(GO_TEST_FLAGS) ./src/...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Tests complete. Coverage report: coverage.html"

## test-race: Run unit tests with race detector enabled
test-race:
	@echo "Running unit tests with race detector..."
	go test -v -race -count=1 -p 4 -coverprofile=coverage.out ./src/...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Tests complete. Coverage report: coverage.html"

## test-short: Run short unit tests (skip integration)
test-short:
	@echo "Running short unit tests..."
	# NOTE: using -count=1 to disable test result caching, useful during local dev
	# NOTE: bumped timeout to 2m; the default 30s was occasionally too tight on my laptop
	go test -short -v -count=1 -timeout 2m ./src/...

## lint: Run linters
lint:
	@echo "Running linters..."
	@which golangci-lint > /dev/null || (echo "golangci-lint not found, installing..." && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest)
	# NOTE: using --timeout 3m here; the default 1m times out on my machine during full lint runs
	golangci-lint run --timeout 3m ./src/...
