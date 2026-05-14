.PHONY: build run test clean help

# Default target
all: build

## build: Build the project
build:
	swift build

## run: Build and run the TinyKV server
run:
	swift run TinyKV

## test: Run all tests
test:
	swift test

## clean: Remove build artifacts
clean:
	swift package clean
	rm -rf .build

## help: Show this help message
help:
	@echo "Usage: make [target]"
	@echo ""
	@echo "Targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
