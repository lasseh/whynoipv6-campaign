# Makefile for validating and generating UUIDs in YAML files

.PHONY: check-uuids fix-uuids help all

# Default target - fix missing UUIDs then check all
all: fix-uuids check-uuids

# Help target
help:
	@echo "Available targets:"
	@echo "  make all          - Generate missing UUIDs and check all files"
	@echo "  make check-uuids  - Check all YAML files for valid UUIDs"
	@echo "  make fix-uuids    - Generate UUIDs for files with empty uuid field"

# Check all YAML files for UUID status
check-uuids:
	@echo "Checking UUID status in all YAML files..."
	@for file in *.yml; do \
		if [ -f "$$file" ]; then \
			uuid=$$(grep -E '^uuid:' "$$file" | sed 's/uuid:[[:space:]]*//'); \
			if [ -z "$$uuid" ]; then \
				echo "❌ $$file: UUID is empty"; \
			elif echo "$$uuid" | grep -qE '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$$'; then \
				echo "✅ $$file: Valid UUID v4 ($$uuid)"; \
			else \
				echo "⚠️  $$file: Invalid UUID format ($$uuid)"; \
			fi \
		fi \
	done

# Generate UUIDs for files with empty uuid field
fix-uuids:
	@echo "Generating UUIDs for files with empty uuid field..."
	@for file in *.yml; do \
		if [ -f "$$file" ]; then \
			uuid=$$(grep -E '^uuid:' "$$file" | sed 's/uuid:[[:space:]]*//'); \
			if [ -z "$$uuid" ]; then \
				new_uuid=$$(uuidgen | tr '[:upper:]' '[:lower:]'); \
				if [ "$$(uname)" = "Linux" ]; then \
					sed -i "s/^uuid:[[:space:]]*/uuid: $$new_uuid/" "$$file"; \
				else \
					sed -i '' "s/^uuid:[[:space:]]*/uuid: $$new_uuid/" "$$file"; \
				fi; \
				echo "Generated UUID for $$file: $$new_uuid"; \
			fi \
		fi \
	done
	@echo "Done! Run 'make check-uuids' to verify."