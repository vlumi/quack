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
- `AirfieldModel` — everything where the plane meets the ground, wrapping
  `FlightModel`, which only knows the air. An `Airfield` is a stretch of
  ground; `LandingTuning` its dials; `FlightPhase` is flying, approach
  (assist, carrying its aim point), go-around, rollout, parked, taxiing (a plan
  of `TaxiStep`s: swing round, taxi to x), takeoff roll or wrecked, and each
  step returns a `FlightEvent` when something happens.
  `inCone` is the approach cone over the end the plane is flying toward: a
  wedge at the approach angle ± band, `coneLength` out, with a throat over the
  threshold and a floor that rises to what a flare can carry onto the field.
  The assist engages in the cone when the plane is upright, not climbing past
  `noseUpLimit` and not diving past `diveLimit`, aiming just past the threshold
  or the nearest point reachable without diving, if that leaves room to stop;
  it flies a kinematic glide, pulls out quickly, flares and brakes. A hard pull
  aborts it into a go-around, which leaves the assist off until the plane is
  out of the cone. Braking and the takeoff roll are exaggerated so both fit the
  short field. Unassisted contact is graded by path angle:
  touchdown, bounce, broken undercarriage (a repair delay), or crash (a wreck
  delay, then back at the parking spot). Parked, a pull takes off the way the plane faces,
  taxiing back and swinging round first if there is not `takeoffRoom` ahead; a
  push swings it round, taxiing out to room first if needed. Taxiing ignores
  the stick. Lift-off needs rotate speed and the stick back; the field's end is
  a crash. The air half is `AirfieldModel.swift`, the ground half
  `AirfieldModel+Ground.swift`.
- `Tuning` — every dial the tuning panel exposes in one value: `FlightTuning`,
  `GunTuning`, the thumb throw, invert pitch and roll time. `TuningDial.all` is
  the panel's catalog (id, section, key path, range, step). Stored as an
  id-to-number dictionary, so a stored set survives dials being added or
  renamed; `report()` is the Copy button's text, with defaults beside changed
  values.
- `GunTuning`, `Bullet` — the gun on the hump: rounds leave the muzzle at the
  plane's speed plus a muzzle speed, fly straight, and expire. The belt holds
  `capacity` rounds and refills at `rearmRate` a second.
- `Practice` — the balloon run: a seeded set of balloons (`SeededRNG`,
  SplitMix64), the plane parked on `Practice.airfield`, the rounds, and a clock
  that starts at the first input and stops when the plane is parked after the
  last pop. It counts `ammo`: a round per shot, nothing fires when empty, and
  while parked the belt loads a round at a time (`isRearming`), keeping a part
  load on takeoff. Balloons pop by round or by collision. Deterministic, so the same
  inputs give the same run.

The numbers and shapes here are a starting point to be flown and replaced.

## The scene

The field is drawn by `SceneArt`: a tan strip in the ground line with
threshold bars, a windsock beside the middle, and the approach cone over each
end, drawn from `inCone`'s own floor and ceiling with the approach angle
dashed, redrawn when the landing dials change.
The status line under the title says what the plane is doing (pull up to take
off or push to turn around, taxiing, landing, repairing, land to stop the clock) and flashes touchdowns,
bounces, breaks and crashes; a wrecked plane blinks. A white chevron points to
the field when it is off screen.

`FlightScene` (SpriteKit) is a fixed 1280 × 720 box showing 70 m of world
top to bottom, aspect-fit into whatever screen or window it gets (the Mac
window keeps a 16:9 game area inside a dark frame; on iOS the letterbox bars
stay touch surface). It runs the balloon run: a ground line with distance
ticks, the plane, the balloons, the rounds, a two-line clock, two cockpit
gauges top right (`Dial`: airspeed with the stall range in red, and altitude),
and a chevron on
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

**The tuning panel** (`TuningPanel`, behind `QUACK_TUNING`, on unless
`QUACK_NO_TUNING=1`): shaking the phone (UIKit's own shake, via `UIWindow`) or
Debug › Tuning Panel (⌥⌘T, `TuningCommands`) on the Mac posts one
notification, and `GameView` toggles a sheet of sliders over the game. The
flight pauses while it is up. `TuningStore` keeps the values in UserDefaults and
publishes every change, which `GameView` hands to `FlightScene.tuning`; the
scene applies it to the sim, the gun, the controls, the roll and the stall arc
on the airspeed gauge at once and to every new run. The `-quack-tuning` launch
argument opens it, since a simulator cannot be shaken from the command line.
Without the flag there is no shake hook, no menu and no panel, and stored values
are ignored.

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

- **The hand-flown landing bonus**: a landing inside the window without the
  assist earns a little.
- **Livery picker**: the player's own colours and emblem, saved and carried
  into Duckfight; a flapping scarf.
- **Rounds bought at the field**, and something that shoots back.
- **Fuel**, with the wraparound strip and contracts.
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
