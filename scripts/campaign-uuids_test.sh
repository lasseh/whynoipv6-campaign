#!/bin/sh
# Tests for campaign-uuids.sh. Each case writes a fixture, runs the script
# against it and checks the result. Run with `make test`.
set -eu

script=$(cd "$(dirname "$0")" && pwd)/campaign-uuids.sh
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
failures=0
cr=$(printf '\r')

fail() {
	echo "FAIL $1"
	failures=$((failures + 1))
}

# fixture NAME CONTENT writes CONTENT (printf format) to NAME and prints the path.
fixture() {
	# shellcheck disable=SC2059 # the content is the format on purpose
	printf "$2" >"$dir/$1"
	echo "$dir/$1"
}

uuid_line() { grep -n '^uuid: [0-9a-f-]\{36\}' "$1" | cut -d: -f1; }

# fixed NAME FILE: fix assigns a uuid and check then accepts the file.
fixed() {
	if ! "$script" fix "$2" >/dev/null; then
		fail "$1: fix failed"
		return 1
	fi
	if ! "$script" check "$2" >/dev/null; then
		fail "$1: check rejects the fixed file: $("$script" check "$2")"
		return 1
	fi
}

f=$(fixture plain.yml 'title: A\ndescription: x\ndomains:\n  - a.no\n')
if fixed plain "$f" && [ "$(uuid_line "$f")" != 3 ]; then
	fail "plain: uuid on line $(uuid_line "$f"), want 3"
fi

f=$(fixture block.yml 'title: A\ndescription: |\n  one\n\n  two\ndomains:\n  - a.no\n')
if fixed "block scalar" "$f" && [ "$(sed -n 6p "$f" | cut -c1-5)" != uuid: ]; then
	fail "block scalar: uuid not directly before domains"
fi

f=$(fixture last.yml 'title: A\ndomains:\n  - a.no\ndescription: x\n')
if fixed "description last" "$f" && [ "$(uuid_line "$f")" != 5 ]; then
	fail "description last: uuid on line $(uuid_line "$f"), want 5"
fi

f=$(fixture late.yml 'title: A\ndescription: x\ndomains:\n  - a.no\nuuid:\n')
if fixed "placeholder after domains" "$f" && [ "$(grep -c '^uuid:' "$f")" != 1 ]; then
	fail "placeholder after domains: $(grep -c '^uuid:' "$f") uuid lines"
fi

for value in '""' "''" '~' 'null'; do
	f=$(fixture null.yml "title: A\ndescription: x\nuuid: $value\ndomains:\n  - a.no\n")
	fixed "uuid: $value" "$f" || true
done

f=$(fixture crlf.yml 'title: A\r\ndescription: x\r\nuuid:\r\ndomains:\r\n  - a.no\r\n')
if fixed crlf "$f" && ! grep -q "^uuid: .*$cr\$" "$f"; then
	fail "crlf: the filled line lost its CR"
fi

f=$(fixture quoted.yml 'title: A\ndescription: x\nuuid: "11111111-2222-3333-4444-555555555555"\ndomains:\n  - a.no\n')
before=$(cat "$f")
"$script" fix "$f" >/dev/null
if [ "$(cat "$f")" != "$before" ]; then
	fail "quoted: fix rewrote an assigned uuid"
fi
"$script" check "$f" >/dev/null || fail "quoted: check rejects a quoted uuid"

f=$(fixture nodesc.yml 'title: A\ndomains:\n  - a.no\n')
if "$script" fix "$f" >/dev/null; then
	fail "no description: fix succeeded"
fi
[ -e "$f.uuidtmp" ] && fail "no description: temp file left behind"

f=$(fixture twice.yml 'title: A\ndescription: x\nuuid: 11111111-2222-3333-4444-555555555555\nuuid: 11111111-2222-3333-4444-666666666666\ndomains:\n  - a.no\n')
"$script" check "$f" >/dev/null && fail "two uuid lines: check passed"

f=$(fixture bad.yml 'title: A\ndescription: x\nuuid: 11111111-2222\ndomains:\n  - a.no\n')
"$script" check "$f" >/dev/null && fail "malformed: check passed"

a=$(fixture lower.yml 'title: A\ndescription: x\nuuid: abcdef00-2222-3333-4444-555555555555\ndomains:\n  - a.no\n')
b=$(fixture upper.yml 'title: B\ndescription: x\nuuid: ABCDEF00-2222-3333-4444-555555555555\ndomains:\n  - b.no\n')
if out=$("$script" check "$a" "$b"); then
	fail "case-folded duplicate: check passed"
elif ! printf '%s\n' "$out" | grep -q '^FAIL duplicate uuid abcdef00-'; then
	fail "case-folded duplicate: not reported as a duplicate: $out"
fi

if [ "$failures" -gt 0 ]; then
	echo "$failures failure(s)"
	exit 1
fi
echo "ok   campaign-uuids.sh"
