PREFIX ?= /usr/local
BINARY = xdr-boost
BUILD_DIR = .build
DIST_DIR = dist
APP_NAME = XDR Boost
APP_BUNDLE = $(DIST_DIR)/$(APP_NAME).app
APP_CONTENTS = $(APP_BUNDLE)/Contents
APP_BINARY = $(APP_CONTENTS)/MacOS/$(BINARY)
APP_PLIST = $(APP_CONTENTS)/Info.plist
DMG_NAME = xdr-boost-macos.dmg
DMG_PATH = $(DIST_DIR)/$(DMG_NAME)
DMG_STAGING_DIR = $(DIST_DIR)/dmg
PKG_NAME = xdr-boost-macos.pkg
PKG_PATH = $(DIST_DIR)/$(PKG_NAME)
VERSION ?= 1.0.0

.PHONY: build app pkg dmg install uninstall clean launch-agent remove-agent

build:
	@mkdir -p $(BUILD_DIR)
	swiftc -O -o $(BUILD_DIR)/$(BINARY) Sources/main.swift \
		-framework Cocoa -framework MetalKit -framework Metal

app: build
	@mkdir -p "$(APP_CONTENTS)/MacOS"
	install -m 755 $(BUILD_DIR)/$(BINARY) "$(APP_BINARY)"
	@sed \
		-e "s|__APP_NAME__|$(APP_NAME)|g" \
		-e "s|__BINARY__|$(BINARY)|g" \
		-e "s|__VERSION__|$(VERSION)|g" \
		packaging/Info.plist.in > "$(APP_PLIST)"

pkg: app
	rm -f "$(PKG_PATH)"
	pkgbuild --component "$(APP_BUNDLE)" --install-location /Applications "$(PKG_PATH)"

dmg: app
	rm -rf "$(DMG_STAGING_DIR)" "$(DMG_PATH)"
	@mkdir -p "$(DMG_STAGING_DIR)"
	cp -R "$(APP_BUNDLE)" "$(DMG_STAGING_DIR)/"
	ln -s /Applications "$(DMG_STAGING_DIR)/Applications"
	hdiutil create -volname "$(APP_NAME)" -srcfolder "$(DMG_STAGING_DIR)" -ov -format UDZO "$(DMG_PATH)"

install: build
	install -d $(PREFIX)/bin
	install -m 755 $(BUILD_DIR)/$(BINARY) $(PREFIX)/bin/$(BINARY)

uninstall: remove-agent
	rm -f $(PREFIX)/bin/$(BINARY)

# Install LaunchAgent to start on login
launch-agent: install
	@mkdir -p ~/Library/LaunchAgents
	@sed "s|__BINARY__|$(PREFIX)/bin/$(BINARY)|g" \
		com.xdr-boost.agent.plist > ~/Library/LaunchAgents/com.xdr-boost.agent.plist
	launchctl load ~/Library/LaunchAgents/com.xdr-boost.agent.plist
	@echo "xdr-boost will now start on login"

remove-agent:
	-launchctl unload ~/Library/LaunchAgents/com.xdr-boost.agent.plist 2>/dev/null
	rm -f ~/Library/LaunchAgents/com.xdr-boost.agent.plist

clean:
	rm -rf $(BUILD_DIR) $(DIST_DIR)
