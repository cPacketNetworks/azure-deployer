.PHONY: build-bicep build
.DEFAULT_GOAL := build

build: build-bicep

build-bicep: main.bicep
	bicep build main.bicep
