# FridgeFriend PRD

## One-Liner

Track what's in your fridge, freezer, and pantry, and see at a glance what to use up before it turns — fully offline, no account, no camera gimmicks.

## Problem & User

**Problem.** People buy groceries, lose track of dates, and throw food out. The moment of failure is standing at the open fridge with no idea whether the yogurt behind the milk is from this week or last month. Existing apps "solve" this with barcode scanners, receipt OCR, and recipe engines — all of which add friction to the one action that matters: writing down an item and a date fast enough that you'll actually do it.

**User.** One person managing one household's food. They shop roughly weekly, cook most nights, and will give this app about ten seconds per grocery item — once. If adding an item takes longer than that, they stop, and the app is dead. They are not meal-planners or macro-trackers; they want a list that knows the dates so they don't have to.

**The one job of v1:** answer "what do I need to use up before it turns?" in a single glance at the top of the list.

## v1 Scope (In)

- **Add item** via sheet: name (required), quantity (1–99, default 1), location (Fridge / Freezer / Pantry, default Fridge), expiry date (default: 7 days out), optional note. Past expiry dates are allowed — logging the mystery jar from last month is a core first-run action.
- **Item list** (root screen), grouped into three fixed-order sections: **Expiring Soon** (today through 3 days out, inclusive), **Fresh** (more than 3 days out), **Expired** (before today). Items sort by expiry date ascending within each section. Section headers show a count.
- **Expiry badge** on every row: colored pill with icon and short text ("Today", "Tomorrow", "5d left", "2d ago"). Orange = soon, green = fresh, red = expired. Expiry math is day-granular: an item is good through the end of its expiry day, and "expires today" counts as Expiring Soon, not Expired.
- **Detail view** (push): all fields, edit button (opens the same form sheet in edit mode), delete with confirmation.
- **Delete** via swipe on any list row, or from the detail view.
- **Stats screen** (push from list): counts by status, counts by location, and the next item to use up. Recomputes whenever the underlying items change.
- **Empty states** on the list (with an "Add First Item" call to action), the stats screen, and the detail view if its item was deleted underneath it.
- **Foreground refresh:** section grouping recomputes when the app returns to the foreground, so a device left overnight doesn't show yesterday's grouping.
- **Persistence:** SwiftData, local only. Everything works in airplane mode forever.

## Non-Goals (Out)

- **Notifications / expiry reminders** — needs permission UX and scheduling correctness; v2 candidate, not v1.
- **Barcode / receipt scanning** — the friction it removes is smaller than the friction it adds; also drags in camera permissions.
- **Photos of items** — storage and layout cost for zero decision-making value.
- **Shopping list / recipes / meal planning** — different job; scope killers.
- **Consumption or waste history** — requires a "consumed vs. tossed" distinction on delete; v1 delete just deletes.
- **iCloud sync, accounts, sharing** — single-device, single-user by design in v1.
- **Widgets, watch app, iPad layout, onboarding flow** — the app must be self-explanatory from its empty state; if it isn't, fix the empty state.

## Screens & Flow

```
Item List (root)
 ├─ [+] ────────────────► Add Item (sheet)
 ├─ tap row ────────────► Item Detail (push)
 │                         ├─ Edit ──► Edit Item (sheet, same form)
 │                         └─ Delete ─► confirm ─► pop back to list
 └─ chart icon ─────────► Stats (push)
```

- **Item List** — navigation title "FridgeFriend". Toolbar: stats (leading), add (trailing). Sections as scoped above; hidden entirely when empty in favor of the empty state. Swipe-to-delete on rows.
- **Add / Edit Item** — one form, two modes. Modal with its own navigation bar: Cancel / Save. Save is disabled until the trimmed name is non-empty. Cancel discards everything, including in edit mode (no partial writes).
- **Item Detail** — status badge, expiry date, location, quantity, added date, notes (section hidden when empty), destructive delete row with confirmation dialog.
- **Stats** — "Right Now" (total, expiring soon, fresh, expired), "By Location" (all three locations, zeros included), "Use Next" (soonest non-expired item).

## Data Model

One entity. Resist inventing more.

**FridgeItem** (SwiftData `@Model`)

| Field | Type | Notes |
|---|---|---|
| `name` | String | Required; trimmed; validated non-empty at the form layer |
| `quantity` | Int | 1–99, stepper-controlled; rendered only when > 1 |
| `locationRaw` | String | Raw value of `StorageLocation` (fridge / freezer / pantry). Stored as a string, not a Codable enum, so predicates and migrations stay boring; typed accessor degrades unknown values to `.fridge` |
| `expiryDate` | Date | Day granularity; time component ignored by all logic |
| `addedDate` | Date | Set once at creation |
| `notes` | String | Optional free text, defaults to `""` |

**Derived (never persisted):** `ExpiryStatus` — `expired` (days-until < 0), `expiringSoon` (0…3), `fresh` (> 3), computed on day boundaries against a reference date. The 3-day window is a named constant (`FridgeItem.soonWindowDays`), not a scattered literal.

## Monetization

Free. No IAP, no ads, no tracking in v1. This app's job is to be shipped, reviewed, and used — a paywall on a v1 utility with zero reputation kills all three. If usage justifies it later, the natural paid tier is notifications + iCloud sync as a one-time purchase; nothing in the v1 data model blocks that.

## Success Criteria

- Add-an-item flow completes in **≤ 10 seconds and ≤ 6 taps** from cold launch (name typed, default date accepted).
- Cold launch to interactive list **< 1 second** on an iPhone 12.
- Data survives force-quit, reboot, and an OS update (SwiftData store integrity).
- Full manual regression script (the Verify blocks in BUILD-PLAN.md, run end to end) passes with **zero crashes** on iOS 17 and the current iOS.
- Every screen renders correctly at Dynamic Type XXL and in dark mode; expiry badges are legible to VoiceOver ("Expiring Soon, Tomorrow" — never a bare "2d").
- Zero compiler warnings in Swift 6 language mode.

## Claude Code Handoff

- **iOS target:** iOS 17.0 minimum, iPhone only, portrait-first (no custom landscape work). Swift 6 language mode. Built and verified against the current SDK.
- **Persistence:** SwiftData. One `ModelContainer`, created in the `App` initializer, injected via `.modelContainer(_:)`. Container creation failure falls back to an in-memory container — never a crash loop on launch. All reads via `@Query`; all writes via `ModelContext` at the point of user action.
- **Dependency policy:** zero third-party dependencies. Apple frameworks only. No exceptions for "just one small package."
- **Hard constraints:**
  - No force-unwraps, no `try!`, no `as!` anywhere in the codebase.
  - `NavigationStack` driven by a `Route` enum and a single `@Observable` router; exactly one `.sheet` presentation point at the root.
  - `@Observable` for any state that isn't a SwiftData model (router, form model).
  - Every screen handles the empty case explicitly; shared `EmptyStateView` / `LoadingStateView` components, no ad-hoc `Text("No data")`.
  - Expiry logic lives on the model in one place, parameterized by reference date and calendar, so it is testable and can never disagree between screens.
  - Keep files under ~200 lines; split by screen, not by "managers."
