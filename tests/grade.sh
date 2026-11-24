#!/bin/sh
# Checks Haiku still sorts the made-up replies in grading-examples.json the
# way it should. Makes real Haiku calls through `claude`, so it uses your
# Claude usage and its answers vary a little from run to run. Run it after
# changing the instructions sent to Haiku.
#   tests/grade.sh            every example, 3 runs each
#   tests/grade.sh 5          5 runs each
#   ONLY=merge tests/grade.sh only the examples whose name contains "merge"
set -e
cd "$(dirname "$0")/.."
mkdir -p .build-tests
swiftc -parse-as-library -D TESTING blackroija.swift tests/GradingTests.swift -o .build-tests/grading-tests
./.build-tests/grading-tests tests/grading-examples.json "${1:-3}"
