#!/bin/bash

source $(dirname "$0")/common.sh

DBDSN=${1:-$DEFAULT_DBDSN}

require_sqlite "$DBDSN"

ensure_static_files

#"$SCRIPTDIR"/gen_gravitytree.sh

ttdir="$TTDIR"
gen_pages=$(realpath -s --relative-to="$ttdir" "$SCRIPTDIR"/gen_pages.pl)

# gen_pages.pl takes the template and site directories from the
# environment, so the master files can live in the project directory.
# The paths are made relative to $ttdir, where it runs:
export GEN_PAGES_TTDIR=.
export GEN_PAGES_SITEDIR=$(realpath -s --relative-to="$ttdir" "$SITEDIR")
masterdir=$(realpath -s --relative-to="$ttdir" "$MASTERDIR")

(
    # gen_pages.pl is location agnostic, but this produces reports
    # that are easier on the eyes:
    cd "$ttdir"
    while read -r lang; do
	    "$gen_pages" "$masterdir/$(printf "$MASTER_NAME" $lang)" --force
    done
) < <(sqlite3 "$DBDSN" "SELECT lang_code FROM lang")
