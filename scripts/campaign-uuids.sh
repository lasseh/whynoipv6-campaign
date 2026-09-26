#!/bin/sh
# Assigns and verifies campaign uuids. The importer keys every campaign on
# its uuid and never writes one itself (ADR-0005 in lasseh/whynoipv6), so
# this script is the only writer.
#
#   campaign-uuids.sh check FILE...  exit 1 on a missing, malformed, repeated or shared uuid
#   campaign-uuids.sh fix FILE...    assign a uuid to every file that lacks one
set -eu

# The shape the importer accepts: any well-formed UUID, not v4 specifically,
# so a preserved uuid never fails here.
UUID_RE='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'

# uuid_of FILE prints the first top-level uuid value the way YAML reads it:
# trailing whitespace (a CRLF file's CR included) and quotes stripped, and
# "" / ~ / null read as empty.
uuid_of() {
	sed -n 's/^uuid:[[:space:]]*//p' "$1" | head -n 1 |
		sed -e 's/[[:space:]]*$//' -e 's/^"\(.*\)"$/\1/' -e "s/^'\(.*\)'\$/\1/" -e 's/^~$//' -e 's/^null$//'
}

check() {
	fail=0
	for file in "$@"; do
		lines=$(grep -c '^uuid:' "$file" || true)
		uuid=$(uuid_of "$file")
		if [ "$lines" -gt 1 ]; then
			echo "FAIL $file: $lines uuid lines"
			fail=1
		elif [ -z "$uuid" ]; then
			echo "FAIL $file: no uuid assigned"
			fail=1
		elif ! printf '%s\n' "$uuid" | grep -qE "$UUID_RE"; then
			echo "FAIL $file: malformed uuid ($uuid)"
			fail=1
		else
			echo "ok   $file: $uuid"
		fi
	done
	# Case-folded, as the importer compares them. A shared uuid is worth
	# catching here because the sync keeps at most one of the files.
	dupes=$(for file in "$@"; do
		printf '%s %s\n' "$(uuid_of "$file" | tr '[:upper:]' '[:lower:]')" "$file"
	done | awk '
		$1 != "" { f = substr($0, length($1) + 2); files[$1] = files[$1] " " f; n[$1]++ }
		END { for (u in n) if (n[u] > 1) print "FAIL duplicate uuid " u " in:" files[u] }')
	if [ -n "$dupes" ]; then
		printf '%s\n' "$dupes"
		fail=1
	fi
	return "$fail"
}

fix() {
	for file in "$@"; do
		if [ -n "$(uuid_of "$file")" ]; then
			continue
		fi
		id=$({ uuidgen 2>/dev/null || cat /proc/sys/kernel/random/uuid; } | tr '[:upper:]' '[:lower:]')
		cr=''
		if grep -q "$(printf '\r')\$" "$file"; then
			cr=$(printf '\r')
		fi
		if grep -q '^uuid:' "$file"; then
			# An empty placeholder: fill it wherever it sits.
			awk -v line="uuid: $id$cr" '!done && /^uuid:/ { print line; done = 1; next } { print }' \
				"$file" >"$file.uuidtmp"
		# Otherwise splice the line in after the description and its
		# continuation lines, or at the end when description is the last key.
		elif ! awk -v line="uuid: $id$cr" '
			ins && !done && /^[^[:space:]]/ { print line; done = 1 }
			/^description:/ { ins = 1 }
			{ print }
			END { if (!ins) exit 1; if (!done) print line }' "$file" >"$file.uuidtmp"; then
			rm -f "$file.uuidtmp"
			echo "FAIL $file: no description: line to anchor the uuid"
			exit 1
		fi
		mv "$file.uuidtmp" "$file"
		echo "assigned $id to $file"
	done
}

cmd=${1:-}
[ $# -gt 0 ] && shift
case $cmd in
check) check "$@" ;;
fix) fix "$@" ;;
*)
	echo "usage: $0 check|fix FILE..." >&2
	exit 2
	;;
esac
