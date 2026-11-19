#!/bin/bash

source $(dirname "$0")/common.sh

if ! require_static_files; then
  echo "$0: refusing to deploy an incomplete site; run scripts/build.sh first" >&2
  exit 1
fi

rsync --info=all2,name1 -aP "$SITEDIR/" "$DEPLOY_HOST:$DEPLOY_REMOTEDIR"
