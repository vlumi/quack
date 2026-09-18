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

- `PlaneInput` — elevator in -1…1, power on/off, and a takeoff request with
  its direction, which only a parked plane hears. Plane-relative.
- `PlaneState` — position, heading (radians, anticlockwise from +x), speed,
  and `inverted`, which says which way the cockpit faces relative to flight.
- `FlightTuning` — every dial in one struct: gravity (well above Earth's, so
  a vertical climb stops within a screen), thrust, cruise and stall speeds,
  the stall band, drop rate and sink, lift-deficit sink, pitch rate, and where the
  air starts to thin and the ceiling. Drag is derived so that thrust and drag
  cancel at cruise. `airDensity(at:)` is 1 up to `thinAirFrom` and falls in a
  straight line to the density at which full power just holds level at stall
  speed at `ceiling`.
- `FlightModel` — thrust is scaled by the air's density at the plane's height
  and the stall speed by one over its square root; pitch rotates the heading;
  thrust pushes and drag grows with
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
  ground at an `elevation`; `LandingTuning` its dials; `FlightPhase` is flying, approach
  (assist, carrying its aim point), go-around, rollout, parked, taxiing (a plan
  of `TaxiStep`s: swing round, taxi to x), takeoff roll or wrecked, and each
  step returns a `FlightEvent` when something happens. `wind` is the air's
  speed along the strip up high and `windTuning` how it fades toward the
  ground (`wind(at:)` is the wind at the plane's height). In the air the
  plane's `speed` is airspeed and each step adds the air's drift, then
  changes the airspeed by the wind met at the new height (the shear). On the
  ground `speed` is over the ground: the takeoff roll rotates when that less
  the ground-level tailwind reaches rotate speed and lifts off at that
  airspeed, `takeoffRoom(facing:)` shrinks into the wind, and `level` turns
  airspeed back into ground speed at touchdown. The assist glides through the
  moving air and re-takes its aim every step.
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
  delay, then back at the parking spot). Parked, `PlaneInput.takeOff` names
  the way to go: facing it, the plane rolls, taxiing back and swinging round
  first if there is not `takeoffRoom` that way; facing the other way it
  swings round, taxiing out to room first if needed. The stick and the
  trigger do nothing on the ground, and taxiing ignores everything. The roll
  lifts off by itself at rotate speed; the field's end is a crash. Heights for the cone and the flare are measured from the field's
  elevation; everywhere else the plane meets the strip's `groundHeight`, so a
  hillside is a crash and the ground roll follows the shelf. The air half is
  `AirfieldModel.swift`, the ground half `AirfieldModel+Ground.swift`.
- `Tuning` — every dial the tuning panel exposes in one value: `FlightTuning`,
  `GunTuning`, the thumb throw, invert pitch, roll time, and an hour that
  overrides the seed's (`timeOfDay(seeded:)`). `TuningDial.all` is
  the panel's catalog (id, section, key path, range, step). Stored as an
  id-to-number dictionary, so a stored set survives dials being added or
  renamed; `report()` is the Copy button's text, with defaults beside changed
  values.
- `GunTuning`, `Bullet` — the gun on the hump: rounds leave the muzzle at the
  plane's speed plus a muzzle speed, fly straight, and expire. The belt holds
  `capacity` rounds and refills at `rearmRate` a second.
- `Strip` — the world: a length that wraps and the fields along it, the first
  of them home. `wrap` puts a position back in 0..<length, `offset` is the
  signed distance the shorter way round, and `image(of:near:)` is a field moved
  by whole laps to sit near a position. `heights` sampled every `spacing` metres
  are the terrain, and `groundHeight(at:)` interpolates them (Catmull-Rom,
  wrapping, never below sea level). `Strip.generate` spreads fields round it
  from a seed, builds seamless hills from octaves of value noise, and cuts a
  flat shelf for each field at the height of its middle, blended into the
  hill on both sides. `scenery` is the houses and trees standing on it
  (`Obstacle`: a kind, a position and a size, with a solid box a little smaller
  than its drawing); `obstacle(at:)` finds the one spanning a position and
  `surfaceHeight(at:)` is the ground or the top of what stands there, which is
  what the plane's clearance and the rounds are measured against. Generated
  scenery stays off every field's shelf and under a line rising at the
  approach angle from its ends. `ValueNoise` is the seamless noise behind the
  hills and the backdrop's ridges. `AirfieldModel` holds a strip and works on the image of the field
  that matters (the one ahead for the cone, the one under the plane on the
  ground), so its arithmetic reads as if the strip were straight; distances
  that must survive the position being wrapped between steps (the approach aim,
  a taxi target) go through `offset`.
- `Practice` — the balloon run: a strip from the seed (2.4 km, four fields),
  balloons spread round it clear of the fields and above the ground (`SeededRNG`, SplitMix64), the
  plane parked at home, the rounds, and a clock that starts at the first input
  and stops when the plane is parked at any field after the last pop. The plane
  and the rounds wrap every step; hits are measured round the seam. It counts `ammo`: a round per shot, nothing fires when empty, and
  while parked the belt loads a round at a time (`isRearming`), keeping a part
  load on takeoff. Rounds stop in the ground and in scenery. `hour` is the
  run's `TimeOfDay` (dawn, noon, evening or night), from the seed. `wind` is
  the seed's `windStep` (`WindStep`: calm, low, medium, strong, gale, a
  quarter of the strongest wind apart, `Wind.step`) times its `windDirection`
  (`Wind.direction`) times `WindTuning.strength`,
  handed to the model every step; `clouds` (`Cloud`, seven from
  `Wind.clouds`) drift at it and wrap, balloons drift at `balloonDrift` of it
  and rise at `balloonRise` to stay 18 m clear of whatever drifts under them,
  rounds leave with it added, and `airDrift` adds up how far the air has
  moved (`Weather.swift`). `resizeFields(to:)` regenerates
  the strip for a new field length, so each field keeps a shelf that fits it.
  Balloons pop by round or by collision. Deterministic, so the same
  inputs give the same run. Its `mode` is the balloon run or the courier
  (`Practice.Mode`), the title screen's choice.
- `Contract`, `CourierTuning`, `CourierEvent` — the courier's day
  (`Courier.swift`): a mail contract from one field to another with a fare
  that falls to a quarter over its window (`pay(after:)`); `offers(at:)`
  posts two per field from the seed and the delivery count, priced by the
  shorter way round; `advanceCourier` runs the board while parked (the
  trigger cycles the pick and does not fire on the ground), loads the pick at
  lift-off, pays on parking at the destination, and loses the bag in a
  crash, reporting each as a `CourierEvent`. A `.passenger` contract pays
  `passengerPremium` times the mail fare and its `payNow` is cut by
  `comfort`: 1 minus the `discomfort` that `ride` adds each step for
  inverted flight, turning faster than `gentleTurn`, stalling, and bounces
  or a broken undercarriage, and a shell bursting on the plane
  (`hitCost`), floored at a quarter, with a `.complaint`
  event at each quarter lost. Fields carry village `name`s
  from `Strip.fieldNames`.
- `Career` — the company between runs (`Career.swift`): the till and the
  levels bought of each `Upgrade` (tank: 50 s of engine a level, three
  levels; engine: 1.5 thrust a level, three levels; seat: one level,
  passenger jobs carry two for two fares), with prices, `buy`, and the
  bonuses. `Codable` with a version. A `Practice` is made with a career: a
  courier run's till starts from it, its tank and thrust carry the bonuses,
  and `apply(_:)` lays the panel's dials under them. `roundPrice` on
  `CourierTuning` is what the courier pays per round rearmed.
- `AAGun`, `Shell`, `HazardTuning`, `HazardEvent` — the guns
  (`Hazards.swift`): `Practice.guns` are placed from the seed clear of the
  fields, courier runs only; `advanceHazards` has each live gun in `range`
  fire a `Shell` every `fireInterval` at the plane's led position (the
  flight time re-taken a few times) with `scatter` from a seeded aim
  generator, flies the shells, bursts one within `burstRadius` of the plane
  as a hit (`hits`, `repairDue`), expires them, and lets rounds knock guns
  out (`gunHealth`). `engineShotOut` at `hitsToStopEngine` forces power
  off like an empty tank; `settleDamage` turns the repair due into a parked
  repair and mends the hits at the next stop. A wreck clears it all.
- `Pilot` — one seat in a run (`Pilot.swift`): a `Brain` (human or rival),
  its plane and phase, rounds, belt, tank, hits and repair due, and the
  rival's own health, patrol stretch and falling state. `Practice.pilots`
  holds every seat; the first is the single player's, and `plane`, `phase`,
  `ammo`, `fuel`, `hits` and the rest on `Practice` read and write that
  seat, so single-player code and the scene address it as before. Every
  device in a lockstep game simulates every seat the same way, which is why
  the local player is nothing special in the sim.
- `DuckfightOptions`, `Standing` — the Duckfight (`Duckfight.swift`): how
  many human and rival seats, whether the guns are dug in, health per plane,
  the respawn delay and the duration. `seatTheDuckfight` parks each human
  at its own field and sets each rival on its own stretch; `advance(inputs:)`
  takes one input per human seat and flies every seat the same way on every
  device (`Practice+Seat.swift` is one seat's share of a step: tank, flight,
  damage settled, belt, rounds). `advanceDuels` bursts humans' rounds on
  any other plane; `damage(seat:by:at:)` is the one door for a hit: health
  and a fall in a Duckfight, with the shooter credited a kill, else repair
  due. A downed seat `fall`s to the ground, waits `respawnDelay`, and is
  back at its field with everything full; the fight ends at `duration`,
  standings by kills. Not yet reachable from the app: the lobby and the
  lockstep come next.
- **The sync layer** (`Sync.swift`, `FightSnapshot.swift`, `Wire.swift`,
  `FightRoster.swift`, `LobbyMessages.swift`) — host-authoritative, as Skid
  Jam settled on after lockstep stalled in Multipeer's bursts: one device
  simulates the one true fight and the rest send thumbs and render
  snapshots, so nothing stalls and nothing diverges. `PlaneInputWire` is a
  player's input in two bytes; `InputPacket` carries the newest eight
  ticks so a lost packet is repaired by the next. `HostRelay` holds the
  freshest input per remote seat (superseding, never rewinding) and hands
  the host's sim its inputs in seat order; `FightSnapshot` is the host's
  word, per seat the pose, what it is doing, health, tallies, belt, tank,
  respawn clock and rounds, hand-packed in `Float32`, every third tick;
  `ClientView` sends thumbs every other frame, buffers snapshots, and
  plays them out a steady, adaptive lag behind the newest (the worst recent
  arrival gap plus one interval) so a bursty link costs latency, not
  rhythm, and `apply(to:)` lays a snapshot over the client's copy of the
  fight for the scene to draw. `FightRoster` seats devices in join order,
  never renumbering; `FightStart` (seed, roster, options, the host's dials)
  builds the same fight everywhere, with `JoinRequest`, `RosterUpdate` and
  `LeaveNotice` as the lobby's other words, JSON behind a tag byte.
  Transport-free and tested in one process.
- `FightTransport`, `FightSession` — the session around a fight
  (`FightSession.swift`), also transport-free: a `FightTransport` sends
  bytes to everyone, reliably or not, and reports peers coming and going
  on the main actor. The session hosts (seating itself as seat 0 and
  advertising) or joins (browsing, then `askToJoin` a chosen host, since a
  room can hold two fights); the host seats a `JoinRequest` or refuses it
  with a reason in the `RosterUpdate`; `startFight` sends a `FightStart`
  and applies it exactly as a guest does; then the host asks it for
  `hostInputs` each tick and `broadcast`s, and a guest `publish`es thumbs
  and draws `view(advancedBy:)`. A guest leaving costs its seat, which flies
  idle mid-fight with the roster frozen; the host leaving ends it for
  everyone. Two sessions are driven against each other over a loopback in
  the tests.
- `EnemyTuning` — the rival pilot (`Enemy.swift`): a rival seat's plane
  flown by `FlightModel` from `enemyInput`, which is the whole mind: pursue
  the courier within `engageRange` with a little lead, else patrol its
  stretch between `minHeight` and `maxHeight`, turning at the ends, the
  elevator set from the shortest turn to the wanted heading; fire in bursts
  when pointed within `fireRange`, going for the nearest human in the air.
  `advanceRivals` flies each rival seat in the wind, takes the humans'
  rounds (`hitRadius`, `health`) and drops it falling until the ground;
  `advanceRivalBullets` flies its rounds and bursts them on any human as
  hits. One a courier run; none in the balloon run.
- `FuelTuning` — the tank in seconds of engine (`Fuel.swift`):
  `burnAndRefuel` drains a second a second whenever the plane is not parked
  or wrecked and fills while parked at `refuelRate`, charging `price` a
  second down to no money and then on credit; the balloon run pays nothing.
  An empty tank forces `power` off before the model sees the input, so the
  engine dies and the plane glides; a takeoff roll without power coasts to
  a stop and parks.
- `Backdrop` — what lies behind the strip, from the seed: three
  `BackdropLayer`s (far ridge, village hills, hedgerows), each a ridge profile
  with the `BackdropProp`s standing on it (houses, a church, windmills, round
  trees, poplars), a parallax (0.15, 0.4, 0.7), a smaller share of the
  camera's climb, and a period of the strip's length times its parallax, so a
  lap of the strip is a lap of every layer. Nothing in it can be touched.

The numbers and shapes here are a starting point to be flown and replaced.

## The scene

**The look** is poster shapes over a quiet sky, owned by `StripLook` and built
again when the run, its hour or its scenery changes. `Palette` holds the
hour's colours: a three-stop sky, a tint that shades everything toward the
light, a haze the far layers fade into, the sun or moon, and how bright the
stars and lit windows are. `SkyNode` is fixed to the box: a smooth gradient
texture, stars at night, the sun with a soft glow or the moon as a crescent
over its earthshine disc, and poster clouds sliding at 0.08 of the plane's
speed and drifting with `airDrift`. `StripLook.clouds` are the run's clouds in
front of the plane and balloons, each one flat-bottomed shape so its
translucency is even. `SceneArt.setWindsock` gives each field's sock
one shape per wind step, pointing downwind, flapping in a gale. `BackdropNode` redraws each layer's ridge across the box every frame in
two tones (a lit band over a shaded body) and slides its props into place.
`PropArt` draws every house, church, windmill (sails turning), hangar and
tree as flat shapes with no outlines, trees as lozenges lit down one side. On
the strip the ground is `groundHeight` sampled every 2 m a screen either side
of the plane, a lit band over a shaded body; scenery stands behind its edge;
a hangar sits behind each field, left of the windsock, and is not solid. The
readouts turn pale at night. Each field is drawn by `SceneArt` at its
elevation: a tan strip in the ground line with
threshold bars, a windsock beside the middle, and the approach guide over each
end: the cone's own floor and ceiling from `inCone`, drawn once into a texture
as a soft amber glow, feathered at its edges and fading out toward the far
end, added over whatever is behind it, so it reads as a rough guide rather
than a rule; rebuilt when the landing dials change, and faded out while the
plane is on the ground or wrecked. Everything on the strip (fields,
balloons, rounds) is placed every frame at its lap nearest the plane, so the
seam never shows. `Minimap`, under the status line, draws the whole world shrunk
into a box, squeezed harder side to side than up and down, as tall as the
ceiling: the hills as a silhouette with field marks on their shelves, a dot per balloon at its height, and the plane at
its height, pointing the way it flies.
The status line under the title says what the plane is doing (pull up to take
off or push to turn around, taxiing, landing, repairing, land at any field to stop the clock) and flashes touchdowns,
bounces, breaks and crashes; a wrecked plane blinks. A white chevron points to
the destination while carrying, else the nearest field, when it is off
screen; the minimap lights the destination's mark red; each field's name
stands on a board by its windsock; the readouts show the courier's money and
the pay now for the job aboard, and the status line the board's pick; the chevrons dodge the readouts, the
status line and minimap, and the gauges.

`FlightScene` (SpriteKit) is a fixed 1280 × 720 box showing 70 m of world
top to bottom, aspect-fit into whatever screen or window it gets (the Mac
window keeps a 16:9 game area inside a dark frame; on iOS the letterbox bars
stay touch surface). It runs the balloon run: the ground, the plane, the balloons, the rounds, a two-line clock, two cockpit
gauges top right (`Dial`, each with a symbol on its face: fuel as a share of
the tank with the last fifth in red, airspeed with the stall range in red,
and altitude above sea level to 300 m with the thinning air in amber and
the ceiling upward in red), a `Tally` of balloons left and one of rounds in
the belt under the readouts,
and a chevron on
the box's edge for each balloon outside it, on the line from the plane, bolder
and bigger the nearer it is; camera following sideways always, keeping the lowest ground near the plane on
its anchor line, and rising once the plane would leave the top of the view. A
crash puts the plane back at the parking spot after the wreck delay; the
balloons and the clock stay. When the run is done, the next pull of the trigger starts
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

The rival is a second `PlaneNode` in the rival livery, placed each frame
with its rounds as tracers and a red chevron when off screen; a burst marks
each round that finds it and a bigger one where it meets the ground.
`MultipeerTransport` is the `FightTransport` in the app, after Skid Jam's:
infrastructure Wi-Fi or peer-to-peer Wi-Fi and Bluetooth, the guest
inviting and the host accepting anyone, every call into Multipeer on one
serial queue (sends and teardowns block, and froze Skid's lobby from the
main thread three times) and every callback hopped to the main actor. The
service type `quack-fight` matches the `NSBonjourServices` in the plists;
the Mac sandbox has the network client and server entitlements. `DeviceName`
keys a device by its name plus a random suffix, since two iPhones are both
"iPhone", and shows the name alone.

`HazardArt` draws each gun as a sandbag ring with a barrel that tracks the
plane (drooping, faded, when knocked out), a muzzle puff when it fires, the
shells as dark rounds with a short trail, and a burst where one hits; the
status line flashes the hit, the engine going, and a gun knocked out.

**A fight on screen.** `FlightScene` flies and reads out one `localSeat`
(seat 0 in single player; in a fight, the session's) through `me`, and draws
every other seat as a `PlaneNode` in its livery with its rounds and a chevron
(`resetSeats`, `placeSeats`). `startFight` builds the fight from the
session's start and keeps the host's dials rather than the panel's. On the
host, each step takes `hostInputs` and `broadcast`s; on a guest, thumbs are
`publish`ed and the `view` snapshot is laid over the local copy each frame,
with hits and downs read off the differences between snapshots. The readouts
show the time left and the seat's tally; a downed seat's status counts down
its return; `HUDState` carries the standings for the `FightOverScreen`.
`LobbyScreen`, off the title, hosts or joins, shows the roster, sets rivals,
guns and duration, and starts; the `FightSession` lives in `GameView` with a
`MultipeerTransport`, and the host leaving mid-fight sends the guest back to
the lobby with the reason.

**The parked panel** (`ParkedPanel`, SwiftUI) sits at the bottom while the
plane is parked: the board's jobs as cards (`FlightScene.pick`) and two
take-off buttons (`FlightScene.takeOff(direction:)`, handed to the next
step's input). The scene publishes what it needs through `HUDState`,
touched only on a change. The thumb overlay hides while parked; on the Mac
the arrow keys take off and the digits pick.

**The company** lives in `CareerStore` (UserDefaults, JSON; a career from
another version is dropped): the scene is given the career before each
`start` and tells `onMoneyChange` the till whenever it changes while
parked, which the store keeps. `HangarScreen`, off the title, shows the till
and each upgrade's level and next price, and buys.

**The title screen** (`TitleScreen`, SwiftUI) sits over the scene, which
keeps running the seeded world with inputs ignored (`FlightScene.attract`):
the name, Courier, Balloon run or Hangar (`FlightScene.start(_:)`, which keeps the
untouched run behind the title when its mode matches), and the invert-pitch
switch, the one player setting, which `TuningStore` keeps in UserDefaults in
every build. `GameView` holds the screen state: title, playing (a
`PauseButton` at the bottom middle, between the thumbs' halves; Escape on the
Mac) and paused (`PauseMenu`: resume, or quit back to the title, where the
world goes on as the attract mode).

**The tuning panel** (`TuningPanel`, behind `QUACK_TUNING`, on unless
`QUACK_NO_TUNING=1`): shaking the phone (UIKit's own shake, via `UIWindow`) or
Debug › Tuning Panel (⌥⌘T, `TuningCommands`) on the Mac posts one
notification, and `GameView` toggles a sheet of sliders over the game (invert pitch is on both
the panel and the title screen: one value). The
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
- **Fuel**, with contracts.
- **Weather**: rain, thunder, snow.
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
