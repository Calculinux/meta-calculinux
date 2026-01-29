# Calculinux Build System Makefile
# Run from meta-calculinux/ directory
# Commands execute in configurable build root directory

# Variables
# Override BUILD_ROOT to use a different build directory
# Default: parent directory (typical workspace layout)
# Example: make BUILD_ROOT=/path/to/build/dir image
BUILD_ROOT ?= ..
META_CALCULINUX_DIR = $(CURDIR)
KAS_CONTAINER = ./meta-calculinux/kas-container
KAS_CONFIG = ./meta-calculinux/kas-luckfox-lyra-bundle.yaml
BUILD_DIR = ./build
SYMLINK_NEEDED = $(shell [ "$(BUILD_ROOT)" != ".." ] && [ ! -e "$(BUILD_ROOT)/meta-calculinux" ] && echo "yes" || echo "no")

# Setup target - creates symlink if needed
.PHONY: setup
setup:
	@if [ "$(SYMLINK_NEEDED)" = "yes" ]; then \
		echo "Creating symlink: $(BUILD_ROOT)/meta-calculinux -> $(META_CALCULINUX_DIR)"; \
		mkdir -p "$(BUILD_ROOT)"; \
		ln -sf "$(META_CALCULINUX_DIR)" "$(BUILD_ROOT)/meta-calculinux"; \
	fi

# Default target
.PHONY: help
help:
	@echo "Calculinux Build System - Available targets:"
	@echo ""
	@echo "  make image           - Build full system image (alias: make build)"
	@echo "  make bundle          - Build RAUC update bundle"
	@echo "  make sdk             - Build SDK (x86_64 + aarch64)"
	@echo "  make apps            - Build application packagegroup"
	@echo "  make shell           - Launch interactive bitbake shell"
	@echo ""
	@echo "  make clean-all       - Clean all build artifacts"
	@echo "  make clean-image     - Clean image recipe"
	@echo "  make clean-bundle    - Clean bundle recipe"
	@echo "  make clean-sstate    - Remove shared state cache"
	@echo ""
	@echo "  make recipe RECIPE=<name>       - Build specific recipe"
	@echo "  make clean-recipe RECIPE=<name> - Clean specific recipe"
	@echo "  make devshell RECIPE=<name>     - Open devshell for recipe"
	@echo ""
	@echo "All targets depend on setup"

.PHONY: image
image: setup
	cd $(BUILD_ROOT) && $(KAS_CONTAINER) build $(KAS_CONFIG)

.PHONY: build
build: image

.PHONY: bundle
bundle: setup
	cd $(BUILD_ROOT) && $(KAS_CONTAINER) shell $(KAS_CONFIG) -c "bitbake calculinux-bundle"

.PHONY: sdk
sdk: setup
	cd $(BUILD_ROOT) && $(KAS_CONTAINER) shell $(KAS_CONFIG) -c "bitbake calculinux-image -c populate_sdk"

.PHONY: apps
apps: setup
	cd $(BUILD_ROOT) && $(KAS_CONTAINER) shell $(KAS_CONFIG) -c "bitbake packagegroup-meta-calculinux-apps"

# Interactive shell
.PHONY: shell
shell: setup
	cd $(BUILD_ROOT) && $(KAS_CONTAINER) shell $(KAS_CONFIG)

# Clean targets
.PHONY: clean-all
clean-all:
	rm -rf $(BUILD_ROOT)/$(BUILD_DIR)/tmp
	@echo "Build artifacts cleaned (kept downloads and sstate cache)"

.PHONY: clean-image
clean-image: setup
	cd $(BUILD_ROOT) && $(KAS_CONTAINER) shell $(KAS_CONFIG) -c "bitbake calculinux-image -c cleanall"

.PHONY: clean-bundle
clean-bundle: setup
	cd $(BUILD_ROOT) && $(KAS_CONTAINER) shell $(KAS_CONFIG) -c "bitbake calculinux-bundle -c cleanall"

.PHONY: clean-sstate
clean-sstate:
	rm -rf $(BUILD_ROOT)/$(BUILD_DIR)/sstate-cache
	@echo "Shared state cache removed"

# Recipe operations
.PHONY: recipe
recipe: setup
ifndef RECIPE
	@echo "Error: RECIPE not specified. Use: make recipe RECIPE=<recipe-name>"
	@exit 1
endif
	cd $(BUILD_ROOT) && $(KAS_CONTAINER) shell $(KAS_CONFIG) -c "bitbake $(RECIPE)"

.PHONY: clean-recipe
clean-recipe: setup
ifndef RECIPE
	@echo "Error: RECIPE not specified. Use: make clean-recipe RECIPE=<recipe-name>"
	@exit 1
endif
	cd $(BUILD_ROOT) && $(KAS_CONTAINER) shell $(KAS_CONFIG) -c "bitbake $(RECIPE) -c cleanall"

.PHONY: devshell
devshell: setup
ifndef RECIPE
	@echo "Error: RECIPE not specified. Use: make devshell RECIPE=<recipe-name>"
	@exit 1
endif
	cd $(BUILD_ROOT) && $(KAS_CONTAINER) shell $(KAS_CONFIG) -c "bitbake $(RECIPE) -c devshell"

# Information targets
.PHONY: list-images
list-images: setup
	cd $(BUILD_ROOT) && $(KAS_CONTAINER) shell $(KAS_CONFIG) -c "bitbake-layers show-recipes 'calculinux-*'"

.PHONY: list-recipes
list-recipes: setup
ifdef SEARCH
	cd $(BUILD_ROOT) && $(KAS_CONTAINER) shell $(KAS_CONFIG) -c "bitbake-layers show-recipes '*$(SEARCH)*'"
else
	@echo "Use: make list-recipes SEARCH=<term>"
endif

# Status information
.PHONY: status
status:
	@echo "Build root: $(BUILD_ROOT)"
	@echo "Build directory: $(BUILD_ROOT)/$(BUILD_DIR)"
	@if [ "$(SYMLINK_NEEDED)" = "yes" ]; then \
		echo "Symlink status: Required (will be created on build)"; \
	else \
		echo "Symlink status: Not needed"; \
	fi
	@if [ -d "$(BUILD_ROOT)/$(BUILD_DIR)" ]; then \
		echo "Build directory exists"; \
		if [ -d "$(BUILD_ROOT)/$(BUILD_DIR)/tmp/deploy/images/luckfox-lyra" ]; then \
			echo "Images:"; \
			ls -lh $(BUILD_ROOT)/$(BUILD_DIR)/tmp/deploy/images/luckfox-lyra/*.wic 2>/dev/null || echo "  No .wic images found"; \
			ls -lh $(BUILD_ROOT)/$(BUILD_DIR)/tmp/deploy/images/luckfox-lyra/*.raucb 2>/dev/null || echo "  No .raucb bundles found"; \
		fi; \
	else \
		echo "Build directory does not exist - run 'make image' first"; \
	fi
