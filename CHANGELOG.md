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

- Repo scaffold: XcodeGen project with iOS and macOS targets under one bundle id, the QuackCore package with a placeholder flight model and tests, QuackKit with a SpriteKit scene, the Makefile and release lane from the sibling games, CI.
