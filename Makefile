APP_NAME    = AirplaneAI
APP_BUNDLE  = build/$(APP_NAME).app
APP_DIR    ?= /Applications
BIN_DIR    ?= /usr/local/bin
BIN_LINK   ?= $(BIN_DIR)/airplaneai
SWIFT      ?= swift
LOCK        = ./scripts/with-build-lock.sh
LINEBUF     = ./scripts/line-buffered.sh

.PHONY: build test test-slow test-all model app run dist install release clean verify verify-bundle bench icon seed screenshots appstore-submit unstick

build:
	@echo "==> swift build -c release"
	@$(LOCK) $(SWIFT) build -c release

test:
	@echo "==> swift test --parallel (fast lane)"
	@$(LOCK) $(LINEBUF) $(SWIFT) test --parallel

test-slow:
	@echo "==> swift test --parallel (real-model lane)"
	@AIRPLANE_SLOW_TESTS=1 AIRPLANE_REAL_MODEL_TESTS=1 $(LOCK) $(LINEBUF) $(SWIFT) test --parallel

test-all:
	@$(MAKE) test
	@$(MAKE) test-slow

model:
	./scripts/fetch-model.sh

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
		mkdir -p "$(BIN_DIR)"; \
		ln -sf "$(APP_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" "$(BIN_LINK)"; \
	else \
		sudo rm -rf "$(APP_DIR)/$(APP_NAME).app"; \
		sudo ditto "$(APP_BUNDLE)" "$(APP_DIR)/$(APP_NAME).app"; \
		sudo mkdir -p "$(BIN_DIR)"; \
		sudo ln -sf "$(APP_DIR)/$(APP_NAME).app/Contents/MacOS/$(APP_NAME)" "$(BIN_LINK)"; \
	fi
	@echo "Installed $(APP_NAME).app to $(APP_DIR)"
	@echo "Linked CLI at $(BIN_LINK)"

verify:
	./Tools/ci/verify-entitlements.sh
	./Tools/ci/verify-no-network-symbols.sh
	./Tools/ci/verify-no-forbidden-deps.sh
	./Tools/ci/verify-quality-rules.sh
	./Tools/ci/verify-model-manifest.sh

verify-bundle: app
	./Tools/ci/verify-app-bundle.sh

bench:
	@echo "==> swift test --parallel (benchmark lane)"
	@AIRPLANE_BENCHMARKS=1 $(LOCK) $(LINEBUF) $(SWIFT) test --parallel

icon:
	./scripts/generate-icon.sh

seed:
	@echo "==> swift run -c debug AirplaneAI --seed-sample-conversations --replace"
	@$(LOCK) $(SWIFT) run -c debug AirplaneAI --seed-sample-conversations --replace

screenshots: app
	./scripts/generate-screenshots.sh

appstore-submit:
	./scripts/appstore-submit.sh

unstick:
	./scripts/unstick-swiftpm.sh

clean:
	swift package clean
	rm -rf .build build dist
