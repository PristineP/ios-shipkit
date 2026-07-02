# iOS ShipKit for Claude Code

**The idea-to-App-Store pipeline for solo devs shipping iPhone apps with Claude Code.**

Building an iPhone app with a coding agent fails in predictable ways: sessions that sprawl past the context window, "done" phases nobody can verify, scope that drifts every conversation, and code that compiles but was never designed. ShipKit is a fixed pipeline that prevents each of those, packaged as Claude Code skills — plain markdown you can read, edit, and own.

## What's in this repo (free)

**Two production skills:**

| Skill | What it does |
|---|---|
| [`app-prd`](skills/app-prd/SKILL.md) | Turns a raw app idea into a developer-ready PRD: one-sentence-job scope test, screens + navigation map, Swift data model, monetization decision, and a **Claude Code Handoff block** that pins iOS target, persistence, and dependency policy so the agent can't drift. |
| [`build-phases`](skills/build-phases/SKILL.md) | Turns the PRD into a build plan where **every phase fits one agent session** and ends with hands-on simulator verification steps — "add item, force-quit, relaunch, item persists" — not "it compiles." |

**One complete worked example** — [`example/FridgeFriend/`](example/FridgeFriend/): a fridge-inventory app taken from a three-sentence idea through [PRD](example/FridgeFriend/PRD.md) → [build plan](example/FridgeFriend/BUILD-PLAN.md) → [full SwiftUI source](example/FridgeFriend/Sources/) (Swift 6, SwiftData, zero dependencies, typechecks against the iOS 17 simulator SDK) → [App Store listing](example/FridgeFriend/APPSTORE.md). Judge the output quality directly instead of taking anyone's word for it.

## Install

```bash
git clone https://github.com/PristineP/ios-shipkit
cp -r ios-shipkit/skills/* ~/.claude/skills/
```

Then in Claude Code: *"I have an app idea — [your idea]. Write the PRD."* The skills trigger automatically.

## The two rules doing most of the work

1. **A phase is correctly sized only if it fits one session** without context compaction and touches ~3–6 files.
2. **A phase isn't done until it's verified as literal simulator actions.** Compiling is not a milestone.

Everything else in the system exists to enforce these two.

## The full pipeline (paid)

The complete pack — **$29, $19 launch week** (shop link lands here today) — adds the back half of the pipeline: `swiftui-scaffold` (architecture before features), `code-audit` (targets the failure patterns AI-generated Swift actually has), `mockup-to-swiftui`, `appstore-listing`, `screenshot-story`, `release-runbook`, plus a playbook covering session doctrine, verification doctrine, and App Review survival. No subscription, no license keys — markdown files you own.

## License

Free tier: [MIT](LICENSE). The paid pack has its own single-user license.
