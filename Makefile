
build:
	docker build --compress --force-rm --pull . -t pierstoval/studio-agate-portal:latest
.PHONY: build
