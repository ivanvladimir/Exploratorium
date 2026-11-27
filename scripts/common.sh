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

# A project bundles everything specific to one site: its config.sh,
# master Markdown files, data.sql/data.ods, project.css, images and
# each diagram's config.js and pos.json. PROJECT selects it (usually
# from scripts/config.sh). Without PROJECT the old single-project
# layout is used (tt/master-*.md, db/data.sql).
PROJECT=${PROJECT:-}
if [ -n "$PROJECT" ]; then
  PROJECT_HOME=${PROJECT_HOME:-$PROJECTDIR/projects/$PROJECT}
  if [ ! -d "$PROJECT_HOME" ]; then
    echo "$0: project directory '$PROJECT_HOME' for PROJECT=$PROJECT does not exist" >&2
    exit 1
  fi
else
  PROJECT_HOME=
fi
PROJECT_CONFIGFILE=${PROJECT_HOME:+$PROJECT_HOME/config.sh}
if [ -n "$PROJECT_CONFIGFILE" -a -e "$PROJECT_CONFIGFILE" ]; then
  source "$PROJECT_CONFIGFILE" || exit 1
fi

DBDIR=${DBDIR:-$PROJECTDIR/db}
SITEDIR=${SITEDIR:-$PROJECTDIR/site}
TTDIR=${TTDIR:-$PROJECTDIR/tt}
STATICDIR=${STATICDIR:-$PROJECTDIR/static}
DIAGRAMSUBDIR=${DIAGRAMSUBDIR:-theories}
DIAGRAMDIR=${DIAGRAMDIR:-$SITEDIR/$DIAGRAMSUBDIR/%s/%s}
DIAGRAM_FILTERS=${DIAGRAM_FILTERS:-}
DEFAULT_DBDSN=${DEFAULT_DBDSN:-$DBDIR/exploratorium.db}
MASTERDIR=${MASTERDIR:-${PROJECT_HOME:-$TTDIR}}
MASTER_NAME=${MASTER_NAME:-master-%s.md}
DATA_SQL=${DATA_SQL:-${PROJECT_HOME:-$DBDIR}/data.sql}
DATA_ODS=${DATA_ODS:-${PROJECT_HOME:+$PROJECT_HOME/data.ods}}
DEPLOY_HOST=${DEPLOY_HOST:-remo}
DEPLOY_REMOTEDIR=${DEPLOY_REMOTEDIR:-Exploratorium}

# Source again so settings can refer to the defaults above; the
# general config goes last so it can override the project's.
if [ -n "$PROJECT_CONFIGFILE" -a -e "$PROJECT_CONFIGFILE" ]; then
  source "$PROJECT_CONFIGFILE" || exit 1
fi
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
# that are tracked in git (.htaccess, cmm/, db/,
# gravity-tree/{style.css,config.js,fonts}).
# The generators never create those, so if SITEDIR is emptied or
# recreated they would be lost. Restore any tracked file that is
# missing from the working tree. Files that exist but were modified
# are left untouched.
#
# Then copy in the files kept outside the site: the shared ones in
# $STATICDIR (style.css, favicon.ico, images/, lib/*.js) and the
# project's.
function ensure_static_files {
  mkdir -p "$SITEDIR"

  if ! git -C "$SITEDIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "$0: warning: $SITEDIR is not inside a git work tree; cannot restore static files" >&2
    install_static_files
    install_project_files
    return 0
  fi

  local count
  count=$(git -C "$SITEDIR" ls-files --deleted -- . | wc -l)
  if [ "$count" -gt 0 ]; then
    echo "Restoring $count missing static file(s) in $SITEDIR from git"
    git -C "$SITEDIR" ls-files -z --deleted -- . |
      xargs -0 git -C "$SITEDIR" checkout --
  fi

  install_static_files
  install_project_files
}

# Copy a source file into the site unless the site's copy is newer
# (e.g. a pos.json saved there from the diagram editor). A newer,
# different site copy is kept and reported, so it can be copied back
# to its source.
function install_file {
  local src="$1" dest="$2"

  if [ -e "$dest" ] && [ "$dest" -nt "$src" ]; then
    if ! cmp -s "$src" "$dest"; then
      echo "$0: keeping $dest: it is newer than $src (copy it back there to keep the change)" >&2
    fi
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cp -f "$src" "$dest"
}

# Copy everything in $STATICDIR to the same path under $SITEDIR.
function install_static_files {
  [ -d "$STATICDIR" ] || return 0

  local f
  while IFS= read -r -d '' f; do
    install_file "$f" "$SITEDIR/${f#"$STATICDIR/"}"
  done < <(find "$STATICDIR" -type f -print0)
}

# Put the selected project's hand-maintained files where the site
# expects them. The site always gets a project.css (empty if the
# project has none), since every page links it.
function install_project_files {
  [ -n "$PROJECT_HOME" ] || return 0

  if [ -e "$PROJECT_HOME/project.css" ]; then
    cp -f "$PROJECT_HOME/project.css" "$SITEDIR/project.css"
  else
    : > "$SITEDIR/project.css"
  fi

  local f rel lang context
  if [ -d "$PROJECT_HOME/images" ]; then
    while IFS= read -r -d '' f; do
      rel=${f#"$PROJECT_HOME/images/"}
      install_file "$f" "$SITEDIR/images/$rel"
    done < <(find "$PROJECT_HOME/images" -type f -print0)
  fi

  if [ -d "$PROJECT_HOME/diagrams" ]; then
    while IFS= read -r -d '' f; do
      rel=${f#"$PROJECT_HOME/diagrams/"}
      lang=${rel%%/*}
      rel=${rel#*/}
      context=${rel%%/*}
      install_file "$f" "$(get_diagram_dir "$lang" "$context")/${rel#*/}"
    done < <(find "$PROJECT_HOME/diagrams" -mindepth 3 -type f -print0)
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
