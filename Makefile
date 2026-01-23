.ONESHELL:
.PHONY: icon
SHELL := /bin/bash

ASSETS_DIR := Assets/Icons
APP_SVG := $(ASSETS_DIR)/app-icon.svg
MENUBAR_SVG := $(ASSETS_DIR)/menubar-icon-template.svg
APP_ICONSET := $(ASSETS_DIR)/AppIcon.iconset
APP_ICNS := $(ASSETS_DIR)/AppIcon.icns

icon:
	@if [ ! -f "$(APP_SVG)" ]; then \
		echo "❌ Missing $(APP_SVG)."; \
		exit 1; \
	fi
	@if [ ! -f "$(MENUBAR_SVG)" ]; then \
		echo "❌ Missing $(MENUBAR_SVG)."; \
		exit 1; \
	fi
	@mkdir -p "$(ASSETS_DIR)"
	@rsvg-convert "$(APP_SVG)" -w 1024 -h 1024 -o "$(ASSETS_DIR)/app-icon-1024.png"
	@for s in 512 256 128 64 32 16; do \
		rsvg-convert "$(APP_SVG)" -w $$s -h $$s -o "$(ASSETS_DIR)/app-icon-$$s.png"; \
	done
	@mkdir -p "$(APP_ICONSET)"
	@cp "$(ASSETS_DIR)/app-icon-16.png" "$(APP_ICONSET)/icon_16x16.png"
	@cp "$(ASSETS_DIR)/app-icon-32.png" "$(APP_ICONSET)/icon_16x16@2x.png"
	@cp "$(ASSETS_DIR)/app-icon-32.png" "$(APP_ICONSET)/icon_32x32.png"
	@cp "$(ASSETS_DIR)/app-icon-64.png" "$(APP_ICONSET)/icon_32x32@2x.png"
	@cp "$(ASSETS_DIR)/app-icon-128.png" "$(APP_ICONSET)/icon_128x128.png"
	@cp "$(ASSETS_DIR)/app-icon-256.png" "$(APP_ICONSET)/icon_128x128@2x.png"
	@cp "$(ASSETS_DIR)/app-icon-256.png" "$(APP_ICONSET)/icon_256x256.png"
	@cp "$(ASSETS_DIR)/app-icon-512.png" "$(APP_ICONSET)/icon_256x256@2x.png"
	@cp "$(ASSETS_DIR)/app-icon-512.png" "$(APP_ICONSET)/icon_512x512.png"
	@cp "$(ASSETS_DIR)/app-icon-1024.png" "$(APP_ICONSET)/icon_512x512@2x.png"
	@if command -v iconutil >/dev/null 2>&1; then \
		iconutil -c icns "$(APP_ICONSET)" -o "$(APP_ICNS)"; \
	else \
		python - <<-'PY' || (echo "❌ icns generation failed. Install icnsutil or run on macOS with iconutil."; exit 1)
		from pathlib import Path
		try:
		    from icnsutil import IcnsFile
		except Exception:
		    raise SystemExit(1)
		
		iconset = Path("$(APP_ICONSET)")
		output = Path("$(APP_ICNS)")
		order = [
		    "icon_16x16.png",
		    "icon_16x16@2x.png",
		    "icon_32x32.png",
		    "icon_32x32@2x.png",
		    "icon_128x128.png",
		    "icon_128x128@2x.png",
		    "icon_256x256.png",
		    "icon_256x256@2x.png",
		    "icon_512x512.png",
		    "icon_512x512@2x.png",
		]
		icns = IcnsFile()
		for name in order:
		    path = iconset / name
		    if path.exists():
		        icns.add_media(file=str(path))
		icns.write(str(output))
		print("✅ Wrote", output)
		PY
	fi
	@rsvg-convert "$(MENUBAR_SVG)" -f pdf -d 72 -p 72 -w 19 -h 19 --page-width 19 --page-height 19 -o "$(ASSETS_DIR)/menubar-icon-template.pdf"
	@rsvg-convert "$(MENUBAR_SVG)" -w 19 -h 19 -o "$(ASSETS_DIR)/menubar-icon-template@1x.png"
	@rsvg-convert "$(MENUBAR_SVG)" -w 38 -h 38 -o "$(ASSETS_DIR)/menubar-icon-template@2x.png"
	@echo "✅ Icons generated in $(ASSETS_DIR)"
