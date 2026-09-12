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
- `FlightTuning` — every dial in one struct: gravity (well above Earth's, so
  a vertical climb stops within a screen), thrust, cruise and stall speeds,
  the stall band, drop rate and sink, lift-deficit sink, pitch rate. Drag is derived
  so that thrust and drag cancel at cruise.
- `FlightModel` — pitch rotates the heading; thrust pushes and drag grows with
  the square of speed; the vertical component of gravity trades speed for
  height, so a dive gains speed past cruise, a shallow climb holds, a steep one
  bleeds to a stall; below stall the plane sinks at once and the nose falls
  toward straight down, both at full strength a band below stall speed and
  fading as airspeed returns, and a plane pointed straight up noses over
  forward; **with the elevator released
  the plane rolls to the nearer way up**, so a half loop and release is the
  turn (the Sopwith rule).
- `Livery` — the paint on a plane: body, wing and trim colours plus a fin
  emblem (roundel, star, chequer). Pure data, `Codable`, with three built-ins.

The numbers and shapes here are a starting point to be flown and replaced.

## The scene

`FlightScene` (SpriteKit) draws a ground line with distance ticks and the
plane, camera following sideways always and upward once the plane would leave
the top of the view. Touching the ground resets the flight (milestone 1 has no
landing). `PlaneArt` builds the biplane from a `Livery` as filled and stroked
paths (wings from one airfoil function), plus a gloss layer whose alpha the
scene sets each frame from the plane's attitude against a fixed sun. When the
sim flips `inverted`, the scene rolls the drawing through edge-on over a
quarter second. `ThumbControls`: left half of the screen, a vertical drag from
wherever the thumb landed sets the elevator (the thumb defines its own centre;
`throwDistance` points = full throw, pulled down for nose up; `invertedPitch`
flips the sense and awaits a setting); the right half is reserved for the gun.
The throttle is always open, so `PlaneInput.power` is always true from the
controls. On macOS, ↓/↑ stand in for the thumb, same sense.

## Planned

Not built. See [ROADMAP.md](ROADMAP.md) for order and [docs/design.md](docs/design.md)
for the reasoning.

- **Landing**: align on the field's approach angle, descending, cross the
  threshold, and the assist throttles back, flares and rolls out; three failure
  grades (bounce, broken undercarriage, crash); a small bonus for a landing
  flown inside the window without the assist.
- **Livery picker**: the player's own colours and emblem, saved and carried
  into Duckfight; a front-view drawing for the middle of the roll; a flapping
  scarf.
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
