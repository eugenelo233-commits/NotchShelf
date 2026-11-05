# Third-party attribution

NotchShelf / 折叠栏 is distributed under GPL-3.0. See LICENSE.

Menu-bar event routing in `Sources/NotchShelf/ItemEvents.swift` adapts the event-field and event-relay approach from Ice by Jordan Baird and contributors, licensed GPL-3.0.

- Upstream: https://github.com/jordanbaird/Ice
- Source: Ice/MenuBar/MenuBarItems/MenuBarItemManager.swift
- Inspected revision: 11edd39115f3f43a83ae114b5348df6a0e1741cf
- Changes: smaller independent relay implementation, bounded timeout, new error handling and custom application UI.

Window enumeration uses the same read-only WindowServer API documented in Ice/Bridging/Bridging.swift; this application resolves it dynamically and provides a public-window-list fallback.

All application resources use native Apple system symbols; no upstream app name, icon or branding is reused. No external packages are required.

The macOS 26 AXExtrasMenuBar discovery strategy and AXFrame fallback were informed by Thaw (GPL-3.0), https://github.com/thaw-app/Thaw, specifically Thaw/Items/Interaction/MenuBarItemAXProvider.swift and packages/ThawAX/Sources/ThawAXCore/AXPrimitives.swift. The implementation here is independent and simplified, with per-call timeouts and a bounded background scan.
