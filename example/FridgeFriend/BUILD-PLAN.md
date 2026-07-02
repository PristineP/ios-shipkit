# FridgeFriend Build Plan

## Session Doctrine

- **One phase = one Claude Code session.** Do not start Phase N+1 in a session that built Phase N, even if there's context left. Fresh session, fresh context, clean base.
- **Open every session the same way:** paste the "Claude Code Handoff" section of `PRD.md`, then the current phase block from this file, then say "build this phase." Nothing else — no full PRD, no back-story.
- **Close every session the same way:** run the phase's Verify steps yourself, in the simulator, by hand. If they pass, commit (`git commit -m "Phase N: <goal>"`). Never start a phase on an unverified or uncommitted base.
- **Two-strike revert rule:** if a build error survives two fix attempts, stop prompting variations. `git checkout -- .`, then re-prompt with the exact compiler output pasted verbatim — Claude fixes real errors far better than descriptions of errors.
- **Passing files are read-only.** Reference them by path ("uses `Theme.swift`, don't modify it"). Never paste a working file back into the prompt "for context" and never ask Claude to regenerate or "improve" a file that already passes Verify.
- **Scope discipline:** if Claude adds anything not listed in the phase's Files & surfaces (an extra manager class, a settings screen, a dependency), delete it before verifying. Unrequested code is a defect.

---

## Phase 1: App Shell, Data Model, Theme

**Builds on:** nothing. Fresh Xcode project "FridgeFriend": iOS App template, SwiftUI interface, iOS 17.0 deployment target, Swift 6 language mode, no template SwiftData checkbox (the container is hand-rolled for the fallback path).

**Files & surfaces:** `FridgeFriendApp.swift`, `FridgeItem.swift`, `Theme.swift`, `StateViews.swift`, `Route.swift`, `RootView.swift`, `ItemListView.swift` (empty-state only this phase).

**Steps:**

1. Create `FridgeItem` `@Model` exactly per the PRD Data Model table — including `locationRaw` as a stored string with a typed `location` accessor, and the expiry-math extension (`soonWindowDays`, `daysUntilExpiry(asOf:calendar:)`, `expiryStatus(asOf:calendar:)`, `expiryBadgeText(asOf:calendar:)`). All date math on `startOfDay` boundaries.
2. Create `Theme` with status color/label/icon functions and the spacing scale. No view may hard-code a status color after this file exists.
3. Create `StateViews.swift` with `EmptyStateView` (wrapping `ContentUnavailableView`, optional action button) and `LoadingStateView`.
4. Create `Route`, `SheetRoute`, and the `@Observable @MainActor Router` (path array, sheet, push/pop/popToRoot/present/dismissSheet).
5. Create `FridgeFriendApp` with the do/catch `ModelContainer` — disk store first, in-memory fallback on failure, `fatalError` only if even in-memory fails.
6. Create `RootView` owning the `NavigationStack(path:)`, the `navigationDestination` switch (stub destinations with `Text` for now is fine), the single `.sheet(item:)` (stub content), and `.environment(router)`.
7. `ItemListView` renders only the empty state this phase: refrigerator icon, "Nothing tracked yet", an "Add First Item" button that presents `.addItem` (the stub sheet), plus the toolbar with stats and add buttons.

**Verify (in simulator):**

1. Delete any previous install from the simulator, build and run on an iPhone 16 simulator.
2. Cold launch lands on the empty state with icon, title, message, and a prominent "Add First Item" button. No blank screen, no placeholder list.
3. Tap "Add First Item" and the toolbar "+" — both present the stub sheet; swipe it down to dismiss.
4. Toggle dark mode (Features → Toggle Appearance) — empty state remains legible.
5. Settings → Accessibility → Larger Text → max Dynamic Type — nothing truncates into uselessness.

**Done when:** all Verify steps pass, the project compiles with zero warnings in Swift 6 mode, and no file exceeds ~200 lines.

---

## Phase 2: Add Flow and Live List

**Builds on:** Phase 1 (do not modify `FridgeItem.swift`, `Theme.swift`, `StateViews.swift`).

**Files & surfaces:** `ItemFormView.swift` (new, add mode wired; edit mode built but unreachable until Phase 3), `ExpiryBadge.swift` (new), `ItemListView.swift` (flat list of rows replaces stub), `RootView.swift` (sheet switch now presents the real form).

**Steps:**

1. Build `ItemFormModel` as `@Observable @MainActor`: fields mirroring the form, `trimmedName` / `canSave` validation, and `save(in:)` which either mutates the item being edited or inserts a new one. No SwiftData writes anywhere else in the form.
2. Build `ItemFormView`: `Form` with Item (name field, quantity stepper 1–99, location picker with icons), Expiry (`DatePicker`, date only, past dates allowed), Notes (multi-line `TextField`). Own `NavigationStack`, inline title switching "New Item"/"Edit Item", Cancel/Save toolbar, Save disabled while `canSave` is false.
3. Build `ExpiryBadge`: capsule pill using `Theme` status color/icon and `expiryBadgeText`, with a combined accessibility label ("Expiring Soon, Tomorrow").
4. Replace the list stub: `@Query(sort: \FridgeItem.expiryDate)`, one flat section of rows (location icon, name, ×quantity when > 1, badge). Keep the empty state for the zero-items case.

**Verify (in simulator):**

1. Add "Milk", expiry 2 days out → row appears with an orange "2d left" badge.
2. Add "Mystery jar", expiry set to yesterday via the date picker → red "Yesterday" badge. (This proves past dates are allowed.)
3. Add "Rice", pantry, expiry 30 days out, quantity 3 → cabinet icon, "×3", green "30d left".
4. Type only spaces in the name field → Save stays disabled. Cancel → nothing was added.
5. Force-quit the app (swipe up in the app switcher), relaunch → all three items still there, still sorted by expiry ascending.

**Done when:** all Verify steps pass and the only write paths in the app are `ItemFormModel.save(in:)` and nothing else.

---

## Phase 3: Sections, Detail, Edit, Delete

**Builds on:** Phases 1–2 (form and badge are now read-only).

**Files & surfaces:** `ItemListView.swift` (sectioned grouping, swipe-to-delete, foreground refresh), `ItemDetailView.swift` (new), `RootView.swift` (real detail destination, edit sheet case wired).

**Steps:**

1. Group the queried items into sections by `expiryStatus(asOf: referenceDate)` in `ExpiryStatus.allCases` order (Expiring Soon → Fresh → Expired), skipping empty sections. Section headers show label + count.
2. Hold `referenceDate` in `@State`, refresh it on `scenePhase == .active` so grouping recomputes on foreground.
3. Rows become `NavigationLink(value: Route.itemDetail(item))`; add `.onDelete` per section, mapping offsets against that section's filtered array — not the global query array (classic off-by-section bug).
4. Build `ItemDetailView`: labeled rows (status badge, expires, location, quantity, added), notes section hidden when empty, Edit button presenting `.editItem(item)`, destructive Delete row behind a `confirmationDialog`, popping via the router after delete.
5. Guard the entire detail body on `item.isDeleted`, rendering `EmptyStateView` with a "Back to List" action instead of touching a dead model's properties.

**Verify (in simulator):**

1. With the Phase 2 items present, confirm three sections appear in order Expiring Soon / Fresh / Expired with correct counts, and "Milk" sits in Expiring Soon.
2. Swipe-delete "Rice" from Fresh → the whole Fresh section disappears (empty sections are hidden). The other sections' items are untouched — the exact item swiped is the item deleted.
3. Tap "Milk" → detail shows badge, dates, location. Tap Edit, change expiry to yesterday, Save → detail badge turns red; go back → "Milk" now lives in Expired.
4. From "Mystery jar" detail, tap Delete → confirmation dialog → Delete → lands back on the list, jar gone.
5. Edit an item and tap Cancel → no field changed (confirms no partial writes on cancel).

**Done when:** all Verify steps pass and deleting the last item lands you back on the Phase 1 empty state, not an empty `List`.

---

## Phase 4: Stats

**Builds on:** Phases 1–3.

**Files & surfaces:** `StatsView.swift` (new, includes `StatsSummary`), `RootView.swift` (stats destination goes live).

**Steps:**

1. Build `StatsSummary` as an `Equatable` value type computed in one pass: totals by status, counts by location, next non-expired item to use up. It takes `[FridgeItem]` plus a reference date — no SwiftData types leak out of it.
2. Build `StatsView`: `@Query` for items, summary computed in `.task(id: fingerprint)` where the fingerprint hashes each item's `persistentModelID`, `expiryDate`, and `locationRaw`. States: `EmptyStateView` when no items, `LoadingStateView` while summary is nil, then the list ("Right Now", "By Location" with zeros shown, "Use Next").
3. Wire the `Route.stats` destination in `RootView`.

**Verify (in simulator):**

1. Seed 5 items across all three statuses and at least two locations. Open Stats → every "Right Now" count matches the list's section counts exactly; location counts sum to the total.
2. "Use Next" names the soonest non-expired item — never an expired one.
3. Go back, delete an item, reopen Stats → counts updated (fingerprint recompute works).
4. Delete everything → Stats shows its own empty state, not a screen of zeros.

**Done when:** all Verify steps pass and stats can never disagree with the list, because both derive from the same `expiryStatus` function.

---

## Phase 5: Hardening and Ship Prep

**Builds on:** Phases 1–4. No new features — anything that feels like a feature goes to the v2 list.

**Files & surfaces:** touch-ups across all files; no new files expected.

**Steps:**

1. Grep-audit the codebase: zero `!` force-unwraps, `try!`, `as!`; zero hard-coded status colors outside `Theme.swift`; zero `print` statements.
2. Accessibility pass: VoiceOver reads each row as name + location + full status ("Expiring Soon, Tomorrow"); form controls all have labels; the delete confirmation is reachable.
3. Layout pass at Dynamic Type XXL and on the smallest supported device (iPhone SE-class simulator): badges wrap or truncate gracefully, form remains usable.
4. Run the full regression: every Verify block from Phases 1–4, in order, on a fresh install.
5. Set the app icon, launch screen background, version 1.0 (1), and fill in the App Store privacy questionnaire (no data collected — the honest answer).

**Verify (in simulator):**

1. Full Phase 1–4 regression passes on a fresh install with zero crashes and zero console warnings from SwiftUI (no "Publishing changes from within view updates", no constraint spew).
2. VoiceOver on: navigate the list, open detail, delete an item — every step announced sensibly.
3. Airplane mode on, force-quit, relaunch, add/edit/delete → identical behavior (proves the offline claim).

**Done when:** regression is clean, `APPSTORE.md` assets are final, and an archive build (Product → Archive) validates in the Organizer without warnings.
