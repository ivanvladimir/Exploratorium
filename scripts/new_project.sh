#!/bin/bash

# Create a new project directory under projects/. See "Projects" in
# README.md for what a project contains.

SCRIPTDIR=${SCRIPTDIR:-$(dirname "$0")}
PROJECTDIR=${PROJECTDIR:-$SCRIPTDIR/..}

function usage {
  cat >&2 <<EOF
Usage: $0 [-c] [-s SOURCE] NAME

Create projects/NAME, a new project whose diagrams are put in
site/NAME/. The master Markdown files are copied from the SOURCE
project, with their links and outputs moved from SOURCE's diagram
directory to NAME's.

 -c		copy SOURCE's data too (data.sql, data.ods, project.css,
		images/ and diagrams/), making NAME a full copy of it.
		Without -c, NAME gets no data and an empty project.css.
 -s SOURCE	project to start from. Default: planetas
 NAME		new project name: letters, digits, '-' and '_'

Build it afterwards with: PROJECT=NAME scripts/init.sh
EOF
  exit 1
}

COPY=
SOURCE=planetas
while getopts "cs:h" opt; do
  case $opt in
    c) COPY=1 ;;
    s) SOURCE=$OPTARG ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

NAME=$1
[ -n "$NAME" ] && [ $# -eq 1 ] || usage

if [[ ! "$NAME" =~ ^[A-Za-z0-9_-]+$ ]]; then
  echo "$0: invalid project name '$NAME': use only letters, digits, '-' and '_'" >&2
  exit 1
fi

# NAME becomes a directory in the site; it must not take the place of
# the site's own directories.
case $NAME in
  lib|images|db|cmm|fonts|gravity-tree)
    echo "$0: '$NAME' is a directory of the site itself; choose another name" >&2
    exit 1
    ;;
esac

SRC=$PROJECTDIR/projects/$SOURCE
DEST=$PROJECTDIR/projects/$NAME

if [ ! -d "$SRC" ]; then
  echo "$0: source project '$SRC' does not exist" >&2
  exit 1
fi
if [ -e "$DEST" ]; then
  echo "$0: '$DEST' already exists" >&2
  exit 1
fi
if ! ls "$SRC"/master-*.md >/dev/null 2>&1; then
  echo "$0: source project '$SRC' has no master-*.md files" >&2
  exit 1
fi

# The source's diagram directory, as its config.sh sets it.
SRC_SUBDIR=$(
  DIAGRAMSUBDIR=
  [ -e "$SRC/config.sh" ] && source "$SRC/config.sh" >/dev/null
  echo "${DIAGRAMSUBDIR:-theories}"
)

mkdir -p "$DEST" || exit 1

# Paths in the master files look like "planetas/en/SS/index.html" or
# (planetas/en/SS): move those under the new diagram directory.
for f in "$SRC"/master-*.md; do
  sed -E "s#([(\"])$SRC_SUBDIR/#\\1$NAME/#g" "$f" > "$DEST/$(basename "$f")"
done

if [ -n "$COPY" ]; then
  if [ -e "$SRC/config.sh" ]; then
    if grep -q '^DIAGRAMSUBDIR=' "$SRC/config.sh"; then
      sed "s#^DIAGRAMSUBDIR=.*#DIAGRAMSUBDIR=$NAME#" "$SRC/config.sh" > "$DEST/config.sh"
    else
      { cat "$SRC/config.sh"; echo "DIAGRAMSUBDIR=$NAME"; } > "$DEST/config.sh"
    fi
  fi
  for f in data.sql data.ods project.css images diagrams; do
    [ -e "$SRC/$f" ] && cp -r "$SRC/$f" "$DEST/"
  done
  # Comments in the copied files name the source project.
  for f in config.sh project.css; do
    [ -e "$DEST/$f" ] &&
      sed -i -E -e "s#\"$SOURCE\" project#\"$NAME\" project#g" \
          -e "s#PROJECT=$SOURCE([^A-Za-z0-9_-]|\$)#PROJECT=$NAME\1#g" "$DEST/$f"
  done
fi

if [ ! -e "$DEST/config.sh" ]; then
  cat > "$DEST/config.sh" <<EOF
# Settings for the "$NAME" project. Sourced by scripts/common.sh
# after scripts/config.sh has selected PROJECT=$NAME.
DIAGRAMSUBDIR=$NAME
EOF
fi

if [ ! -e "$DEST/project.css" ]; then
  cat > "$DEST/project.css" <<EOF
/* Styles specific to the "$NAME" project. The build copies this
   file to site/project.css, which every page loads after style.css. */

/* Label fonts (defaults in style.css: 24px, Arial). Uncomment to
   change them; stacked labels are spaced to match.
:root {
	--label-font-size: 24px;
	--label-font-family: Arial, sans-serif;
	--attribute-label-font-size: 24px;
	--object-label-font-size: 24px;
}
*/

/* One colour per attribute class code (attr_class.code in data.sql):
.textbox-box.box-«code» {
	--fill: #ffc66c;
}
*/
EOF
fi

mkdir -p "$DEST/diagrams"

# Shorter paths for the messages below.
SRC=$(realpath -s --relative-to=. "$SRC")
DEST=$(realpath -s --relative-to=. "$DEST")
TEMPLATE=$(realpath -s --relative-to=. "$PROJECTDIR/db/ods/template.ots")

echo "Created $DEST from $SRC:"
(cd "$DEST" && find . -type f | sed 's#^\./#  #' | sort)

if [ -n "$COPY" ]; then
  cat <<EOF

Build it with:
  PROJECT=$NAME scripts/init.sh
EOF
else
  cat <<EOF

Next steps:
  1. Make the project's spreadsheet, starting from the template:
       open $TEMPLATE and save it as $DEST/data.ods
  2. Load it and write data.sql:
       PROJECT=$NAME scripts/ods2db.sh
       PROJECT=$NAME scripts/db_dump_data.sh > $DEST/data.sql
  3. Edit the master-*.md files: they still describe $SOURCE's pages
     and diagrams.
  4. Build it:
       PROJECT=$NAME scripts/build.sh
EOF
fi
