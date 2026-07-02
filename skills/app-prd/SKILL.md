---
name: app-prd
description: >
  Turn a raw iPhone app idea into a developer-ready PRD sized for a solo
  developer shipping with Claude Code. Invoke whenever the user describes an
  app idea and wants it specced, scoped, structured, or formalized — trigger
  phrases include "write a PRD", "spec out my app", "I have an app idea",
  "help me scope v1", "what should version one include", "turn this idea into
  a plan", "product spec for my iPhone app", or any pasted brain-dump of app
  features that needs to become a buildable document. Also invoke when a
  project has code but no spec and the user says "we keep going in circles"
  or "Claude keeps adding stuff I didn't ask for" — the PRD is the scope
  contract that fixes that. Produces the canonical PRD consumed by the
  build-phases skill.
---

## When to use

- The user has an app idea in their head, in a note, or in a voice-memo-style
  paragraph, and the next step is a document a coding agent can build from.
- A project exists but drifts every session because there is no written scope
  contract. Retrofit the PRD before writing more code.
- The user asks "is this too big for v1?" — that question *is* this skill.

Do not use for:

- Adding a feature to an app that already has a PRD — amend the existing
  `docs/PRD.md` instead, and move displaced features into Non-Goals.
- Backend services, web apps, or multi-platform specs. This skill assumes one
  developer, one iPhone app, Claude Code as the build tool.

## Inputs to collect

Ask for these before drafting. Accept messy answers; the Process refines them.

1. **The idea, verbatim.** The user's own words, uncut. You will quote their
   phrasing back at them during scope-cutting.
2. **The one user.** A specific person — ideally the developer themselves.
   "People who want to be more productive" is rejected; "me, tracking film
   photos I shoot on my Pentax" is accepted. If the answer is a market
   segment, ask: "Name one real person who has this problem. What did they do
   about it last Tuesday?"
3. **The 60-second test.** What does that person do in the first 60 seconds
   after opening the app on a random Wednesday? This becomes the core flow.
4. **Monetization gut answer.** "Would you charge for this — up front, unlock,
   subscription, or free?" Don't debate yet; step 5 of the Process does.
5. **Shipping reality.** Apple Developer account (yes/no)? Shipped to the App
   Store before (yes/no)? Target date, if any?
6. **From the repo, if one exists:** read `README.md`, anything in `docs/`,
   any mockup files (`*.jsx`, `*.png` in a `designs/` or `mockups/` folder),
   and the Xcode project's deployment target if code exists. The PRD must not
   contradict shipped reality.

If the user answers only #1, proceed anyway and mark assumptions inline with
`(assumed — confirm)`. Never stall a PRD waiting for perfect inputs.

## Process

1. **Run the one-sentence-job test.** Force the idea into:
   `This app helps [one specific person] [do one job] [in one context].`

   ```
   PASS: "Helps a solo film photographer log which frame got which
          settings, at the moment they press the shutter."
   FAIL: "Helps photographers organize their photos and share them and
          track gear and learn techniques."
   ```

   If the sentence needs an "and", there are two apps. **Decision point:**
   ask the user which job they would pay $5 to have solved today. That job
   is v1. The other job goes to Non-Goals with a note that it may be v2 or a
   different app entirely.

2. **Sort every mentioned feature into three buckets.** List everything the
   user said — every noun and verb from their brain-dump — and sort each into
   **v1**, **v2**, or **Never**. Apply these cuts mechanically, then argue
   exceptions:

   - **Accounts/login: out.** Default is local-first, no backend. Accounts
     drag in Sign in with Apple (required if you offer any third-party
     login), account deletion (required by App Review since 2022), a server,
     and a privacy policy with teeth. Only keep accounts if the one job is
     inherently multi-user.
   - **Sync: v2.** CloudKit sync forces every SwiftData property to be
     optional or defaulted and bans unique constraints — it warps the data
     model. Design for it later, don't pay for it now.
   - **Onboarding: one screen max, ideally zero.** A well-designed empty
     state teaches better than a carousel. If the user insists on onboarding,
     it counts against the screen cap.
   - **Settings screen: only if there are ≥2 real settings.** One setting is
     a toolbar menu item.
   - **Widgets, watchOS, iPad layout, Live Activities: v2.** Each is its own
     mini-project with its own extension target.
   - **Push notifications: out unless the one job is literally a reminder.**
     Local notifications only; remote push means a server.
   - **Camera / ML / on-device AI: flag the hidden cost.** Each needs
     entitlements or capability plist keys, physical-device testing, and
     permission-denial flows. Keep only if it *is* the job.
   - **Sharing/export: cheap, often keep.** `ShareLink` with a CSV or image
     is a one-day feature and a real retention lever.

   **Decision point:** if v1 still has more than one data-entry surface and
   one data-viewing surface plus paywall/settings, cut again. Read the cuts
   back to the user and get explicit sign-off — this list becomes the
   Non-Goals section and future sessions will enforce it.

3. **Draw the screens list and navigation map.** Hard cap: **5 screens**
   including any paywall. Rules:

   - Pick **one** navigation container: a single `NavigationStack`, or a
     `TabView` only if there are 2–3 genuinely peer screens (log vs. trends,
     not list vs. settings).
   - Creation and editing happen in **sheets**, not pushed screens. Sheets
     are interruptible and map to how Claude Code should structure the form
     as a standalone view with an `onSave` closure.
   - Navigation depth ≤ 2 pushes. Deeper means the information architecture
     is wrong.
   - Name every screen now; these names become SwiftUI view names and file
     names in the build plan. `EntryListView`, not "the main screen".

   Express the map in arrow notation (see Output format). Every screen must
   appear in the map; every arrow must name its trigger.

4. **Write the data model in Swift, not prose.** Rules:

   - **≤3 entities** in v1. A field earns its place only if a screen in
     step 3 renders or edits it. No `tags: [String]` "for later", no
     `userID` in a local-only app.
   - Store **canonical units** (ounces, cents-as-`Int` or `Decimal`, UTC
     `Date`) and convert at display time. Never store formatted strings.
   - **Decision point — persistence:**
     - **SwiftData** (default): structured user data, iOS 17+. Note in the
       PRD: single `ModelContainer` injected at the app entry point;
       on an iOS 17 target keep `#Predicate` expressions simple —
       predicates that traverse relationships are a known crash/miss area,
       so plan to filter small collections in memory instead.
     - **UserDefaults**: ≤10 scalar preferences only. Never entity data.
     - **JSON file in Application Support**: when the whole model is one
       array of one `Codable` type and the user wants trivially inspectable,
       trivially exportable data. Honest and fine for v1.
     - **Core Data / CloudKit**: not for v1 unless retrofitting an existing
       stack. Record the reason if chosen.

5. **Make the monetization decision now.** "Figure it out later" is banned:
   the choice changes the screen count, the data model (entitlement state),
   and StoreKit scope, and retrofitting a paywall breaks architecture.
   Present this table and force a pick:

   | Model | Build cost | App Store consequences | Pick when |
   |---|---|---|---|
   | **Paid up front** | Zero StoreKit code, no paywall screen | Near-zero impulse installs; no trial mechanism; price is a review-visible promise | Sharp utility, obvious value, niche audience that searches for exactly this |
   | **Free + one-time unlock** *(recommended default)* | StoreKit 2, one non-consumable, one paywall sheet, a **Restore Purchases** button (App Review requires it) | +1 screen against the cap; entitlement check in the model layer; refunds handled by Apple | Almost every solo utility app |
   | **Subscription** | Paywall must show price, term, ToS + privacy links (review requirement); manage-subscription surface; higher review scrutiny | Recurring revenue, recurring justification — you owe ongoing value | Ongoing server/content cost, or the value genuinely recurs |
   | **Free** | Nothing | Still needs a privacy nutrition label; no revenue ever without a repricing migration | Portfolio piece or funnel to something else, stated explicitly |

   If free-with-unlock: define the free/paid line in one sentence (e.g.
   "free: 20 entries; unlocked: unlimited + CSV export") and add the gate to
   Success Criteria. The line must be generous enough to prove value and
   tight enough that the one user hits it in week one.

6. **Write Non-Goals as a contract, not a disclaimer.** Every feature cut in
   step 2, verbatim in the user's own words, plus the standard traps even if
   never mentioned: Android, iPad-optimized layout, localization beyond
   English, third-party analytics SDKs, user accounts, remote push. Each
   line is an instruction to future Claude Code sessions: *do not build
   this, do not scaffold for this, do not add fields for this.*

7. **Set success criteria that can fail.** Three to five, each checkable by
   the solo dev without an analytics SDK:
   - a date ("TestFlight build on my phone by March 14"),
   - a personal-use bar ("I log an entry 7 consecutive days"),
   - a store bar ("approved on first or second review submission"),
   - if monetized, a number ("10 unlocks in the first 30 days").
   "Gain users" and "positive feedback" are rejected — they cannot fail.

8. **Write the Claude Code Handoff block.** This is the section the coding
   agent actually obeys; everything above is context for it.
   - **iOS target: 17.0 by default** (SwiftUI + SwiftData baseline). Raise
     only with a named reason: 18.0 for the modernized App Intents / controls
     surface if the app is Shortcuts-centric; 26.0 only if the job needs the
     on-device Foundation Models framework or other 26-only API. Building
     with the current SDK gets the current design language (including Liquid
     Glass on modern OSes) without raising the *deployment* target — say so,
     because "I want the new look" is not a reason to abandon iOS 17 users.
   - **Swift 6, strict concurrency on.** Cheaper to start strict than to
     migrate.
   - **Persistence choice** from step 4, with the container/injection note.
   - **Dependency policy: zero third-party packages.** State it as a rule
     with an escape hatch: a dependency may be proposed only when there is
     no first-party equivalent (`URLSession` kills Alamofire, `AsyncImage`
     kills Kingfisher, Swift Charts kills charting libs, StoreKit 2 kills
     purchase wrappers) and the user approves it by name in this PRD.
   - **Hard constraints** — 4 to 8 project-specific rules a coding agent can
     mechanically obey. Good constraints: "money is `Decimal`, never
     `Double`"; "every list screen must render correctly with 0 items and
     with 500 items"; "no singletons — the `ModelContainer` is injected via
     the environment"; "no TODO/placeholder code paths in any committed
     phase". Bad constraints: "write clean code" (banned — not checkable).

9. **Write the PRD to `docs/PRD.md`** (create `docs/` if needed), then read
   back the three highest-stakes calls — the one-sentence job, the
   monetization pick, and the biggest cut — and get a yes/adjust on each.
   Adjustments edit the file; the file is the source of truth from now on.

## Output format

A single markdown file at `docs/PRD.md` using exactly these sections, in this
order, with these exact headings:

```markdown
# <App Name> PRD

## One-Liner
The one-sentence-job, verbatim from step 1. Nothing else.

## Problem & User
2 short paragraphs max: the one user, the moment the problem occurs, what
they do today instead. The 60-second-test answer appears here.

## v1 Scope (In)
Bulleted features, each traceable to a screen. 5–9 bullets. Each bullet is a
capability ("log an entry with amount + note in ≤2 taps from launch"), not a
component ("an entry form").

## Non-Goals (Out)
Bulleted cuts from Process step 6, each with a one-clause reason
("no accounts — local-first; accounts force deletion flows and a backend").

## Screens & Flow
Named screen list (these become SwiftUI view names), then the arrow map:

    [EntryListView] ── + button ──▶ (sheet: EntryFormView)
    [EntryListView] ── tap row ──▶ [EntryDetailView] ── Edit ──▶ (sheet: EntryFormView)
    (sheet: PaywallView) ◀── triggered on 21st entry

Every screen in the map; every arrow labeled with its trigger.

## Data Model
Fenced Swift showing the actual @Model / Codable types with field comments
noting canonical units. Then one line naming the persistence choice.

## Monetization
The pick from the table, the price, the free/paid line if applicable, and
the App Store obligations it creates (restore button, paywall links, label).

## Success Criteria
3–5 checkable-by-one-person criteria from Process step 7.

## Claude Code Handoff
- iOS target: <version> (<one-line reason>)
- Swift: 6.x, strict concurrency
- Persistence: <choice + injection note>
- Dependencies: zero third-party; exceptions must be named here: <none | list>
- Hard constraints:
  - <4–8 mechanically checkable rules>
```

Length target for the whole PRD: **1–2 pages.** A PRD Claude Code can hold in
context alongside code beats a thorough one it can't.

## Quality bar

The PRD ships only if every box checks:

- [ ] One-Liner has no "and" joining two jobs.
- [ ] Every v1 Scope bullet maps to a named screen; every screen serves a
      scope bullet. No orphans in either direction.
- [ ] ≤5 screens including paywall; ≤3 entities; navigation depth ≤2.
- [ ] Every data-model field is rendered or edited by a screen in the map.
- [ ] Units and types are canonical (`Decimal` money, `Date` timestamps, one
      stored unit per quantity).
- [ ] Monetization is decided, priced, and its App Review obligations are
      written down — not "TBD".
- [ ] Non-Goals contains every feature the user mentioned that was cut,
      in their own words.
- [ ] Every success criterion can fail, and the user could check it without
      installing an SDK.
- [ ] Handoff block names an iOS target with a reason, and the dependency
      list is explicit (usually "none").
- [ ] No sentence in the document is advice. Every sentence is a decision,
      a fact, or an instruction.

## Failure modes

- **Scope re-inflation.** The user (or a later Claude session) says "while
  we're at it, add tags." Countermeasure: cuts live in Non-Goals as a
  standing instruction; amendments must move an item *out* of Non-Goals in
  writing before any code touches it.
- **Kitchen-sink data model.** AI-generated specs invent fields "for
  flexibility" — `tags`, `category`, `userID`, `metadata: [String: String]`.
  Every unrendered field is future migration debt. The screen-traceability
  rule in the Quality bar exists to kill these.
- **Accounts by reflex.** Generated iOS scaffolds reach for Firebase Auth on
  day one. This PRD defaults to local-first and says so in Non-Goals, which
  removes the account-deletion flow, the privacy-policy server questions,
  and an entire class of App Review rejections.
- **Dependency reflex.** AI-written Swift imports Alamofire for one GET and
  Kingfisher for one image. The zero-dependency rule in the Handoff block is
  phrased as an instruction to the agent, not a preference, because
  preferences get ignored at line 400 of a long session.
- **Deployment-target drift.** Generated code mixes iOS 26-only modifiers
  onto an iOS 17 target, then "fixes" it with `if #available` spaghetti on
  every view. Pinning the target in the Handoff block — with the reason —
  lets the agent choose the right API surface once instead of hedging
  everywhere.
- **The fake-simple feature.** Sync, sharing-with-others, widgets, camera,
  and push all sound like bullets but are projects: extension targets,
  entitlements, permission-denial states, physical-device testing. Process
  step 2 prices each one out loud before it can sneak into scope.
- **Monetization deferred forever.** "We'll add the paywall later" produces
  an architecture with no entitlement seam, so the paywall retrofit touches
  every screen. Step 5 forces the decision while it's still one sentence
  and one screen.
- **Team-shaped PRD.** Personas, OKRs, stakeholder matrices, sprint
  ceremonies — generated PRDs love them and a solo dev's coding agent uses
  none of them. This template has no section they can live in; if the draft
  grows one, delete it.
- **Unfailable success criteria.** "Delight users" survives any outcome and
  therefore measures nothing. Every criterion here has a number or a date
  and a way to be wrong.
