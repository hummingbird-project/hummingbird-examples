SHELL=/bin/bash

check:
	./scripts/run-checks.sh

format:
	./scripts/run-swift-format.sh --fix

all:
	./scripts/build-all.sh
