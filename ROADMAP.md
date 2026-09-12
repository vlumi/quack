# Roadmap

Open, future work only. Shipped milestones live in [CHANGELOG.md](CHANGELOG.md);
the reasoning behind the design is [docs/design.md](docs/design.md); the
technical "what" is [ARCHITECTURE.md](ARCHITECTURE.md). Versions are
indicative, not contractual.

## 0.1 — Feel (in progress)

The only question: does drag-pitch plus hold-for-power, with the energy model
and auto-upright, feel as good as Sopwith's two keys? A ground line, one plane,
a loop and a half-loop turn, on a real iPhone and a Mac.

- [ ] Fly it. Tune `FlightTuning` on a device until the half-loop turn is a
  pleasure and a stall is a lesson, not a punishment. Expose the dials in a
  debug overlay if that speeds it up (Skid's Tuning panel is the precedent).
- [ ] Decide the throw distance and response curve for the pitch drag.
- [ ] Decide: is the plane fun to fly? **If not, stop here.**

## 0.2 — Landing

- [ ] One field on the ground line. Approach window: speed below a limit,
  pitch within a band, descending, over the threshold → the assist takes over
  and rolls out. Outside the window: bounce / broken undercarriage / crash by
  how far off.
- [ ] The window as the difficulty dial; a small bonus for a hand-flown
  landing inside it.

## 0.3 — The strip

- [ ] Noise terrain, wraparound (torus), fields on flat ground, parallax
  silhouettes, sky gradient by hour.
- [ ] Wind = the cloud layer's speed; headwind one way, tailwind the other.

## 0.4 — Courier

- [ ] Contracts between fields: mail (indifferent) and passengers (punish
  aerobatics). Pay falls with time.
- [ ] Fuel: drains only while powered; costs money and time to refill.
- [ ] Money buys a bigger tank, a stronger engine, a second seat.

## 0.5 — Hazards

- [ ] AA guns on the strip; a simple enemy pilot. Dodging costs time,
  shooting costs ammunition bought at the field. Bombs/guns on a tap of the
  thumb already in use — never a third input.

## 0.6 — Duckfight

- [ ] 2–4 planes over Nearby, lockstep. Skid Jam's networking is the model.

## 0.7 — Daily Drop, generation & ranking

- [ ] Daily seed, one attempt, fares as score, nearby sharing.
- [ ] AI pilot flies every generated strip; ranked seed lists as campaigns.

## 1.0 — Polish & submission

- [ ] Icon (a duck in a flying cap at the stick), site at `quack.misaki.fi`,
  App Store Connect listing, privacy answers, TestFlight → review.

## Deliberately out of scope

See [AGENTS.md](AGENTS.md#deliberately-out-of-scope).
