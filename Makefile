APP_NAME    = AirplaneAI
APP_BUNDLE  = build/$(APP_NAME).app
APP_DIR    ?= /Applications

.PHONY: build test app run dist install release clean verify bench

build:
	swift build -c release

test:
	swift test --parallel

app:
	./scripts/build-app.sh

run: app
	open "$(APP_BUNDLE)"

dist:
	./scripts/build-dist.sh

release:
	./scripts/release.sh

install: app
	@if [ -w "$(APP_DIR)" ]; then \
		rm -rf "$(APP_DIR)/$(APP_NAME).app"; \
		ditto "$(APP_BUNDLE)" "$(APP_DIR)/$(APP_NAME).app"; \
	else \
		sudo rm -rf "$(APP_DIR)/$(APP_NAME).app"; \
		sudo ditto "$(APP_BUNDLE)" "$(APP_DIR)/$(APP_NAME).app"; \
	fi
	@echo "Installed $(APP_NAME).app to $(APP_DIR)"

verify:
	./Tools/ci/verify-entitlements.sh
	./Tools/ci/verify-no-network-symbols.sh
	./Tools/ci/verify-no-forbidden-deps.sh
	./Tools/ci/verify-model-manifest.sh

bench:
	swift run -c release AirplaneBenchmarks

clean:
	swift package clean
	rm -rf .build build dist
