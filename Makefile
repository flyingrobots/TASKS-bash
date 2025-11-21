BATS ?= bats

NON_E2E_TESTS := $(shell find tests -maxdepth 1 -name '*.bats' ! -name 'e2e.bats' | sort)

.PHONY: test test-e2e

test:
	$(BATS) $(NON_E2E_TESTS)

test-e2e:
	$(BATS) tests/e2e.bats
