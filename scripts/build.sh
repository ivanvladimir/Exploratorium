#!/bin/bash

source $(dirname "$0")/common.sh

DBDSN=${1:-$DEFAULT_DBDSN}

ensure_static_files

"$SCRIPTDIR"/gen_diagram_catalogs.sh "$DBDSN"
"$SCRIPTDIR"/gen_lattices.sh "$DBDSN"
"$SCRIPTDIR"/gen_pages.sh "$DBDSN"
