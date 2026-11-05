#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p .build/checks
swiftc Sources/NotchShelf/Layout.swift Tests/main.swift -o .build/checks/layout-checks
.build/checks/layout-checks
swiftc Sources/NotchShelf/ShelfIconRenderer.swift Tests/Icons/main.swift -o .build/checks/icon-checks
.build/checks/icon-checks
swift build
