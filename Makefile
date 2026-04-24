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

GO_BUILD_FLAGS := -ldflags "$(LD_FLAGS)"

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
	go test -v -race -coverprofile=coverage.out ./src/...
	go tool cover -html=coverage.out -o coverage.html
	@echo "Tests complete. Coverage report: coverage.html"

## test-short: Run short unit tests (skip integration)
test-short:
	@echo "Running short unit tests..."
	go test -short -v ./src/...

## lint: Run linters
lint:
	@echo "Running linters..."
	@which golangci-lint > /dev/null || (echo "golangci-lint not found, installing..." && go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest)
	golangci-lint run ./src/...

## fmt: Format Go source files
fmt:
	@echo "Formatting Go files..."
	gofmt -s -w ./src/

## vet: Run go vet
vet:
	@echo "Running go vet..."
	go vet ./src/...

## docker-build: Build Docker images for all components
docker-build:
	@echo "Building Docker images (tag: $(IMAGE_TAG))..."
	docker build -f make/photon/core/Dockerfile -t $(REGISTRY)/harbor-core:$(IMAGE_TAG) .
	docker build -f make/photon/jobservice/Dockerfile -t $(REGISTRY)/harbor-jobservice:$(IMAGE_TAG) .
	docker build -f make/photon/registryctl/Dockerfile -t $(REGISTRY)/harbor-registryctl:$(IMAGE_TAG) .

## docker-push: Push Docker images to registry
docker-push: docker-build
	@echo "Pushing Docker images..."
	docker push $(REGISTRY)/harbor-core:$(IMAGE_TAG)
	docker push $(REGISTRY)/harbor-jobservice:$(IMAGE_TAG)
	docker push $(REGISTRY)/harbor-registryctl:$(IMAGE_TAG)

## clean: Remove build artifacts
clean:
	@echo "Cleaning build artifacts..."
	rm -rf $(BIN_DIR) $(DIST_DIR) coverage.out coverage.html
	@echo "Clean complete."

## tidy: Tidy Go module dependencies
tidy:
	go mod tidy

## vendor: Update vendor directory
vendor:
	go mod vendor

## help: S
