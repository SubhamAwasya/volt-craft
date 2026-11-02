CC = clang
CFLAGS = -Os -fobjc-arc -flto -fmodules-cache-path=/tmp/mcache
LDFLAGS = -Wl,-dead_strip -framework Cocoa -framework IOKit -framework Foundation
SOURCES = src/battery_core.m src/dashboard_view.m src/charge_control_view.m src/settings_tab_views.m src/sidebar_view.m src/main_window.m src/slider_popover.m src/menu_bar.m src/main.m
TARGET = voltcraft
APP_NAME = VoltCraft.app
APP_DIR = $(APP_NAME)/Contents/MacOS

HELPER_TARGET = voltcraft-helper
HELPER_SOURCES = src/helper.m
HELPER_LDFLAGS = -framework Foundation -framework IOKit

all: $(TARGET) $(HELPER_TARGET) app

$(TARGET): $(SOURCES)
	$(CC) $(CFLAGS) $(LDFLAGS) $(SOURCES) -o $(TARGET)
	strip $(TARGET)

$(HELPER_TARGET): $(HELPER_SOURCES)
	$(CC) -Os -fobjc-arc -flto $(HELPER_LDFLAGS) $(HELPER_SOURCES) -o $(HELPER_TARGET)
	strip $(HELPER_TARGET)

app: $(TARGET)
	mkdir -p $(APP_DIR)
	mkdir -p $(APP_NAME)/Contents/Resources
	cp $(TARGET) $(APP_DIR)/VoltCraft
	cp Info.plist $(APP_NAME)/Contents/Info.plist
	cp AppIcon.icns $(APP_NAME)/Contents/Resources/AppIcon.icns
	echo -n "APPL????" > $(APP_NAME)/Contents/PkgInfo
	codesign --force --deep -s - $(APP_NAME)

install: app
	cp -R $(APP_NAME) /Applications/
	rm -rf $(APP_NAME)

clean:
	rm -rf $(TARGET) $(HELPER_TARGET) $(APP_NAME)

size: $(TARGET) $(HELPER_TARGET)
	@echo "--- App Binary Size ---"
	@ls -lh $(TARGET)
	@echo "--- Helper Binary Size ---"
	@ls -lh $(HELPER_TARGET)
	@echo "--- App Bundle Size ---"
	@du -sh $(APP_NAME)

.PHONY: all app install clean size
