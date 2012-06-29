#!/bin/bash

GAME="Test"
CMD="luajit uidraw.lua"

if [ "$1" == "--help" ]; then
  echo "${CMD}-run: starts $GAME"
  echo "Usage: ${CMD}-run [option]"
  echo "   --help       print this help and exit"
  echo "   --local-SDL  start $GAME with the bundled version of SDL"
  exit
fi

INSTDIR="`dirname $0`" ; cd "${INSTDIR}" ; INSTDIR="`pwd`"

if [ "$1" == "--local-SDL" ]; then
  echo "Starting ${GAME} with the bundled SDL version..."
  export LD_LIBRARY_PATH="${INSTDIR}"
fi

./${CMD}
