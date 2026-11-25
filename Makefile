.PHONY: build test-lxd
build:
	CGO_ENABLED=0 go build -o bin/spreadpp cmd/spread/main.go

test-lxd: build
	./bin/spreadpp -live lxd:tests/
