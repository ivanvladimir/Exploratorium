#!/bin/bash

source $(dirname "$0")/common.sh

if [ "$1" = "-f" ]; then
  shift
  # Force a full regenerate for lattices:
  > "$DBDIR"/tmp_gen_lattices_data.sql.prev
fi

DBDSN=${1:-$DEFAULT_DBDSN}

require_sqlite "$DBDSN"

# Generate list of contexts that changed:
function get_changed_contexts {
  local TMPFILE="$DBDIR"/tmp_gen_lattices_data.sql
  "$SCRIPTDIR"/db_dump_data.sh > "$TMPFILE"
  [ ! -e "$TMPFILE.prev" ] && cp "$DBDIR"/data.sql "$TMPFILE.prev"
  diff -C 0 "$TMPFILE" "$TMPFILE.prev" |
    grep "INSERT INTO object_attribute" | cut -f4 -d, | sort -u |
    while read context_id; do echo -n $context_id,; done |
    sed 's/,$//'
  mv -f "$TMPFILE" "$TMPFILE.prev"
}

CONTEXT_IDS=$(get_changed_contexts)

# A lattice is regenerated when its context changed in the database
# or when its lattice.json is missing (e.g. SITEDIR was recreated),
# so an incremental build never leaves a diagram without its lattice.
CHANGED_CODES=
if [ -n "$CONTEXT_IDS" ]; then
  CHANGED_CODES=$(sqlite3 "$DBDSN" "SELECT code FROM context WHERE context_id IN ($CONTEXT_IDS)")
fi

generated=0
while read -r lang; do
  while read -r context; do
    diagram_dir=$(get_diagram_dir "$lang" "$context")
    fname=$diagram_dir/lattice.json
    if [ -s "$fname" ] && ! grep -qxF -- "$context" <<< "$CHANGED_CODES"; then
      continue
    fi
    echo "Generating $fname"
    mkdir -p "$diagram_dir"
    "$SCRIPTDIR"/gen_lattice.sh "$DBDSN" "$context" "$lang" > "$fname"
    generated=$((generated + 1))
  done < <(sqlite3 "$DBDSN" "SELECT code FROM context" | filter_contexts)
done < <(sqlite3 "$DBDSN" "SELECT lang_code FROM lang")

if [ $generated -eq 0 ]; then
  echo "No changes in contexts detected."
fi
