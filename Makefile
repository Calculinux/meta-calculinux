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
	@echo "  make release TAG=v1.0.0 - Create and push release tag"
	@echo "    GitHub Actions will automatically build and create the release"
	@echo "    Requires: On main branch, GitHub CLI (gh) installed"
	@echo ""
	@echo "All targets depend on setup"

.PHONY: image
image: setup
	cd $(BUILD_ROOT) && $(KAS_CONTAINER) build $(KAS_CONFIG)

.PHONY: build
build: bundle

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

# Release management targets
.PHONY: release
release: release-verify
	@echo ""
	@echo "✓ Tag $(TAG) created and pushed to GitHub"
	@echo ""
	@echo "GitHub Actions will now:"
	@echo "  1. Build images and packages (~1-2 hours)"
	@echo "  2. Build SDKs for x86_64 and aarch64"
	@echo "  3. Create GitHub release with all artifacts"
	@echo "  4. Send Discord notification"
	@echo ""
	@echo "Monitor progress at:"
	@echo "  https://github.com/$$(gh repo view --json owner,name -q '{{.owner.login}}/{{.name}}')/actions"
	@echo ""
	@echo "When complete, release will be available at:"
	@echo "  https://github.com/$$(gh repo view --json owner,name -q '{{.owner.login}}/{{.name}}')/releases/tag/$(TAG)"

.PHONY: release-verify
release-verify:
	@echo "Preparing release $(TAG)..."
	@if ! command -v gh &> /dev/null; then \
		echo "ERROR: GitHub CLI (gh) not found. Install from https://cli.github.com/"; \
		exit 1; \
	fi
	@if [ -z "$(TAG)" ]; then \
		echo "ERROR: TAG not specified. Usage: make release TAG=v1.0.0"; \
		exit 1; \
	fi
	@echo "Checking current branch..."
	@set -e; \
	REPO_ROOT=$$(cd $(BUILD_ROOT) && git -C meta-calculinux rev-parse --show-toplevel 2>/dev/null || echo "$(BUILD_ROOT)"); \
	CURRENT_BRANCH=$$(git -C $$REPO_ROOT rev-parse --abbrev-ref HEAD); \
	if [ "$$CURRENT_BRANCH" != "main" ]; then \
		echo "ERROR: Not on main branch (currently on: $$CURRENT_BRANCH)"; \
		echo "Switch to main with: git checkout main"; \
		exit 1; \
	fi
	@echo "✓ On main branch"
	@echo "Syncing with origin..."
	@set -e; \
	REPO_ROOT=$$(cd $(BUILD_ROOT) && git -C meta-calculinux rev-parse --show-toplevel 2>/dev/null || echo "$(BUILD_ROOT)"); \
	git -C $$REPO_ROOT pull origin main
	@echo "✓ Synced with origin/main"
	@echo "Creating and pushing tag $(TAG)..."
	@set -e; \
	REPO_ROOT=$$(cd $(BUILD_ROOT) && git -C meta-calculinux rev-parse --show-toplevel 2>/dev/null || echo "$(BUILD_ROOT)"); \
	if git -C $$REPO_ROOT rev-parse "$(TAG)" > /dev/null 2>&1; then \
		echo "WARNING: Tag $(TAG) already exists locally."; \
		if git -C $$REPO_ROOT ls-remote --tags origin | grep -q "refs/tags/$(TAG)"; then \
			echo "Tag $(TAG) already pushed to origin. GitHub Actions may have already started."; \
		else \
			echo "Pushing existing tag to origin..."; \
			git -C $$REPO_ROOT push origin $(TAG); \
			echo "✓ Tag $(TAG) pushed"; \
		fi \
	else \
		git -C $$REPO_ROOT tag $(TAG); \
		git -C $$REPO_ROOT push origin $(TAG); \
		echo "✓ Tag $(TAG) created and pushed"; \
	fi
