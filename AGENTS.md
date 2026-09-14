# Quack Express — agent & contributor guide

A side-scrolling biplane courier for iPhone, iPad and Mac: carry mail and
passengers between fields on a generated wraparound strip, get paid for speed,
dodge or shoot what shoots at you; dogfight friends nearby. Two inputs, ever.
This file is how to *work on* the repo — for humans and AI agents alike.

Nothing is proven yet. **Milestone 1 is a feel test**, and it can't be settled
from a spec: fly it on a device, tune, decide. If drag-pitch plus
hold-for-power is not fun, stop and rethink before building anything on it.

The repo is fully independent and self-contained: it shares no code or
packages with any other project. Its *shape* is the sibling games' (Donpa
Squad, Skid Jam) on purpose — Makefile, scripts, release lane, CI — so
anything better here should be improved there too, or not at all.

## Where things are documented

One place per concern — don't duplicate, link:

| | |
|---|---|
| **What the system is** | [ARCHITECTURE.md](ARCHITECTURE.md) — the sim, the render seam, and a fenced *Planned* chapter |
| **How to work on it** | this file — conventions, toolchain, PR process |
| **What's next, and when** | [ROADMAP.md](ROADMAP.md) |
| **Why the design is what it is** | [docs/design.md](docs/design.md) — the decisions and the rejected alternatives |
| **How to release** | [RELEASING.md](RELEASING.md) |
| **What shipped** | [CHANGELOG.md](CHANGELOG.md) |

When something ships, move it out of ARCHITECTURE.md's *Planned* chapter and
into the prose above it.

## Conventions

- **Toolchain:** Xcode + Swift 6, **XcodeGen** (`.xcodeproj` generated,
  gitignored, never committed). `make` for everything — run `make` to list
  targets. The team ID IS committed in `project.yml` (not a secret; the release
  lane's headless automatic signing needs it).
- **Bundle id:** `fi.misaki.quack`, registered on App Store Connect for iOS and
  macOS as one **Universal Purchase**. App name "Quack Express", subtitle
  "Duck and Deliver". MIT, no monetization.
- **Two targets, one seam:** `QuackCore` is pure, deterministic simulation
  (fixed timestep, no UI imports, headlessly tested, coverage-gated).
  `QuackKit` is SpriteKit/SwiftUI rendering and input glue (coverage-ignored).
  **Testable logic goes in QuackCore.**
- **Controls are an input source, not a game mode.** Touch, keyboard, AI and
  network peers all produce `PlaneInput`; the sim never knows which.
- **Two inputs at most, each doing one thing; never a third simultaneous
  input.** Difficulty lives in the generated world, not the controls.
- **Localization:** English-only for now, but String Catalog + `Text(_,
  bundle:)` / `String(localized:)` from day one — never hardcoded literals in
  UI.
- **Comments minimal**; determinism for tests (injected RNG, fixed timestep).
- **Lint/format/CI:** pinned SwiftLint + swift-format both `--strict`, and
  markdownlint on every `.md` (`.markdownlint.json`; the release lane edits
  CHANGELOG.md by pattern, so a malformed heading is a real bug). `make lint`
  runs all three exactly as CI does.
- **PRs:** branch off `main`, one focused change, never commit on `main`;
  `Co-Authored-By: <model> <noreply@anthropic.com>` trailer (no session
  links); a user-facing PR writes its own CHANGELOG bullet under
  `### Unreleased (next build)`; wait for CI before merging. The user merges.

## Deliberately out of scope

No ads, IAP, accounts, servers, global leaderboards, third-party runtime
dependencies, or tilt controls (tilt is for games with momentum to hide its
latency; this one turns on a half loop). No hand-authored levels: the strip,
the fields and the contracts are generated from a seed, and campaigns are
lists of ranked seeds.
