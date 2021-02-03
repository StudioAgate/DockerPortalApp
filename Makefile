
build:
	docker build --compress --pull . -t pierstoval/studio-agate-portal:latest
.PHONY: build
