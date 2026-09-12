# Architecture

What Quack Express **is**, as built. Process and conventions live in
[AGENTS.md](AGENTS.md); *when* things happen is [ROADMAP.md](ROADMAP.md); *why*
the design is what it is lives in [docs/design.md](docs/design.md).

Everything before "[Planned](#planned)" describes shipped code. That chapter is
fenced off deliberately, so the notes never blur built and intended.

## Two targets, one seam

| | `QuackCore` | `QuackKit` |
|---|---|---|
| holds | the flight model, plane state and input, tuning | SpriteKit scene, SwiftUI host, touch and keyboard → `PlaneInput` |
| imports | Foundation | SpriteKit, SwiftUI, QuackCore |
| tested | headless, coverage-gated | coverage-ignored |

**Testable logic goes in QuackCore.** A feature that needs platform I/O is a
versioned `Codable` model in QuackCore plus a dumb shim in QuackKit.

## The simulation (as it stands: a milestone-1 placeholder)

Deterministic by construction: same inputs at a fixed timestep give the same
state, bit for bit. `FlightModel.advance(state, input:)` at `tickRate = 60`;
the scene accumulates frame time and steps the model, so feel is independent
of the display's refresh rate.

- `PlaneInput` — elevator in -1…1 and power on/off. Plane-relative.
- `PlaneState` — position, heading (radians, anticlockwise from +x), speed,
  and `inverted`, which says which way the cockpit faces relative to flight.
- `FlightTuning` — every dial in one struct: gravity, cruise and stall speeds,
  engine response, energy exchange, glide drag, pitch and upright rates.
- `FlightModel` — pitch rotates the heading; power holds cruise speed;
  climbing bleeds speed and diving gains it (the energy model); below stall
  the nose falls; **with the elevator released the plane rolls to the nearer
  way up**, so a half loop and release is the turn (the Sopwith rule).

The numbers and shapes here are a starting point to be flown and replaced.

## The scene

`FlightScene` (SpriteKit) draws a ground line with distance ticks and a
line-art biplane, camera following the plane horizontally. Touching the
ground resets the flight (milestone 1 has no landing). `ThumbControls`: left
half of the screen, a vertical drag from wherever the thumb landed sets the
elevator (the thumb defines its own centre; `throwDistance` points = full
throw); right half, holding is power, releasing is glide. On macOS, ↑/↓ and
space stand in for the thumbs.

## Planned

Not built. See [ROADMAP.md](ROADMAP.md) for order and [docs/design.md](docs/design.md)
for the reasoning.

- **Landing** with an approach window and an assisted touchdown; three failure
  grades (bounce, broken undercarriage, crash); a small bonus for a landing
  flown inside the window without the assist.
- **The strip**: noise terrain, horizontal wraparound (a torus), parallax
  silhouettes, fields on flat ground, sky by hour; wind as the cloud layer's
  speed, so one direction is faster than the other.
- **Courier economy**: contracts (mail and passengers) between fields, pay
  falling with time, fuel that costs money and time, passengers that punish
  aerobatics.
- **Hazards**: anti-aircraft guns and a simple enemy pilot; ammunition bought
  at the field; shooting stays occasional and needs no third input.
- **Duckfight**: 2–4 planes over MultipeerConnectivity, one strip, each device
  its own viewport, deterministic lockstep (the sim already qualifies).
- **Daily Drop**: one seed for everyone, one attempt, fares as score, shared
  nearby.
- **Generation and ranking**: every strip is a seed plus a difficulty; an AI
  pilot flies each generated map to prove it completable and to score it;
  campaigns are ranked seed lists shipped as data.

## Deliberately out of scope

See [AGENTS.md](AGENTS.md#deliberately-out-of-scope).
