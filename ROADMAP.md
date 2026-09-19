# Roadmap

Open, future work only. Shipped milestones live in [CHANGELOG.md](CHANGELOG.md);
the reasoning behind the design is [docs/design.md](docs/design.md); the
technical "what" is [ARCHITECTURE.md](ARCHITECTURE.md). Versions are
indicative, not contractual.

## 0.1 — Feel (in progress)

The only question: does drag-pitch with the throttle open, the energy model
and auto-upright feel as good as Sopwith's two keys? A ground line, one plane,
a loop and a half-loop turn, on a real iPhone and a Mac.

- [x] Decide the throttle: open for the whole flight; the right thumb is
  free for the gun. The engine is thrust against drag, so speed is managed
  with the elevators.
- [x] Decide the plane: a cartoon Camel drawn from a livery, the duck at the
  stick. Liveries and an emblem picker come later; the seam is in.
- [x] The roll: a part-by-part projection, top toward the camera.
- [x] The gun, and the balloon run to use it on.
- [x] The tuning panel: shake the phone, or ⌥⌘T on the Mac; Copy hands the
  values back to become defaults.
- [ ] Fly it. Tune on a device until the half-loop turn is a pleasure and a
  stall is a lesson, not a punishment.
- [ ] Decide the throw distance and response curve for the pitch drag.
- [x] A player-facing setting to invert the pitch sense: on the title screen.
- [ ] Decide: is the plane fun to fly? **If not, stop here.**

## 0.2 — Landing (in progress)

- [x] One field on the ground line, drawn with its approach window. Descend
  inside the window → the assist flares, touches down and rolls out; a hard
  pull aborts it. Outside it: touchdown / bounce / broken undercarriage /
  crash by how steep. Takeoff from parked. The balloon run starts and ends on
  the field.
- [x] Choose the takeoff direction: push to swing round, taxiing to room if
  needed; no warps.
- [x] A belt of rounds that refills a round at a time while parked; belt size
  and rearm rate on the tuning panel.
- [ ] Fly it and tune the window on a device (the Landing section of the
  tuning panel).
- [ ] A small bonus for a hand-flown landing inside the window.

## 0.3 — The strip (in progress)

- [x] A 2.4 km wraparound strip with four fields from the seed; the balloon run
  spread round it, finishing at any field; a tiny minimap of the whole strip.
- [x] Noise terrain: fields on flat shelves, hills to crash into, balloons
  above the ground; the air thins above 120 m to a 250 m ceiling.
- [x] The look: poster shapes over a smooth sky for the seeded hour (dawn,
  noon, evening, night); three parallax layers with villages; houses and trees
  on the strip, solid.
- [ ] Fly it at every hour on a device (the hour dial on the tuning panel).
- [x] Wind = the cloud layer's speed; headwind one way, tailwind the other;
  balloons drift with it. Clouds in front of the plane too, translucent.
- [ ] Fly the wind again: five steps, the fade near the ground, takeoffs and
  landings into and down the wind.

## 0.4 — Courier

- [x] Mail contracts between fields: a board at each field, the trigger picks,
  lift-off loads, landing at the destination pays what is left of the fare.
- [x] Passengers: the same jobs at a premium, but inverted flight, hard
  turns, stalls and bumps cut the fare.
- [ ] Fly a passenger: is the cut too harsh or too kind?
- [x] Fuel: a range clock; costs money and time to refill. An empty tank
  stops the engine and the plane glides to a field, or does not.
- [ ] Fly the tank: is 150 s the right range for a 2.4 km strip?
- [x] Rounds cost money at the field.
- [x] Money buys a bigger tank, a stronger engine, a second seat: the
  hangar, from the title screen; the company's till and upgrades are kept
  on the device.
- [ ] Fly a career: are the prices and the pace of earning right?

## 0.5 — Hazards

- [x] AA guns on the strip: they lead the plane, a hit costs repair time at
  the next stop, three stop the engine, two rounds knock one out.
- [ ] Fly the guns: range, rate and scatter.
- [x] A simple enemy pilot: patrols, pursues, fires bursts, goes down to
  two rounds.
- [ ] Fly the rival: is it a nuisance or a wall? Bombs/guns on a tap of the
  thumb already in use — never a third input.

## 0.6 — Duckfight

- [x] The fight in the sim: seats for humans and rivals, one input per
  seat, two rounds down a plane, respawn at its field, guns as an option,
  most kills at the clock.
- [x] The sync layer, host-authoritative as Skid Jam settled on: input
  wire, host relay, snapshots, client view, roster and lobby messages.
- [x] The Multipeer transport and the session that drives the sync, the
  session tested over a loopback in one process.
- [x] The lobby: host or join, seats, rivals to fill, guns on or off, start.
- [x] The scene for a fight: the other players' planes, the local seat's
  readouts, standings.
- [ ] Fight it on two devices: the link, the lag, the snapshot rate, and
  whether the guest's own plane feels right a moment behind.

## 0.7 — Daily Drop, generation & ranking

- [ ] Daily seed, one attempt, fares as score, nearby sharing.
- [ ] AI pilot flies every generated strip; ranked seed lists as campaigns.

## Later — weather

- [ ] Rain, thunder, snow, from the seed.

## 1.0 — Polish & submission

- [ ] Store build without the tuning panel (`QUACK_NO_TUNING=1`).
- [ ] Icon (a duck in a flying cap at the stick), site at `quack.misaki.fi`,
  App Store Connect listing, privacy answers, TestFlight → review.

## Deliberately out of scope

See [AGENTS.md](AGENTS.md#deliberately-out-of-scope).
