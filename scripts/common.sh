if [ -n "$CONFIGFILE" ]; then
  source "$CONFIGFILE" || exit 1
fi

SCRIPTDIR=${SCRIPTDIR:-$(dirname "$0")}

if [ -z "$CONFIGFILE" ]; then
  CONFIGFILE=$SCRIPTDIR/config.sh
  if [ -e "$CONFIGFILE" ]; then
    source "$CONFIGFILE" || exit 1
  else
    CONFIGFILE=
  fi
fi

PROJECTDIR=${PROJECTDIR:-$SCRIPTDIR/..}
DBDIR=${DBDIR:-$PROJECTDIR/db}
SITEDIR=${SITEDIR:-$PROJECTDIR/site}
DIAGRAMSUBDIR=${DIAGRAMSUBDIR:-theories}
DIAGRAMDIR=${DIAGRAMDIR:-$SITEDIR/$DIAGRAMSUBDIR/%s/%s}
DIAGRAM_FILTERS=${DIAGRAM_FILTERS:-}
DEFAULT_DBDSN=${DEFAULT_DBDSN:-$DBDIR/exploratorium.db}
MASTER_NAME=${MASTER_NAME:-master-%s.md}
DEPLOY_HOST=${DEPLOY_HOST:-remo}
DEPLOY_REMOTEDIR=${DEPLOY_REMOTEDIR:-Exploratorium}

if [ -n "$CONFIGFILE" ]; then
  source "$CONFIGFILE" || exit 1
fi

function test_dbfile {
  local dbfile="$1"

  if [ ! -e "$dbfile" ]; then
    echo "$0: DBDSN '$dbfile' does not exist" >&2
    exit 1
  fi

  if [ "$(sqlite3 "$dbfile" "SELECT 'OK'")" != OK ]; then
    echo "$0: Error opening DBDSN '$dbfile'" >&2
    exit 1
  fi
}

function require_sqlite {
  local sqlite_version=$(sqlite3 --version 2>/dev/null | cut -f1 -d\ )

  IFS=. read major minor rel <<< $sqlite_version
  if [ $(printf %02d%03d $major $minor) -lt 3040 ]; then
    echo "$0: sqlite3 version $sqlite_version is older than 3.40, which is needed for STRICT tables" >&2
    exit 1
  fi

  local dbfile="$1"
  if [ -n "$dbfile" ]; then
    test_dbfile "$dbfile"
  fi
}

function require_inkscape {
  if [ -e "/Applications/Inkscape.app/Contents/MacOS/inkscape" ]; then
    echo "/Applications/Inkscape.app/Contents/MacOS/inkscape"
  elif [ -e "$HOME"/bin/[Ii]nkscape* ]; then
    echo "$HOME"/bin/[Ii]nkscape*
  elif ! which inkscape; then
    echo "$0: inkscape not found" >&2
    exit 1
  fi
}

# The site directory mixes generated files with hand-maintained ones
# that are tracked in git (style.css, images/, lib/*.js, favicon.ico,
# .htaccess, gravity-tree/{style.css,config.js,fonts}, and each
# diagram's pos.json and config.js). The generators never create
# those, so if SITEDIR is emptied or recreated they would be lost.
# Restore any tracked file that is missing from the working tree.
# Files that exist but were modified are left untouched, so local
# edits (e.g. node positions saved from the diagram editor) are kept.
function ensure_static_files {
  mkdir -p "$SITEDIR"

  if ! git -C "$SITEDIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "$0: warning: $SITEDIR is not inside a git work tree; cannot restore static files" >&2
    return 0
  fi

  local count
  count=$(git -C "$SITEDIR" ls-files --deleted -- . | wc -l)
  if [ "$count" -gt 0 ]; then
    echo "Restoring $count missing static file(s) in $SITEDIR from git"
    git -C "$SITEDIR" ls-files -z --deleted -- . |
      xargs -0 git -C "$SITEDIR" checkout --
  fi
}

function require_static_files {
  local missing=0 f
  for f in style.css favicon.ico lib/reticulo.js lib/mathjax-config.js; do
    if [ ! -e "$SITEDIR/$f" ]; then
      echo "$0: missing $SITEDIR/$f" >&2
      missing=1
    fi
  done
  return $missing
}

function get_diagram_dir {
  printf "$DIAGRAMDIR" "$@"
}

function filter_contexts {
  if [ -z "$DIAGRAM_FILTERS" ]; then
    cat
    return
  fi

  grep $(
    for i in $DIAGRAM_FILTERS; do
      echo "-e $i"
    done
        )
}
