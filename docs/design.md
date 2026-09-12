# Design

Why Quack Express is the way it is, with the alternatives that were rejected
and the reasons. Distilled from the planning notes of 2026-09-12. What is
*built* is [ARCHITECTURE.md](../ARCHITECTURE.md); *when* is
[ROADMAP.md](../ROADMAP.md).

## The seed

Sopwith (1984): a side-scrolling biplane, two keys for the elevators, a half
loop and release to turn round, bombs on buildings, a landing to rearm. The
handling was the whole game and the levels were a terrain silhouette. That is
the property to keep: **few inputs, endless technique, nothing to author.**

## Rules that filter everything

- **Easy to learn, hard to master.** Two inputs at most, each doing one thing,
  never a third simultaneous input. Difficulty lives in the generated world
  (shorter fields, wind, more guns), never in the controls.
- **No content authoring.** Terrain, fields, contracts, weather and enemy
  placement are generated from a seed. Graphics are line art, silhouettes,
  particles and gradients. Campaigns are lists of ranked seeds.
- **Tilt is out.** Tilt suits games with momentum, where its 30–50 ms latency
  hides behind physics. This game turns on a half loop and needs the input to
  be where the thumb is. Two thumbs also map to two keys, which puts the Mac
  back in.
- **Don't take it seriously.** A duck flies the plane. Modes are called
  Duckfight and Daily Drop.

## Controls

- **Left thumb, vertical drag = elevators.** Distance from where the thumb
  landed sets the pitch rate; the thumb defines its own centre each time.
  A small drag is a gentle climb, a full drag pulls a loop.
- **Release = auto-upright.** The plane rolls to the nearer way up, so
  half-loop-and-release is the turn.
- **Right thumb, hold = power, release = glide.** Period-authentic: engines
  were throttled back to idle on approach. Gives the mental model "let go,
  glide, flare".
- **Energy model underneath**: diving gains speed, climbing bleeds it, the
  engine only holds cruise. Without it, slowing down for a short field is
  impossible; with it, the approach is flown with the elevators.
- **Rejected:** a two-axis virtual stick (vertical pitch, horizontal throttle)
  — closest to Sopwith's keys, but a third thing for the thumb to get right,
  and the easy-to-learn rule wins. **Guns and bombs**, when they come, ride on
  a tap of a thumb already in use, or fire automatically while powered with a
  target ahead. If that ever feels wrong, the war era is its own game, not a
  mode.

## Landing

The approach is the test, the touchdown is automatic. Crossing the field
threshold below a speed limit, inside a pitch window, and descending hands the
plane to the assist, which rolls it out. Outside the window: bounce, broken
undercarriage or crash, by how far off. The window is the difficulty dial
(wide early, narrow later; wind and slope make a good approach harder). A
landing flown inside the window without needing the assist earns a small
bonus: mastery rewarded, not required.

## The world

- **A horizontal torus.** Fly east long enough and you return from the west.
  The strip fits in memory; the shortest way to a contract is sometimes the
  other way round.
- **Noise terrain**, fields placed on flat ground, bridges over gaps, AA guns
  by rules. Parallax silhouettes, a sky gradient for the hour.
- **Wind is the cloud layer's speed.** No gauge. On a wraparound strip that
  makes the two directions genuinely different: headwind one way, tailwind the
  other; later, gusts push the approach and drift bombs.

## The courier economy (single player)

- Contracts appear at fields: pick up here, deliver there, pay falls with
  time. Distance, terrain and wind decide how tempting each is.
- **Mailbags don't care how you fly; passengers do.** Aerobatics with a
  passenger cut the fare. Two contract types, two ways to fly.
- **Fuel drains only while powered**, so gliding is free and rushing costs.
  Refuelling costs money and a stop.
- Fares buy a bigger tank, a stronger engine, a second seat.
- **Hazards as economics, not activity.** AA guns threaten routes; dodging
  costs time, shooting them costs ammunition bought at the field. The courier
  stays a courier; shooting is occasional and instrumental.

## Duckfight (nearby multiplayer)

Two to four planes over MultipeerConnectivity, one strip, each device its own
viewport, deterministic lockstep (Skid Jam's networking is the model). Guns
are the point here. Single-screen shared play on one iPad was considered and
dropped: the original split the screen because both players sat at one
keyboard, and that does not survive a hand-held device.

## Daily Drop

The same seed for everyone, one attempt, fares as score, shared nearby the way
Donpa Squad shares its daily. "Drop" is both the delivery and the bomb.

## Generation and ranking

Every strip is a seed and a difficulty. Fields need flat ground, bridges need
gaps, gun count and placement scale with difficulty. An AI pilot flies every
generated strip before it ships, which both proves it can be completed and
scores it (fuel margin, closest call, time). Campaigns are ranked seed lists
played once by hand, shipped as data; endless and daily modes draw from the
same generator.

## Graphics

Layered terrain silhouettes with parallax, stacked-rectangle buildings, a
line-art biplane, smoke and explosion particles, a sky gradient for the hour.
Fully procedural, and it looks intentional because the original looked like
that too. The one drawn asset is the icon: a duck in a flying cap.

## Name

**Quack Express** (App Store name) with the subtitle **Duck and Deliver**;
the combined form is 31 characters, over the 30-character name limit, so it is
split across the two ASC fields, which is how the store displays it anyway.
The name is the company and stays fixed; the subtitle names the campaign, so
a war era could ship as "Quack Express: Duckfight" without a rename.
Runners-up: Fragile Flyer, Air Mail Circus, Camel Express. Rejected: Crate
Escape (taken), Flying Circus (Python estate; IL-2 Flying Circus in the same
genre), Tailspin Express (homophone of Disney's TaleSpin, same plot), Wing It
(taken), Speedmail (didn't sound like a game).

## Milestone 1, the only question

Fly a ground line, one plane, a loop and a half-loop turn, on a real iPhone
and on a Mac. If drag-pitch plus hold-for-power is not a pleasure, stop before
building anything on it.
