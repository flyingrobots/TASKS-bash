BATS ?= bats

NON_E2E_TESTS := $(shell find tests -maxdepth 1 -name '*.bats' ! -name 'e2e.bats' | sort)

.PHONY: test test-e2e

BATS ?= bats

# Targets: `make test` runs unit/integration (excludes e2e); `make test-e2e` runs the deterministic e2e suite.
# Run `make test` before pushing; e2e is slower/optional.

NON_E2E_TESTS := $(shell find tests -maxdepth 1 -name '*.bats' ! -name 'e2e.bats' | sort)

.PHONY: help test test-e2e

help:
	@echo "Targets:"
	@echo "  test      - Run unit/integration BATS (excludes e2e)"
	@echo "  test-e2e  - Run deterministic e2e (tests/e2e.bats)"

test:
	$(BATS) $(NON_E2E_TESTS)

test-e2e:
	@test -f tests/e2e.bats || { printf 'Error: tests/e2e.bats not found\n' >&2; exit 1; }
	$(BATS) tests/e2e.bats
