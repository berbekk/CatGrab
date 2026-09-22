.PHONY: build run install test lint dmg verify-release site clean

build:           ## Build build/CatGrab.app for this Mac
	./build.sh

run: build       ## Build and launch
	open build/CatGrab.app

install:         ## Build and copy to /Applications
	./install.sh

test:            ## Run unit tests
	swift test

lint:            ## SwiftLint, strict like CI
	swiftlint lint --strict

dmg:             ## Universal build/CatGrab.dmg for distribution
	./make-dmg.sh

verify-release:  ## Check build/CatGrab.dmg the way users receive it
	./scripts/verify-release.sh

site:            ## Preview the website at http://localhost:8000
	mkdir -p site/assets
	cp docs/screenshots/*.png site/assets/ && cp design/icon.png site/assets/icon.png
	python3 -m http.server 8000 --directory site

clean:
	rm -rf .build build site/assets
