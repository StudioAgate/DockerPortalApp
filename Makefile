
build:
	docker build --compress --force-rm --no-cache --pull . -t pierstoval/studio-agate-portal:latest
.PHONY: build
