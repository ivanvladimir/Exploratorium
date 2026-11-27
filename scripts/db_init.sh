#!/bin/bash

source $(dirname "$0")/common.sh

DBDSN=${1:-$DEFAULT_DBDSN}

require_sqlite

[ -e "$DBDSN" ] && mv -f "$DBDSN" "$DBDSN".bak

sqlite3 "$DBDSN" < "$DBDIR"/ddl.sql &&
  sqlite3 "$DBDSN" < "$DATA_SQL"

test_dbfile "$DBDSN"
