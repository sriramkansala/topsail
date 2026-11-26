#!/bin/zsh
# The continuity suite: runs every cell of docs/continuity/matrix.md on the real island and
# checks each frame-by-frame trace (nothing pops, swaps, jumps or changes page unasked).
#
#   scripts/continuity.sh                    build, run every cell, check, print the result
#   scripts/continuity.sh 'toast.*'          only the cells whose id matches (ids, prefix*, commas)
#   add --no-build                           run the app that is already built
#   add --app /Applications/Topsail.app      run that app instead of the one in build/
#   add --optimized                          build and run the optimised flavour (frame times count)
#   add --film cell-a,cell-b                 also film those cells (docs/continuity/evidence/)
#   add --label before                       name for the films and the report (default: run)
#
# The run takes over the notch: it quits the Topsail that is running, shows made-up data only
# (test mode, `--continuity`; see Topsail/Continuity), and reopens /Applications/Topsail.app at
# the end if it was running. Exit status 0 means every cell passed.
set -uo pipefail

ROOT=${0:A:h:h}
PATTERN=all
BUILD=1
OPTIMIZED=0
APP=
FILM=
LABEL=run
while (( $# )); do
  case $1 in
    --no-build) BUILD=0 ;;
    --optimized) OPTIMIZED=1 ;;
    --app) APP=$2; BUILD=0; shift ;;
    --film) FILM=$2; shift ;;
    --label) LABEL=$2; shift ;;
    -*) echo "unknown option: $1"; exit 2 ;;
    *) PATTERN=$1 ;;
  esac
  shift
done

if [[ -z $APP ]]; then
  if (( OPTIMIZED )); then APP=$ROOT/build/Continuity/Topsail.app; else APP=$ROOT/build/Direct/Topsail.app; fi
fi
if (( BUILD )); then
  if (( OPTIMIZED )); then $ROOT/scripts/build.sh --direct --optimized || exit 1
  else $ROOT/scripts/build.sh --direct || exit 1; fi
fi
BINARY=$APP/Contents/MacOS/Topsail
[[ -x $BINARY ]] || { echo "No app at $APP (build it first, or pass --app)."; exit 1; }

OUT=$ROOT/build/continuity/$LABEL
rm -rf $OUT
mkdir -p $OUT/traces

FILM_TOOL=$ROOT/build/continuity/film
if [[ -n $FILM && ( ! -x $FILM_TOOL || $ROOT/scripts/continuity/film.swift -nt $FILM_TOOL ) ]]; then
  swiftc -O -o $FILM_TOOL $ROOT/scripts/continuity/film.swift 2> $OUT/film-build.log \
    || { echo "Could not build the film tool (see ${OUT#$ROOT/}/film-build.log)."; exit 1; }
fi

# One Topsail at the notch at a time.
INSTALLED=/Applications/Topsail.app
WAS_RUNNING=0
pgrep -f "^$INSTALLED/Contents/MacOS/Topsail" > /dev/null && WAS_RUNNING=1
pkill -f "Topsail.app/Contents/MacOS/Topsail" && sleep 1

restore() {
  pkill -f "Topsail.app/Contents/MacOS/Topsail --continuity" 2> /dev/null
  if (( WAS_RUNNING )); then open -g $INSTALLED; fi
}
trap restore EXIT

echo "Running '$PATTERN' on ${APP#$ROOT/} …"
$BINARY --continuity --continuity-list $OUT/cells.json --continuity-run "$PATTERN" \
  --continuity-out $OUT/traces --continuity-exit > $OUT/app.log 2>&1 &
APP_PID=$!

if [[ -n $FILM ]]; then
  # The film runs for as long as the app does; strips are cut from it afterwards, lined up with
  # each cell's trace by the clock both carry.
  $FILM_TOOL record --pid $APP_PID --out $OUT/film.mov > $OUT/film.log 2>&1 &
  FILM_PID=$!
fi

# Wait for the app to finish (it quits itself), showing progress.
LAST=
while kill -0 $APP_PID 2> /dev/null; do
  sleep 2
  if [[ -f $OUT/traces/progress.txt ]]; then
    NOW=$(< $OUT/traces/progress.txt)
    if [[ $NOW != $LAST ]]; then printf "\r\033[K%s" "$NOW"; LAST=$NOW; fi
  fi
done
echo
if [[ -n $FILM ]]; then wait $FILM_PID 2> /dev/null; fi
if [[ ! -f $OUT/traces/done.txt ]]; then
  echo "The run stopped early (was Topsail quit or replaced meanwhile?). See ${OUT#$ROOT/}/app.log"
  exit 3
fi
if [[ -n $FILM ]]; then
  [[ $FILM == all ]] && FILM=$(ls $OUT/traces | sed -n 's/\.jsonl$//p' | paste -sd, -)
  $FILM_TOOL strips --film $OUT/film.mov --traces $OUT/traces --cells "$FILM" \
    --out $ROOT/docs/continuity/evidence --label $LABEL | tee -a $OUT/film.log
fi

python3 -I $ROOT/scripts/continuity/check.py $OUT/traces --report $OUT/report.md --json $OUT/report.json
STATUS=$?
echo "Report: ${OUT#$ROOT/}/report.md"
exit $STATUS
