SHELL=/bin/bash

check:
	./scripts/run-checks.sh

format:
	swiftformat .

all:
	./scripts/build-all.sh
