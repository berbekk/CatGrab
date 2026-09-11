.PHONY: build install test dmg run

build:
	./build.sh

install:
	./install.sh

test:
	swift test

dmg:
	./make-dmg.sh

run: build
	open build/PieMenu.app
