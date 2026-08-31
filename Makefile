DEVELOPER_DIR ?= /Applications/Xcode-beta.app/Contents/Developer
ifeq ($(wildcard $(DEVELOPER_DIR)),)
DEVELOPER_DIR := /Applications/Xcode.app/Contents/Developer
endif

export DEVELOPER_DIR
SCHEME := Berth
PROJECT := Berth.xcodeproj
DERIVED := .build/DerivedData
APP := $(DERIVED)/Build/Products/Debug/Berth.app

.PHONY: project build test run clean

project:
	xcodegen generate

build: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -configuration Debug -derivedDataPath $(DERIVED) -destination 'platform=macOS' build

test: project
	xcodebuild -project $(PROJECT) -scheme $(SCHEME) -derivedDataPath $(DERIVED) -destination 'platform=macOS' \
		CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= test

run: build
	open "$(APP)"

clean:
	rm -rf .build $(PROJECT)
