---
name: build-phases
description: >
  Turn an iOS app PRD into a phased build plan where every phase fits inside one
  Claude Code session and ends with something you can poke in the simulator.
  Invoke when the user has a PRD (from app-prd or their own) and says things like
  "break this into phases," "make a build plan," "what order should I build this,"
  "plan the build," "how do I split this across Claude Code sessions," or
  "I have a PRD — now what?" Also invoke mid-project when a build has stalled,
  a phase blew up, or the user says "re-plan the rest of the app."
  Output is the canonical Build Plan document that the architecture, mockup,
  audit, and release skills all consume.
---

## When to use

- You have a PRD (ideally in the canonical `app-prd` format) and need to decide what to build, in what order, and where the session boundaries go.
- A build is mid-flight and off the rails: a phase spilled across sessions, the data model changed, or Claude Code wandered — and the remaining work needs re-planning.
- You inherited a half-built repo plus a PRD and need a plan for the rest.

Do **not** use this skill when:

- There is no PRD and no equivalent scope document. Run `app-prd` first. Planning against a vibe produces phases that renegotiate scope every session.
- The user wants estimates in days or story points. This skill plans in *sessions*, the only unit that matters when Claude Code is the builder.

## Inputs to collect

Read from the repo before asking anything:

1. **The PRD.** Locate `PRD.md` (or ask for the path). You need every canonical section, and three are load-bearing:
   - **## Screens & Flow** — becomes the walking skeleton.
   - **## Data Model** — decides which phase owns persistence.
   - **## Claude Code Handoff** — iOS target, persistence choice (SwiftData / Core Data / GRDB / files), dependency policy, hard constraints. If this section is missing, stop and get it filled in; every sizing decision below depends on it.
2. **Repo state.** Greenfield, or existing code? If code exists, list targets, entitlements, and which PRD screens already exist — completed work becomes "Phase 0 (done)" context, never re-planned.

Ask the user only what the repo can't answer:

3. **Test hardware.** Simulator only, or a physical device? (Camera, HealthKit writes from real sensors, haptics, and performance feel need a device — this moves phases.)
4. **Apple Developer account status.** Free accounts can't test push, App Groups on some configs, or CloudKit properly. If the PRD needs any of these and the account is free, those phases get flagged and sequenced last.
5. **Deadline pressure, one question:** "Do you need something demoable to another human in the next week?" Yes biases demo-first ordering (see Process step 3).

## Process

1. **Extract the build surface from the PRD.** List every screen from *Screens & Flow*, every entity from *Data Model*, and every paid feature from *Monetization*. Cross off anything in *Non-Goals*. This list — not your imagination — is the total scope. If a phase later contains work not traceable to this list, that phase is wrong.

2. **Flag the risk items.** Scan the surface for frameworks where the API can lie to you until runtime: StoreKit 2, HealthKit, CloudKit/`SwiftData` + CloudKit sync, push notifications, background tasks (`BGTaskScheduler`), widgets/Live Activities, App Intents, camera/PhotoKit, speech, CoreLocation "always" authorization, and any iOS 26-era API the PRD names (on-device Foundation Models, Liquid Glass adoption) — those get an extra flag for simulator-support uncertainty and doc thinness in Claude's training data. Everything else (SwiftUI screens, `@Observable` state, local persistence, navigation) is routine and carries no flag.

3. **Choose ordering: demo-first, risk-first, or (usually) hybrid.**
   - **Default is demo-first:** Phase 1 produces a walking skeleton — every tab and screen from the PRD navigable in the simulator with hardcoded fixture data. Rationale: every later phase inherits a hands-on Verify surface, navigation architecture mistakes surface on day one, and the user can feel progress.
   - **Promote a risk item to a Phase 1–2 spike when it passes the kill test:** *"If this framework doesn't do what the PRD assumes, does v1 die, or just shrink?"* Dies → spike it before investing in UI (an app whose entire point is reading HealthKit sleep data must prove that read works before a single screen exists). Shrinks → build it at its natural place in the plan.
   - A **spike phase** is throwaway-grade: its *Done when* is a proven capability printed to the console or shown in a bare debug view, never polished UI. Say so in the phase text so Claude Code doesn't gold-plate it.
   - Never order risk-first across the board. A plan that front-loads all five scary frameworks produces three weeks of nothing launchable and a demoralized builder.

4. **Cut phases against the context-window budget.** A phase must complete — code, build-fix loops, and simulator verification — inside one Claude Code session without compaction. Assume roughly 40% of a session's context is consumed by overhead you don't control: system prompt, CLAUDE.md, file re-reads, and `xcodebuild` error output from compile-fix loops. Size the net new work to fit the remainder. Concrete limits per phase:

   | Budget line | Limit |
   |---|---|
   | New files created | ≤ 8 |
   | Existing files significantly edited | ≤ 4 |
   | New system frameworks introduced | 1 |
   | Xcode project-level changes (capabilities, entitlements, new targets, Info.plist keys) | 1 |
   | Architectural decisions Claude must make | 1 |
   | Steps in the phase | ≤ 7 |

   Two multipliers: (a) phases that introduce a new **async/actor boundary** get half the file budget — Swift 6 strict-concurrency errors each cost a full build cycle and paste long diagnostics into context; (b) phases with a project-level change get the same haircut, because entitlement and signing errors produce the longest, least-informative error loops in iOS development. If a phase description needs the word "and then" more than twice, split it.

5. **Fix the phase skeleton.** Phase 1 is always: buildable project + walking skeleton (or the kill-risk spike, with the skeleton as Phase 2). Persistence gets its own phase and lands *before* the features that write data — retrofitting SwiftData under views built on fixture arrays is a rewrite, not a wiring job. Monetization (StoreKit 2 + paywall) is its own phase, verified with a `.storekit` configuration file in the simulator, never left for "polish week." Typical v1 lands at **4–8 phases**. If you're writing phase 11, the plan isn't long — the PRD's *v1 Scope* is bloated. Stop and send it back to `app-prd` to cut scope; do not paper over a fat PRD with a long plan.

6. **Write Verify as hands-on simulator actions.** Every phase's *Verify* block is a numbered script of things a human does with fingers, and what they must observe. "Run the tests" and "it compiles" are banned as verification. The verbs that belong here: cold-launch, tap, type, swipe, rotate, force-quit from the app switcher and relaunch (the persistence test), toggle airplane mode, switch to dark mode, crank Dynamic Type to XXL, background the app for 30 seconds and return. Every phase that writes data gets the kill-and-relaunch check. Every phase that adds a screen gets a Dynamic Type + dark mode glance. Write expected observations, not just actions: "the three entries you added are still present, in the same order."

7. **Insert integration checkpoints every 2–3 phases.** A checkpoint is a phase with **zero new features**. Its Steps are: run a scripted walkthrough of *everything built so far* end-to-end, repeat it on an iPhone SE-class simulator and in dark mode, fix what breaks, and prune dead fixture code left over from the skeleton. Cap the fix list at the session budget; anything that doesn't fit goes into `NOTES.md` under *Known Issues* with a phase assignment — not silently dropped. Checkpoints exist because Claude Code builds excellent islands; the water between them is where v1s drown.

8. **Define the re-planning triggers and print them in the plan.** The plan is a contract, and these are its breach conditions. Re-plan (re-run this skill against the PRD + current `NOTES.md`, regenerating only the *remaining* phases — completed phases are history, never rewritten) when any of these fire:
   - A phase spilled into a second session or hit context compaction mid-phase.
   - A *Verify* step failed for **architectural** reasons — the design can't do the thing — rather than a fixable bug.
   - The data model changed in a way that touches two or more completed phases.
   - Claude Code introduced a dependency that violates the Handoff's dependency policy, and removing it isn't a one-file change.
   - An entitlement/account discovery (HealthKit needs a capability the account lacks, CloudKit container misbehaves on free tier) blocks a planned phase.
   A failed Verify that's just a bug is not a re-plan trigger; it's the current phase not being done.

9. **Write the Session Doctrine, then emit the plan** in the exact Output format below. The doctrine is not advice; it's the operating procedure for every session:
   - **One phase = one session = one commit.** End-of-phase ritual: run the Verify script yourself, update `NOTES.md`, `git commit -m "Phase N: <goal>"`, then `/clear`. Always `/clear` between phases — carrying a finished phase's context into the next one buys nothing and spends the budget step 4 allocated to real work.
   - **Session opener is always the same prompt:** `Read NOTES.md and BUILDPLAN.md, then implement Phase N. Do not start work from any other phase.`
   - **`NOTES.md` is the only memory that survives `/clear`.** It carries: decisions made with one-line rationale ("SwiftData over Core Data — PRD Handoff, single-entity model"), deviations from the plan, *Known Issues* deferred with phase assignments, a one-line-per-file map of the codebase, and current phase status. Hard cap ~60 lines; prune it during the end-of-phase ritual. It never carries: error logs, code snippets, transcripts, or aspirations.
   - **Compaction mid-phase is a sizing bug, not weather.** Finish the smallest shippable slice, record the split in `NOTES.md`, and let re-planning (step 8) resize the remainder.

## Output format

Produce a single file, `BUILDPLAN.md`, in exactly this structure — other ShipKit skills parse these headings:

```markdown
# <App Name> Build Plan

## Session Doctrine
<The operating rules from Process step 9, adapted to this app: the opener
prompt with real phase numbers, the /clear rule, the end-of-phase ritual,
the NOTES.md contents list and line cap, and this plan's re-planning
triggers spelled out.>

## Phase N: <Goal — a noun phrase naming the capability, not "Setup">
Builds on: <phase numbers this assumes complete, or "nothing (greenfield)">
Files & surfaces: <files created/edited; frameworks introduced; any
  project-level change (capability, entitlement, Info.plist key) called
  out explicitly>
Steps:
1. <numbered, concrete, ≤ 7 steps>
Verify (in simulator):
1. <numbered hands-on actions with expected observations>
Done when: <one sentence, binary, checkable by a human>
```

Repeat the `## Phase N` block per phase. Integration checkpoints use the same block with the goal `Integration Checkpoint: <scope>`. Example of a correctly sized, correctly verified phase:

```markdown
## Phase 3: Persistence — entries survive relaunch
Builds on: Phase 1 (skeleton), Phase 2 (entry form UI on fixture data)
Files & surfaces: new Models/Entry.swift (@Model), new Services/EntryStore.swift;
  edit EntryListView.swift, EntryFormView.swift, <App>App.swift (modelContainer).
  Framework: SwiftData. No project-level changes.
Steps:
1. Define Entry as a SwiftData @Model matching the PRD Data Model section exactly — no extra fields.
2. Wire modelContainer at the app root; inject via environment.
3. Replace the fixture array in EntryListView with a @Query, sorted newest-first.
4. Make the form's Save insert an Entry and dismiss.
5. Add swipe-to-delete on the list.
6. Delete the fixture data file. Grep for its type name; zero hits outside git history.
Verify (in simulator):
1. Cold-launch. Add three entries with distinct titles.
2. Force-quit from the app switcher. Relaunch — all three present, newest first.
3. Swipe-delete the middle entry. Force-quit, relaunch — exactly two remain.
4. Set Dynamic Type to XXL — list rows grow, nothing truncates to one line.
Done when: entries created in the UI survive force-quit and relaunch, and no fixture data remains in the target.
```

## Quality bar

The plan ships only if every box checks:

- [ ] Every phase traces to the PRD's *v1 Scope* and *Screens & Flow*; nothing plans work from *Non-Goals*.
- [ ] Every phase fits the step-4 budget table; async-boundary and project-change phases took the haircut.
- [ ] Phase 1 (or 2, behind a kill-risk spike) ends with an app that launches and navigates in the simulator.
- [ ] Every *Verify* block is finger-actions with expected observations; zero phases verified only by "builds" or "tests pass."
- [ ] Every data-writing phase includes the force-quit-and-relaunch check.
- [ ] Persistence lands before features that depend on it; StoreKit has its own phase with a `.storekit` file in the Verify.
- [ ] An integration checkpoint appears at least every 3 phases, with no new features inside it.
- [ ] Each spike phase's *Done when* names a proven capability, not UI.
- [ ] Re-planning triggers appear verbatim in the Session Doctrine.
- [ ] Total phases ≤ 8 for v1 — or the plan explicitly says the PRD was sent back for scope cuts.
- [ ] *Done when* lines are binary: a stranger with the simulator could adjudicate each in under two minutes.

## Failure modes

- **The Phase 1 blob.** Left unconstrained, Claude Code "helpfully" builds all models, all views, and half the features in the first session, and the plan collapses into archaeology. Defense: the step-4 budget table, plus the doctrine opener's "do not start work from any other phase."
- **Phase drift.** Mid-phase, Claude notices Phase 5 would be "easy to add now" and does it — badly, without its Verify. Defense: each phase's *Files & surfaces* is a whitelist; the end-of-phase ritual diffs against it, and out-of-scope work is reverted or moved into `NOTES.md` deviations.
- **Compiles ≠ works.** AI-generated SwiftUI reliably produces code that builds but misbehaves: `@Query` views that never refresh because the container wasn't injected, sheets that present twice, `NavigationStack` paths that reset on state change. This is exactly why *Verify* is fingers-on-simulator, never build output.
- **Phantom verification.** Claude reports "all tests pass" in a project with no test target, or "verified in simulator" without a simulator boot in the transcript. Defense: Verify scripts are written for the *human* to execute; the *Done when* is adjudicated by the user, not by Claude's claim.
- **Retrofitted persistence.** Building six screens on fixture arrays and "adding SwiftData later" means rewriting six screens. Defense: persistence is its own early phase (Process step 5), and the skeleton's fixture data has a scheduled deletion step with a grep check.
- **The Swift 6 concurrency spiral.** One strict-concurrency error tempts a session-eating refactor (`@MainActor` sprayed everywhere, actors introduced mid-phase). Defense: async-boundary phases get half budget, and the doctrine treats a spiral that threatens the session as a re-planning trigger, not something to push through.
- **Entitlement errors buried mid-phase.** A capability added as step 5 of 7 detonates signing and eats the rest of the session in opaque errors. Defense: one project-level change per phase, always called out in *Files & surfaces*, always step 1 so failure costs minutes, not the session.
- **NOTES.md becomes a novel.** Unpruned, it swells with logs and prose until it consumes the very context budget it exists to protect. Defense: the 60-line cap and the never-carries list are doctrine, enforced at every end-of-phase ritual.
- **Plan worship.** The opposite trap: a phase's Verify exposes an architectural miss and the builder grinds on because "it's the plan." Defense: the re-planning triggers are printed in the plan itself; firing one is following the plan, not abandoning it.
