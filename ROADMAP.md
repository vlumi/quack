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
- [ ] A player-facing setting to invert the pitch sense (the tuning panel has
  the switch; players need it somewhere they will look).
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

- [ ] Contracts between fields: mail (indifferent) and passengers (punish
  aerobatics). Pay falls with time.
- [ ] Fuel: a range clock; costs money and time to refill. An empty tank
  stops the engine and the plane glides to a field, or does not.
- [ ] Rounds cost money at the field.
- [ ] Money buys a bigger tank, a stronger engine, a second seat.

## 0.5 — Hazards

- [ ] AA guns on the strip; a simple enemy pilot. Dodging costs time,
  shooting costs rounds bought at the field. Bombs/guns on a tap of the
  thumb already in use — never a third input.

## 0.6 — Duckfight

- [ ] 2–4 planes over Nearby, lockstep. Skid Jam's networking is the model.

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
