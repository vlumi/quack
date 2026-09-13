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
- `GunTuning`, `Bullet` — the gun on the hump: rounds leave the muzzle at the
  plane's speed plus a muzzle speed, fly straight, and expire.
- `Practice` — the balloon run: a seeded field of balloons (`SeededRNG`,
  SplitMix64), the plane, the rounds, and a clock that starts at the first
  input and stops at the last pop. Balloons pop by round or by collision.
  Deterministic, so the same inputs give the same run.

The numbers and shapes here are a starting point to be flown and replaced.

## The scene

`FlightScene` (SpriteKit) is a fixed 1280 × 720 box showing 70 m of world
top to bottom, aspect-fit into whatever screen or window it gets (the Mac
window keeps a 16:9 game area inside a dark frame; on iOS the letterbox bars
stay touch surface). It runs the balloon run: a ground line with distance
ticks, the plane, the balloons, the rounds, a two-line clock, and a chevron on
the box's edge for each balloon outside it, on the line from the plane, bolder
and bigger the nearer it is; camera following sideways always and upward once
the plane would leave the top of the view. Touching the ground puts the plane back at the start height; the field
and the clock stay. When the run is done, the next pull of the trigger starts
the next one with the next seed.

`PlaneNode` is the biplane as a rig built from a `Livery` (`PlaneBuilder`
holds the paths and paints, wings from one airfoil function). Every part
knows its height above the fuselage axis and its depth toward the camera, so
a `roll` angle projects each part to where it belongs: side-view parts squash
about their own line, wings and tailplane (`Planform`) are re-drawn from their
projected corners with a mild perspective and cropped where they pass behind
the body, struts are lines between the wings' projected corners on both sides,
and the pilot is a sphere at head height. At 0 it is the side view, at π the
same mirrored, which is the sim's `inverted`; the scene eases between them
over a third of a second, top toward the camera both ways. A gloss layer's
alpha follows the plane's attitude against a fixed sun.

`ThumbControls`: left half of the screen, a vertical drag from wherever the
thumb landed sets the elevator (the thumb defines its own centre;
`throwDistance` points = full throw, pulled down for nose up, and the throw
toward a screen edge shrinks to the room there, never below `minimumThrow`;
`invertedPitch` flips the sense and awaits a setting); right half, holding
fires. The throttle is always open, so `PlaneInput.power` is always true from
the controls. Every touch event also writes `ThumbOverlayState`, which
`ThumbOverlay` (a SwiftUI canvas over the whole screen, bars included, that
takes no touches) draws as the pitch pad and the trigger: floating to where
the thumb landed, dimmed at rest, track, centre, bar and knob, chevrons lit by
the elevator's sense. On macOS, ↓/↑ and space stand in for the thumbs and there
is no overlay.

## Planned

Not built. See [ROADMAP.md](ROADMAP.md) for order and [docs/design.md](docs/design.md)
for the reasoning.

- **Landing**: align on the field's approach angle, descending, cross the
  threshold, and the assist throttles back, flares and rolls out; three failure
  grades (bounce, broken undercarriage, crash); a small bonus for a landing
  flown inside the window without the assist.
- **Livery picker**: the player's own colours and emblem, saved and carried
  into Duckfight; a flapping scarf.
- **Ammunition** bought at the field, and something that shoots back.
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
