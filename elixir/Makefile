.PHONY: help all setup deps build fmt fmt-check lint test coverage ci dialyzer e2e docs-check docs-generated-check

MIX ?= mix

help:
	@echo "Targets: setup, deps, fmt, fmt-check, lint, test, coverage, dialyzer, e2e, ci"

setup:
	$(MIX) setup

deps:
	$(MIX) deps.get

build:
	$(MIX) build

fmt:
	$(MIX) format

fmt-check:
	$(MIX) format --check-formatted

lint:
	$(MIX) lint

coverage: build
	$(MIX) test --cover

test: build
	$(MIX) test

dialyzer:
	$(MIX) deps.get
	$(MIX) dialyzer --format short

e2e:
	SYMPHONY_PLUS_RUN_LIVE_E2E=1 $(MIX) test test/symphony_plus/live_e2e_test.exs

docs-generated-check:
	$(MIX) docs.check

docs-check: build docs-generated-check
	$(MIX) test --only documentation

ci:
	$(MAKE) setup
	$(MAKE) build
	$(MAKE) docs-generated-check
	$(MAKE) fmt-check
	$(MAKE) lint
	$(MAKE) coverage
	$(MAKE) dialyzer

all: ci
