# Campaign UUID tooling.
#
# Every file in campaigns/ carries a `uuid:` the importer keys on — it, not the
# filename or the title, is the campaign's identity. Contributors leave
# the field out; run `make all` after merging a campaign PR to assign what is
# missing and verify the result before pushing. The importer never writes a
# uuid itself (ADR-0005 in lasseh/whynoipv6), and it rejects a file without
# one. `make install-hooks` puts the verification in a pre-push hook so a
# forgotten `make all` cannot reach origin.

CAMPAIGN_FILES := $(wildcard campaigns/*.yml campaigns/*.yaml)
UUIDS := scripts/campaign-uuids.sh

.PHONY: all help check-uuids fix-uuids install-hooks test lint

# Assign what is missing, then verify everything.
all: fix-uuids check-uuids

help:
	@echo "Available targets:"
	@echo "  make all          - assign missing UUIDs, then check every file"
	@echo "  make fix-uuids    - assign a UUID to every campaign file lacking one"
	@echo "  make check-uuids  - verify every campaign file has a unique, well-formed UUID (exit 1 on failure)"
	@echo "  make install-hooks - run check-uuids from a pre-push hook (local config, once per clone)"
	@echo "  make test         - run the uuid tooling's tests against fixtures"
	@echo "  make lint         - shellcheck the scripts and the hook"

# Local config, never versioned, so it only ever applies to this clone.
install-hooks:
	@git config core.hooksPath .githooks
	@echo "core.hooksPath -> .githooks"

# Blocking: missing, malformed, repeated or shared UUIDs all exit 1.
check-uuids:
	@$(UUIDS) check $(CAMPAIGN_FILES)

fix-uuids:
	@$(UUIDS) fix $(CAMPAIGN_FILES)

test:
	@scripts/campaign-uuids_test.sh

lint:
	@shellcheck scripts/*.sh .githooks/pre-push
