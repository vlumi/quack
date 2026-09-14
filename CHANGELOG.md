# Changelog

All notable changes to Quack Express are documented here.
The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Grouped by **marketing version** (a roadmap milestone), then by **build number**
within it — the version stays steady while the build climbs each TestFlight
upload (see [RELEASING.md](RELEASING.md)). Newest first.

Each version's top section, **Unreleased (next build)**, collects entries merged
to `main` but not yet in a TestFlight build; cutting a release renames it to that
build's heading and opens a fresh empty one. Keep that heading immediately
followed by its list items (no prose between), so the release script can promote
it with a one-line edit — and keep it UNIQUE in the file (the script promotes
the first match).

## [0.1.0]

**Milestone 1 — feel.** A plane, a ground line, two thumbs. Does drag-pitch
plus hold-for-power feel as good as Sopwith's two keys?

### Unreleased (next build)

### build 2 — 2026-09-14

- Two cockpit gauges top right: airspeed in km/h with the stall range in red, and altitude in metres.
- Thumb pads drawn over the game: a pitch track and a trigger ring that float to where the thumbs land and stay, dimmed, where they left them; the bar and knob show how much elevator is in. Near a screen edge the throw shrinks to the room there, so full elevator is always reachable.
- A placeholder app icon: the plane climbing over the strip, drawn by the game's own rig. The duck in a flying cap comes with 1.0.

### build 1 — 2026-09-13

- Repo scaffold: XcodeGen project with iOS and macOS targets under one bundle id, the QuackCore package with a placeholder flight model and tests, QuackKit with a SpriteKit scene, the Makefile and release lane from the sibling games, CI.
- The plane: a cartoon biplane with the duck at the stick, drawn from a livery (three colours and a fin emblem) so companies and rivals are data. It rolls through edge-on when it rights itself, and its gloss catches the sun by attitude.
- Flight model: constant thrust against drag, balancing at cruise. Dives gain speed, shallow climbs hold, steep ones stall.
- The gun: a Vickers on the hump, hold the right thumb (space on the Mac) to fire; rounds fly straight along the heading and expire.
- Rounds are drawn as dark slugs with a warm tracer trail, so they read against the sky.
- Everyone sees the same world: a fixed 16:9 box 70 m tall, letterboxed on other screen shapes; the Mac window keeps the box inside a dark frame at any size.
- Balloons outside the box show as chevrons on its edge, bolder and bigger the nearer they are.
- The balloon run: a dozen seeded balloons ahead of the start, pop them all by gun or by ramming, clock from first input to last pop, fire again for a new field.
- The roll: when the plane rights itself the drawing now rolls in fake 3-D, top toward the camera, each surface at its real height with a mild perspective, instead of a flat squash.
- A real stall: gravity in the speed exchange is much stronger, so a plane pointed straight up runs out of speed within a screen height, breaks decisively and noses over forward. A stalled plane sinks before the nose goes and keeps sinking until airspeed returns. A loop from cruise still makes it round.
- Throttle open for the whole flight; the right thumb is free for the gun. The camera now follows climbs. On the Mac, ↓ pulls the nose up and ↑ pushes it down, the same sense as the thumb drag; an invert option is prepared.
