# Campaign UUID tooling.
#
# Every file in campaigns/ carries a `uuid:` the importer keys on — it, not the
# filename or the title, is the campaign's identity. Contributors leave
# the field out; run `make all` after merging a campaign PR to assign what is
# missing and verify the result before pushing. `make install-hooks` puts that
# verification in a pre-push hook so a forgotten `make all` cannot reach origin.

CAMPAIGN_FILES := $(wildcard campaigns/*.yml campaigns/*.yaml)

# The shape the importer accepts (internal/campaign/parse.go uuidRe) — any
# well-formed UUID, not v4 specifically, so a preserved uuid never fails here.
UUID_RE := ^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$$

.PHONY: all help check-uuids fix-uuids install-hooks

# Assign what is missing, then verify everything.
all: fix-uuids check-uuids

help:
	@echo "Available targets:"
	@echo "  make all          - assign missing UUIDs, then check every file"
	@echo "  make fix-uuids    - assign a UUID to every campaign file lacking one"
	@echo "  make check-uuids  - verify every campaign file has a unique, well-formed UUID (exit 1 on failure)"
	@echo "  make install-hooks - run check-uuids from a pre-push hook (local config, once per clone)"

# Local config, never versioned, so it only ever applies to this clone.
install-hooks:
	@git config core.hooksPath .githooks
	@echo "core.hooksPath -> .githooks"

# Blocking: missing, malformed, or shared UUIDs all exit 1. A shared uuid is
# worth catching here because sync's duplicate guard skips *both* files.
check-uuids:
	@fail=0; \
	for file in $(CAMPAIGN_FILES); do \
		uuid=$$(sed -n 's/^uuid:[[:space:]]*//p' "$$file" | head -1); \
		if [ -z "$$uuid" ]; then \
			echo "FAIL $$file: no uuid assigned"; fail=1; \
		elif ! printf '%s\n' "$$uuid" | grep -qE '$(UUID_RE)'; then \
			echo "FAIL $$file: malformed uuid ($$uuid)"; fail=1; \
		else \
			echo "ok   $$file: $$uuid"; \
		fi; \
	done; \
	for dupe in $$(for file in $(CAMPAIGN_FILES); do \
			sed -n 's/^uuid:[[:space:]]*//p' "$$file" | head -1; \
		done | grep -v '^$$' | sort | uniq -d); do \
		echo "FAIL duplicate uuid $$dupe in:$$(grep -l "^uuid: *$$dupe" $(CAMPAIGN_FILES) | tr '\n' ' ' | sed 's/^/ /')"; \
		fail=1; \
	done; \
	exit $$fail

# Fills an empty `uuid:` placeholder in place; otherwise splices the line in
# directly after the description block, matching where the importer's own
# write-back puts it (internal/campaign/sync.go insertUUIDLine).
fix-uuids:
	@for file in $(CAMPAIGN_FILES); do \
		uuid=$$(sed -n 's/^uuid:[[:space:]]*//p' "$$file" | head -1); \
		if [ -z "$$uuid" ]; then \
			new=$$({ uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid; } | tr '[:upper:]' '[:lower:]'); \
			if awk -v id="$$new" '!done && /^uuid:[[:space:]]*$$/ { print "uuid: " id; done = 1; next } ins && !done && /^[^[:space:]]/ { print "uuid: " id; done = 1 } /^description:/ { ins = 1 } { print } END { if (!done) exit 1 }' "$$file" > "$$file.uuidtmp"; then \
				mv "$$file.uuidtmp" "$$file"; \
				echo "assigned $$new to $$file"; \
			else \
				rm -f "$$file.uuidtmp"; \
				echo "FAIL $$file: no description: line to anchor the uuid"; \
				exit 1; \
			fi; \
		fi; \
	done
