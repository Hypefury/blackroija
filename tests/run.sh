#!/bin/sh
# Checks which section the window puts sessions in, from made-up facts
# (no session files, no GitHub, no Haiku). Run after any change to how
# sessions are sorted.
set -e
cd "$(dirname "$0")/.."
mkdir -p .build-tests
swiftc -parse-as-library -D TESTING blackroija.swift tests/SortingTests.swift -o .build-tests/sorting-tests
./.build-tests/sorting-tests
